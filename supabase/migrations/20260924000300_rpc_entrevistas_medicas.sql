-- =============================================================================
-- Migración: RPCs de entrevista médica F2F (agendar / iniciar / dictamen /
-- consentimiento / grabación).
-- -----------------------------------------------------------------------------
-- Todas son SECURITY DEFINER y validan autoría:
--   * Admin: `is_administrador()` AND `tiene_permiso('admin.entrevistas')`.
--   * Paciente: entrevista cuyo `paciente_id` pertenece al auth.uid().
-- Notifican al paciente (in-app + push FCM) y auditan cada evento en
-- `auditoria` (ePHI/HIPAA). El dictamen hace el upsert en
-- `validaciones_telemedicina` + `profiles` (desbloquea RN-020); reemplaza a
-- `registrar_validacion_telemedicina`, cuyo EXECUTE quedó revocado (Fase 0).
-- Idempotente. Aplicar en orden ascendente.
-- =============================================================================

-- ── 1. agendar_entrevista ────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.agendar_entrevista(
    p_paciente_id        uuid,
    p_fecha_programada   timestamptz,
    p_duracion_min       integer DEFAULT 30,
    p_evaluacion_salud_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_sala          text;
    v_id            uuid;
    v_usuario       uuid;
    v_nombre        text;
BEGIN
    IF NOT (public.is_administrador() AND public.tiene_permiso('admin.entrevistas')) THEN
        RAISE EXCEPTION 'No autorizado';
    END IF;

    IF p_fecha_programada IS NULL THEN
        RAISE EXCEPTION 'RN: la fecha de la entrevista es obligatoria';
    END IF;

    SELECT pa.usuario_id, COALESCE(pr.full_name, 'el paciente')
      INTO v_usuario, v_nombre
      FROM public.pacientes pa
      LEFT JOIN public.profiles pr ON pr.id = pa.usuario_id
     WHERE pa.id = p_paciente_id;

    IF v_usuario IS NULL THEN
        RAISE EXCEPTION 'RN: paciente no encontrado';
    END IF;

    v_sala := 'meraki-entrevista-' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 12);

    INSERT INTO public.entrevistas_medicas (
        paciente_id, evaluacion_salud_id, medico_id, agendada_por,
        fecha_programada, duracion_min, estado, sala_id
    ) VALUES (
        p_paciente_id, p_evaluacion_salud_id, auth.uid(), auth.uid(),
        p_fecha_programada, COALESCE(p_duracion_min, 30), 'PROGRAMADA', v_sala
    )
    RETURNING id INTO v_id;

    PERFORM public.notificar_usuario_push(
        v_usuario,
        'Entrevista médica agendada',
        'Tu entrevista médica por videollamada fue agendada para el '
        || to_char(p_fecha_programada AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI')
        || ' (UTC). Podrás unirte desde la app.',
        'ENTREVISTA_MEDICA',
        jsonb_build_object('entrevista_id', v_id, 'fecha_programada', p_fecha_programada)
    );

    PERFORM public.registrar_auditoria(
        auth.uid(), 'ENTREVISTA_MEDICA_AGENDADA', 'entrevistas_medicas', v_id::text,
        jsonb_build_object('paciente_id', p_paciente_id, 'fecha_programada', p_fecha_programada)
    );

    RETURN jsonb_build_object(
        'id', v_id, 'sala_id', v_sala, 'estado', 'PROGRAMADA',
        'fecha_programada', p_fecha_programada
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.agendar_entrevista(uuid, timestamptz, integer, uuid)
    TO authenticated;

-- ── 2. iniciar_entrevista ────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.iniciar_entrevista(p_entrevista_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_estado text;
BEGIN
    IF NOT (public.is_administrador() AND public.tiene_permiso('admin.entrevistas')) THEN
        RAISE EXCEPTION 'No autorizado';
    END IF;

    SELECT estado INTO v_estado
      FROM public.entrevistas_medicas WHERE id = p_entrevista_id;

    IF v_estado IS NULL THEN
        RAISE EXCEPTION 'RN: entrevista no encontrada';
    END IF;

    IF v_estado IN ('COMPLETADA', 'CANCELADA', 'NO_ASISTIO') THEN
        RAISE EXCEPTION 'RN: la entrevista ya está cerrada';
    END IF;

    UPDATE public.entrevistas_medicas
       SET estado = 'EN_CURSO',
           iniciada_at = COALESCE(iniciada_at, now())
     WHERE id = p_entrevista_id;

    PERFORM public.registrar_auditoria(
        auth.uid(), 'ENTREVISTA_MEDICA_INICIADA', 'entrevistas_medicas', p_entrevista_id::text, NULL
    );

    RETURN jsonb_build_object('id', p_entrevista_id, 'estado', 'EN_CURSO');
END;
$$;

GRANT EXECUTE ON FUNCTION public.iniciar_entrevista(uuid) TO authenticated;

-- ── 3. guardar_grabacion_entrevista ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.guardar_grabacion_entrevista(
    p_entrevista_id uuid,
    p_path          text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
BEGIN
    IF NOT (public.is_administrador() AND public.tiene_permiso('admin.entrevistas')) THEN
        RAISE EXCEPTION 'No autorizado';
    END IF;

    UPDATE public.entrevistas_medicas
       SET grabacion_url = p_path
     WHERE id = p_entrevista_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'RN: entrevista no encontrada';
    END IF;

    PERFORM public.registrar_auditoria(
        auth.uid(), 'ENTREVISTA_MEDICA_GRABACION', 'entrevistas_medicas', p_entrevista_id::text,
        jsonb_build_object('grabacion', p_path)
    );

    RETURN jsonb_build_object('id', p_entrevista_id, 'grabacion_url', p_path);
END;
$$;

GRANT EXECUTE ON FUNCTION public.guardar_grabacion_entrevista(uuid, text) TO authenticated;

-- ── 4. registrar_consentimiento_entrevista (paciente) ────────────────────────
CREATE OR REPLACE FUNCTION public.registrar_consentimiento_entrevista(
    p_entrevista_id uuid,
    p_firma_url     text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_ok boolean;
BEGIN
    SELECT TRUE INTO v_ok
      FROM public.entrevistas_medicas e
      JOIN public.pacientes p ON p.id = e.paciente_id
     WHERE e.id = p_entrevista_id
       AND p.usuario_id = auth.uid();

    IF NOT COALESCE(v_ok, false) THEN
        RAISE EXCEPTION 'No autorizado';
    END IF;

    UPDATE public.entrevistas_medicas
       SET consentimiento_telemedicina = true,
           firma_consentimiento_url = p_firma_url
     WHERE id = p_entrevista_id;

    PERFORM public.registrar_auditoria(
        auth.uid(), 'ENTREVISTA_MEDICA_CONSENTIMIENTO', 'entrevistas_medicas', p_entrevista_id::text,
        jsonb_build_object('firma', p_firma_url)
    );

    RETURN jsonb_build_object('id', p_entrevista_id, 'consentimiento_telemedicina', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.registrar_consentimiento_entrevista(uuid, text) TO authenticated;

-- ── 5. emitir_dictamen_entrevista (examen médico total) ──────────────────────
-- Aprueba o rechaza el examen médico total: cierra la entrevista, refleja el
-- dictamen en `validaciones_telemedicina` (gate RN-020) y en `profiles`.
CREATE OR REPLACE FUNCTION public.emitir_dictamen_entrevista(
    p_entrevista_id uuid,
    p_aprobado      boolean,
    p_observaciones text,
    p_hallazgos     text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_paciente_id   uuid;
    v_usuario       uuid;
    v_estado        text;
    v_dictamen      text := CASE WHEN p_aprobado THEN 'APTO' ELSE 'NO_APTO' END;
    v_val_estado    text := CASE WHEN p_aprobado THEN 'APROBADA' ELSE 'RECHAZADA' END;
    v_validacion_id uuid;
    v_codigo        text;
BEGIN
    IF NOT (public.is_administrador() AND public.tiene_permiso('admin.entrevistas')) THEN
        RAISE EXCEPTION 'No autorizado';
    END IF;

    SELECT e.paciente_id, e.estado, pa.usuario_id
      INTO v_paciente_id, v_estado, v_usuario
      FROM public.entrevistas_medicas e
      JOIN public.pacientes pa ON pa.id = e.paciente_id
     WHERE e.id = p_entrevista_id;

    IF v_paciente_id IS NULL THEN
        RAISE EXCEPTION 'RN: entrevista no encontrada';
    END IF;

    IF v_estado IN ('CANCELADA', 'NO_ASISTIO') THEN
        RAISE EXCEPTION 'RN: la entrevista está cerrada sin dictamen';
    END IF;

    -- Upsert de la validación médica más reciente (gate RN-020).
    SELECT id INTO v_validacion_id
      FROM public.validaciones_telemedicina
     WHERE paciente_id = v_paciente_id
     ORDER BY created_at DESC
     LIMIT 1;

    v_codigo := 'ENTREVISTA_VAL_' || extract(epoch from now())::BIGINT::TEXT;

    IF v_validacion_id IS NOT NULL THEN
        UPDATE public.validaciones_telemedicina
           SET proveedor = 'Medicina Interna',
               estado = v_val_estado,
               codigo_referencia = v_codigo,
               fecha_validacion = now(),
               fecha_vencimiento = now() + interval '365 days',
               observaciones = p_observaciones,
               updated_at = now()
         WHERE id = v_validacion_id;
    ELSE
        INSERT INTO public.validaciones_telemedicina (
            paciente_id, proveedor, estado, codigo_referencia,
            fecha_validacion, fecha_vencimiento, observaciones, created_at, updated_at
        ) VALUES (
            v_paciente_id, 'Medicina Interna', v_val_estado, v_codigo,
            now(), now() + interval '365 days', p_observaciones, now(), now()
        )
        RETURNING id INTO v_validacion_id;
    END IF;

    UPDATE public.entrevistas_medicas
       SET estado = 'COMPLETADA',
           dictamen = v_dictamen,
           dictamen_observaciones = p_observaciones,
           hallazgos = COALESCE(p_hallazgos, hallazgos),
           validacion_id = v_validacion_id,
           finalizada_at = now()
     WHERE id = p_entrevista_id;

    UPDATE public.profiles
       SET activo = p_aprobado,
           evaluation_passed = p_aprobado,
           updated_at = now()
     WHERE id = v_usuario;

    PERFORM public.notificar_usuario_push(
        v_usuario,
        'Resultado de tu entrevista médica',
        CASE WHEN p_aprobado
             THEN 'Tu examen médico fue aprobado. Ya puedes acceder a los servicios.'
             ELSE 'Tu examen médico no fue aprobado. Revisa las observaciones del médico.' END,
        'ENTREVISTA_MEDICA',
        jsonb_build_object('entrevista_id', p_entrevista_id, 'dictamen', v_dictamen)
    );

    PERFORM public.registrar_auditoria(
        auth.uid(), 'ENTREVISTA_MEDICA_DICTAMEN', 'entrevistas_medicas', p_entrevista_id::text,
        jsonb_build_object('dictamen', v_dictamen, 'validacion_id', v_validacion_id)
    );

    RETURN jsonb_build_object(
        'id', p_entrevista_id,
        'estado', 'COMPLETADA',
        'dictamen', v_dictamen,
        'validacion_id', v_validacion_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.emitir_dictamen_entrevista(uuid, boolean, text, text)
    TO authenticated;
