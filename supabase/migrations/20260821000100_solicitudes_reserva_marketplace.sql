-- =============================================================================
-- Migración: Solicitudes, Reserva y Marketplace.
-- -----------------------------------------------------------------------------
-- Cierra el ciclo completo:
--   1. `crear_solicitud_reserva` (RPC): solicitud multi-servicio (detalles) en
--      estado PENDIENTE_PAGO + pagos PARCIAL (depósito = adelanto % o totalidad).
--   2. `confirmar_deposito_solicitud` (RPC): transacción APROBADO + publicación.
--      Gate `enforce_pago_real`: en 'true' solo service_role (webhook); en
--      'false' el app autenticado (pruebas sin dinero real).
--   3. Trigger `trg_proteger_publicacion_solicitud`: cierra el hueco RLS (el
--      paciente ya no puede publicar sin pago confirmado).
--   4. Trigger `trg_log_solicitud_estado` SECURITY DEFINER: historial SOLICITUD
--      (reemplaza el huérfano eliminado, sin reintroducir el 42501).
--   5. RLS nuevas: especialista asignado lee su solicitud (revela dirección
--      exacta), historial SOLICITUD (paciente + asignado), `solicitud_detalles`
--      (RLS habilitada) y cita del paciente (seguimiento).
--   6. `obtener_solicitudes_publicadas_geo` v2: agrega servicios (jsonb_agg) +
--      precio total + GEOFENCING ST_DWithin (radio config global o por solicitud).
--   7. `aceptar_solicitud` v2: cita con fecha_programada, historial CITA y
--      notificaciones in-app + push (pg_net → send-push) a especialistas del radio.
-- Idempotente: CREATE OR REPLACE / DROP ... IF EXISTS / ON CONFLICT.
-- =============================================================================

-- ── 1. Índices de soporte ──────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_solicitud_detalles_solicitud
    ON public.solicitud_detalles (solicitud_id);
CREATE INDEX IF NOT EXISTS idx_historial_estados_entidad
    ON public.historial_estados (tipo_entidad, entidad_id);
CREATE INDEX IF NOT EXISTS idx_solicitudes_estado_expiracion
    ON public.solicitudes (estado, fecha_expiracion);

-- ── 2. Seeds de configuración ──────────────────────────────────────────────
-- `enforce_pago_real`: 'true' en producción (solo webhook publica). En desarrollo
-- se cambia a 'false' para pruebas simuladas sin dinero real.
INSERT INTO public.configuracion_sistema
    (id, clave, valor, tipo_dato, descripcion, activo, updated_at)
VALUES
    (gen_random_uuid(), 'radio_busqueda_km', '10', 'NUMERIC',
     'Radio de búsqueda por defecto (km)', true, now()),
    (gen_random_uuid(), 'solicitud_expiracion_horas', '24', 'NUMERIC',
     'Horas de vigencia de una solicitud publicada', true, now()),
    (gen_random_uuid(), 'enforce_pago_real', 'false', 'BOOLEAN',
     'Si true, la publicación requiere confirmación vía webhook de Stripe', true, now()),
    (gen_random_uuid(), 'push_notifications', 'true', 'BOOLEAN',
     'Habilita envío push FCM al asignar solicitudes', true, now())
ON CONFLICT (clave) DO UPDATE
    SET valor = EXCLUDED.valor, updated_at = now();

-- ── 3. RPC: crear_solicitud_reserva ────────────────────────────────────────
-- Crea la solicitud en estado PENDIENTE_PAGO (proceso de reserva) con uno o
-- varios servicios en `solicitud_detalles`, y la obligación de pago PARCIAL.
-- El depósito se calcula server-side: adelanto_porcentaje % del total, o la
-- totalidad si p_pago_total. Valida RN-020 por cada ítem.
CREATE OR REPLACE FUNCTION public.crear_solicitud_reserva(
    p_paciente_id      uuid,
    p_items            jsonb,          -- [{"servicio_id": uuid, "cantidad": int, "observaciones": text}]
    p_direccion_id     uuid,
    p_fecha_programada timestamptz,
    p_radio_km         numeric,
    p_observaciones    text,
    p_pago_total       boolean DEFAULT false
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_item         jsonb;
    v_sid          uuid;
    v_precio       numeric;
    v_req          boolean;
    v_total        numeric := 0;
    v_deposito     numeric;
    v_saldo        numeric;
    v_pct          numeric;
    v_solicitud_id uuid;
    v_primary      uuid;
    v_cantidad     int;
    v_obs          text;
    v_enforce      text;
BEGIN
    IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'La solicitud debe contener al menos un servicio';
    END IF;

    SELECT COALESCE(valor, '50') INTO v_pct
      FROM public.configuracion_sistema WHERE clave = 'adelanto_porcentaje';

    -- Valida cada ítem (RN-020 por servicio) y calcula el total.
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_sid := NULL;
        SELECT sv.id, sv.precio_base, sv.requiere_telemedicina
          INTO v_sid, v_precio, v_req
          FROM public.servicios sv
         WHERE sv.id = (v_item->>'servicio_id')::uuid;

        IF v_sid IS NULL THEN
            RAISE EXCEPTION 'Servicio no encontrado: %', (v_item->>'servicio_id');
        END IF;

        v_cantidad := COALESCE((v_item->>'cantidad')::int, 1);
        IF v_cantidad < 1 THEN
            RAISE EXCEPTION 'Cantidad inválida para el servicio %', v_sid;
        END IF;

        IF v_req THEN
            SELECT COALESCE(valor, 'true') INTO v_enforce
              FROM public.configuracion_sistema WHERE clave = 'enforce_rn020';
            IF lower(v_enforce) <> 'false' AND NOT EXISTS (
                SELECT 1 FROM public.validaciones_telemedicina v
                 WHERE v.paciente_id = p_paciente_id
                   AND v.estado = 'APROBADA'
                   AND v.fecha_vencimiento IS NOT NULL
                   AND v.fecha_vencimiento > now()
            ) THEN
                RAISE EXCEPTION 'RN-020: El servicio requiere validación de telemedicina vigente (APROBADA, sin vencer)';
            END IF;
        END IF;

        v_total := v_total + (v_precio * v_cantidad);
        IF v_primary IS NULL THEN
            v_primary := v_sid;
        END IF;
    END LOOP;

    IF p_pago_total THEN
        v_deposito := round(v_total, 2);
    ELSE
        v_deposito := round((v_total * v_pct / 100), 2);
    END IF;

    IF v_deposito < 0.5 THEN
        RAISE EXCEPTION 'El monto del depósito es demasiado bajo (mínimo 0.50 USD)';
    END IF;

    v_saldo := round(v_total - v_deposito, 2);

    -- Solicitud en estado PENDIENTE_PAGO (estado inicial del proceso de reserva).
    INSERT INTO public.solicitudes (
        paciente_id, servicio_id, direccion_id, fecha_solicitud, fecha_programada,
        estado, deposito_requerido, deposito_pagado, observaciones_paciente,
        radio_busqueda, created_at, updated_at
    ) VALUES (
        p_paciente_id, v_primary, p_direccion_id, now(), p_fecha_programada,
        'PENDIENTE_PAGO', v_deposito, false, p_observaciones,
        p_radio_km, now(), now()
    ) RETURNING id INTO v_solicitud_id;

    -- Detalles (snapshot de precio_unitario).
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_sid := (v_item->>'servicio_id')::uuid;
        v_cantidad := COALESCE((v_item->>'cantidad')::int, 1);
        v_obs := v_item->>'observaciones';
        SELECT sv.precio_base INTO v_precio FROM public.servicios sv WHERE sv.id = v_sid;
        INSERT INTO public.solicitud_detalles (
            solicitud_id, servicio_id, cantidad, precio_unitario, observaciones,
            created_at, updated_at
        ) VALUES (
            v_solicitud_id, v_sid, v_cantidad, v_precio, nullif(v_obs, ''), now(), now()
        );
    END LOOP;

    -- Obligación de pago PARCIAL hasta confirmar el depósito.
    INSERT INTO public.pagos (
        solicitud_id, monto_total, deposito, saldo_pendiente, estado, created_at, updated_at
    ) VALUES (
        v_solicitud_id, round(v_total, 2), v_deposito, v_saldo, 'PARCIAL', now(), now()
    );

    RETURN json_build_object(
        'solicitud_id', v_solicitud_id,
        'total', round(v_total, 2),
        'deposito_requerido', v_deposito,
        'saldo_pendiente', v_saldo,
        'moneda', 'USD'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.crear_solicitud_reserva(uuid, jsonb, uuid, timestamptz, numeric, text, boolean)
    TO authenticated;

-- ── 4. RPC: confirmar_deposito_solicitud ───────────────────────────────────
-- Confirma el depósito y publica la solicitud. Idempotente. El gate
-- `enforce_pago_real` restringe la publicación a service_role (webhook) en
-- producción; en 'false' permite pruebas simuladas.
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

-- ── 5. Trigger: proteger la publicación (cierra el hueco RLS del ítem 7) ──
-- Solo se puede pasar a PUBLICADA/BUSCANDO_ESPECIALISTA si el depósito fue
-- confirmado por `confirmar_deposito_solicitud` (marca de sesión + transacción
-- APROBADO). ACEPTADA solo desde PUBLICADA/BUSCANDO_ESPECIALISTA.
CREATE OR REPLACE FUNCTION public.proteger_publicacion_solicitud()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NEW.estado IN ('PUBLICADA', 'BUSCANDO_ESPECIALISTA') THEN
        IF NOT (
            NEW.deposito_pagado = true
            AND COALESCE(current_setting('app.pago_confirmado', true), '') = 'true'
            AND EXISTS (
                SELECT 1 FROM public.transacciones t
                 WHERE t.solicitud_id = NEW.id
                   AND t.estado = 'APROBADO'
                   AND t.tipo_transaccion IN ('DEPOSITO', 'ADELANTO', 'PAGO_TOTAL')
            )
        ) THEN
            RAISE EXCEPTION 'La solicitud no puede publicarse sin un depósito confirmado';
        END IF;
    END IF;

    IF NEW.estado = 'ACEPTADA' THEN
        IF OLD.estado NOT IN ('PUBLICADA', 'BUSCANDO_ESPECIALISTA') OR OLD.deposito_pagado <> true THEN
            RAISE EXCEPTION 'Solo las solicitudes publicadas con depósito pueden aceptarse';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_proteger_publicacion_solicitud ON public.solicitudes;
CREATE TRIGGER trg_proteger_publicacion_solicitud
    BEFORE UPDATE ON public.solicitudes
    FOR EACH ROW EXECUTE FUNCTION public.proteger_publicacion_solicitud();

-- ── 6. Historial de estados de SOLICITUD (ítem 13) ────────────────────────
-- SECURITY DEFINER para evitar el 42501 que llevó a eliminar el trigger
-- huérfano `tr_log_solicitud_estado` (la RLS de historial solo cubría CITA).
CREATE OR REPLACE FUNCTION public.log_solicitud_estado_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.historial_estados
            (tipo_entidad, entidad_id, estado, fecha_estado, usuario_id, observaciones)
        VALUES ('SOLICITUD', NEW.id, NEW.estado, now(), auth.uid(), 'Creación de solicitud');
    ELSIF TG_OP = 'UPDATE' AND NEW.estado IS DISTINCT FROM OLD.estado THEN
        INSERT INTO public.historial_estados
            (tipo_entidad, entidad_id, estado, fecha_estado, usuario_id, observaciones)
        VALUES ('SOLICITUD', NEW.id, NEW.estado, now(), auth.uid(), 'Cambio de estado');
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_log_solicitud_estado ON public.solicitudes;
CREATE TRIGGER trg_log_solicitud_estado
    AFTER INSERT OR UPDATE OF estado ON public.solicitudes
    FOR EACH ROW EXECUTE FUNCTION public.log_solicitud_estado_change();

-- ── 7. RLS nuevas ──────────────────────────────────────────────────────────

-- Especialista asignado lee su solicitud (revela la dirección exacta, ítem 12).
DROP POLICY IF EXISTS "solicitud_especialista_asignado_select" ON public.solicitudes;
CREATE POLICY "solicitud_especialista_asignado_select"
    ON public.solicitudes
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.citas c
             WHERE c.solicitud_id = solicitudes.id
               AND c.especialista_id = (
                    SELECT id FROM public.especialistas WHERE usuario_id = auth.uid() LIMIT 1
               )
        )
    );

-- Historial SOLICITUD: paciente dueño y especialista asignado.
DROP POLICY IF EXISTS "historial_solicitud_select" ON public.historial_estados;
CREATE POLICY "historial_solicitud_select"
    ON public.historial_estados
    FOR SELECT TO authenticated
    USING (
        tipo_entidad = 'SOLICITUD'
        AND (
            EXISTS (
                SELECT 1 FROM public.solicitudes s
                JOIN public.pacientes p ON p.id = s.paciente_id
                 WHERE s.id = historial_estados.entidad_id AND p.usuario_id = auth.uid()
            )
            OR EXISTS (
                SELECT 1 FROM public.citas c
                 WHERE c.solicitud_id = historial_estados.entidad_id
                   AND c.especialista_id = (
                        SELECT id FROM public.especialistas WHERE usuario_id = auth.uid() LIMIT 1
                   )
            )
        )
    );

-- `solicitud_detalles`: habilita RLS (antes abierta).
ALTER TABLE public.solicitud_detalles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "solicitud_detalle_paciente_all" ON public.solicitud_detalles;
CREATE POLICY "solicitud_detalle_paciente_all"
    ON public.solicitud_detalles
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.solicitudes s
            JOIN public.pacientes p ON p.id = s.paciente_id
             WHERE s.id = solicitud_detalles.solicitud_id AND p.usuario_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.solicitudes s
            JOIN public.pacientes p ON p.id = s.paciente_id
             WHERE s.id = solicitud_detalles.solicitud_id AND p.usuario_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "solicitud_detalle_especialista_select" ON public.solicitud_detalles;
CREATE POLICY "solicitud_detalle_especialista_select"
    ON public.solicitud_detalles
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.solicitudes s
             WHERE s.id = solicitud_detalles.solicitud_id
               AND (
                    s.estado IN ('PUBLICADA', 'BUSCANDO_ESPECIALISTA')
                    OR EXISTS (
                        SELECT 1 FROM public.citas c
                         WHERE c.solicitud_id = s.id
                           AND c.especialista_id = (
                                SELECT id FROM public.especialistas WHERE usuario_id = auth.uid() LIMIT 1
                           )
                    )
               )
        )
    );

-- El paciente lee la cita de su solicitud (seguimiento "Mis solicitudes").
DROP POLICY IF EXISTS "cita_paciente_select" ON public.citas;
CREATE POLICY "cita_paciente_select"
    ON public.citas
    FOR SELECT TO authenticated
    USING (
        solicitud_id IN (
            SELECT s.id FROM public.solicitudes s
            JOIN public.pacientes p ON p.id = s.paciente_id
             WHERE p.usuario_id = auth.uid()
        )
    );

-- ── 8. `obtener_solicitudes_publicadas_geo` v2 (ítems 2/8/9/10) ───────────
-- Devuelve a especialistas APROBADOS las solicitudes publicadas con ubicación
-- aproximada (3 decimales, RN-018) y solo dentro del radio (geofencing).
-- Nota: DROP previo porque cambió el tipo de retorno (se agregaron columnas).
DROP FUNCTION IF EXISTS public.obtener_solicitudes_publicadas_geo();
CREATE OR REPLACE FUNCTION public.obtener_solicitudes_publicadas_geo()
RETURNS TABLE (
    solicitud_id     UUID,
    paciente_nombre  TEXT,
    servicio_nombre  TEXT,
    servicios        JSONB,
    precio           NUMERIC,
    precio_total     NUMERIC,
    latitud_aprox    NUMERIC,
    longitud_aprox   NUMERIC,
    ciudad           TEXT,
    radio_busqueda   NUMERIC,
    fecha_programada TIMESTAMPTZ,
    fecha_expiracion TIMESTAMPTZ,
    estado           TEXT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, extensions
AS $$
    SELECT s.id,
           pf.full_name,
           COALESCE(det.nombre_principal, sv.nombre),
           COALESCE(det.servicios, jsonb_build_array(jsonb_build_object(
               'servicio_id', s.servicio_id,
               'nombre', sv.nombre,
               'cantidad', 1,
               'precio_unitario', sv.precio_base
           ))),
           COALESCE(det.precio_total, sv.precio_base),
           COALESCE(det.precio_total, sv.precio_base),
           round(dp.latitud::numeric, 3),
           round(dp.longitud::numeric, 3),
           dp.ciudad,
           s.radio_busqueda,
           s.fecha_programada,
           s.fecha_expiracion,
           s.estado
    FROM public.solicitudes s
    JOIN public.direcciones_paciente dp ON dp.id = s.direccion_id
    JOIN public.pacientes p             ON p.id  = s.paciente_id
    JOIN public.profiles pf             ON pf.id = p.usuario_id
    JOIN public.servicios sv            ON sv.id = s.servicio_id
    LEFT JOIN LATERAL (
        SELECT jsonb_agg(jsonb_build_object(
                   'servicio_id', sd.servicio_id,
                   'nombre', sv2.nombre,
                   'cantidad', sd.cantidad,
                   'precio_unitario', sd.precio_unitario
               ) ORDER BY sd.created_at) AS servicios,
               string_agg(sv2.nombre, ', ' ORDER BY sd.created_at) AS nombre_principal,
               sum(sd.precio_unitario * sd.cantidad) AS precio_total
          FROM public.solicitud_detalles sd
          JOIN public.servicios sv2 ON sv2.id = sd.servicio_id
         WHERE sd.solicitud_id = s.id
    ) det ON det.servicios IS NOT NULL
    LEFT JOIN LATERAL (
        SELECT ue.ubicacion
          FROM public.ubicaciones_especialista ue
          JOIN public.especialistas e2 ON e2.id = ue.especialista_id
         WHERE e2.usuario_id = auth.uid()
         ORDER BY ue.created_at DESC
         LIMIT 1
    ) u ON TRUE
    CROSS JOIN LATERAL (
        SELECT COALESCE(
            (SELECT valor::numeric FROM public.configuracion_sistema WHERE clave = 'radio_busqueda_km'),
            10
        ) * 1000 AS cfg_radio_m
    ) cfg
    WHERE s.estado IN ('PUBLICADA', 'BUSCANDO_ESPECIALISTA')
      AND dp.ubicacion IS NOT NULL
      AND u.ubicacion IS NOT NULL
      AND ST_DWithin(dp.ubicacion, u.ubicacion, COALESCE(s.radio_busqueda * 1000, cfg.cfg_radio_m))
      AND EXISTS (
          SELECT 1 FROM public.especialistas e
           WHERE e.usuario_id = auth.uid()
             AND e.estado_verificacion = 'APROBADO'
             AND e.activo = TRUE
      )
    ORDER BY s.fecha_solicitud ASC;
$$;

GRANT EXECUTE ON FUNCTION public.obtener_solicitudes_publicadas_geo()
    TO authenticated;

-- ── 9. Push (FCM) opcional vía pg_net → edge function send-push ───────────
-- No-op si pg_net no existe o no hay config/URL. Solo se dispara con
-- `push_notifications = 'true'` y `edge_function_base_url`/`anon_key` seteados.
CREATE OR REPLACE FUNCTION public.notificar_solicitud_asignada_push(
    p_solicitud_id uuid,
    p_usuario_ids  uuid[]
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
    IF p_usuario_ids IS NULL OR array_length(p_usuario_ids, 1) IS NULL THEN
        RETURN;
    END IF;
    IF to_regnamespace('net') IS NULL THEN
        RETURN;
    END IF;

    SELECT COALESCE(valor, 'false') INTO v_push_enabled
      FROM public.configuracion_sistema WHERE clave = 'push_notifications';
    IF lower(v_push_enabled) <> 'true' THEN
        RETURN;
    END IF;

    SELECT COALESCE(valor, '') INTO v_base_url
      FROM public.configuracion_sistema WHERE clave = 'edge_function_base_url';
    SELECT COALESCE(valor, '') INTO v_anon_key
      FROM public.configuracion_sistema WHERE clave = 'anon_key';
    IF v_base_url = '' OR v_anon_key = '' THEN
        RETURN;
    END IF;

    SELECT COALESCE(array_agg(d.token_fcm), array[]::text[])
      INTO v_tokens
      FROM public.dispositivos_usuario d
     WHERE d.usuario_id = ANY(p_usuario_ids)
       AND d.activo = true
       AND d.token_fcm IS NOT NULL;

    IF v_tokens IS NULL OR array_length(v_tokens, 1) = 0 THEN
        RETURN;
    END IF;

    v_url := rtrim(v_base_url, '/') || '/send-push';

    v_payload := jsonb_build_object(
        'solicitud_id', p_solicitud_id,
        'tokens', to_jsonb(v_tokens),
        'titulo', 'Solicitud asignada',
        'mensaje', 'La solicitud ya fue asignada a otro especialista.'
    );

    PERFORM net.http_post(
        url := v_url,
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || v_anon_key
        ),
        body := v_payload
    );
END;
$$;

-- ── 10. `aceptar_solicitud` v2 (ítems 12/13/14) ────────────────────────────
-- Añade: cita con fecha_programada del paciente, historial de la cita creada y
-- notificaciones in-app (+ push) a los especialistas del radio (excepto ganador).
CREATE OR REPLACE FUNCTION public.aceptar_solicitud(
    p_solicitud_id      uuid,
    p_especialista_id   uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_estado              text;
    v_claim               int;
    v_cita_id             uuid;
    v_especialista_valido boolean;
    v_paciente_nombre     text;
    v_fecha_programada    timestamptz;
    v_dir_ubicacion       geography;
    v_radio_m             numeric;
    v_usuario_ids         uuid[];
BEGIN
    SELECT estado INTO v_estado
      FROM public.solicitudes
     WHERE id = p_solicitud_id;

    IF v_estado IS NULL THEN
        RETURN json_build_object('aceptada', false, 'cita_id', null, 'motivo', 'NO_ENCONTRADA');
    END IF;

    IF v_estado NOT IN ('PUBLICADA', 'BUSCANDO_ESPECIALISTA') THEN
        RETURN json_build_object('aceptada', false, 'cita_id', null, 'motivo', 'ASIGNADA');
    END IF;

    -- Solo especialistas APROBADOS, activos y con expediente completo.
    SELECT EXISTS (
        SELECT 1 FROM public.especialistas
         WHERE id = p_especialista_id
           AND estado_verificacion = 'APROBADO'
           AND activo = true
           AND public.cumple_requisitos_habilitacion(id)
    ) INTO v_especialista_valido;

    IF NOT v_especialista_valido THEN
        RETURN json_build_object('aceptada', false, 'cita_id', null, 'motivo', 'NO_APROBADO');
    END IF;

    -- Claim atómico ("primer aviso gana").
    UPDATE public.solicitudes
       SET estado     = 'ACEPTADA',
           updated_at = now()
     WHERE id = p_solicitud_id
       AND estado IN ('PUBLICADA', 'BUSCANDO_ESPECIALISTA')
       AND (fecha_expiracion IS NULL OR now() < fecha_expiracion);

    GET DIAGNOSTICS v_claim = ROW_COUNT;

    IF v_claim = 0 THEN
        RETURN json_build_object('aceptada', false, 'cita_id', null, 'motivo', 'EXPIRADA');
    END IF;

    -- Datos de la solicitud para la cita y las notificaciones.
    SELECT s.fecha_programada,
           dp.ubicacion,
           COALESCE(s.radio_busqueda,
                    (SELECT valor::numeric FROM public.configuracion_sistema WHERE clave = 'radio_busqueda_km')
           ) * 1000,
           pf.full_name
      INTO v_fecha_programada, v_dir_ubicacion, v_radio_m, v_paciente_nombre
      FROM public.solicitudes s
      LEFT JOIN public.direcciones_paciente dp ON dp.id = s.direccion_id
      LEFT JOIN public.pacientes pa ON pa.id = s.paciente_id
      LEFT JOIN public.profiles pf   ON pf.id = pa.usuario_id
     WHERE s.id = p_solicitud_id;

    -- Crea la cita PROGRAMADA (con la preferencia de fecha/hora del paciente).
    -- El historial CITA lo registra el trigger previo `tr_log_cita_estado` en INSERT.
    INSERT INTO public.citas (solicitud_id, especialista_id, estado, fecha_aceptacion, fecha_inicio)
    VALUES (p_solicitud_id, p_especialista_id, 'PROGRAMADA', now(), v_fecha_programada)
    RETURNING id INTO v_cita_id;

    -- Notificaciones in-app a especialistas del radio (excepto el ganador).
    IF v_dir_ubicacion IS NOT NULL AND v_radio_m IS NOT NULL THEN
        SELECT COALESCE(array_agg(e.usuario_id), array[]::uuid[])
          INTO v_usuario_ids
          FROM public.especialistas e
          JOIN LATERAL (
              SELECT ue.ubicacion
                FROM public.ubicaciones_especialista ue
               WHERE ue.especialista_id = e.id
               ORDER BY ue.created_at DESC
               LIMIT 1
          ) u ON TRUE
         WHERE e.estado_verificacion = 'APROBADO'
           AND e.activo = true
           AND e.id <> p_especialista_id
           AND u.ubicacion IS NOT NULL
           AND ST_DWithin(u.ubicacion, v_dir_ubicacion, v_radio_m);

        IF v_usuario_ids IS NOT NULL AND array_length(v_usuario_ids, 1) > 0 THEN
            INSERT INTO public.notificaciones (usuario_id, titulo, mensaje, tipo, fecha_envio)
            SELECT unnest(v_usuario_ids),
                   'Solicitud asignada',
                   'La solicitud de ' || COALESCE(v_paciente_nombre, 'un paciente') || ' ya fue asignada a otro especialista.',
                   'SOLICITUD_ASIGNADA',
                   now();
            PERFORM public.notificar_solicitud_asignada_push(p_solicitud_id, v_usuario_ids);
        END IF;
    END IF;

    RETURN json_build_object('aceptada', true, 'cita_id', v_cita_id, 'motivo', 'OK');
END;
$$;

GRANT EXECUTE ON FUNCTION public.aceptar_solicitud(uuid, uuid) TO authenticated;
