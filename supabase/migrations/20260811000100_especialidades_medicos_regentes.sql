-- =============================================================================
-- Migración: Catálogo de especialidades + especialista_especialidades +
-- médicos regentes (versión de las tablas que ya viven en la BD real).
-- -----------------------------------------------------------------------------
-- Las tablas existen en la instancia remota pero no estaban versionadas en el
-- repo ni tenían RLS/seeds. Esta migración es idempotente:
--   * crea `especialidades` (catálogo) + seeds
--   * crea `especialista_especialidades` (M:N con el especialista)
--   * crea `medicos_regentes` (registrados por el especialista, validados por admin)
--   * RLS + grants consistentes con el resto del proyecto
--   * FK de `especialistas.medico_regente_id` -> medicos_regentes.id (NOT VALID
--     para no fallar si ya hay filas huérfanas)
-- Aplicar con `supabase db push` o desde el SQL Editor del dashboard.
-- =============================================================================

-- 1. Catálogo de especialidades ------------------------------------------------
CREATE TABLE IF NOT EXISTS public.especialidades (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre          TEXT NOT NULL UNIQUE,
    descripcion     TEXT,
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Relación M:N especialista -> especialidades ------------------------------
CREATE TABLE IF NOT EXISTS public.especialista_especialidades (
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    especialista_id  UUID NOT NULL REFERENCES public.especialistas(id) ON DELETE CASCADE,
    especialidad_id  BIGINT NOT NULL REFERENCES public.especialidades(id) ON DELETE CASCADE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_especialista_especialidad UNIQUE (especialista_id, especialidad_id)
);

CREATE INDEX IF NOT EXISTS idx_esp_esp_especialista
    ON public.especialista_especialidades(especialista_id);

-- 3. Médicos regentes (estado: PENDIENTE al registrarse; admin valida a ACTIVO) --
CREATE TABLE IF NOT EXISTS public.medicos_regentes (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre           TEXT NOT NULL,
    numero_licencia  TEXT,
    estado           TEXT NOT NULL DEFAULT 'PENDIENTE',
    telefono         TEXT,
    correo           TEXT,
    activo           BOOLEAN NOT NULL DEFAULT FALSE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. FK de especialistas.medico_regente_id (columna ya existente, sin FK) -----
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.especialistas'::regclass
          AND conname = 'fk_especialistas_medico_regente'
    ) THEN
        ALTER TABLE public.especialistas
            ADD CONSTRAINT fk_especialistas_medico_regente
            FOREIGN KEY (medico_regente_id)
            REFERENCES public.medicos_regentes(id)
            ON DELETE SET NULL
            NOT VALID;
    END IF;
END $$;

-- 5. Seeds del catálogo de especialidades -------------------------------------
INSERT INTO public.especialidades (nombre, descripcion) VALUES
    ('Medicina Estética', 'Procedimientos médicos orientados a la mejora estética no quirúrgica.'),
    ('Dermatología Cosmética', 'Tratamientos de piel con enfoque cosmético.'),
    ('Mesoterapia', 'Aplicación intradérmica de principios activos.'),
    ('Rellenos Dérmicos', 'Ácido hialurónico y volumizadores faciales.'),
    ('Toxina Botulínica', 'Aplicación de bótox para arrugas de expresión.'),
    ('Limpieza Facial', 'Limpieza profunda e hidratación facial.'),
    ('Láser Estético', 'Depilación láser y tratamientos con luz pulsada.'),
    ('Radiofrecuencia', 'Reafirmación de piel por radiofrecuencia.'),
    ('Carboxiterapia', 'Aplicación de CO2 medicinal con fines estéticos.'),
    ('Microneedling', 'Microperforación para regeneración cutánea.'),
    ('Peelings Químicos', 'Exfoliación química controlada de la piel.'),
    ('Cosmiatría', 'Cuidados estéticos del rostro y cuerpo.')
ON CONFLICT (nombre) DO NOTHING;

-- 6. RLS ------------------------------------------------------------------------

-- 6.1 especialidades: catálogo público (lectura)
ALTER TABLE public.especialidades ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "especialidades_public_select" ON public.especialidades;
CREATE POLICY "especialidades_public_select"
    ON public.especialidades FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "especialidades_admin_write" ON public.especialidades;
CREATE POLICY "especialidades_admin_write"
    ON public.especialidades FOR ALL TO authenticated
    USING ((SELECT p.role FROM public.profiles p WHERE p.id = auth.uid()) = 'Administrador')
    WITH CHECK ((SELECT p.role FROM public.profiles p WHERE p.id = auth.uid()) = 'Administrador');

-- 6.2 especialista_especialidades: dueño + admin
ALTER TABLE public.especialista_especialidades ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "esp_esp_own_all" ON public.especialista_especialidades;
CREATE POLICY "esp_esp_own_all"
    ON public.especialista_especialidades FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.especialistas e
            WHERE e.id = especialista_especialidades.especialista_id
              AND e.usuario_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.especialistas e
            WHERE e.id = especialista_especialidades.especialista_id
              AND e.usuario_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "esp_esp_admin_all" ON public.especialista_especialidades;
CREATE POLICY "esp_esp_admin_all"
    ON public.especialista_especialidades FOR ALL TO authenticated
    USING ((SELECT p.role FROM public.profiles p WHERE p.id = auth.uid()) = 'Administrador')
    WITH CHECK ((SELECT p.role FROM public.profiles p WHERE p.id = auth.uid()) = 'Administrador');

-- 6.3 medicos_regentes: lectura autenticada; alta autenticada (queda PENDIENTE);
--     actualización (validación) solo admin.
ALTER TABLE public.medicos_regentes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "medicos_regentes_select" ON public.medicos_regentes;
CREATE POLICY "medicos_regentes_select"
    ON public.medicos_regentes FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "medicos_regentes_insert" ON public.medicos_regentes;
CREATE POLICY "medicos_regentes_insert"
    ON public.medicos_regentes FOR INSERT TO authenticated
    WITH CHECK (
        estado = 'PENDIENTE'
        AND activo = FALSE
        AND (SELECT p.role FROM public.profiles p WHERE p.id = auth.uid()) <> 'Administrador'
    );

DROP POLICY IF EXISTS "medicos_regentes_admin_update" ON public.medicos_regentes;
CREATE POLICY "medicos_regentes_admin_update"
    ON public.medicos_regentes FOR UPDATE TO authenticated
    USING ((SELECT p.role FROM public.profiles p WHERE p.id = auth.uid()) = 'Administrador')
    WITH CHECK ((SELECT p.role FROM public.profiles p WHERE p.id = auth.uid()) = 'Administrador');

DROP POLICY IF EXISTS "medicos_regentes_admin_delete" ON public.medicos_regentes;
CREATE POLICY "medicos_regentes_admin_delete"
    ON public.medicos_regentes FOR DELETE TO authenticated
    USING ((SELECT p.role FROM public.profiles p WHERE p.id = auth.uid()) = 'Administrador');

-- 7. Grants ----------------------------------------------------------------------
GRANT SELECT ON public.especialidades TO anon, authenticated;
GRANT SELECT ON public.especialista_especialidades TO authenticated;
GRANT SELECT, INSERT ON public.medicos_regentes TO authenticated;
