-- =============================================================================
-- Migración: Gestión de citas y logística del servicio (actividades 6/8/9/10/12)
-- -----------------------------------------------------------------------------
-- Cierra los huecos del ciclo operativo de la cita:
--   * A1: Máquina de estados en servidor (Act. 9) — impide saltos de estado.
--   * A2: RPC registrar_llegada_especialista (Act. 8) — geo de llegada + distancia.
--   * A3: RPC cancelar_cita (Act. 10) — CANCELADA con motivo + historial.
--   * A4: Trigger de notificación de cambio de estado al paciente (Act. 12) —
--        in-app + push FCM vía pg_net → send-push.
-- No se toca `aceptar_solicitud` (fuente única de creación de cita). Las
-- transiciones siguen yéndose por app → UPDATE de `citas` + historial manual.
-- Idempotente: DROP ... IF EXISTS + CREATE OR REPLACE + DO $$.
-- =============================================================================

-- ── A1. Máquina de estados de la cita (Act. 9) ───────────────────────────────
-- Impide que un UPDATE de `citas.estado` salte estados inválidos o retroceda.
-- Solo el especialista dueño o el admin pueden transicionar (refuerza RLS).
DROP TRIGGER IF EXISTS trg_validar_transicion_estado_cita ON public.citas;

CREATE OR REPLACE FUNCTION public.validar_transicion_estado_cita()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_valido boolean;
BEGIN
    IF TG_OP = 'UPDATE' AND OLD.estado = NEW.estado THEN
        RETURN NEW;
    END IF;

    -- Solo el especialista dueño o el administrador pueden cambiar el estado.
    IF NOT (
        NEW.especialista_id IN (
            SELECT id FROM public.especialistas WHERE usuario_id = auth.uid()
        )
        OR public.is_administrador()
    ) THEN
        RAISE EXCEPTION 'No autorizado para cambiar el estado de esta cita';
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM (
            VALUES
                ('PROGRAMADA', 'EN_CAMINO'),
                ('PROGRAMADA', 'CANCELADA'),
                ('EN_CAMINO',  'LLEGO'),
                ('EN_CAMINO',  'CANCELADA'),
                ('LLEGO',      'EN_PROCESO'),
                ('LLEGO',      'CANCELADA'),
                ('EN_PROCESO', 'FINALIZADA'),
                ('EN_PROCESO', 'NO_COMPLETADA'),
                ('EN_PROCESO', 'CANCELADA')
        ) AS t(origen, destino)
        WHERE t.origen = OLD.estado::text
          AND t.destino = NEW.estado::text
    ) INTO v_valido;

    IF NOT v_valido THEN
        RAISE EXCEPTION 'Transición de estado inválida: % -> %',
            OLD.estado, NEW.estado;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validar_transicion_estado_cita
    BEFORE UPDATE OF estado ON public.citas
    FOR EACH ROW
    EXECUTE FUNCTION public.validar_transicion_estado_cita();

-- ── A2. RPC registrar_llegada_especialista (Act. 8) ──────────────────────────
-- Escribe latitud_llegada/longitud_llegada y calcula distancia_recorrida (m)
-- contra el domicilio del paciente. Solo en estado LLEGO y por el dueño/admin.
CREATE OR REPLACE FUNCTION public.registrar_llegada_especialista(
    p_cita_id    uuid,
    p_latitud    numeric,
    p_longitud   numeric
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_estado       text;
    v_distancia    numeric;
    v_autorizado   boolean;
BEGIN
    SELECT c.estado, EXISTS (
        SELECT 1 FROM public.especialistas e
         WHERE e.id = c.especialista_id AND e.usuario_id = auth.uid()
    )
      INTO v_estado, v_autorizado
      FROM public.citas c
     WHERE c.id = p_cita_id;

    IF v_estado IS NULL THEN
        RETURN json_build_object('ok', false, 'motivo', 'NO_ENCONTRADA');
    END IF;

    IF NOT (v_autorizado OR public.is_administrador()) THEN
        RETURN json_build_object('ok', false, 'motivo', 'NO_AUTORIZADO');
    END IF;

    IF v_estado <> 'LLEGO' THEN
        RETURN json_build_object('ok', false, 'motivo', 'ESTADO_INVALIDO');
    END IF;

    -- Distancia recorrida desde la ubicación de llegada hasta el domicilio.
    SELECT ST_Distance(
               dp.ubicacion,
               ST_SetSRID(ST_MakePoint(p_longitud, p_latitud), 4326)::geography
           )
      INTO v_distancia
      FROM public.citas c
      JOIN public.solicitudes s   ON s.id = c.solicitud_id
      JOIN public.direcciones_paciente dp ON dp.id = s.direccion_id
     WHERE c.id = p_cita_id
       AND dp.ubicacion IS NOT NULL;

    UPDATE public.citas
       SET latitud_llegada  = p_latitud,
           longitud_llegada = p_longitud,
           distancia_recorrida = v_distancia,
           updated_at       = now()
     WHERE id = p_cita_id;

    RETURN json_build_object('ok', true, 'distancia_recorrida_m', v_distancia);
END;
$$;

GRANT EXECUTE ON FUNCTION public.registrar_llegada_especialista(uuid, numeric, numeric) TO authenticated;

-- ── A3. RPC cancelar_cita (Act. 10) ──────────────────────────────────────────
-- Cancela la cita (estado CANCELADA), registra el motivo y el usuario en
-- `historial_estados`. El trigger de máquina de estados valida la transición.
CREATE OR REPLACE FUNCTION public.cancelar_cita(
    p_cita_id uuid,
    p_motivo  text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_estado     text;
    v_autorizado boolean;
    v_motivo     text;
BEGIN
    SELECT c.estado, EXISTS (
        SELECT 1 FROM public.especialistas e
         WHERE e.id = c.especialista_id AND e.usuario_id = auth.uid()
    )
      INTO v_estado, v_autorizado
      FROM public.citas c
     WHERE c.id = p_cita_id;

    IF v_estado IS NULL THEN
        RETURN json_build_object('ok', false, 'motivo', 'NO_ENCONTRADA');
    END IF;

    IF NOT (v_autorizado OR public.is_administrador()) THEN
        RETURN json_build_object('ok', false, 'motivo', 'NO_AUTORIZADO');
    END IF;

    IF v_estado IN ('FINALIZADA', 'CANCELADA', 'NO_COMPLETADA') THEN
        RETURN json_build_object('ok', false, 'motivo', 'ESTADO_INVALIDO');
    END IF;

    v_motivo := COALESCE(NULLIF(trim(p_motivo), ''), 'Sin motivo');

    UPDATE public.citas
       SET estado        = 'CANCELADA',
           observaciones = v_motivo,
           updated_at    = now()
     WHERE id = p_cita_id;

    INSERT INTO public.historial_estados
        (tipo_entidad, entidad_id, estado, fecha_estado, usuario_id,
         observaciones, motivo_cancelacion)
    VALUES ('CITA', p_cita_id, 'CANCELADA', now(), auth.uid(),
            v_motivo, v_motivo);

    RETURN json_build_object('ok', true, 'motivo', 'OK');
END;
$$;

GRANT EXECUTE ON FUNCTION public.cancelar_cita(uuid, text) TO authenticated;

-- ── A4. Notificación de cambio de estado de cita al paciente (Act. 12) ──────
-- Trigger AFTER UPDATE de `citas.estado`: inserta notificación in-app al
-- paciente de la solicitud y dispara push FCM (si configurado).
DROP TRIGGER IF EXISTS trg_notificar_cambio_estado_cita ON public.citas;

CREATE OR REPLACE FUNCTION public.notificar_cambio_estado_cita()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_paciente_usuario uuid;
    v_titulo           text;
    v_mensaje          text;
    v_push_enabled     text;
    v_base_url         text;
    v_anon_key         text;
    v_tokens           text[];
    v_url              text;
    v_payload          jsonb;
BEGIN
    IF TG_OP = 'UPDATE' AND OLD.estado = NEW.estado THEN
        RETURN NEW;
    END IF;

    -- Usuario del paciente de la solicitud de esta cita.
    SELECT pa.usuario_id INTO v_paciente_usuario
      FROM public.solicitudes s
      JOIN public.pacientes pa ON pa.id = s.paciente_id
     WHERE s.id = NEW.solicitud_id;

    IF v_paciente_usuario IS NULL THEN
        RETURN NEW;
    END IF;

    -- Título/mensaje según el nuevo estado.
    CASE NEW.estado::text
        WHEN 'EN_CAMINO'   THEN
            v_titulo  := 'Especialista en camino';
            v_mensaje := 'Tu especialista está en camino a tu domicilio.';
        WHEN 'LLEGO'       THEN
            v_titulo  := 'Especialista en el lugar';
            v_mensaje := 'Tu especialista llegó a tu domicilio.';
        WHEN 'EN_PROCESO'  THEN
            v_titulo  := 'Tratamiento en progreso';
            v_mensaje := 'Tu tratamiento está en progreso.';
        WHEN 'FINALIZADA'  THEN
            v_titulo  := 'Cita completada';
            v_mensaje := 'Tu cita fue completada exitosamente.';
        WHEN 'CANCELADA'   THEN
            v_titulo  := 'Cita cancelada';
            v_mensaje := 'Tu cita fue cancelada.';
        WHEN 'NO_COMPLETADA' THEN
            v_titulo  := 'Cita no completada';
            v_mensaje := 'Tu cita no pudo completarse.';
        ELSE
            RETURN NEW;
    END CASE;

    -- Notificación in-app.
    INSERT INTO public.notificaciones (usuario_id, titulo, mensaje, tipo, fecha_envio)
    VALUES (v_paciente_usuario, v_titulo, v_mensaje, 'CITA_ESTADO', now());

    -- Push FCM (opcional, patrón notificar_solicitud_asignada_push).
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
                 WHERE d.usuario_id = v_paciente_usuario
                   AND d.activo = true
                   AND d.token_fcm IS NOT NULL;
                IF v_tokens IS NOT NULL AND array_length(v_tokens, 1) > 0 THEN
                    v_url := rtrim(v_base_url, '/') || '/send-push';
                    v_payload := jsonb_build_object(
                        'tokens', to_jsonb(v_tokens),
                        'titulo', v_titulo,
                        'mensaje', v_mensaje,
                        'data', jsonb_build_object('cita_id', NEW.id, 'estado', NEW.estado)
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

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_notificar_cambio_estado_cita
    AFTER UPDATE OF estado ON public.citas
    FOR EACH ROW
    EXECUTE FUNCTION public.notificar_cambio_estado_cita();
