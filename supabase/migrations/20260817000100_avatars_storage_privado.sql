-- =============================================================================
-- Migración: Storage privado para avatares.
-- -----------------------------------------------------------------------------
--   * vuelve PRIVADO el bucket `avatars` (creado a mano con public=TRUE para
--     usar `getPublicUrl`)
--   * elimina la policy pública legacy `avatars_public_select`
--   * agrega policies de INSERT/SELECT/UPDATE/DELETE para el dueño (path
--     `<userId>/<archivo>`) y SELECT para administradores
--   * migra los `profiles.avatar_url` existentes: de URL pública a path de
--     storage para poder servirlos con URLs firmadas (`createSignedUrl`)
-- Aplicar con `supabase db push` o desde el SQL Editor del dashboard.
-- =============================================================================

-- 1. Bucket privado -----------------------------------------------------------
DO $$
BEGIN
    INSERT INTO storage.buckets (id, name, public)
    VALUES ('avatars', 'avatars', FALSE)
    ON CONFLICT (id) DO UPDATE SET public = FALSE;
END $$;

-- 2. Quitar la lectura pública -------------------------------------------------
DROP POLICY IF EXISTS "avatars_public_select" ON storage.objects;

-- 3. INSERT: el dueño sube sus propios avatares --------------------------------
DROP POLICY IF EXISTS "avatars_storage_own_insert" ON storage.objects;
CREATE POLICY "avatars_storage_own_insert"
    ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- 4. SELECT: el dueño lee sus propios avatares ---------------------------------
DROP POLICY IF EXISTS "avatars_storage_own_select" ON storage.objects;
CREATE POLICY "avatars_storage_own_select"
    ON storage.objects
    FOR SELECT TO authenticated
    USING (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- 5. UPDATE/DELETE: solo el dueño sobre sus propios objetos --------------------
DROP POLICY IF EXISTS "avatars_storage_own_update" ON storage.objects;
CREATE POLICY "avatars_storage_own_update"
    ON storage.objects
    FOR UPDATE TO authenticated
    USING (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
    )
    WITH CHECK (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

DROP POLICY IF EXISTS "avatars_storage_own_delete" ON storage.objects;
CREATE POLICY "avatars_storage_own_delete"
    ON storage.objects
    FOR DELETE TO authenticated
    USING (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- 6. SELECT: el administrador lee los avatares de todos -------------------------
DROP POLICY IF EXISTS "avatars_storage_admin_select" ON storage.objects;
CREATE POLICY "avatars_storage_admin_select"
    ON storage.objects
    FOR SELECT TO authenticated
    USING (
        bucket_id = 'avatars'
        AND (SELECT p.role FROM public.profiles p WHERE p.id = auth.uid()) = 'Administrador'
    );

-- 7. Migrar URLs públicas existentes a paths ------------------------------------
-- Formato previo: .../object/public/avatars/<userId>/<ts>.<ext>
-- Resultado: <userId>/<ts>.<ext> (lo que devuelve uploadBinary y usa createSignedUrl)
UPDATE public.profiles
SET avatar_url = regexp_replace(
        avatar_url,
        '^.*/object/public/avatars/',
        ''
    ),
    updated_at = NOW()
WHERE avatar_url LIKE '%/object/public/avatars/%';