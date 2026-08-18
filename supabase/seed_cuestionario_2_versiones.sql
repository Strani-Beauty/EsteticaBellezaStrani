-- =============================================================================
-- SEED: Cuestionario de Salud con 2 versiones (para validar versión histórica)
-- =============================================================================
-- Requiere haber aplicado primero la migración
-- `20260818000300_salud_cuestionario_paciente_rls.sql` (crea v1 y la deja activa).
--
-- Genera la v2 (idempotente):
--   * Copia la relación de preguntas de la v1 a la v2.
--   * Agrega una pregunta nueva exclusiva de la v2 (ej. historial oncológico).
--   * Vincula la v2 a los mismos servicios médicos/inyectables.
--   * La v2 nace INACTIVA → la v1 sigue activa (las evaluaciones previas
--     conservan `version_cuestionario`). Para activarla:
--
--       UPDATE public.cuestionarios SET activo = true
--        WHERE nombre = 'Cuestionario de Salud' AND version = 2;
--       UPDATE public.cuestionarios SET activo = false
--        WHERE nombre = 'Cuestionario de Salud' AND version = 1;
--
-- Para ver el histórico:
--   SELECT id, nombre, version, activo FROM public.cuestionarios ORDER BY version;
-- =============================================================================

DO $$
DECLARE
    v_nombre    CONSTANT TEXT := 'Cuestionario de Salud';
    v_v1_id     BIGINT;
    v_v2_id     BIGINT;
    v_nueva_preg BIGINT;
    v_servicio  UUID;
BEGIN
    -- Localiza la v1 (debe existir tras la migración).
    SELECT id INTO v_v1_id
    FROM public.cuestionarios
    WHERE nombre = v_nombre AND version = 1
    LIMIT 1;

    IF v_v1_id IS NULL THEN
        RAISE EXCEPTION 'No existe la v1 del cuestionario "%". Aplica primero la migración.', v_nombre;
    END IF;

    -- Crea la v2 (idempotente, nace inactiva).
    SELECT id INTO v_v2_id
    FROM public.cuestionarios
    WHERE nombre = v_nombre AND version = 2
    LIMIT 1;

    IF v_v2_id IS NULL THEN
        INSERT INTO public.cuestionarios (nombre, descripcion, activo, version, created_at, updated_at)
        VALUES (v_nombre, 'Cuestionario de salud pre-tratamiento v2 (con historial oncológico)', false, 2, now(), now())
        RETURNING id INTO v_v2_id;
    END IF;

    -- Copia las relaciones de preguntas de la v1 a la v2.
    INSERT INTO public.cuestionario_preguntas (cuestionario_id, pregunta_id, orden, activo, created_at)
    SELECT v_v2_id, cp.pregunta_id, cp.orden, true, now()
    FROM public.cuestionario_preguntas cp
    WHERE cp.cuestionario_id = v_v1_id
    ON CONFLICT DO NOTHING;

    -- Pregunta nueva exclusiva de la v2 (idempotente por texto + tipo).
    SELECT id INTO v_nueva_preg
    FROM public.preguntas
    WHERE pregunta = '¿Tienes o has tenido antecedentes oncológicos o de radioterapia en la zona a tratar?' AND tipo_respuesta = 'SI_NO'
    LIMIT 1;

    IF v_nueva_preg IS NULL THEN
        INSERT INTO public.preguntas (pregunta, tipo_respuesta, obligatoria, opciones, riesgo, activo, created_at, updated_at)
        VALUES ('¿Tienes o has tenido antecedentes oncológicos o de radioterapia en la zona a tratar?',
                'SI_NO', true, '["Sí","No"]'::jsonb,
                '{"detonante":"SI","etiqueta":"Antecedentes oncológicos","critico":true}'::jsonb,
                true, now(), now())
        RETURNING id INTO v_nueva_preg;
    END IF;

    -- Agrega la pregunta al final de la v2 (orden 11).
    INSERT INTO public.cuestionario_preguntas (cuestionario_id, pregunta_id, orden, activo, created_at)
    VALUES (v_v2_id, v_nueva_preg, 11, true, now())
    ON CONFLICT DO NOTHING;

    -- Vincula la v2 a los mismos servicios médicos/inyectables.
    FOR v_servicio IN
        SELECT id FROM public.servicios
        WHERE id IN ('11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222',
                     '33333333-3333-3333-3333-333333333333','44444444-4444-4444-4444-444444444444',
                     '55555555-5555-5555-5555-555555555555')
    LOOP
        INSERT INTO public.servicio_cuestionarios (servicio_id, cuestionario_id, obligatorio, orden, activo, created_at)
        VALUES (v_servicio, v_v2_id, true, 1, true, now())
        ON CONFLICT DO NOTHING;
    END LOOP;
END $$;

-- ── RESUMEN ────────────────────────────────────────────────────────────────
SELECT nombre, version, activo,
       (SELECT count(*) FROM public.cuestionario_preguntas cp
        WHERE cp.cuestionario_id = c.id) AS preguntas
FROM public.cuestionarios c
ORDER BY version;