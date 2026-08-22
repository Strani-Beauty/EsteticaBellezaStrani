# Pruebas manuales — Panel de administración (Dashboard)

| | |
|---|---|
| **Módulo** | admin_config (dashboard) + admin_master_data (Datos Maestros) |
| **Estado del código** | COMPLETO (KPIs, secciones, RLS y RPC) |
| **Fecha** | 2026-08-22 |
| **Versión** | 1.0 |

## Alcance

`/admin` → dashboard con **KPIs** (solicitudes por estado, citas activas, especialistas
pendientes, médicos pendientes, ingresos, usuarios) y **tarjetas agrupadas**:

- **Administrativo**: Usuarios · Cuestionario de Salud · Catálogo de Servicios · Verificación de Licencias.
- **Datos Maestros**: Roles y Permisos · Configuración del Sistema · Comisiones y Liquidaciones · Especialidades · Médicos Regentes.

## Precondiciones generales

- Sesión de **Administrador** (`admin@test` / `admin@strani.com`, `Test1234!`).
- Migración `20260822000100_admin_dashboard_rls.sql` aplicada al remoto.

## Casos

| ID | Título | Pasos | Resultado esperado | Prioridad | Resultado |
|---|---|---|---|---|---|
| AD-H-01 | Home con KPIs | 1. Entrar a `/admin` | KPIs cargados (RPC `admin_resumen_kpis`) | Crítica | |
| AD-H-02 | Tarjetas Administrativo | 1. Ver home | Usuarios, Cuestionario, Catálogo, Licencias navegan | Crítica | |
| AD-H-03 | Tarjetas Datos Maestros | 1. Ver home | Roles, Configuración, Comisiones, Especialidades, Médicos navegan | Crítica | |
| AD-H-04 | Licencias propia | 1. `/admin/licencias` | Expedientes + aprobar/rechazar/bloquear + médicos | Crítica | |
| AD-H-05 | Configuración editar | 1. `/admin/configuracion` 2. Editar una clave | Guarda y persiste | Alta | |
| AD-H-06 | Roles CRUD | 1. `/admin/datos-maestros/roles` 2. Nuevo rol + asignar permiso | Se crea y asigna | Alta | |
| AD-H-07 | Especialidades CRUD | 1. `/admin/datos-maestros/especialidades` 2. Nueva + toggle | Se crea y activa/desactiva | Media | |
| AD-H-08 | Médicos regentes | 1. `/admin/datos-maestros/medicos-regentes` 2. Registrar + aprobar | Registra PENDIENTE; aprueba → ACTIVO | Media | |
| AD-H-09 | Comisiones y liquidaciones | 1. `/admin/datos-maestros/comisiones` | Lista liquidaciones/pagos; enlace a configuración | Media | |
| AD-V-01 | Guard por rol | 1. Sesión especialista/paciente → `/admin/*` | Redirige por rol | Crítica | |
| AD-V-02 | RLS admin | 1. Leer `configuracion_sistema`/`roles`/`comisiones` sin admin | Sin filas (RLS) | Crítica | |

## Resumen de ejecución

| Total | Pasa | Falla | Bloqueado | Pendiente |
|---|---|---|---|---|
| 11 | | | | 11 |
