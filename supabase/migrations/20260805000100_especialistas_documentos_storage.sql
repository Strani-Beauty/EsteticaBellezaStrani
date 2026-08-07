-- =============================================================================
-- Migración: Tablas de especialistas y documentos + bucket de storage
-- (aplicar con `supabase db push` o desde el SQL Editor del dashboard)
--
-- Crea:
--   * enums `tipo_documento_enum` y `estado_revision_enum`
--   * tabla `especialistas`
--   * tabla `documentos_especialista`
--   * bucket público `documentos-especialistas`
--   * RLS para dueño (especialista) y lectura para administradores
--   * políticas de Storage para subida/lectura de documentos
-- =============================================================================



-- 2. Tabla `especialistas` -----------------------------------------------------
CREATE TABLE IF NOT EXISTS public.especialistas (
    id                              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id                      UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    medico_regente_id               UUID,
    numero_licencia                 TEXT,
    estado_verificacion             TEXT NOT NULL DEFAULT 'PENDIENTE',
    fecha_solicitud_verificacion    TIMESTAMPTZ,
    fecha_verificacion              TIMESTAMPTZ,
    fecha_aprobacion                TIMESTAMPTZ,
    aprobado_por                    UUID,
    disponible                      BOOLEAN NOT NULL DEFAULT FALSE,
    activo                          BOOLEAN NOT NULL DEFAULT FALSE,
    created_at                      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at                      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_especialistas_usuario_id
    ON public.especialistas(usuario_id);

-- Índice parcial sobre texto de estado (para dashboards de admin)
CREATE INDEX IF NOT EXISTS idx_especialistas_estado
    ON public.especialistas(estado_verificacion);

-- 3. Tabla `documentos_especialista` -------------------------------------------
CREATE TABLE IF NOT EXISTS public.documentos_especialista (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    especialista_id         UUID NOT NULL REFERENCES public.especialistas(id) ON DELETE CASCADE,
    tipo_documento          public.tipo_documento_enum NOT NULL,
    nombre_archivo          TEXT,
    url_archivo             TEXT,
    estado_revision         public.estado_revision_enum NOT NULL DEFAULT 'PENDIENTE',
    observacion_revision    TEXT,
    revisado_por            UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    fecha_revision          TIMESTAMPTZ,
    version_documento       INTEGER NOT NULL DEFAULT 1,
    activo                  BOOLEAN NOT NULL DEFAULT TRUE,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_documentos_especialista_esp
    ON public.documentos_especialista(especialista_id);

-- 4. RLS: `especialistas` -------------------------------------------------------
ALTER TABLE public.especialistas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "especialista_own_access" ON public.especialistas;
CREATE POLICY "especialista_own_access"
    ON public.especialistas
    FOR ALL TO authenticated
    USING (auth.uid() = usuario_id)
    WITH CHECK (auth.uid() = usuario_id);

DROP POLICY IF EXISTS "especialista_admin_select" ON public.especialistas;
CREATE POLICY "especialista_admin_select"
    ON public.especialistas
    FOR SELECT TO authenticated
    USING (
        (SELECT p.role FROM public.profiles p WHERE p.id = auth.uid()) = 'Administrador'
    );

-- 5. RLS: `documentos_especialista` ------------------------------------------------
ALTER TABLE public.documentos_especialista ENABLE ROW LEVEL SECURITY;

-- El especialista dueño lee/inserta sus propios documentos.
DROP POLICY IF EXISTS "documento_own_all" ON public.documentos_especialista;
CREATE POLICY "documento_own_all"
    ON public.documentos_especialista
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.especialistas e
            WHERE e.id = documentos_especialista.especialista_id
              AND e.usuario_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.especialistas e
            WHERE e.id = documentos_especialista.especialista_id
              AND e.usuario_id = auth.uid()
        )
    );

-- El administrador lee y revisa los documentos de todos.
DROP POLICY IF EXISTS "documento_admin_review" ON public.documentos_especialista;
CREATE POLICY "documento_admin_review"
    ON public.documentos_especialista
    FOR ALL TO authenticated
    USING (
        (SELECT p.role FROM public.profiles p WHERE p.id = auth.uid()) = 'Administrador'
    )
    WITH CHECK (
        (SELECT p.role FROM public.profiles p WHERE p.id = auth.uid()) = 'Administrador'
    );

-- 6. Bucket de storage (público para poder usar getPublicUrl) -------------------
DO $$
BEGIN
    INSERT INTO storage.buckets (id, name, public)
    VALUES ('documentos-especialistas', 'documentos-especialistas', TRUE)
    ON CONFLICT (id) DO UPDATE SET public = TRUE;
END $$;

-- El especialista sube y elimina sus propios objetos (path: <uuid-especialista>/<archivo>).
DROP POLICY IF EXISTS "documento_storage_own_insert" ON storage.objects;
CREATE POLICY "documento_storage_own_insert"
    ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'documentos-especialistas'
        AND (storage.foldername(name))[1] = (
            SELECT id::text FROM public.especialistas
            WHERE usuario_id = auth.uid()
            LIMIT 1
        )
    );

DROP POLICY IF EXISTS "documento_storage_own_update" ON storage.objects;
CREATE POLICY "documento_storage_own_update"
    ON storage.objects
    FOR UPDATE TO authenticated
    USING (
        bucket_id = 'documentos-especialistas'
        AND (storage.foldername(name))[1] = (
            SELECT id::text FROM public.especialistas
            WHERE usuario_id = auth.uid()
            LIMIT 1
        )
    );

DROP POLICY IF EXISTS "documento_storage_own_delete" ON storage.objects;
CREATE POLICY "documento_storage_own_delete"
    ON storage.objects
    FOR DELETE TO authenticated
    USING (
        bucket_id = 'documentos-especialistas'
        AND (storage.foldername(name))[1] = (
            SELECT id::text FROM public.especialistas
            WHERE usuario_id = auth.uid()
            LIMIT 1
        )
    );

-- Lectura pública (bucket público → URL firmada por getPublicUrl del cliente).
DROP POLICY IF EXISTS "documento_storage_public_select" ON storage.objects;
CREATE POLICY "documento_storage_public_select"
    ON storage.objects
    FOR SELECT TO public
    USING (bucket_id = 'documentos-especialistas');