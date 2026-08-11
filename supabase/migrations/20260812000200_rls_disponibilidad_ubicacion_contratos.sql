-- =============================================================================
-- Migración: RLS para disponibilidad, ubicación y contratos de especialistas.
-- -----------------------------------------------------------------------------
-- Estas tres tablas quedaron creadas en el dashboard con RLS habilitada pero SIN
-- ninguna política, por lo que ningún rol podía leer/escribir:
--   * toggle de disponibilidad (setDisponibilidad/updateDisponibilidad)
--   * guardar ubicación en onboarding (saveUbicacion) y lectura en el mapa
--   * firmar/leer contratos (firmarContrato/fetchContrato)
-- El especialista dueño gestiona sus registros; el administrador los lee todos.
-- El mapa de especialistas solo muestra la ubicación propia (no hay policy de
-- lectura entre especialistas). Idempotente (DROP POLICY IF EXISTS).
-- =============================================================================

-- 1. RLS: `disponibilidad_especialista` ----------------------------------------
DROP POLICY IF EXISTS "disponibilidad_own" ON public.disponibilidad_especialista;
CREATE POLICY "disponibilidad_own"
    ON public.disponibilidad_especialista
    FOR ALL TO authenticated
    USING (
        especialista_id IN (
            SELECT id FROM public.especialistas WHERE usuario_id = auth.uid()
        )
    )
    WITH CHECK (
        especialista_id IN (
            SELECT id FROM public.especialistas WHERE usuario_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "disponibilidad_admin_select" ON public.disponibilidad_especialista;
CREATE POLICY "disponibilidad_admin_select"
    ON public.disponibilidad_especialista
    FOR SELECT TO authenticated
    USING ((SELECT p.role FROM public.profiles p WHERE p.id = auth.uid()) = 'Administrador');

-- 2. RLS: `ubicaciones_especialista` --------------------------------------------
DROP POLICY IF EXISTS "ubicacion_own" ON public.ubicaciones_especialista;
CREATE POLICY "ubicacion_own"
    ON public.ubicaciones_especialista
    FOR ALL TO authenticated
    USING (
        especialista_id IN (
            SELECT id FROM public.especialistas WHERE usuario_id = auth.uid()
        )
    )
    WITH CHECK (
        especialista_id IN (
            SELECT id FROM public.especialistas WHERE usuario_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "ubicacion_admin_select" ON public.ubicaciones_especialista;
CREATE POLICY "ubicacion_admin_select"
    ON public.ubicaciones_especialista
    FOR SELECT TO authenticated
    USING ((SELECT p.role FROM public.profiles p WHERE p.id = auth.uid()) = 'Administrador');

-- 3. RLS: `contratos` -------------------------------------------------------------
DROP POLICY IF EXISTS "contrato_own" ON public.contratos;
CREATE POLICY "contrato_own"
    ON public.contratos
    FOR ALL TO authenticated
    USING (
        especialista_id IN (
            SELECT id FROM public.especialistas WHERE usuario_id = auth.uid()
        )
    )
    WITH CHECK (
        especialista_id IN (
            SELECT id FROM public.especialistas WHERE usuario_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "contrato_admin_select" ON public.contratos;
CREATE POLICY "contrato_admin_select"
    ON public.contratos
    FOR SELECT TO authenticated
    USING ((SELECT p.role FROM public.profiles p WHERE p.id = auth.uid()) = 'Administrador');
