-- =============================================================================
-- MIGRACIÓN: Imagen de servicio gestionable por el administrador.
-- -----------------------------------------------------------------------------
-- El admin sube una imagen por servicio desde el formulario del catálogo. Se
-- guarda la URL pública en `servicios.imagen_url` y el archivo en el bucket
-- `imagenes-servicios` (público, catálogo no sensible).
--   * columna imagen_url en servicios
--   * bucket público imagenes-servicios
--   * storage policy de INSERT solo para administradores
-- Idempotente (ADD COLUMN IF NOT EXISTS / ON CONFLICT DO UPDATE /
-- DROP POLICY IF EXISTS).
-- =============================================================================

-- ── 1. Columna imagen_url en servicios ───────────────────────────────────────
ALTER TABLE public.servicios
    ADD COLUMN IF NOT EXISTS imagen_url text;

-- ── 2. Bucket público de imágenes de servicios ───────────────────────────────
DO $$
BEGIN
    INSERT INTO storage.buckets (id, name, public)
    VALUES ('imagenes-servicios', 'imagenes-servicios', TRUE)
    ON CONFLICT (id) DO UPDATE SET public = TRUE;
END $$;

-- ── 3. Storage: solo el administrador sube imágenes ──────────────────────────
-- La lectura es pública por ser un bucket público (catálogo).
DROP POLICY IF EXISTS "servicio_imagen_admin_insert" ON storage.objects;
CREATE POLICY "servicio_imagen_admin_insert"
    ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'imagenes-servicios'
        AND (SELECT p.role FROM public.profiles p WHERE p.id = auth.uid()) = 'Administrador'
    );