-- =============================================================================
-- Migración: fix de cast en `confirmar_deposito_solicitud`.
-- -----------------------------------------------------------------------------
-- `pagos.estado` es del tipo enum `estado_pago_enum`; el `CASE` del UPDATE
-- devuelve `text` y Postgres no lo castea implícitamente ("column estado is of
-- type estado_pago_enum but expression is of type text"). Se castea el CASE a
-- `estado_pago_enum`. Idempotente (CREATE OR REPLACE).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.confirmar_deposito_solicitud(
    p_solicitud_id      uuid,
    p_stripe_payment_id text,
    p_concepto          text,
    p_monto             numeric
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_sid              uuid;
    v_estado           text;
    v_paciente_id      uuid;
    v_solicitud_radio  numeric;
    v_tipo             text;
    v_expiracion_horas numeric;
    v_radio_km         numeric;
    v_enforce          text;
    v_expiracion       timestamptz;
BEGIN
    SELECT s.id, s.estado, s.paciente_id, s.radio_busqueda
      INTO v_sid, v_estado, v_paciente_id, v_solicitud_radio
      FROM public.solicitudes s
     WHERE s.id = p_solicitud_id;

    IF v_sid IS NULL THEN
        RETURN json_build_object('ok', false, 'motivo', 'NO_ENCONTRADA');
    END IF;

    -- Idempotente: ya confirmada o publicada → no duplicar transacción.
    IF v_estado IN ('PUBLICADA', 'BUSCANDO_ESPECIALISTA', 'ACEPTADA')
       OR EXISTS (
           SELECT 1 FROM public.transacciones t
            WHERE t.solicitud_id = p_solicitud_id
              AND t.estado = 'APROBADO'
              AND t.tipo_transaccion IN ('DEPOSITO', 'ADELANTO', 'PAGO_TOTAL')
       ) THEN
        RETURN json_build_object('ok', true, 'solicitud_id', p_solicitud_id,
                                 'estado', v_estado, 'motivo', 'YA_CONFIRMADA');
    END IF;

    IF v_estado NOT IN ('PENDIENTE_PAGO', 'BORRADOR') THEN
        RETURN json_build_object('ok', false, 'motivo', 'ESTADO_INVALIDO');
    END IF;

    -- Gate: en producción solo el webhook (service_role) puede publicar.
    SELECT COALESCE(valor, 'true') INTO v_enforce
      FROM public.configuracion_sistema WHERE clave = 'enforce_pago_real';
    IF lower(v_enforce) = 'true' AND auth.role() <> 'service_role' THEN
        RAISE EXCEPTION 'El pago debe confirmarse vía webhook (enforce_pago_real activo)';
    END IF;

    v_tipo := CASE upper(COALESCE(p_concepto, 'ADELANTO'))
                WHEN 'PAGO_TOTAL' THEN 'PAGO_TOTAL'
                WHEN 'DEPOSITO'   THEN 'DEPOSITO'
                ELSE 'DEPOSITO'
              END;

    -- 1) Transacción confirmada ANTES del UPDATE (el trigger de publicación la exige).
    INSERT INTO public.transacciones (
        solicitud_id, paciente_id, tipo_transaccion, monto, moneda, estado,
        stripe_payment_id, stripe_payment_intent, fecha_transaccion, created_at
    ) VALUES (
        p_solicitud_id, v_paciente_id, v_tipo, p_monto, 'USD', 'APROBADO',
        p_stripe_payment_id, p_stripe_payment_id, now(), now()
    );

    -- 2) Obligación de pago (cast al enum `estado_pago_enum`).
    UPDATE public.pagos
       SET deposito        = p_monto,
           saldo_pendiente = GREATEST(0, monto_total - p_monto),
           estado          = CASE WHEN GREATEST(0, monto_total - p_monto) <= 0
                                  THEN 'PAGADO' ELSE 'PARCIAL' END::estado_pago_enum,
           updated_at      = now()
     WHERE solicitud_id = p_solicitud_id;

    -- 3) Config de expiración y radio.
    SELECT COALESCE(valor, '24') INTO v_expiracion_horas
      FROM public.configuracion_sistema WHERE clave = 'solicitud_expiracion_horas';
    SELECT COALESCE(valor, '10') INTO v_radio_km
      FROM public.configuracion_sistema WHERE clave = 'radio_busqueda_km';
    v_expiracion := now() + (v_expiracion_horas::numeric * interval '1 hour');

    -- 4) Publica (marca local para el trigger de publicación).
    PERFORM set_config('app.pago_confirmado', 'true', true);

    UPDATE public.solicitudes
       SET deposito_pagado   = true,
           estado            = 'PUBLICADA',
           radio_busqueda    = COALESCE(v_solicitud_radio, v_radio_km),
           fecha_expiracion  = v_expiracion,
           updated_at        = now()
     WHERE id = p_solicitud_id;

    RETURN json_build_object('ok', true, 'solicitud_id', p_solicitud_id,
                             'estado', 'PUBLICADA', 'fecha_expiracion', v_expiracion,
                             'motivo', 'CONFIRMADA');
END;
$$;

GRANT EXECUTE ON FUNCTION public.confirmar_deposito_solicitud(uuid, text, text, numeric)
    TO authenticated;
