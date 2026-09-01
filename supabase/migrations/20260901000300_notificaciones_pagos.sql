-- =============================================================================
-- Migración: Notificaciones de eventos de pago (in-app + push FCM).
-- -----------------------------------------------------------------------------
-- Faltaban notificaciones para los eventos de dinero del flujo:
--   * Depósito confirmado            → paciente (confirmar_deposito_solicitud)
--   * Saldo pagado / cita completada → paciente (confirmar_pago_saldo)
--   * Liquidación pagada             → especialista (registrar_pago_especialista)
--   * Nueva liquidación disponible   → especialista (generar_liquidaciones)
-- Se crea una función helper `notificar_usuario_push(...)` (patrón de
-- `notificar_cambio_estado_cita` de 20260824000100) que inserta en
-- `notificaciones` y dispara la edge function `send-push` vía pg_net si
-- `push_notifications` está habilitado. Los RPCs se redefinen (CREATE OR
-- REPLACE) para llamar al helper en el punto de éxito.
-- Idempotente. Aplicar en orden ascendente.
-- =============================================================================

-- ── 0. Helper de notificación in-app + push FCM ──────────────────────────────
CREATE OR REPLACE FUNCTION public.notificar_usuario_push(
    p_usuario_id uuid,
    p_titulo     text,
    p_mensaje    text,
    p_tipo       text,
    p_data       jsonb DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_push_enabled text;
    v_base_url     text;
    v_anon_key     text;
    v_tokens       text[];
    v_url          text;
    v_payload      jsonb;
BEGIN
    IF p_usuario_id IS NULL THEN
        RETURN;
    END IF;

    -- Notificación in-app.
    INSERT INTO public.notificaciones (usuario_id, titulo, mensaje, tipo, fecha_envio)
    VALUES (p_usuario_id, p_titulo, p_mensaje, p_tipo, now());

    -- Push FCM (opcional).
    IF to_regnamespace('net') IS NOT NULL THEN
        SELECT COALESCE(valor, 'false') INTO v_push_enabled
          FROM public.configuracion_sistema WHERE clave = 'push_notifications';
        IF lower(v_push_enabled) = 'true' THEN
            SELECT COALESCE(valor, '') INTO v_base_url
              FROM public.configuracion_sistema WHERE clave = 'edge_function_base_url';
            SELECT COALESCE(valor, '') INTO v_anon_key
              FROM public.configuracion_sistema WHERE clave = 'anon_key';
            IF v_base_url <> '' AND v_anon_key <> '' THEN
                SELECT COALESCE(array_agg(d.token_fcm), array[]::text[])
                  INTO v_tokens
                  FROM public.dispositivos_usuario d
                 WHERE d.usuario_id = p_usuario_id
                   AND d.activo = true
                   AND d.token_fcm IS NOT NULL;
                IF v_tokens IS NOT NULL AND array_length(v_tokens, 1) > 0 THEN
                    v_url := rtrim(v_base_url, '/') || '/send-push';
                    v_payload := jsonb_build_object(
                        'tokens', to_jsonb(v_tokens),
                        'titulo', p_titulo,
                        'mensaje', p_mensaje,
                        'data', COALESCE(p_data, '{}'::jsonb)
                    );
                    PERFORM net.http_post(
                        url := v_url,
                        headers := jsonb_build_object(
                            'Content-Type', 'application/json',
                            'Authorization', 'Bearer ' || v_anon_key
                        ),
                        body := v_payload
                    );
                END IF;
            END IF;
        END IF;
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.notificar_usuario_push(uuid, text, text, text, jsonb)
    TO authenticated;

-- ── 1. confirmar_deposito_solicitud: notifica al paciente ────────────────────
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
    v_usuario          uuid;
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

    -- 5) Notificación al paciente.
    SELECT pa.usuario_id INTO v_usuario
      FROM public.pacientes pa WHERE pa.id = v_paciente_id;
    IF v_usuario IS NOT NULL THEN
        PERFORM public.notificar_usuario_push(
            v_usuario,
            'Depósito confirmado',
            'Tu depósito fue confirmado. Tu solicitud ya está publicada.',
            'PAGO',
            jsonb_build_object('solicitud_id', p_solicitud_id, 'monto', p_monto)
        );
    END IF;

    RETURN json_build_object('ok', true, 'solicitud_id', p_solicitud_id,
                             'estado', 'PUBLICADA', 'fecha_expiracion', v_expiracion,
                             'motivo', 'CONFIRMADA');
END;
$$;

GRANT EXECUTE ON FUNCTION public.confirmar_deposito_solicitud(uuid, text, text, numeric)
    TO authenticated;

-- ── 2. confirmar_pago_saldo: notifica al paciente ─────────────────────────────
CREATE OR REPLACE FUNCTION public.confirmar_pago_saldo(
    p_solicitud_id      uuid,
    p_cita_id           uuid,
    p_monto             numeric,
    p_stripe_payment_id text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_saldo               numeric;
    v_paciente_id         uuid;
    v_usuario             uuid;
    v_especialista_ok     boolean;
    v_pago_ok             boolean;
BEGIN
    SELECT p.saldo_pendiente, s.paciente_id,
           EXISTS (SELECT 1 FROM public.citas c
                    WHERE c.id = p_cita_id
                      AND c.especialista_id = (
                          SELECT e.id FROM public.especialistas e
                           WHERE e.usuario_id = auth.uid() LIMIT 1))
      INTO v_saldo, v_paciente_id, v_especialista_ok
      FROM public.pagos p
      JOIN public.solicitudes s ON s.id = p.solicitud_id
     WHERE p.solicitud_id = p_solicitud_id;

    IF v_saldo IS NULL THEN
        RETURN json_build_object('ok', false, 'motivo', 'NO_ENCONTRADO');
    END IF;

    IF NOT (v_especialista_ok OR public.is_administrador() OR auth.role() = 'service_role') THEN
        RETURN json_build_object('ok', false, 'motivo', 'NO_AUTORIZADO');
    END IF;

    IF EXISTS (SELECT 1 FROM public.transacciones t
                WHERE t.cita_id = p_cita_id
                  AND t.tipo_transaccion = 'SALDO'
                  AND t.estado = 'APROBADO') THEN
        RETURN json_build_object('ok', false, 'motivo', 'YA_REGISTRADA');
    END IF;

    IF round(p_monto, 2) <> round(v_saldo, 2) THEN
        INSERT INTO public.transacciones
            (solicitud_id, cita_id, paciente_id, tipo_transaccion, monto, moneda,
             estado, stripe_payment_id, stripe_payment_intent, fecha_transaccion)
        VALUES
            (p_solicitud_id, p_cita_id, v_paciente_id, 'SALDO', p_monto, 'USD',
             'FALLIDA', p_stripe_payment_id, p_stripe_payment_id, now());
        RETURN json_build_object('ok', false, 'motivo', 'MONTO_INCORRECTO');
    END IF;

    UPDATE public.pagos
       SET estado = 'PAGADO'::estado_pago_enum,
           saldo_pendiente = 0,
           updated_at = now()
     WHERE solicitud_id = p_solicitud_id;

    INSERT INTO public.transacciones
        (solicitud_id, cita_id, paciente_id, tipo_transaccion, monto, moneda,
         estado, stripe_payment_id, stripe_payment_intent, fecha_transaccion)
    VALUES
        (p_solicitud_id, p_cita_id, v_paciente_id, 'SALDO', p_monto, 'USD',
         'APROBADO', p_stripe_payment_id, p_stripe_payment_id, now());

    -- Notificación al paciente.
    SELECT pa.usuario_id INTO v_usuario
      FROM public.pacientes pa WHERE pa.id = v_paciente_id;
    IF v_usuario IS NOT NULL THEN
        PERFORM public.notificar_usuario_push(
            v_usuario,
            'Saldo pagado',
            'Tu saldo fue pagado. Tu tratamiento está completado.',
            'PAGO',
            jsonb_build_object('cita_id', p_cita_id, 'monto', p_monto)
        );
    END IF;

    RETURN json_build_object('ok', true, 'motivo', 'OK');
END;
$$;

GRANT EXECUTE ON FUNCTION public.confirmar_pago_saldo(uuid, uuid, numeric, text)
    TO authenticated, service_role;

-- ── 3. registrar_pago_especialista: notifica al especialista ──────────────────
CREATE OR REPLACE FUNCTION public.registrar_pago_especialista(
    p_liquidacion_id   uuid,
    p_metodo_pago      text,
    p_referencia_pago  text,
    p_comprobante_url  text,
    p_notas            text,
    p_monto_pagado     numeric DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_estado      text;
    v_especialista uuid;
    v_usuario     uuid;
    v_monto       numeric;
    v_monto_pagado numeric;
BEGIN
    IF NOT public.is_administrador() THEN
        RETURN json_build_object('ok', false, 'motivo', 'NO_AUTORIZADO');
    END IF;

    SELECT l.estado, l.especialista_id, l.monto_pagar
      INTO v_estado, v_especialista, v_monto
      FROM public.liquidaciones_especialistas l
     WHERE l.id = p_liquidacion_id;

    IF v_estado IS NULL THEN
        RETURN json_build_object('ok', false, 'motivo', 'NO_ENCONTRADA');
    END IF;

    IF v_estado = 'PAGADA' THEN
        RETURN json_build_object('ok', false, 'motivo', 'YA_PAGADA');
    END IF;

    IF v_estado <> 'APROBADA' THEN
        RETURN json_build_object('ok', false, 'motivo', 'ESTADO_INVALIDO');
    END IF;

    INSERT INTO public.pagos_especialistas
        (liquidacion_id, especialista_id, fecha_pago, monto_pagado,
         metodo_pago, referencia_pago, comprobante_url, notas)
    VALUES
        (p_liquidacion_id, v_especialista, now(),
         COALESCE(p_monto_pagado, v_monto),
         p_metodo_pago, p_referencia_pago, p_comprobante_url, p_notas);

    UPDATE public.liquidaciones_especialistas
       SET estado = 'PAGADA',
           fecha_pago = now()
     WHERE id = p_liquidacion_id;

    v_monto_pagado := COALESCE(p_monto_pagado, v_monto);

    -- Notificación al especialista.
    SELECT e.usuario_id INTO v_usuario
      FROM public.especialistas e WHERE e.id = v_especialista;
    IF v_usuario IS NOT NULL THEN
        PERFORM public.notificar_usuario_push(
            v_usuario,
            'Liquidación pagada',
            'Tu liquidación fue pagada. Ver el comprobante en Mis liquidaciones.',
            'LIQUIDACION',
            jsonb_build_object('liquidacion_id', p_liquidacion_id, 'monto', v_monto_pagado)
        );
    END IF;

    RETURN json_build_object('ok', true, 'motivo', 'OK',
                             'monto_pagado', v_monto_pagado);
END;
$$;

GRANT EXECUTE ON FUNCTION public.registrar_pago_especialista(
    uuid, text, text, text, text, numeric)
    TO authenticated;

-- ── 4. generar_liquidaciones: notifica a cada especialista con corte nuevo ────
CREATE OR REPLACE FUNCTION public.generar_liquidaciones(
    p_fecha_inicio date,
    p_fecha_fin    date
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_pct             numeric := 20;
    v_esp_id          uuid;
    v_usuario         uuid;
    v_total           numeric := 0;
    v_com             numeric := 0;
    v_pagar           numeric := 0;
    v_liquidacion_id  uuid;
    v_cita            record;
    v_especialistas   int := 0;
    v_citas           int := 0;
    v_grand_total     numeric := 0;
    v_grand_comision  numeric := 0;
    v_grand_pagar     numeric := 0;
BEGIN
    IF NOT public.is_administrador() THEN
        RETURN json_build_object('ok', false, 'motivo', 'NO_AUTORIZADO');
    END IF;

    SELECT COALESCE(valor::numeric, 20) INTO v_pct
      FROM public.configuracion_sistema
     WHERE clave = 'comision_porcentaje' AND activo = true;
    IF v_pct IS NULL THEN v_pct := 20; END IF;

    FOR v_esp_id IN
        SELECT c.especialista_id
          FROM public.citas c
          JOIN public.solicitudes s ON s.id = c.solicitud_id
          JOIN public.pagos p ON p.solicitud_id = s.id
         WHERE c.estado = 'FINALIZADA'
           AND c.fecha_finalizacion IS NOT NULL
           AND c.fecha_finalizacion::date BETWEEN p_fecha_inicio AND p_fecha_fin
           AND p.estado = 'PAGADO'
           AND p.saldo_pendiente <= 0
           AND EXISTS (SELECT 1 FROM public.tratamientos t
                        WHERE t.cita_id = c.id AND t.estado = 'COMPLETADO')
           AND NOT EXISTS (SELECT 1 FROM public.liquidacion_detalles ld
                            WHERE ld.cita_id = c.id)
         GROUP BY c.especialista_id
    LOOP
        SELECT COALESCE(SUM(p.monto_total), 0)
          INTO v_total
          FROM public.citas c
          JOIN public.solicitudes s ON s.id = c.solicitud_id
          JOIN public.pagos p ON p.solicitud_id = s.id
         WHERE c.especialista_id = v_esp_id
           AND c.estado = 'FINALIZADA'
           AND c.fecha_finalizacion IS NOT NULL
           AND c.fecha_finalizacion::date BETWEEN p_fecha_inicio AND p_fecha_fin
           AND p.estado = 'PAGADO'
           AND p.saldo_pendiente <= 0
           AND EXISTS (SELECT 1 FROM public.tratamientos t
                        WHERE t.cita_id = c.id AND t.estado = 'COMPLETADO')
           AND NOT EXISTS (SELECT 1 FROM public.liquidacion_detalles ld
                            WHERE ld.cita_id = c.id);

        v_com   := round(v_total * v_pct / 100, 2);
        v_pagar := round(v_total - v_com, 2);

        INSERT INTO public.liquidaciones_especialistas
            (especialista_id, fecha_inicio, fecha_fin, monto_total_servicios,
             monto_comision, monto_pagar, estado)
        VALUES
            (v_esp_id, p_fecha_inicio, p_fecha_fin, v_total, v_com, v_pagar, 'PENDIENTE')
        RETURNING id INTO v_liquidacion_id;

        FOR v_cita IN
            SELECT c.id AS cita_id, p.monto_total
              FROM public.citas c
              JOIN public.solicitudes s ON s.id = c.solicitud_id
              JOIN public.pagos p ON p.solicitud_id = s.id
             WHERE c.especialista_id = v_esp_id
               AND c.estado = 'FINALIZADA'
               AND c.fecha_finalizacion IS NOT NULL
               AND c.fecha_finalizacion::date BETWEEN p_fecha_inicio AND p_fecha_fin
               AND p.estado = 'PAGADO'
               AND p.saldo_pendiente <= 0
               AND EXISTS (SELECT 1 FROM public.tratamientos t
                            WHERE t.cita_id = c.id AND t.estado = 'COMPLETADO')
               AND NOT EXISTS (SELECT 1 FROM public.liquidacion_detalles ld
                                WHERE ld.cita_id = c.id)
        LOOP
            INSERT INTO public.liquidacion_detalles
                (liquidacion_id, cita_id, monto_servicio, comision_aplicada, monto_especialista)
            VALUES
                (v_liquidacion_id, v_cita.cita_id, v_cita.monto_total,
                 round(v_cita.monto_total * v_pct / 100, 2),
                 round(v_cita.monto_total - v_cita.monto_total * v_pct / 100, 2));

            INSERT INTO public.comisiones
                (cita_id, porcentaje, monto_comision, monto_especialista)
            VALUES
                (v_cita.cita_id, v_pct,
                 round(v_cita.monto_total * v_pct / 100, 2),
                 round(v_cita.monto_total - v_cita.monto_total * v_pct / 100, 2));

            v_citas := v_citas + 1;
        END LOOP;

        -- Notificación al especialista con corte nuevo.
        SELECT e.usuario_id INTO v_usuario
          FROM public.especialistas e WHERE e.id = v_esp_id;
        IF v_usuario IS NOT NULL THEN
            PERFORM public.notificar_usuario_push(
                v_usuario,
                'Nueva liquidación disponible',
                'Se generó tu corte semanal. Revisa tu historial de liquidaciones.',
                'LIQUIDACION',
                jsonb_build_object('liquidacion_id', v_liquidacion_id, 'monto', v_pagar)
            );
        END IF;

        v_especialistas  := v_especialistas + 1;
        v_grand_total    := v_grand_total + v_total;
        v_grand_comision := v_grand_comision + v_com;
        v_grand_pagar    := v_grand_pagar + v_pagar;
    END LOOP;

    RETURN json_build_object(
        'ok', true, 'motivo', 'OK',
        'especialistas', v_especialistas,
        'citas', v_citas,
        'monto_total', v_grand_total,
        'monto_comision', v_grand_comision,
        'monto_pagar', v_grand_pagar
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.generar_liquidaciones(date, date)
    TO authenticated;