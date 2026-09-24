-- =============================================================================
-- Migración: tabla `entrevistas_medicas` (entrevista F2F por videollamada).
-- -----------------------------------------------------------------------------
-- Persiste la cita de entrevista médica que agenda un administrador (permiso
-- `admin.entrevistas`), el consentimiento/firma del paciente, las notas y
-- hallazgos clínicos (ePHI), la grabación y el dictamen del examen médico
-- total. El dictamen se refleja además en `validaciones_telemedicina` para el
-- gate RN-020 (lo hace el RPC `emitir_dictamen_entrevista`, Fase 2).
--   * estado:   PROGRAMADA | EN_CURSO | COMPLETADA | CANCELADA | NO_ASISTIO
--   * dictamen: APTO | NO_APTO | REQUIERE_REVISION (NULL mientras no se emite)
-- RLS: admin ALL; paciente ve la suya y solo puede escribir su consentimiento
-- (reforzado por trigger `proteger_entrevista_medica`, patrón de la casa).
-- Idempotente. Aplicar en orden ascendente.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.entrevistas_medicas (
    id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    paciente_id                 uuid NOT NULL REFERENCES public.pacientes(id) ON DELETE CASCADE,
    evaluacion_salud_id         uuid REFERENCES public.evaluaciones_salud(id) ON DELETE SET NULL,
    medico_id                   uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    agendada_por                uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    fecha_programada            timestamptz NOT NULL,
    duracion_min                integer NOT NULL DEFAULT 30,
    estado                      text NOT NULL DEFAULT 'PROGRAMADA',
    sala_id                     text NOT NULL,
    notas_clinicas              text,
    hallazgos                   text,
    consentimiento_telemedicina boolean NOT NULL DEFAULT false,
    firma_consentimiento_url    text,
    grabacion_url               text,
    dictamen                    text,
    dictamen_observaciones      text,
    validacion_id               uuid REFERENCES public.validaciones_telemedicina(id) ON DELETE SET NULL,
    iniciada_at                 timestamptz,
    finalizada_at               timestamptz,
    created_at                  timestamptz NOT NULL DEFAULT now(),
    updated_at                  timestamptz NOT NULL DEFAULT now()
);

-- ── CHECKs (idempotentes por nombre de constraint) ──────────────────────────
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'entrevistas_medicas_estado_check') THEN
        ALTER TABLE public.entrevistas_medicas
            ADD CONSTRAINT entrevistas_medicas_estado_check
            CHECK (estado IN ('PROGRAMADA', 'EN_CURSO', 'COMPLETADA', 'CANCELADA', 'NO_ASISTIO'));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'entrevistas_medicas_dictamen_check') THEN
        ALTER TABLE public.entrevistas_medicas
            ADD CONSTRAINT entrevistas_medicas_dictamen_check
            CHECK (dictamen IS NULL OR dictamen IN ('APTO', 'NO_APTO', 'REQUIERE_REVISION'));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'entrevistas_medicas_duracion_check') THEN
        ALTER TABLE public.entrevistas_medicas
            ADD CONSTRAINT entrevistas_medicas_duracion_check
            CHECK (duracion_min > 0);
    END IF;
END $$;

-- ── Índices ─────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS entrevistas_medicas_paciente_fecha_idx
    ON public.entrevistas_medicas (paciente_id, fecha_programada DESC);
CREATE INDEX IF NOT EXISTS entrevistas_medicas_estado_fecha_idx
    ON public.entrevistas_medicas (estado, fecha_programada);
CREATE INDEX IF NOT EXISTS entrevistas_medicas_medico_fecha_idx
    ON public.entrevistas_medicas (medico_id, fecha_programada);
CREATE UNIQUE INDEX IF NOT EXISTS entrevistas_medicas_sala_id_key
    ON public.entrevistas_medicas (sala_id);

-- ── updated_at (patrón touch_* del proyecto) ────────────────────────────────
CREATE OR REPLACE FUNCTION public.touch_entrevista_medica()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_touch_entrevista_medica ON public.entrevistas_medicas;
CREATE TRIGGER trg_touch_entrevista_medica
    BEFORE UPDATE ON public.entrevistas_medicas
    FOR EACH ROW EXECUTE FUNCTION public.touch_entrevista_medica();

-- ── Anti-tampering: el paciente solo escribe su consentimiento ──────────────
CREATE OR REPLACE FUNCTION public.proteger_entrevista_medica()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    es_admin BOOLEAN;
BEGIN
    SELECT (p.role = 'Administrador') INTO es_admin
    FROM public.profiles p
    WHERE p.id = auth.uid();

    IF es_admin THEN
        RETURN NEW;
    END IF;

    IF TG_OP = 'INSERT' THEN
        RAISE EXCEPTION 'Solo un administrador puede agendar entrevistas médicas';
    END IF;

    -- El paciente (dueño) solo puede alternar su consentimiento y su firma.
    IF NEW.paciente_id IS DISTINCT FROM OLD.paciente_id
       OR NEW.evaluacion_salud_id IS DISTINCT FROM OLD.evaluacion_salud_id
       OR NEW.medico_id IS DISTINCT FROM OLD.medico_id
       OR NEW.agendada_por IS DISTINCT FROM OLD.agendada_por
       OR NEW.fecha_programada IS DISTINCT FROM OLD.fecha_programada
       OR NEW.duracion_min IS DISTINCT FROM OLD.duracion_min
       OR NEW.estado IS DISTINCT FROM OLD.estado
       OR NEW.sala_id IS DISTINCT FROM OLD.sala_id
       OR NEW.notas_clinicas IS DISTINCT FROM OLD.notas_clinicas
       OR NEW.hallazgos IS DISTINCT FROM OLD.hallazgos
       OR NEW.grabacion_url IS DISTINCT FROM OLD.grabacion_url
       OR NEW.dictamen IS DISTINCT FROM OLD.dictamen
       OR NEW.dictamen_observaciones IS DISTINCT FROM OLD.dictamen_observaciones
       OR NEW.validacion_id IS DISTINCT FROM OLD.validacion_id
       OR NEW.iniciada_at IS DISTINCT FROM OLD.iniciada_at
       OR NEW.finalizada_at IS DISTINCT FROM OLD.finalizada_at THEN
        RAISE EXCEPTION 'El paciente solo puede registrar su consentimiento en la entrevista';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_proteger_entrevista_medica ON public.entrevistas_medicas;
CREATE TRIGGER trg_proteger_entrevista_medica
    BEFORE INSERT OR UPDATE ON public.entrevistas_medicas
    FOR EACH ROW EXECUTE FUNCTION public.proteger_entrevista_medica();

-- ── RLS ─────────────────────────────────────────────────────────────────────
ALTER TABLE public.entrevistas_medicas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS entrevista_medica_admin_all ON public.entrevistas_medicas;
CREATE POLICY entrevista_medica_admin_all
    ON public.entrevistas_medicas
    FOR ALL TO authenticated
    USING (public.is_administrador())
    WITH CHECK (public.is_administrador());

DROP POLICY IF EXISTS entrevista_medica_paciente_select ON public.entrevistas_medicas;
CREATE POLICY entrevista_medica_paciente_select
    ON public.entrevistas_medicas
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.pacientes p
            WHERE p.id = entrevistas_medicas.paciente_id
              AND p.usuario_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS entrevista_medica_paciente_update ON public.entrevistas_medicas;
CREATE POLICY entrevista_medica_paciente_update
    ON public.entrevistas_medicas
    FOR UPDATE TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.pacientes p
            WHERE p.id = entrevistas_medicas.paciente_id
              AND p.usuario_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.pacientes p
            WHERE p.id = entrevistas_medicas.paciente_id
              AND p.usuario_id = auth.uid()
        )
    );

GRANT SELECT, INSERT, UPDATE, DELETE ON public.entrevistas_medicas TO authenticated;
