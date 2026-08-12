-- =============================================================================
-- Migración: bucket de storage `contratos` + políticas de firma manuscrita.
-- -----------------------------------------------------------------------------
-- Permite al especialista subir la imagen de su firma de contrato al bucket
-- público `contratos` (path: <uuid-especialista>/<archivo>) y que la lectura
-- sea pública para poder usar getPublicUrl.
-- Idempotente: DO $$ INSERT ... ON CONFLICT + DROP POLICY IF EXISTS.
-- =============================================================================

-- 1. Bucket público `contratos` ------------------------------------------------
DO $$
BEGIN
    INSERT INTO storage.buckets (id, name, public)
    VALUES ('contratos', 'contratos', TRUE)
    ON CONFLICT (id) DO UPDATE SET public = TRUE;
END $$;

-- 2. El especialista sube su firma (path: <uuid-especialista>/<archivo>). ------
DROP POLICY IF EXISTS "contrato_storage_own_insert" ON storage.objects;
CREATE POLICY "contrato_storage_own_insert"
    ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'contratos'
        AND (storage.foldername(name))[1] = (
            SELECT id::text FROM public.especialistas
            WHERE usuario_id = auth.uid()
            LIMIT 1
        )
    );

-- 3. Lectura pública (bucket público → URL firmada por getPublicUrl). ----------
DROP POLICY IF EXISTS "contrato_storage_public_select" ON storage.objects;
CREATE POLICY "contrato_storage_public_select"
    ON storage.objects
    FOR SELECT TO public
    USING (bucket_id = 'contratos');
