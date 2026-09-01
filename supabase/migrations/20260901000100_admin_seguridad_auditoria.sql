-- =============================================================================
-- Migración: Seguridad admin (cierre de RPCs sin chequeo) + Módulo de Auditoría.
-- -----------------------------------------------------------------------------
-- 1) `admin_resumen_kpis()` y `eliminar_servicio()` eran SECURITY DEFINER con
--    GRANT authenticated pero SIN chequeo admin interno → cualquier usuario
--    autenticado podía leer KPIs completos o borrar servicios.
-- 2) `historial_estados` (log de transiciones) no tenía policy de SELECT para
--    el admin → el panel no podía consultar la trazabilidad.
-- 3) Nueva tabla `auditoria` con trigger genérico sobre las tablas sensibles:
--    registra quién (auth.uid()), qué operación (INSERT/UPDATE/DELETE), cuándo
--    y sobre qué registro. Solo lectura para admin.
-- Idempotente. Aplicar en orden ascendente.
-- =============================================================================

-- ── 1. Cerrar RPCs sin chequeo admin ─────────────────────────────────────────

-- 1a. admin_resumen_kpis: cualquier authenticated podía llamarla y leer KPIs.
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
    IF NOT public.is_administrador() THEN
        RETURN json_build_object('error', 'NO_AUTORIZADO');
    END IF;

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

-- 1b. eliminar_servicio: cualquier authenticated podía borrar servicios.
CREATE OR REPLACE FUNCTION public.eliminar_servicio(
    p_servicio_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_referenciado boolean;
BEGIN
    IF NOT public.is_administrador() THEN
        RETURN json_build_object('ok', false, 'motivo', 'NO_AUTORIZADO');
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM public.solicitud_detalles sd
        WHERE sd.servicio_id = p_servicio_id
    ) OR EXISTS (
        SELECT 1 FROM public.solicitudes s
        WHERE s.servicio_id = p_servicio_id
    ) INTO v_referenciado;

    IF v_referenciado THEN
        RETURN json_build_object('ok', false, 'motivo', 'REFERENCIADO');
    END IF;

    DELETE FROM public.servicio_especialidades
    WHERE servicio_id = p_servicio_id;

    DELETE FROM public.servicio_cuestionarios
    WHERE servicio_id = p_servicio_id;

    UPDATE public.face_maps
    SET servicio_id = NULL, updated_at = now()
    WHERE servicio_id = p_servicio_id;

    DELETE FROM public.servicios
    WHERE id = p_servicio_id;

    RETURN json_build_object('ok', true, 'motivo', 'OK');
END;
$$;

GRANT EXECUTE ON FUNCTION public.eliminar_servicio(uuid) TO authenticated;

-- ── 2. historial_estados: lectura admin (trazabilidad de transiciones) ───────
DROP POLICY IF EXISTS historial_estados_admin_select ON public.historial_estados;
CREATE POLICY historial_estados_admin_select
    ON public.historial_estados
    FOR SELECT TO authenticated
    USING (public.is_administrador());

-- ── 3. Tabla de auditoría ─────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.auditoria (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id  uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    accion      text NOT NULL,
    entidad     text NOT NULL,
    entidad_id  text,
    detalle     jsonb,
    fecha       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_auditoria_entidad ON public.auditoria (entidad, entidad_id);
CREATE INDEX IF NOT EXISTS idx_auditoria_fecha ON public.auditoria (fecha DESC);
CREATE INDEX IF NOT EXISTS idx_auditoria_usuario ON public.auditoria (usuario_id);

ALTER TABLE public.auditoria ENABLE ROW LEVEL SECURITY;

-- Solo el admin puede leer auditoría; la escritura la hacen los triggers
-- SECURITY DEFINER (owner = postgres, elude RLS).
DROP POLICY IF EXISTS auditoria_admin_select ON public.auditoria;
CREATE POLICY auditoria_admin_select
    ON public.auditoria
    FOR SELECT TO authenticated
    USING (public.is_administrador());

-- ── 4. Función + trigger genérico de auditoría ───────────────────────────────

CREATE OR REPLACE FUNCTION public.registrar_auditoria(
    p_usuario_id uuid,
    p_accion     text,
    p_entidad    text,
    p_entidad_id text,
    p_detalle    jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.auditoria (usuario_id, accion, entidad, entidad_id, detalle)
    VALUES (p_usuario_id, p_accion, p_entidad, p_entidad_id, p_detalle);
END;
$$;

GRANT EXECUTE ON FUNCTION public.registrar_auditoria(uuid, text, text, text, jsonb)
    TO authenticated;

-- Trigger genérico: audita INSERT/UPDATE/DELETE sobre una tabla.
-- Se pueden indicar columnas sensibles como argumentos (TG_ARGV): si se indican,
-- en UPDATE solo se audita cuando alguna de esas columnas cambió (reduce ruido).
CREATE OR REPLACE FUNCTION public.auditar_entidad()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_entidad_id text;
    v_detalle    jsonb;
    v_col        text;
    v_cambio     boolean := false;
BEGIN
    IF TG_OP = 'UPDATE' AND NEW IS NOT DISTINCT FROM OLD THEN
        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' AND TG_NARGS > 0 THEN
        FOREACH v_col IN ARRAY TG_ARGV LOOP
            IF (to_jsonb(OLD) ->> v_col) IS DISTINCT FROM (to_jsonb(NEW) ->> v_col) THEN
                v_cambio := true;
                EXIT;
            END IF;
        END LOOP;
        IF NOT v_cambio THEN
            RETURN NEW;
        END IF;
    END IF;

    v_entidad_id := COALESCE(to_jsonb(NEW) ->> 'id', to_jsonb(OLD) ->> 'id');

    CASE TG_OP
        WHEN 'DELETE' THEN v_detalle := to_jsonb(OLD);
        ELSE               v_detalle := to_jsonb(NEW);
    END CASE;

    PERFORM public.registrar_auditoria(
        auth.uid(),
        TG_OP,
        TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME,
        v_entidad_id,
        v_detalle
    );

    RETURN COALESCE(NEW, OLD);
END;
$$;

-- ── 5. Triggers sobre tablas sensibles ───────────────────────────────────────

-- perfiles: solo cuando cambian datos de identidad/estado.
DROP TRIGGER IF EXISTS trg_auditoria_profiles ON public.profiles;
CREATE TRIGGER trg_auditoria_profiles
    AFTER INSERT OR UPDATE OR DELETE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.auditar_entidad('activo', 'role', 'role_id', 'full_name', 'email', 'phone');

-- especialistas: verificación/estado/disponibilidad.
DROP TRIGGER IF EXISTS trg_auditoria_especialistas ON public.especialistas;
CREATE TRIGGER trg_auditoria_especialistas
    AFTER INSERT OR UPDATE OR DELETE ON public.especialistas
    FOR EACH ROW
    EXECUTE FUNCTION public.auditar_entidad('estado_verificacion', 'aprobado_por', 'observacion', 'disponible', 'activo');

-- documentos_especialista: revisión de documentos.
DROP TRIGGER IF EXISTS trg_auditoria_documentos_especialista ON public.documentos_especialista;
CREATE TRIGGER trg_auditoria_documentos_especialista
    AFTER INSERT OR UPDATE OR DELETE ON public.documentos_especialista
    FOR EACH ROW
    EXECUTE FUNCTION public.auditar_entidad('estado_revision', 'observacion_revision', 'revisado_por', 'fecha_revision', 'activo');

-- liquidaciones_especialistas: transición de estado / pago.
DROP TRIGGER IF EXISTS trg_auditoria_liquidaciones_especialistas ON public.liquidaciones_especialistas;
CREATE TRIGGER trg_auditoria_liquidaciones_especialistas
    AFTER INSERT OR UPDATE OR DELETE ON public.liquidaciones_especialistas
    FOR EACH ROW
    EXECUTE FUNCTION public.auditar_entidad('estado', 'fecha_pago', 'monto_pagar');

-- pagos_especialistas: pago registrado (insert inmutable).
DROP TRIGGER IF EXISTS trg_auditoria_pagos_especialistas ON public.pagos_especialistas;
CREATE TRIGGER trg_auditoria_pagos_especialistas
    AFTER INSERT OR UPDATE OR DELETE ON public.pagos_especialistas
    FOR EACH ROW
    EXECUTE FUNCTION public.auditar_entidad();

-- roles / permisos / rol_permisos (RBAC).
DROP TRIGGER IF EXISTS trg_auditoria_roles ON public.roles;
CREATE TRIGGER trg_auditoria_roles
    AFTER INSERT OR UPDATE OR DELETE ON public.roles
    FOR EACH ROW
    EXECUTE FUNCTION public.auditar_entidad();

DROP TRIGGER IF EXISTS trg_auditoria_permisos ON public.permisos;
CREATE TRIGGER trg_auditoria_permisos
    AFTER INSERT OR UPDATE OR DELETE ON public.permisos
    FOR EACH ROW
    EXECUTE FUNCTION public.auditar_entidad();

DROP TRIGGER IF EXISTS trg_auditoria_rol_permisos ON public.rol_permisos;
CREATE TRIGGER trg_auditoria_rol_permisos
    AFTER INSERT OR UPDATE OR DELETE ON public.rol_permisos
    FOR EACH ROW
    EXECUTE FUNCTION public.auditar_entidad();

-- configuracion_sistema: cambios de parámetros operativos.
DROP TRIGGER IF EXISTS trg_auditoria_configuracion_sistema ON public.configuracion_sistema;
CREATE TRIGGER trg_auditoria_configuracion_sistema
    AFTER INSERT OR UPDATE OR DELETE ON public.configuracion_sistema
    FOR EACH ROW
    EXECUTE FUNCTION public.auditar_entidad('clave', 'valor', 'activo');

-- citas: solo transición de estado (evita ruido por latitud/longitud).
DROP TRIGGER IF EXISTS trg_auditoria_citas ON public.citas;
CREATE TRIGGER trg_auditoria_citas
    AFTER INSERT OR UPDATE OR DELETE ON public.citas
    FOR EACH ROW
    EXECUTE FUNCTION public.auditar_entidad('estado');

-- solicitudes: transición de estado / publicación.
DROP TRIGGER IF EXISTS trg_auditoria_solicitudes ON public.solicitudes;
CREATE TRIGGER trg_auditoria_solicitudes
    AFTER INSERT OR UPDATE OR DELETE ON public.solicitudes
    FOR EACH ROW
    EXECUTE FUNCTION public.auditar_entidad('estado');

-- transacciones: pagos (insert inmutable, pero audita cambios/anulaciones).
DROP TRIGGER IF EXISTS trg_auditoria_transacciones ON public.transacciones;
CREATE TRIGGER trg_auditoria_transacciones
    AFTER INSERT OR UPDATE OR DELETE ON public.transacciones
    FOR EACH ROW
    EXECUTE FUNCTION public.auditar_entidad();

-- pagos: estado / saldo / montos.
DROP TRIGGER IF EXISTS trg_auditoria_pagos ON public.pagos;
CREATE TRIGGER trg_auditoria_pagos
    AFTER INSERT OR UPDATE OR DELETE ON public.pagos
    FOR EACH ROW
    EXECUTE FUNCTION public.auditar_entidad('estado', 'monto_total', 'deposito', 'saldo_pendiente');

-- tratamientos: ciclo de tratamiento.
DROP TRIGGER IF EXISTS trg_auditoria_tratamientos ON public.tratamientos;
CREATE TRIGGER trg_auditoria_tratamientos
    AFTER INSERT OR UPDATE OR DELETE ON public.tratamientos
    FOR EACH ROW
    EXECUTE FUNCTION public.auditar_entidad('estado');