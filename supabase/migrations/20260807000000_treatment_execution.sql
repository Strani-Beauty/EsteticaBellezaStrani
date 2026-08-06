-- =============================================================================
-- MIGRACIÓN: Módulo treatment_execution — RLS para el ciclo de la cita.
-- Especialista con cita asignada ejecuta el tratamiento (citas, tratamientos,
-- productos_aplicados, consentimientos_tratamiento, historial_estados) y lectura
-- de datos del paciente asignado. Idempotente (DROP POLICY IF EXISTS).
-- =============================================================================

-- ── 1. `citas`: el especialista dueño gestiona sus citas ───────────────────
ALTER TABLE public.citas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "cita_especialista_own" ON public.citas;
CREATE POLICY "cita_especialista_own"
    ON public.citas
    FOR ALL TO authenticated
    USING (
        especialista_id = (
            SELECT id FROM public.especialistas WHERE usuario_id = auth.uid() LIMIT 1
        )
    )
    WITH CHECK (
        especialista_id = (
            SELECT id FROM public.especialistas WHERE usuario_id = auth.uid() LIMIT 1
        )
    );

-- ── 2. `tratamientos` RLS ─────────────────────────────────────────────────
ALTER TABLE public.tratamientos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tratamiento_especialista_own" ON public.tratamientos;
CREATE POLICY "tratamiento_especialista_own"
    ON public.tratamientos
    FOR ALL TO authenticated
    USING (
        especialista_id = (
            SELECT id FROM public.especialistas WHERE usuario_id = auth.uid() LIMIT 1
        )
    )
    WITH CHECK (
        especialista_id = (
            SELECT id FROM public.especialistas WHERE usuario_id = auth.uid() LIMIT 1
        )
    );

-- ── 3. RLS: `productos_aplicados` (vía su tratamiento) ─────────────────────
ALTER TABLE public.productos_aplicados ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "producto_tratamiento_own" ON public.productos_aplicados;
CREATE POLICY "producto_tratamiento_own"
    ON public.productos_aplicados
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.tratamientos t
            WHERE t.id = productos_aplicados.tratamiento_id
              AND t.especialista_id = (
                  SELECT id FROM public.especialistas WHERE usuario_id = auth.uid() LIMIT 1
              )
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.tratamientos t
            WHERE t.id = productos_aplicados.tratamiento_id
              AND t.especialista_id = (
                  SELECT id FROM public.especialistas WHERE usuario_id = auth.uid() LIMIT 1
              )
        )
    );

-- ── 4. RLS: `consentimientos_tratamiento` (vía su tratamiento) ─────────────
ALTER TABLE public.consentimientos_tratamiento ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "consentimiento_tratamiento_own" ON public.consentimientos_tratamiento;
CREATE POLICY "consentimiento_tratamiento_own"
    ON public.consentimientos_tratamiento
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.tratamientos t
            WHERE t.id = consentimientos_tratamiento.tratamiento_id
              AND t.especialista_id = (
                  SELECT id FROM public.especialistas WHERE usuario_id = auth.uid() LIMIT 1
              )
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.tratamientos t
            WHERE t.id = consentimientos_tratamiento.tratamiento_id
              AND t.especialista_id = (
                  SELECT id FROM public.especialistas WHERE usuario_id = auth.uid() LIMIT 1
              )
        )
    );

-- ── 5. RLS: `historial_estados` (transiciones de citas propias) ────────────
ALTER TABLE public.historial_estados ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "historial_cita_own" ON public.historial_estados;
CREATE POLICY "historial_cita_own"
    ON public.historial_estados
    FOR ALL TO authenticated
    USING (
        tipo_entidad = 'CITA'
        AND (
            SELECT id FROM public.citas c
            WHERE c.id = historial_estados.entidad_id
              AND c.especialista_id = (
                  SELECT id FROM public.especialistas WHERE usuario_id = auth.uid() LIMIT 1
              )
            LIMIT 1
        ) IS NOT NULL
    )
    WITH CHECK (
        tipo_entidad = 'CITA'
        AND (
            SELECT id FROM public.citas c
            WHERE c.id = historial_estados.entidad_id
              AND c.especialista_id = (
                  SELECT id FROM public.especialistas WHERE usuario_id = auth.uid() LIMIT 1
              )
            LIMIT 1
        ) IS NOT NULL
    );

-- ── 6. RLS: lectura del paciente asignado (nombre/teléfono) ────────────────
DROP POLICY IF EXISTS "profiles_especialista_cita" ON public.profiles;
CREATE POLICY "profiles_especialista_cita"
    ON public.profiles
    FOR SELECT TO authenticated
    USING (
        id IN (
            SELECT p.usuario_id
            FROM public.citas c
            JOIN public.solicitudes s ON s.id = c.solicitud_id
            JOIN public.pacientes p    ON p.id = s.paciente_id
            WHERE c.especialista_id = (
                SELECT id FROM public.especialistas WHERE usuario_id = auth.uid() LIMIT 1
            )
        )
    );

DROP POLICY IF EXISTS "pacientes_especialista_cita" ON public.pacientes;
CREATE POLICY "pacientes_especialista_cita"
    ON public.pacientes
    FOR SELECT TO authenticated
    USING (
        id IN (
            SELECT s.paciente_id
            FROM public.citas c
            JOIN public.solicitudes s ON s.id = c.solicitud_id
            WHERE c.especialista_id = (
                SELECT id FROM public.especialistas WHERE usuario_id = auth.uid() LIMIT 1
            )
        )
    );

-- ── 7. RLS: `direcciones_paciente` ─────────────────────────────────────────
ALTER TABLE public.direcciones_paciente ENABLE ROW LEVEL SECURITY;

-- El propio paciente gestiona (lee/inserta/actualiza) sus direcciones.
DROP POLICY IF EXISTS "direccion_paciente_own" ON public.direcciones_paciente;
CREATE POLICY "direccion_paciente_own"
    ON public.direcciones_paciente
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.pacientes p
            WHERE p.id = direcciones_paciente.paciente_id AND p.usuario_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.pacientes p
            WHERE p.id = direcciones_paciente.paciente_id AND p.usuario_id = auth.uid()
        )
    );

-- El especialista asignado lee la dirección del paciente de una cita suya.
DROP POLICY IF EXISTS "direccion_paciente_especialista_cita" ON public.direcciones_paciente;
CREATE POLICY "direccion_paciente_especialista_cita"
    ON public.direcciones_paciente
    FOR SELECT TO authenticated
    USING (
        paciente_id IN (
            SELECT s.paciente_id
            FROM public.citas c
            JOIN public.solicitudes s ON s.id = c.solicitud_id
            WHERE c.especialista_id = (
                SELECT id FROM public.especialistas WHERE usuario_id = auth.uid() LIMIT 1
            )
        )
    );

-- ── 8. Bucket de firmas + políticas de storage ─────────────────────────────
DO $$
BEGIN
    INSERT INTO storage.buckets (id, name, public)
    VALUES ('firmas-consentimiento', 'firmas-consentimiento', TRUE)
    ON CONFLICT (id) DO UPDATE SET public = TRUE;
END $$;

-- El especialista sube la firma (path: <uuid-tratamiento>/<archivo>).
DROP POLICY IF EXISTS "firma_storage_own_insert" ON storage.objects;
CREATE POLICY "firma_storage_own_insert"
    ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'firmas-consentimiento'
        AND (storage.foldername(name))[1] = (
            SELECT t.id::text
            FROM public.tratamientos t
            WHERE t.especialista_id = (
                SELECT id FROM public.especialistas WHERE usuario_id = auth.uid() LIMIT 1
            )
            LIMIT 1
        )
    );

DROP POLICY IF EXISTS "firma_storage_public_select" ON storage.objects;
CREATE POLICY "firma_storage_public_select"
    ON storage.objects
    FOR SELECT TO public
    USING (bucket_id = 'firmas-consentimiento');