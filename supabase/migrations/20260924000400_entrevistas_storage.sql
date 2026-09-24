-- =============================================================================
-- Migración: bucket privado `entrevistas-medicas` (grabación + firma de la
-- entrevista F2F, ePHI).
-- -----------------------------------------------------------------------------
-- Contenido sensible: la grabación de la videollamada y la firma del
-- consentimiento del paciente. Bucket PRIVADO; se sirve con URLs firmadas
-- (`createSignedUrl`, 3600 s). Path: `<entrevista_id>/<archivo>`.
--   * INSERT: administrador (permiso `admin.entrevistas`) y el paciente dueño
--     de la entrevista (para su firma).
--   * SELECT: administrador y el paciente dueño.
-- Idempotente (ON CONFLICT DO UPDATE / DROP POLICY IF EXISTS).
-- =============================================================================

DO $$
BEGIN
    INSERT INTO storage.buckets (id, name, public)
    VALUES ('entrevistas-medicas', 'entrevistas-medicas', FALSE)
    ON CONFLICT (id) DO UPDATE SET public = FALSE;
END $$;

-- ── INSERT: administrador sube la grabación / documentos clínicos ───────────
DROP POLICY IF EXISTS "entrevista_storage_admin_insert" ON storage.objects;
CREATE POLICY "entrevista_storage_admin_insert"
    ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'entrevistas-medicas'
        AND public.is_administrador()
    );

-- ── INSERT: el paciente dueño sube su firma de consentimiento ───────────────
DROP POLICY IF EXISTS "entrevista_storage_paciente_insert" ON storage.objects;
CREATE POLICY "entrevista_storage_paciente_insert"
    ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'entrevistas-medicas'
        AND (storage.foldername(name))[1] = ANY (
            SELECT e.id::text
            FROM public.entrevistas_medicas e
            JOIN public.pacientes p ON p.id = e.paciente_id
            WHERE p.usuario_id = auth.uid()
        )
    );

-- ── SELECT: administrador lee todo el bucket ────────────────────────────────
DROP POLICY IF EXISTS "entrevista_storage_admin_select" ON storage.objects;
CREATE POLICY "entrevista_storage_admin_select"
    ON storage.objects
    FOR SELECT TO authenticated
    USING (
        bucket_id = 'entrevistas-medicas'
        AND public.is_administrador()
    );

-- ── SELECT: el paciente dueño lee su propia entrevista ──────────────────────
DROP POLICY IF EXISTS "entrevista_storage_paciente_select" ON storage.objects;
CREATE POLICY "entrevista_storage_paciente_select"
    ON storage.objects
    FOR SELECT TO authenticated
    USING (
        bucket_id = 'entrevistas-medicas'
        AND (storage.foldername(name))[1] = ANY (
            SELECT e.id::text
            FROM public.entrevistas_medicas e
            JOIN public.pacientes p ON p.id = e.paciente_id
            WHERE p.usuario_id = auth.uid()
        )
    );

-- ── UPDATE: administrador puede reemplazar (reenvío de grabación) ───────────
DROP POLICY IF EXISTS "entrevista_storage_admin_update" ON storage.objects;
CREATE POLICY "entrevista_storage_admin_update"
    ON storage.objects
    FOR UPDATE TO authenticated
    USING (
        bucket_id = 'entrevistas-medicas'
        AND public.is_administrador()
    );
