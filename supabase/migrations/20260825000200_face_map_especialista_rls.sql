-- =============================================================================
-- MIGRACIÓN: Face map del especialista — policies de escritura.
-- -----------------------------------------------------------------------------
-- El especialista documenta los puntos de aplicación durante la ejecución del
-- tratamiento (Act. 9): necesita INSERT/UPDATE sobre `face_maps` y
-- `face_map_puntos` vinculados a sus tratamientos. Hoy solo existen policies de
-- SELECT para el especialista (`face_map_especialista_read` /
-- `face_map_punto_especialista_read`).
--   * face_maps: el especialista gestiona los mapas cuyo `tratamiento_id`
--     pertenece a un tratamiento suyo (INSERT/UPDATE/DELETE).
--   * face_map_puntos: el especialista gestiona los puntos de esos mapas.
-- Idempotente (DROP POLICY IF EXISTS).
-- =============================================================================

-- ── 1. `face_maps`: escritura del especialista vía su tratamiento ────────────
DROP POLICY IF EXISTS "face_map_especialista_own" ON public.face_maps;
CREATE POLICY "face_map_especialista_own"
    ON public.face_maps
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.tratamientos t
            WHERE t.id = face_maps.tratamiento_id
              AND t.especialista_id = (
                  SELECT id FROM public.especialistas WHERE usuario_id = auth.uid() LIMIT 1
              )
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.tratamientos t
            WHERE t.id = face_maps.tratamiento_id
              AND t.especialista_id = (
                  SELECT id FROM public.especialistas WHERE usuario_id = auth.uid() LIMIT 1
              )
        )
    );

-- ── 2. `face_map_puntos`: escritura del especialista vía el face map ─────────
DROP POLICY IF EXISTS "face_map_punto_especialista_own" ON public.face_map_puntos;
CREATE POLICY "face_map_punto_especialista_own"
    ON public.face_map_puntos
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.face_maps fm
            JOIN public.tratamientos t ON t.id = fm.tratamiento_id
            WHERE fm.id = face_map_puntos.face_map_id
              AND t.especialista_id = (
                  SELECT id FROM public.especialistas WHERE usuario_id = auth.uid() LIMIT 1
              )
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.face_maps fm
            JOIN public.tratamientos t ON t.id = fm.tratamiento_id
            WHERE fm.id = face_map_puntos.face_map_id
              AND t.especialista_id = (
                  SELECT id FROM public.especialistas WHERE usuario_id = auth.uid() LIMIT 1
              )
        )
    );