-- =============================================================================
-- MIGRACIÓN: Storage privado para firmas de consentimiento y fotografías de
-- tratamiento.
-- -----------------------------------------------------------------------------
--   * vuelve PRIVADOS los buckets `firmas-consentimiento` y
--     `fotografias-tratamiento` (antes públicos para usar `getPublicUrl`)
--   * elimina la policy pública de SELECT de firmas
--   * agrega policies de SELECT para el especialista dueño (vía path
--     `<tratamiento-id>/...`), para el paciente dueño del tratamiento y para
--     los administradores
--   * habilita RLS en `fotografias_tratamiento` con policies para el
--     especialista (ALL vía tratamiento), paciente (SELECT) y admin (ALL)
--   * migra las URLs existentes (`firma_url`, `archivo_url`) de URL pública a
--     path de storage para servirlas con URLs firmadas (`createSignedUrl`)
-- Idempotente (DROP POLICY IF EXISTS / ON CONFLICT DO UPDATE).
-- Aplicar con `supabase db push` o desde el SQL Editor del dashboard.
-- =============================================================================

-- ── 1. Buckets privados -------------------------------------------------------
DO $$
BEGIN
    INSERT INTO storage.buckets (id, name, public)
    VALUES ('firmas-consentimiento', 'firmas-consentimiento', FALSE)
    ON CONFLICT (id) DO UPDATE SET public = FALSE;
END $$;

DO $$
BEGIN
    INSERT INTO storage.buckets (id, name, public)
    VALUES ('fotografias-tratamiento', 'fotografias-tratamiento', FALSE)
    ON CONFLICT (id) DO UPDATE SET public = FALSE;
END $$;

-- ── 2. Quitar la lectura pública de firmas ------------------------------------
DROP POLICY IF EXISTS "firma_storage_public_select" ON storage.objects;

-- ── 3. SELECT storage: el especialista dueño lee sus firmas --------------------
DROP POLICY IF EXISTS "firma_storage_own_select" ON storage.objects;
CREATE POLICY "firma_storage_own_select"
    ON storage.objects
    FOR SELECT TO authenticated
    USING (
        bucket_id = 'firmas-consentimiento'
        AND (storage.foldername(name))[1] = ANY (
            SELECT t.id::text
            FROM public.tratamientos t
            WHERE t.especialista_id = (
                SELECT id FROM public.especialistas WHERE usuario_id = auth.uid() LIMIT 1
            )
        )
    );

-- ── 4. SELECT storage: el paciente dueño lee sus firmas ------------------------
DROP POLICY IF EXISTS "firma_storage_paciente_select" ON storage.objects;
CREATE POLICY "firma_storage_paciente_select"
    ON storage.objects
    FOR SELECT TO authenticated
    USING (
        bucket_id = 'firmas-consentimiento'
        AND (storage.foldername(name))[1] = ANY (
            SELECT t.id::text
            FROM public.tratamientos t
            WHERE t.paciente_id = (
                SELECT id FROM public.pacientes WHERE usuario_id = auth.uid() LIMIT 1
            )
        )
    );

-- ── 5. SELECT storage: administrador lee firmas y fotografías -----------------
DROP POLICY IF EXISTS "firma_storage_admin_select" ON storage.objects;
CREATE POLICY "firma_storage_admin_select"
    ON storage.objects
    FOR SELECT TO authenticated
    USING (
        bucket_id = 'firmas-consentimiento'
        AND (SELECT p.role FROM public.profiles p WHERE p.id = auth.uid()) = 'Administrador'
    );

DROP POLICY IF EXISTS "foto_storage_admin_select" ON storage.objects;
CREATE POLICY "foto_storage_admin_select"
    ON storage.objects
    FOR SELECT TO authenticated
    USING (
        bucket_id = 'fotografias-tratamiento'
        AND (SELECT p.role FROM public.profiles p WHERE p.id = auth.uid()) = 'Administrador'
    );

-- ── 6. INSERT storage: el especialista sube fotografías de sus tratamientos ----
DROP POLICY IF EXISTS "foto_storage_own_insert" ON storage.objects;
CREATE POLICY "foto_storage_own_insert"
    ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'fotografias-tratamiento'
        AND (storage.foldername(name))[1] = ANY (
            SELECT t.id::text
            FROM public.tratamientos t
            WHERE t.especialista_id = (
                SELECT id FROM public.especialistas WHERE usuario_id = auth.uid() LIMIT 1
            )
        )
    );

-- ── 7. SELECT storage: el especialista dueño lee sus fotografías --------------
DROP POLICY IF EXISTS "foto_storage_own_select" ON storage.objects;
CREATE POLICY "foto_storage_own_select"
    ON storage.objects
    FOR SELECT TO authenticated
    USING (
        bucket_id = 'fotografias-tratamiento'
        AND (storage.foldername(name))[1] = ANY (
            SELECT t.id::text
            FROM public.tratamientos t
            WHERE t.especialista_id = (
                SELECT id FROM public.especialistas WHERE usuario_id = auth.uid() LIMIT 1
            )
        )
    );

-- ── 8. SELECT storage: el paciente dueño lee sus fotografías ------------------
DROP POLICY IF EXISTS "foto_storage_paciente_select" ON storage.objects;
CREATE POLICY "foto_storage_paciente_select"
    ON storage.objects
    FOR SELECT TO authenticated
    USING (
        bucket_id = 'fotografias-tratamiento'
        AND (storage.foldername(name))[1] = ANY (
            SELECT t.id::text
            FROM public.tratamientos t
            WHERE t.paciente_id = (
                SELECT id FROM public.pacientes WHERE usuario_id = auth.uid() LIMIT 1
            )
        )
    );

-- ── 9. RLS `fotografias_tratamiento` ─────────────────────────────────────────
ALTER TABLE public.fotografias_tratamiento ENABLE ROW LEVEL SECURITY;

-- El especialista dueño gestiona las fotografías de sus tratamientos.
DROP POLICY IF EXISTS "foto_tratamiento_especialista_own" ON public.fotografias_tratamiento;
CREATE POLICY "foto_tratamiento_especialista_own"
    ON public.fotografias_tratamiento
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.tratamientos t
            WHERE t.id = fotografias_tratamiento.tratamiento_id
              AND t.especialista_id = (
                  SELECT id FROM public.especialistas WHERE usuario_id = auth.uid() LIMIT 1
              )
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.tratamientos t
            WHERE t.id = fotografias_tratamiento.tratamiento_id
              AND t.especialista_id = (
                  SELECT id FROM public.especialistas WHERE usuario_id = auth.uid() LIMIT 1
              )
        )
    );

-- El paciente lee las fotografías de sus tratamientos.
DROP POLICY IF EXISTS "foto_tratamiento_paciente_read" ON public.fotografias_tratamiento;
CREATE POLICY "foto_tratamiento_paciente_read"
    ON public.fotografias_tratamiento
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.tratamientos t
            WHERE t.id = fotografias_tratamiento.tratamiento_id
              AND t.paciente_id = (
                  SELECT id FROM public.pacientes WHERE usuario_id = auth.uid() LIMIT 1
              )
        )
    );

-- El administrador lee todo.
DROP POLICY IF EXISTS "foto_tratamiento_admin_read" ON public.fotografias_tratamiento;
CREATE POLICY "foto_tratamiento_admin_read"
    ON public.fotografias_tratamiento
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid() AND p.role = 'Administrador'
        )
    );

-- ── 10. Migrar URLs públicas existentes a paths --------------------------------
-- Formato previo: .../object/public/<bucket>/<tratamientoId>/<archivo>
-- Resultado: <tratamientoId>/<archivo> (lo que devuelve uploadBinary y usa createSignedUrl)
UPDATE public.consentimientos_tratamiento
SET firma_url = regexp_replace(
        firma_url,
        '^.*/object/public/firmas-consentimiento/',
        ''
    )
WHERE firma_url LIKE '%/object/public/firmas-consentimiento/%';

UPDATE public.fotografias_tratamiento
SET archivo_url = regexp_replace(
        archivo_url,
        '^.*/object/public/fotografias-tratamiento/',
        ''
    )
WHERE archivo_url LIKE '%/object/public/fotografias-tratamiento/%';