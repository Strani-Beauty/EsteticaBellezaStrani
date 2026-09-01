-- =============================================================================
-- Migración: Notificaciones push de solicitudes y compliance (act 4, 5 y 8).
-- -----------------------------------------------------------------------------
--   * (act 4) Trigger AFTER UPDATE en `solicitudes` cuando pasa a PUBLICADA:
--     avisa por in-app + push a los especialistas APROBADOS/activos dentro del
--     radio de búsqueda (misma geo query que `aceptar_solicitud`).
--   * (act 5) `aceptar_solicitud`: notifica al paciente "Solicitud aceptada"
--     cuando un especialista crea la cita PROGRAMADA.
--   * (act 8 + optimización) `notificar_documento_rechazado` y
--     `notificar_verificacion_aprobada` pasan de INSERT in-app directo a
--     `notificar_usuario_push` (añade push FCM al rechazo/aprobación).
-- Idempotente (DROP TRIGGER/FUNCTION IF EXISTS + CREATE OR REPLACE + GRANT).
-- =============================================================================

-- ── 1. (act 4) Solicitud publicada → avisar a especialistas cercanos ────────
CREATE OR REPLACE FUNCTION public.notificar_solicitud_publicada_especialistas()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_dir_ubicacion geography;
    v_radio_m       numeric;
    v_usuario_ids   uuid[];
    v_usuario       uuid;
BEGIN
    -- Solo interesa la transición al estado PUBLICADA.
    IF TG_OP = 'UPDATE' AND NEW.estado <> 'PUBLICADA' THEN
        RETURN NEW;
    END IF;
    IF OLD.estado IS NOT DISTINCT FROM 'PUBLICADA' THEN
        RETURN NEW;
    END IF;

    -- Ubicación del domicilio del paciente y radio de búsqueda (metros).
    SELECT dp.ubicacion,
           COALESCE(NEW.radio_busqueda,
                    (SELECT valor::numeric FROM public.configuracion_sistema
                     WHERE clave = 'radio_busqueda_km')) * 1000
      INTO v_dir_ubicacion, v_radio_m
      FROM public.solicitudes s
      LEFT JOIN public.direcciones_paciente dp ON dp.id = s.direccion_id
     WHERE s.id = NEW.id;

    IF v_dir_ubicacion IS NULL OR v_radio_m IS NULL THEN
        RETURN NEW;
    END IF;

    -- Especialistas APROBADOS y activos con ubicación dentro del radio
    -- (misma lógica que `aceptar_solicitud`).
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
       AND u.ubicacion IS NOT NULL
       AND ST_DWithin(u.ubicacion, v_dir_ubicacion, v_radio_m);

    IF v_usuario_ids IS NOT NULL AND array_length(v_usuario_ids, 1) > 0 THEN
        FOREACH v_usuario IN ARRAY v_usuario_ids
        LOOP
            PERFORM public.notificar_usuario_push(
                v_usuario,
                'Nueva solicitud en tu zona',
                'Hay una nueva solicitud de servicio cerca de tu ubicación. Revísala en el marketplace.',
                'SOLICITUD_NUEVA',
                jsonb_build_object('solicitud_id', NEW.id)
            );
        END LOOP;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notificar_solicitud_publicada ON public.solicitudes;
CREATE TRIGGER trg_notificar_solicitud_publicada
    AFTER UPDATE OF estado ON public.solicitudes
    FOR EACH ROW
    EXECUTE FUNCTION public.notificar_solicitud_publicada_especialistas();

-- ── 2. (act 5) aceptar_solicitud: notifica al paciente ──────────────────────
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
    v_paciente_usuario    uuid;
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
           pf.full_name,
           pa.usuario_id
      INTO v_fecha_programada, v_dir_ubicacion, v_radio_m, v_paciente_nombre, v_paciente_usuario
      FROM public.solicitudes s
      LEFT JOIN public.direcciones_paciente dp ON dp.id = s.direccion_id
      LEFT JOIN public.pacientes pa ON pa.id = s.paciente_id
      LEFT JOIN public.profiles pf   ON pf.id = pa.usuario_id
     WHERE s.id = p_solicitud_id;

    -- Crea la cita PROGRAMADA (con la preferencia de fecha/hora del paciente).
    INSERT INTO public.citas (solicitud_id, especialista_id, estado, fecha_aceptacion, fecha_inicio)
    VALUES (p_solicitud_id, p_especialista_id, 'PROGRAMADA', now(), v_fecha_programada)
    RETURNING id INTO v_cita_id;

    -- Historial de la cita creada (fuente única: ya no existe tr_log_cita_estado).
    INSERT INTO public.historial_estados
        (tipo_entidad, entidad_id, estado, fecha_estado, usuario_id, observaciones)
    VALUES ('CITA', v_cita_id, 'PROGRAMADA', now(), auth.uid(), 'Cita creada al aceptar la solicitud');

    -- (act 5) Notificación al paciente.
    IF v_paciente_usuario IS NOT NULL THEN
        PERFORM public.notificar_usuario_push(
            v_paciente_usuario,
            'Solicitud aceptada',
            'Un especialista aceptó tu solicitud. Tu cita está programada.',
            'SOLICITUD_ACEPTADA',
            jsonb_build_object('cita_id', v_cita_id)
        );
    END IF;

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

-- ── 3. (act 8) Documento rechazado → in-app + push FCM ──────────────────────
CREATE OR REPLACE FUNCTION public.notificar_documento_rechazado()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_usuario      uuid;
    v_nombre_tipo  text;
BEGIN
    IF TG_OP = 'UPDATE'
       AND NEW.estado_revision = 'RECHAZADO'
       AND OLD.estado_revision IS DISTINCT FROM 'RECHAZADO' THEN
        SELECT e.usuario_id INTO v_usuario
          FROM public.especialistas e
         WHERE e.id = NEW.especialista_id;

        IF v_usuario IS NULL THEN
            RETURN NEW;
        END IF;

        v_nombre_tipo := replace(NEW.tipo_documento::text, '_', ' ');

        PERFORM public.notificar_usuario_push(
            v_usuario,
            'Documento rechazado',
            'Tu ' || lower(v_nombre_tipo) || ' (versión ' || NEW.version_documento || ') fue rechazado'
            || CASE WHEN NEW.observacion_revision IS NOT NULL AND NEW.observacion_revision <> ''
                    THEN ': ' || NEW.observacion_revision
                    ELSE '' END
            || '. Puedes corregirlo y reenviarlo desde Documentos.',
            'DOCUMENTO_RECHAZADO',
            jsonb_build_object('documento_id', NEW.id)
        );
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notificar_documento_rechazado ON public.documentos_especialista;
CREATE TRIGGER trg_notificar_documento_rechazado
    AFTER UPDATE ON public.documentos_especialista
    FOR EACH ROW EXECUTE FUNCTION public.notificar_documento_rechazado();

-- ── 4. Verificación aprobada → in-app + push FCM ────────────────────────────
CREATE OR REPLACE FUNCTION public.notificar_verificacion_aprobada()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF TG_OP = 'UPDATE'
       AND NEW.estado_verificacion = 'APROBADO'
       AND OLD.estado_verificacion IS DISTINCT FROM 'APROBADO' THEN
        PERFORM public.notificar_usuario_push(
            NEW.usuario_id,
            'Verificación aprobada',
            'Tu expediente fue aprobado. Ya puedes activar tu disponibilidad y operar en el marketplace.',
            'VERIFICACION_APROBADA',
            jsonb_build_object('especialista_id', NEW.id)
        );
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notificar_verificacion_aprobada ON public.especialistas;
CREATE TRIGGER trg_notificar_verificacion_aprobada
    AFTER UPDATE ON public.especialistas
    FOR EACH ROW EXECUTE FUNCTION public.notificar_verificacion_aprobada();