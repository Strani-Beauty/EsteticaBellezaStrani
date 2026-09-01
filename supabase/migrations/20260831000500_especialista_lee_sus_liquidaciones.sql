-- =============================================================================
-- Migración: el especialista lee (SELECT) sus propias liquidaciones y pagos.
-- -----------------------------------------------------------------------------
-- Punto 13 del corte semanal: "El especialista puede consultar su historial de
-- liquidaciones". Hasta hoy `liquidaciones_especialistas` y `pagos_especialistas`
-- solo tenían policies admin (`*_admin_all` de 20260822000100) y el especialista
-- dueño no podía leer sus filas por RLS.
-- Se agregan policies SELECT para el especialista dueño (patrón
-- `tratamiento_especialista_own` de 20260807000000). El especialista solo lee:
-- no puede cambiar estados ni registrar pagos (RPCs siguen admin-only).
-- También se habilita que el especialista firme/lea los comprobantes de SUS
-- liquidaciones en el bucket privado `comprobantes-pagos` (sin eso
-- `createSignedUrl` falla y no podría ver el comprobante).
-- Idempotente (DROP POLICY IF EXISTS).
-- =============================================================================

-- ── 1. liquidaciones_especialistas: SELECT del especialista dueño ───────────
DROP POLICY IF EXISTS liquidaciones_especialistas_especialista_select
    ON public.liquidaciones_especialistas;
CREATE POLICY liquidaciones_especialistas_especialista_select
    ON public.liquidaciones_especialistas
    FOR SELECT TO authenticated
    USING (
        especialista_id = (
            SELECT id FROM public.especialistas WHERE usuario_id = auth.uid() LIMIT 1
        )
    );

-- ── 2. pagos_especialistas: SELECT del especialista dueño ───────────────────
DROP POLICY IF EXISTS pagos_especialistas_especialista_select
    ON public.pagos_especialistas;
CREATE POLICY pagos_especialistas_especialista_select
    ON public.pagos_especialistas
    FOR SELECT TO authenticated
    USING (
        especialista_id = (
            SELECT id FROM public.especialistas WHERE usuario_id = auth.uid() LIMIT 1
        )
    );

-- ── 3. Storage: el especialista firma/lee los comprobantes de sus liquidaciones
-- (path `<liquidacion_id>/comprobante_<timestamp>.<ext>`). Solo lectura; la
-- subida/borrado sigue siendo admin-only. ─────────────────────────────────────
DROP POLICY IF EXISTS "comprobante_storage_especialista_select" ON storage.objects;
CREATE POLICY "comprobante_storage_especialista_select"
    ON storage.objects
    FOR SELECT TO authenticated
    USING (
        bucket_id = 'comprobantes-pagos'
        AND EXISTS (
            SELECT 1
            FROM public.liquidaciones_especialistas l
            WHERE l.id::text = (storage.foldername(name))[1]
              AND l.especialista_id = (
                  SELECT id FROM public.especialistas
                  WHERE usuario_id = auth.uid() LIMIT 1
              )
        )
    );