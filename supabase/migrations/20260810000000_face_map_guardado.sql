-- =============================================================================
-- MIGRACIÓN: Guardado del Face Map del paciente (selección de puntos).
-- Al seleccionar un servicio facial/inyectable, el paciente marca los puntos de
-- cara que desea tratar ANTES de que exista un tratamiento. Para soportarlo:
--   * face_maps.tratamiento_id pasa a ser nullable (ya no obliga a tratamiento).
--   * se agregan paciente_id (dueño del mapa) y solicitud_id (opcional) para
--     vincular el mapa pre-tratamiento.
--   * RLS: el paciente administra sus propios mapas y puntos; el especialista
--     puede leer los mapas de sus pacientes en ejecución; el admin lee todo.
-- Idempotente (DROP POLICY IF EXISTS / ADD COLUMN IF NOT EXISTS).
-- =============================================================================

-- ── 1. Esquema: tratamiento opcional + vínculos paciente/solicitud ─────────
ALTER TABLE public.face_maps ALTER COLUMN tratamiento_id DROP NOT NULL;

ALTER TABLE public.face_maps
    ADD COLUMN IF NOT EXISTS paciente_id uuid
    REFERENCES public.pacientes (id) ON DELETE CASCADE;

ALTER TABLE public.face_maps
    ADD COLUMN IF NOT EXISTS solicitud_id uuid
    REFERENCES public.solicitudes (id);

CREATE INDEX IF NOT EXISTS face_maps_paciente_id_idx
    ON public.face_maps (paciente_id);
CREATE INDEX IF NOT EXISTS face_maps_solicitud_id_idx
    ON public.face_maps (solicitud_id);

-- ── 2. RLS: `face_maps` ────────────────────────────────────────────────────
ALTER TABLE public.face_maps ENABLE ROW LEVEL SECURITY;

-- El paciente dueño gestiona sus mapas.
DROP POLICY IF EXISTS "face_map_paciente_own" ON public.face_maps;
CREATE POLICY "face_map_paciente_own"
    ON public.face_maps
    FOR ALL TO authenticated
    USING (
        paciente_id = (
            SELECT id FROM public.pacientes WHERE usuario_id = auth.uid() LIMIT 1
        )
    )
    WITH CHECK (
        paciente_id = (
            SELECT id FROM public.pacientes WHERE usuario_id = auth.uid() LIMIT 1
        )
    );

-- El especialista lee los mapas de los pacientes asignados (ejecución), ya sea
-- por tratamiento o por paciente de sus tratamientos.
DROP POLICY IF EXISTS "face_map_especialista_read" ON public.face_maps;
CREATE POLICY "face_map_especialista_read"
    ON public.face_maps
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.tratamientos t
            WHERE t.especialista_id = (
                    SELECT id FROM public.especialistas
                    WHERE usuario_id = auth.uid() LIMIT 1
                )
              AND (face_maps.tratamiento_id = t.id
                OR face_maps.paciente_id = t.paciente_id)
        )
    );

-- Administrador puede leer todos los mapas.
DROP POLICY IF EXISTS "face_map_admin_read" ON public.face_maps;
CREATE POLICY "face_map_admin_read"
    ON public.face_maps
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid() AND p.role = 'Administrador'
        )
    );

-- ── 3. RLS: `face_map_puntos` ───────────────────────────────────────────────
ALTER TABLE public.face_map_puntos ENABLE ROW LEVEL SECURITY;

-- El paciente dueño gestiona los puntos de sus mapas.
DROP POLICY IF EXISTS "face_map_punto_paciente_own" ON public.face_map_puntos;
CREATE POLICY "face_map_punto_paciente_own"
    ON public.face_map_puntos
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.face_maps fm
            WHERE fm.id = face_map_puntos.face_map_id
              AND fm.paciente_id = (
                    SELECT id FROM public.pacientes
                    WHERE usuario_id = auth.uid() LIMIT 1
                )
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.face_maps fm
            WHERE fm.id = face_map_puntos.face_map_id
              AND fm.paciente_id = (
                    SELECT id FROM public.pacientes
                    WHERE usuario_id = auth.uid() LIMIT 1
                )
        )
    );

-- El especialista lee los puntos de los mapas de sus pacientes.
DROP POLICY IF EXISTS "face_map_punto_especialista_read" ON public.face_map_puntos;
CREATE POLICY "face_map_punto_especialista_read"
    ON public.face_map_puntos
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.face_maps fm
            JOIN public.tratamientos t
              ON t.id = fm.tratamiento_id OR t.paciente_id = fm.paciente_id
            WHERE fm.id = face_map_puntos.face_map_id
              AND t.especialista_id = (
                    SELECT id FROM public.especialistas
                    WHERE usuario_id = auth.uid() LIMIT 1
                )
        )
    );

-- Administrador puede leer todos los puntos.
DROP POLICY IF EXISTS "face_map_punto_admin_read" ON public.face_map_puntos;
CREATE POLICY "face_map_punto_admin_read"
    ON public.face_map_puntos
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid() AND p.role = 'Administrador'
        )
    );