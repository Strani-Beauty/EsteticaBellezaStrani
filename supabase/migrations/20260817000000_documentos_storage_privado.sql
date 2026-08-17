-- =============================================================================
-- Migración: Storage privado para documentos de especialistas.
-- -----------------------------------------------------------------------------
--   * vuelve PRIVADO el bucket `documentos-especialistas` (antes público para
--     usar `getPublicUrl`)
--   * elimina la policy pública `documento_storage_public_select`
--   * agrega policies de SELECT para dueño (especialista) y administradores
--   * migra las `url_archivo` existentes: de URL pública a path de storage
--     para poder servirlas con URLs firmadas (`createSignedUrl`)
-- Aplicar con `supabase db push` o desde el SQL Editor del dashboard.
-- =============================================================================

-- 1. Bucket privado -----------------------------------------------------------
DO $$
BEGIN
    INSERT INTO storage.buckets (id, name, public)
    VALUES ('documentos-especialistas', 'documentos-especialistas', FALSE)
    ON CONFLICT (id) DO UPDATE SET public = FALSE;
END $$;

-- 2. Quitar la lectura pública -------------------------------------------------
DROP POLICY IF EXISTS "documento_storage_public_select" ON storage.objects;

-- 3. SELECT: el especialista dueño lee sus propios objetos ----------------------
DROP POLICY IF EXISTS "documento_storage_own_select" ON storage.objects;
CREATE POLICY "documento_storage_own_select"
    ON storage.objects
    FOR SELECT TO authenticated
    USING (
        bucket_id = 'documentos-especialistas'
        AND (storage.foldername(name))[1] = (
            SELECT id::text FROM public.especialistas
            WHERE usuario_id = auth.uid()
            LIMIT 1
        )
    );

-- 4. SELECT: el administrador lee los objetos de todos -------------------------
DROP POLICY IF EXISTS "documento_storage_admin_select" ON storage.objects;
CREATE POLICY "documento_storage_admin_select"
    ON storage.objects
    FOR SELECT TO authenticated
    USING (
        bucket_id = 'documentos-especialistas'
        AND (SELECT p.role FROM public.profiles p WHERE p.id = auth.uid()) = 'Administrador'
    );

-- 5. Migrar URLs públicas existentes a paths ------------------------------------
-- Formato previo: .../object/public/documentos-especialistas/<especialistaId>/<ts>.<ext>
-- Resultado: <especialistaId>/<ts>.<ext> (lo que devuelve uploadBinary y usa createSignedUrl)
UPDATE public.documentos_especialista
SET url_archivo = regexp_replace(
        url_archivo,
        '^.*/object/public/documentos-especialistas/',
        ''
    ),
    updated_at = NOW()
WHERE url_archivo LIKE '%/object/public/documentos-especialistas/%';