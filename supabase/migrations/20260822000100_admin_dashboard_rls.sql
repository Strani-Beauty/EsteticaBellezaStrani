-- =============================================================================
-- Migración: Panel de administración — Dashboard (RLS admin + RPC de KPIs).
-- -----------------------------------------------------------------------------
-- Habilita el acceso del Administrador (vía `is_administrador()`) a las tablas
-- de Datos Maestros y lectura para KPIs:
--   * configuracion_sistema: SELECT/UPDATE (edición de claves).
--   * roles (write), permisos, rol_permisos (ALL) — catálogo RBAC.
--   * comisiones, liquidaciones_especialistas, pagos_especialistas (ALL).
--   * solicitudes, citas, transacciones (SELECT) — KPIs / futura Auditoría.
-- RPC `admin_resumen_kpis()` security definer para el home del dashboard.
-- Idempotente: DROP POLICY IF EXISTS + CREATE OR REPLACE + GRANT.
-- =============================================================================

-- ── 1. configuracion_sistema ───────────────────────────────────────────────
DROP POLICY IF EXISTS "configuracion_sistema_admin_select" ON public.configuracion_sistema;
CREATE POLICY "configuracion_sistema_admin_select"
    ON public.configuracion_sistema
    FOR SELECT TO authenticated
    USING (public.is_administrador());

DROP POLICY IF EXISTS "configuracion_sistema_admin_update" ON public.configuracion_sistema;
CREATE POLICY "configuracion_sistema_admin_update"
    ON public.configuracion_sistema
    FOR UPDATE TO authenticated
    USING (public.is_administrador())
    WITH CHECK (public.is_administrador());

-- ── 2. roles (write) + permisos + rol_permisos (ALL) ───────────────────────
DROP POLICY IF EXISTS "roles_admin_write" ON public.roles;
CREATE POLICY "roles_admin_write"
    ON public.roles
    FOR ALL TO authenticated
    USING (public.is_administrador())
    WITH CHECK (public.is_administrador());

DROP POLICY IF EXISTS "permisos_admin_all" ON public.permisos;
CREATE POLICY "permisos_admin_all"
    ON public.permisos
    FOR ALL TO authenticated
    USING (public.is_administrador())
    WITH CHECK (public.is_administrador());

DROP POLICY IF EXISTS "rol_permisos_admin_all" ON public.rol_permisos;
CREATE POLICY "rol_permisos_admin_all"
    ON public.rol_permisos
    FOR ALL TO authenticated
    USING (public.is_administrador())
    WITH CHECK (public.is_administrador());

-- ── 3. Comisiones / liquidaciones / pagos a especialistas ─────────────────
DROP POLICY IF EXISTS "comisiones_admin_all" ON public.comisiones;
CREATE POLICY "comisiones_admin_all"
    ON public.comisiones
    FOR ALL TO authenticated
    USING (public.is_administrador())
    WITH CHECK (public.is_administrador());

DROP POLICY IF EXISTS "liquidaciones_especialistas_admin_all" ON public.liquidaciones_especialistas;
CREATE POLICY "liquidaciones_especialistas_admin_all"
    ON public.liquidaciones_especialistas
    FOR ALL TO authenticated
    USING (public.is_administrador())
    WITH CHECK (public.is_administrador());

DROP POLICY IF EXISTS "pagos_especialistas_admin_all" ON public.pagos_especialistas;
CREATE POLICY "pagos_especialistas_admin_all"
    ON public.pagos_especialistas
    FOR ALL TO authenticated
    USING (public.is_administrador())
    WITH CHECK (public.is_administrador());

-- ── 4. Lectura admin de solicitudes / citas / transacciones (KPIs) ─────────
DROP POLICY IF EXISTS "solicitudes_admin_select" ON public.solicitudes;
CREATE POLICY "solicitudes_admin_select"
    ON public.solicitudes
    FOR SELECT TO authenticated
    USING (public.is_administrador());

DROP POLICY IF EXISTS "citas_admin_select" ON public.citas;
CREATE POLICY "citas_admin_select"
    ON public.citas
    FOR SELECT TO authenticated
    USING (public.is_administrador());

DROP POLICY IF EXISTS "transacciones_admin_select" ON public.transacciones;
CREATE POLICY "transacciones_admin_select"
    ON public.transacciones
    FOR SELECT TO authenticated
    USING (public.is_administrador());

-- ── 5. RPC: resumen de KPIs del dashboard ─────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_resumen_kpis()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_solicitudes_por_estado jsonb;
    v_citas_activas          int;
    v_especialistas_pendientes int;
    v_medicos_pendientes     int;
    v_ingresos_totales       numeric;
    v_total_usuarios         int;
BEGIN
    SELECT COALESCE(jsonb_object_agg(estado, cnt ORDER BY estado), '{}'::jsonb)
      INTO v_solicitudes_por_estado
      FROM (
          SELECT estado, count(*)::int AS cnt
            FROM public.solicitudes
           GROUP BY estado
      ) t;

    SELECT count(*)::int INTO v_citas_activas
      FROM public.citas
     WHERE estado IN ('PROGRAMADA', 'EN_CAMINO', 'LLEGO', 'EN_PROCESO');

    SELECT count(*)::int INTO v_especialistas_pendientes
      FROM public.especialistas
     WHERE estado_verificacion IN ('PENDIENTE', 'EN_REVISION');

    SELECT count(*)::int INTO v_medicos_pendientes
      FROM public.medicos_regentes
     WHERE activo = false;

    SELECT COALESCE(sum(monto), 0)::numeric INTO v_ingresos_totales
      FROM public.transacciones
     WHERE estado = 'APROBADO';

    SELECT count(*)::int INTO v_total_usuarios
      FROM public.profiles
     WHERE activo = true;

    RETURN json_build_object(
        'solicitudes_por_estado', v_solicitudes_por_estado,
        'citas_activas', v_citas_activas,
        'especialistas_pendientes', v_especialistas_pendientes,
        'medicos_pendientes', v_medicos_pendientes,
        'ingresos_totales', v_ingresos_totales,
        'total_usuarios', v_total_usuarios
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_resumen_kpis() TO authenticated;
