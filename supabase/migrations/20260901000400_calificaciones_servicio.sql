-- =============================================================================
-- Migración: Sistema de calificaciones — `evaluaciones_servicio` bidireccional.
-- -----------------------------------------------------------------------------
-- La tabla `evaluaciones_servicio` existía en el remoto (creada por SQL Editor,
-- RLS habilitada SIN policies, 0 filas) y solo cubría paciente→especialista.
-- Se versiona y se adapta a un modelo BIDIRECCIONAL en una sola tabla:
--   * evaluador_id            = quién califica (profiles.id, = auth.uid()).
--   * evaluado_especialista_id = el especialista evaluado (paciente → esp).
--   * evaluado_paciente_id     = el paciente evaluado (especialista → paciente).
--   * CHECK: exactamente un evaluado por fila.
--   * UNIQUE (cita_id, evaluador_id): una evaluación por participante y cita.
-- Escritura SOLO vía RPC `registrar_evaluacion` (SECURITY DEFINER): valida cita
-- FINALIZADA (no evaluar antes de completar el servicio), autoría (paciente de
-- la cita o especialista dueño) e idempotencia. Lectura pública entre usuarios
-- logueados + admin ALL. Idempotente (DROP ... IF EXISTS).
-- =============================================================================

-- ── 1. Renombrar columnas legacy (si existen) ────────────────────────────────
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = 'public'
                 AND table_name = 'evaluaciones_servicio'
                 AND column_name = 'paciente_id') THEN
        ALTER TABLE public.evaluaciones_servicio
            RENAME COLUMN paciente_id TO evaluado_paciente_id;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = 'public'
                 AND table_name = 'evaluaciones_servicio'
                 AND column_name = 'especialista_id') THEN
        ALTER TABLE public.evaluaciones_servicio
            RENAME COLUMN especialista_id TO evaluado_especialista_id;
    END IF;
END $$;

-- ── 2. Columnas base (los evaluados pasan a ser opcionales) ─────────────────
ALTER TABLE public.evaluaciones_servicio
    ALTER COLUMN evaluado_paciente_id DROP NOT NULL;
ALTER TABLE public.evaluaciones_servicio
    ALTER COLUMN evaluado_especialista_id DROP NOT NULL;

ALTER TABLE public.evaluaciones_servicio
    ADD COLUMN IF NOT EXISTS evaluador_id uuid;
ALTER TABLE public.evaluaciones_servicio
    ALTER COLUMN evaluador_id SET NOT NULL;

-- ── 3. FKs (re-creadas con nombres explícitos e idempotentes) ───────────────
ALTER TABLE public.evaluaciones_servicio
    DROP CONSTRAINT IF EXISTS evaluaciones_servicio_cita_id_fkey;
ALTER TABLE public.evaluaciones_servicio
    ADD CONSTRAINT evaluaciones_servicio_cita_id_fkey
    FOREIGN KEY (cita_id) REFERENCES public.citas(id) ON DELETE CASCADE;

ALTER TABLE public.evaluaciones_servicio
    DROP CONSTRAINT IF EXISTS evaluaciones_servicio_evaluador_id_fkey;
ALTER TABLE public.evaluaciones_servicio
    ADD CONSTRAINT evaluaciones_servicio_evaluador_id_fkey
    FOREIGN KEY (evaluador_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE public.evaluaciones_servicio
    DROP CONSTRAINT IF EXISTS evaluaciones_servicio_evaluado_especialista_id_fkey;
ALTER TABLE public.evaluaciones_servicio
    ADD CONSTRAINT evaluaciones_servicio_evaluado_especialista_id_fkey
    FOREIGN KEY (evaluado_especialista_id) REFERENCES public.especialistas(id) ON DELETE CASCADE;

ALTER TABLE public.evaluaciones_servicio
    DROP CONSTRAINT IF EXISTS evaluaciones_servicio_evaluado_paciente_id_fkey;
ALTER TABLE public.evaluaciones_servicio
    ADD CONSTRAINT evaluaciones_servicio_evaluado_paciente_id_fkey
    FOREIGN KEY (evaluado_paciente_id) REFERENCES public.pacientes(id) ON DELETE CASCADE;

-- ── 4. CHECKs y UNIQUE ──────────────────────────────────────────────────────
ALTER TABLE public.evaluaciones_servicio
    DROP CONSTRAINT IF EXISTS evaluaciones_servicio_puntuacion_check;
ALTER TABLE public.evaluaciones_servicio
    ADD CONSTRAINT evaluaciones_servicio_puntuacion_check
    CHECK (puntuacion BETWEEN 1 AND 5);

ALTER TABLE public.evaluaciones_servicio
    DROP CONSTRAINT IF EXISTS evaluaciones_servicio_un_evaluado_check;
ALTER TABLE public.evaluaciones_servicio
    ADD CONSTRAINT evaluaciones_servicio_un_evaluado_check
    CHECK ((evaluado_especialista_id IS NOT NULL) <> (evaluado_paciente_id IS NOT NULL));

ALTER TABLE public.evaluaciones_servicio
    DROP CONSTRAINT IF EXISTS evaluaciones_servicio_cita_evaluador_unique;
ALTER TABLE public.evaluaciones_servicio
    ADD CONSTRAINT evaluaciones_servicio_cita_evaluador_unique
    UNIQUE (cita_id, evaluador_id);

-- ── 5. RLS ──────────────────────────────────────────────────────────────────
-- Lectura pública entre usuarios autenticados (las calificaciones son públicas
-- en la app; habilita el embed de promedios en Marketplace). El INSERT/UPDATE/
-- DELETE directo queda prohibido: solo el RPC (SECURITY DEFINER) escribe, y el
-- admin gestiona todo.
ALTER TABLE public.evaluaciones_servicio ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS evaluacion_public_select ON public.evaluaciones_servicio;
CREATE POLICY evaluacion_public_select
    ON public.evaluaciones_servicio
    FOR SELECT TO authenticated
    USING (true);

DROP POLICY IF EXISTS evaluacion_admin_all ON public.evaluaciones_servicio;
CREATE POLICY evaluacion_admin_all
    ON public.evaluaciones_servicio
    FOR ALL TO authenticated
    USING (public.is_administrador())
    WITH CHECK (public.is_administrador());

-- ── 6. RPC registrar_evaluacion ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.registrar_evaluacion(
    p_cita_id      uuid,
    p_puntuacion   integer,
    p_comentario   text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_evaluador_id         uuid := auth.uid();
    v_rol                  text;
    v_estado               text;
    v_cita_especialista    uuid;
    v_cita_paciente        uuid;
    v_evaluado_especialista uuid;
    v_evaluado_paciente    uuid;
    v_evaluacion_id        uuid;
    v_existe               boolean;
BEGIN
    IF v_evaluador_id IS NULL THEN
        RETURN json_build_object('ok', false, 'motivo', 'NO_AUTENTICADO');
    END IF;

    IF p_puntuacion IS NULL OR p_puntuacion < 1 OR p_puntuacion > 5 THEN
        RETURN json_build_object('ok', false, 'motivo', 'PUNTUACION_INVALIDA');
    END IF;

    SELECT c.estado, c.especialista_id, s.paciente_id
      INTO v_estado, v_cita_especialista, v_cita_paciente
      FROM public.citas c
      LEFT JOIN public.solicitudes s ON s.id = c.solicitud_id
     WHERE c.id = p_cita_id;

    IF v_estado IS NULL THEN
        RETURN json_build_object('ok', false, 'motivo', 'CITA_NO_ENCONTRADA');
    END IF;

    -- No se puede evaluar antes de completar el servicio.
    IF v_estado <> 'FINALIZADA' THEN
        RETURN json_build_object('ok', false, 'motivo', 'CITA_NO_FINALIZADA');
    END IF;

    SELECT role INTO v_rol FROM public.profiles WHERE id = v_evaluador_id;

    IF v_rol = 'Paciente' THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.pacientes pa
             WHERE pa.id = v_cita_paciente
               AND pa.usuario_id = v_evaluador_id
        ) THEN
            RETURN json_build_object('ok', false, 'motivo', 'NO_AUTORIZADO');
        END IF;
        v_evaluado_especialista := v_cita_especialista;
        v_evaluado_paciente     := NULL;
    ELSIF v_rol = 'Especialista' THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.especialistas e
             WHERE e.id = v_cita_especialista
               AND e.usuario_id = v_evaluador_id
        ) THEN
            RETURN json_build_object('ok', false, 'motivo', 'NO_AUTORIZADO');
        END IF;
        v_evaluado_especialista := NULL;
        v_evaluado_paciente     := v_cita_paciente;
    ELSE
        RETURN json_build_object('ok', false, 'motivo', 'NO_AUTORIZADO');
    END IF;

    -- Idempotencia: una evaluación por participante y cita.
    SELECT EXISTS (
        SELECT 1 FROM public.evaluaciones_servicio ev
         WHERE ev.cita_id = p_cita_id
           AND ev.evaluador_id = v_evaluador_id
    ) INTO v_existe;

    IF v_existe THEN
        RETURN json_build_object('ok', false, 'motivo', 'YA_EVALUADO');
    END IF;

    INSERT INTO public.evaluaciones_servicio
        (cita_id, evaluador_id, evaluado_especialista_id, evaluado_paciente_id,
         puntuacion, comentario, created_at)
    VALUES
        (p_cita_id, v_evaluador_id, v_evaluado_especialista, v_evaluado_paciente,
         p_puntuacion, p_comentario, now())
    RETURNING id INTO v_evaluacion_id;

    RETURN json_build_object('ok', true, 'evaluacion_id', v_evaluacion_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.registrar_evaluacion(uuid, integer, text)
    TO authenticated;

-- ── 7. RPC get_promedio_especialista (json: promedio + total) ───────────────
-- El original retornaba NUMERIC y no lo consumía nadie; ahora devuelve
-- {promedio, total} para la hoja de detalle del especialista y su perfil.
DROP FUNCTION IF EXISTS public.get_promedio_especialista(uuid);

CREATE FUNCTION public.get_promedio_especialista(p_especialista_id uuid)
RETURNS json
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT json_build_object(
        'promedio', COALESCE(ROUND(AVG(puntuacion), 2), 0.00),
        'total', COUNT(*)
    )
    FROM public.evaluaciones_servicio
    WHERE evaluado_especialista_id = p_especialista_id;
$$;

GRANT EXECUTE ON FUNCTION public.get_promedio_especialista(uuid)
    TO authenticated;