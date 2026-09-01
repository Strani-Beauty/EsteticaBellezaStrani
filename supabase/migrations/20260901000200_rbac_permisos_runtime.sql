-- =============================================================================
-- Migración: RBAC en runtime — permisos por rol aplicados en la app.
-- -----------------------------------------------------------------------------
-- Hasta hoy el catálogo roles/permisos/rol_permisos se gestionaba desde el
-- panel (admin_roles_screen) pero NO se aplicaba: toda la autorización real
-- era `profiles.role = 'Administrador'` + RLS `is_administrador()`.
-- Esta migración:
--   1) Crea `tiene_permiso(codigo)` (SECURITY DEFINER, con cache en set_config)
--      y `mis_permisos()` (text[] de códigos del auth.uid()) para gating fino.
--   2) Seeds idempotentes del catálogo de `permisos` (módulos del panel admin).
--   3) Seeds de `rol_permisos` para el rol Administrador (super-rol: ve todo;
--      `is_administrador()` sigue siendo la fuente de autorización de fondo).
-- Idempotente. Aplicar en orden ascendente.
-- =============================================================================

-- ── 1. Catálogo de permisos (seeds idempotentes) ────────────────────────────
-- Se usa ON CONFLICT sobre (codigo) por si la tabla ya tiene filas manuales.
INSERT INTO public.permisos (codigo, nombre, modulo, descripcion)
SELECT * FROM (VALUES
    ('admin.dashboard',   'Panel principal',       'admin', 'Ver KPIs y resumen del panel administrativo'),
    ('admin.usuarios',    'Gestión de usuarios',   'admin', 'Listar y activar/desactivar usuarios'),
    ('admin.pacientes',   'Gestión de pacientes',  'admin', 'Listar, ver detalle y activar/desactivar pacientes'),
    ('admin.cuestionario','Cuestionario de salud', 'admin', 'Administrar versiones y preguntas del cuestionario'),
    ('admin.catalogo',    'Catálogo de servicios', 'admin', 'Crear, editar y eliminar servicios del catálogo'),
    ('admin.licencias',   'Verificación de licencias', 'admin', 'Aprobar/rechazar/bloquear especialistas y revisar documentos'),
    ('admin.configuracion','Configuración del sistema', 'admin', 'Editar parámetros de configuración (configuracion_sistema)'),
    ('admin.conciliacion','Conciliación de pagos', 'admin', 'Ver transacciones y detalle financiero por cita'),
    ('admin.auditoria',   'Auditoría',             'admin', 'Consultar el registro de auditoría'),
    ('admin.roles',       'Roles y permisos',      'admin', 'Gestionar roles y asignación de permisos (RBAC)'),
    ('admin.comisiones',  'Comisiones y liquidaciones', 'admin', 'Generar cortes, revisar, aprobar y pagar liquidaciones'),
    ('admin.especialidades','Especialidades',      'admin', 'Gestionar catálogo de especialidades'),
    ('admin.medicos',     'Médicos regentes',      'admin', 'Registrar y validar médicos regentes')
) AS v(codigo, nombre, modulo, descripcion)
ON CONFLICT (codigo) DO UPDATE SET
    nombre = EXCLUDED.nombre,
    modulo = EXCLUDED.modulo,
    descripcion = EXCLUDED.descripcion;

-- ── 2. rol_permisos del rol Administrador (super-rol) ───────────────────────
INSERT INTO public.rol_permisos (rol_id, permiso_id)
SELECT r.id, p.id
  FROM public.roles r
  JOIN public.permisos p ON TRUE
 WHERE r.name = 'Administrador'
   AND p.codigo LIKE 'admin.%'
   AND NOT EXISTS (
       SELECT 1 FROM public.rol_permisos rp
        WHERE rp.rol_id = r.id AND rp.permiso_id = p.id
   );

-- ── 3. Función tiene_permiso(codigo) con cache por sesión ────────────────────
-- SECURITY DEFINER para eludir RLS de profiles/permisos (mismo patrón de
-- is_administrador). Cachea la lista de códigos del rol del usuario en
-- set_config('app.mis_permisos') para evitar consultas repetidas en la sesión.
CREATE OR REPLACE FUNCTION public.tiene_permiso(p_codigo text)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_role_id    bigint;
    v_cache_key  text;
    v_cache      text;
    v_codes      text[];
BEGIN
    SELECT role_id INTO v_role_id FROM public.profiles WHERE id = auth.uid();

    IF v_role_id IS NULL THEN
        RETURN false;
    END IF;

    -- Cache por sesión keyed por usuario (evita fuga entre usuarios que
    -- compartan transacción/sesión). set_config es local a la transacción.
    -- El nombre GUC solo admite [a-z0-9_]; se limpian los guiones del uuid.
    v_cache_key := 'app.mis_permisos_'
                   || regexp_replace(COALESCE(auth.uid()::text, 'anon'), '[^a-z0-9_]', '', 'g');
    v_cache := current_setting(v_cache_key, true);
    IF v_cache IS NULL THEN
        SELECT COALESCE(array_agg(perm.codigo ORDER BY perm.codigo), array[]::text[])
          INTO v_codes
          FROM public.rol_permisos rp
          JOIN public.permisos perm ON perm.id = rp.permiso_id
         WHERE rp.rol_id = v_role_id;

        v_cache := array_to_string(v_codes, ',');
        PERFORM set_config(v_cache_key, v_cache, true);
    END IF;

    RETURN (p_codigo = ANY (string_to_array(v_cache, ',')));
END;
$$;

-- ── 4. RPC mis_permisos(): text[] de códigos del usuario logueado ────────────
-- Útil para la UI (gating de tiles) sin llamar tiene_permiso por cada tile.
CREATE OR REPLACE FUNCTION public.mis_permisos()
RETURNS text[]
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_role_id bigint;
    v_codes   text[];
BEGIN
    SELECT role_id INTO v_role_id FROM public.profiles WHERE id = auth.uid();

    IF v_role_id IS NULL THEN
        RETURN array[]::text[];
    END IF;

    SELECT COALESCE(array_agg(perm.codigo ORDER BY perm.codigo), array[]::text[])
      INTO v_codes
      FROM public.rol_permisos rp
      JOIN public.permisos perm ON perm.id = rp.permiso_id
     WHERE rp.rol_id = v_role_id;

    RETURN v_codes;
END;
$$;

GRANT EXECUTE ON FUNCTION public.tiene_permiso(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mis_permisos() TO authenticated;