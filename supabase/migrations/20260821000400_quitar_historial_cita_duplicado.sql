-- =============================================================================
-- Migración: elimina el duplicado de historial CITA en `aceptar_solicitud`.
-- -----------------------------------------------------------------------------
-- Existe un trigger previo `tr_log_cita_estado` en `citas` (creado en el SQL
-- Editor, no está en migraciones) que registra en `historial_estados` cualquier
-- INSERT/UPDATE de estado de una cita. `aceptar_solicitud` insertaba además un
-- registro manual de CITA PROGRAMADA → se duplicaban. Se retira el insert manual;
-- el trigger `trg_log_solicitud_estado` (SOLICITUD) y `tr_log_cita_estado` (CITA)
-- quedan como únicas fuentes de historial. Idempotente (CREATE OR REPLACE).
-- =============================================================================

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
    -- El historial CITA lo registra el trigger `tr_log_cita_estado` en INSERT.
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
