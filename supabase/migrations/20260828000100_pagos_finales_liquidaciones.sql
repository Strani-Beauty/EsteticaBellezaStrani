-- Pagos finales, transacciones y conciliación (Stripe + liquidaciones)
-- Idempotente. Aplicar en orden ascendente de nombre.
-- 1) CHECK de estado en transacciones (PENDIENTE/PROCESADA/APROBADO/FALLIDA/REEMBOLSADA).
-- 2) Cierre de huecos RLS: el especialista ya no puede UPDATE directo de pagos ni INSERT
--    directo de transacciones; el cobro del saldo pasa por RPC SECURITY DEFINER.
-- 3) RPC confirmar_pago_saldo: valida monto == saldo_pendiente, registra SALDO APROBADO.
-- 4) RPC registrar_pago_fallido: registra FALLIDA sin tocar pagos.
-- 5) RPC generar_liquidaciones: agrupa citas FINALIZADA + tratamiento COMPLETADO + pago
--    PAGADO por especialista y puebla comisiones / liquidaciones_especialistas /
--    liquidacion_detalles.

-- ── 1. CHECK estado de transacciones ───────────────────────────────────────────
ALTER TABLE public.transacciones DROP CONSTRAINT IF EXISTS transacciones_estado_check;
ALTER TABLE public.transacciones ADD CONSTRAINT transacciones_estado_check
    CHECK (estado = ANY (ARRAY['PENDIENTE'::text,'PROCESADA'::text,'APROBADO'::text,
                            'FALLIDA'::text,'REEMBOLSADA'::text]));

-- ── 2. Cerrar huecos RLS ───────────────────────────────────────────────────────
-- El UPDATE directo del especialista a pagos queda prohibido: ahora solo el RPC
-- confirmar_pago_saldo (SECURITY DEFINER) puede marcar PAGADO y registrar el SALDO.
DROP POLICY IF EXISTS pago_especialista_cita_update ON public.pagos;
-- El INSERT directo de transacciones del especialista queda prohibido: solo el RPC
-- puede insertar SALDO/FALLIDA ligado a pagos.saldo_pendiente.
DROP POLICY IF EXISTS transaccion_especialista_cita_insert ON public.transacciones;

-- ── 3. RPC confirmar_pago_saldo ────────────────────────────────────────────────
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

    -- Idempotencia: ya hay SALDO APROBADO registrado para esta cita
    -- (una SALDO FALLIDA no debe bloquear el reintento del pago).
    IF EXISTS (SELECT 1 FROM public.transacciones t
                WHERE t.cita_id = p_cita_id
                  AND t.tipo_transaccion = 'SALDO'
                  AND t.estado = 'APROBADO') THEN
        RETURN json_build_object('ok', false, 'motivo', 'YA_REGISTRADA');
    END IF;

    -- Validación de monto: el pago debe coincidir con el saldo pendiente.
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

    RETURN json_build_object('ok', true, 'motivo', 'OK');
END;
$$;

GRANT EXECUTE ON FUNCTION public.confirmar_pago_saldo(uuid, uuid, numeric, text)
    TO authenticated, service_role;

-- ── 4. RPC registrar_pago_fallido ──────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.registrar_pago_fallido(
    p_solicitud_id      uuid,
    p_cita_id           uuid,
    p_monto             numeric,
    p_stripe_payment_id text,
    p_motivo            text,
    p_tipo              text DEFAULT 'SALDO'
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_paciente_id uuid;
    v_pago_ok     boolean;
    v_existe      boolean;
BEGIN
    SELECT s.paciente_id,
           EXISTS (SELECT 1 FROM public.citas c
                    WHERE c.id = p_cita_id
                      AND c.especialista_id = (
                          SELECT e.id FROM public.especialistas e
                           WHERE e.usuario_id = auth.uid() LIMIT 1))
      INTO v_paciente_id, v_pago_ok
      FROM public.solicitudes s
     WHERE s.id = p_solicitud_id;

    IF v_paciente_id IS NULL THEN
        RETURN json_build_object('ok', false, 'motivo', 'NO_ENCONTRADO');
    END IF;

    IF NOT (v_pago_ok OR public.is_administrador() OR auth.role() = 'service_role') THEN
        RETURN json_build_object('ok', false, 'motivo', 'NO_AUTORIZADO');
    END IF;

    -- Idempotencia para reintentos del webhook con el mismo PaymentIntent.
    SELECT EXISTS (SELECT 1 FROM public.transacciones t
                    WHERE t.tipo_transaccion = p_tipo
                      AND t.estado = 'FALLIDA'
                      AND (t.stripe_payment_id = p_stripe_payment_id
                           OR (p_stripe_payment_id IS NULL
                               AND t.cita_id = p_cita_id
                               AND t.monto = p_monto)))
      INTO v_existe;

    IF NOT v_existe THEN
        INSERT INTO public.transacciones
            (solicitud_id, cita_id, paciente_id, tipo_transaccion, monto, moneda,
             estado, stripe_payment_id, stripe_payment_intent, fecha_transaccion)
        VALUES
            (p_solicitud_id, p_cita_id, v_paciente_id, p_tipo, p_monto, 'USD',
             'FALLIDA', p_stripe_payment_id, p_stripe_payment_id, now());
    END IF;

    RETURN json_build_object('ok', true, 'motivo', 'OK');
END;
$$;

GRANT EXECUTE ON FUNCTION public.registrar_pago_fallido(uuid, uuid, numeric, text, text, text)
    TO authenticated, service_role;

-- ── 5. RPC generar_liquidaciones ───────────────────────────────────────────────
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