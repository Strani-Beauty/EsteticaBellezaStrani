# Plan: Panel de administración — Dashboard

| | |
|---|---|
| **Fecha** | 2026-08-22 |
| **Estado** | APROBADO por el usuario (2026-08-22) |
| **Proyecto Supabase** | `hhyjremkguvphmjuaazp` |
| **Decisiones tomadas** | Ver sección "Decisiones" |

## Contexto

El panel admin (`/admin`, `AdminDashboardScreen`) muestra 3 tarjetas (Usuarios,
Cuestionario, Catálogo) y **embebe** la Verificación de Licencias (especialistas +
documentos + médicos regentes). Se transforma en un **dashboard** con KPIs y
tarjetas agrupadas, con Licencias como vista propia y nuevas secciones de Datos
Maestros. `admin_config` y `reports_dashboards` son stubs.

### Hallazgos de RLS (2026-08-22)

- `configuracion_sistema`, `comisiones`, `liquidaciones_especialistas`,
  `pagos_especialistas`, `permisos`, `rol_permisos` **sin policies** → el admin no
  puede leerlos vía REST.
- `roles`: solo lectura pública. `solicitudes/citas/transacciones`: sin lectura admin.
- Existe `is_administrador()` (security definer, `profiles.role='Administrador'`).
- Datos: `roles=4`, `permisos=4`, `rol_permisos=0`, `configuracion_sistema=17`.

## Decisiones

1. **Home con KPIs + tarjetas** (sin shell lateral persistente).
2. **Licencias → vista propia** `/admin/licencias` (se extrae del dashboard).
3. **Datos Maestros = todas**: Roles y Permisos, Configuración del Sistema,
   Comisiones y Liquidaciones, Especialidades, Médicos Regentes.
4. **Auditoría → fuera de alcance** (se hará más adelante).
5. **KPIs simples en el home** (resumen).

## Estructura de secciones

- **Administrativo** (operativo): Usuarios · Cuestionario de Salud · Catálogo de Servicios · Verificación de Licencias.
- **Datos Maestros**: Roles y Permisos · Configuración del Sistema · Comisiones y Liquidaciones · Especialidades · Médicos Regentes.

## Actividades → implementación

### A. Migración BD `supabase/migrations/20260822000100_admin_dashboard_rls.sql` (idempotente)

- [x] A1. Policies admin con `is_administrador()`: `configuracion_sistema_admin_select`/`_update`, `roles_admin_write`, `permisos_admin_all`, `rol_permisos_admin_all`, `comisiones_admin_all`, `liquidaciones_especialistas_admin_all`, `pagos_especialistas_admin_all`, `solicitudes_admin_select`, `citas_admin_select`, `transacciones_admin_select`.
- [x] A2. RPC `admin_resumen_kpis()` security definer → json `{solicitudes_por_estado, citas_activas, especialistas_pendientes, medicos_pendientes, ingresos_totales, total_usuarios}` + GRANT authenticated.
- [x] A3. Aplicada al remoto y registrada en `schema_migrations`. Verificado: KPIs devuelven datos reales.

### B. Feature `admin_config` (expandir)

- [x] B1. `AdminDashboardScreen` → Home: KPIs (RPC) + tarjetas agrupadas (Administrativo / Datos Maestros). Se quitó la vista incrustada de licencias.
- [x] B2. `AdminLicenciasScreen` (`/admin/licencias`): extrae `_VerificacionDeLicencias` reutilizando `SpecialistsCubit`.
- [x] B3. `AdminConfiguracionScreen` (`/admin/configuracion`): listar/editar claves de `configuracion_sistema`.
- [x] B4. Datasource `admin_config_supabase_datasource` (RPC KPIs + config CRUD), repository `Either<Failure,T>`, usecases, cubits, registro DI.

### C. Feature nueva `admin_master_data` (Datos Maestros)

- [x] C1. Datasource + entidades: roles/permisos/rol_permisos, comisiones/liquidaciones/pagos_especialistas, especialidades, médicos regentes.
- [x] C2. Repos/usecases/cubits.
- [x] C3. Screens: `AdminDatosMaestrosScreen` (hub) · `AdminRolesScreen` · `AdminComisionesScreen` · `AdminEspecialidadesScreen` · `AdminMedicosRegentesScreen` (reutiliza usecases de specialists).
- [x] C4. Registro DI.

### D. Rutas y guard

- [x] D1. Nuevas rutas en `app_routes.dart` (todas bajo `/admin`, cubiertas por `_esRutaAdmin`).
- [x] D2. Enlaces desde el home del dashboard.

### E. Verificación y documentación

- [x] E1. `flutter analyze` 0 issues; `flutter test` (144 + test nuevo de `AdminDashboardCubit`).
- [x] E2. Migración aplicada al remoto y verificada (policies + RPC).
- [x] E3. Docs: `docs/pruebas/2026-08-22_admin_dashboard_e2e.md` + `docs/Pruebas manuales/13_admin_dashboard.md`.

## Notas

- "Roles y Permisos" es catálogo RBAC maestro: la autorización efectiva sigue siendo
  `profiles.role` + `is_administrador()`; no se modifica `profiles.role` desde esa pantalla.
- Deuda documentada (no corregida aquí): policies demasiado amplias ("Permitir todo a
  usuarios autenticados" en evaluaciones/validaciones/cuestionarios/especialidades) →
  endurecer en plan futuro.
- Auditoría: fuera de alcance (futuro).
- **Fix post-verificación (2026-08-22)**: faltaban FKs para los select embebidos de PostgREST
  (`rol_permisos.rol_id → roles.id`, `liquidaciones/pagos_especialistas.especialista_id →
  especialistas.id`) → PGRST200 "Could not find a relationship". Se añadieron con la migración
  `20260822000200_fk_master_data.sql` (idempotente) y se desambiguó el join a `profiles`
  (`profiles!especialistas_usuario_id_fkey`) en el datasource de Datos Maestros.
