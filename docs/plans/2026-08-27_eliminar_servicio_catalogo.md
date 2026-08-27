# Plan: Eliminar servicios del catálogo (admin) con RPC seguro

| | |
|---|---|
| **Fecha** | 2026-08-27 |
| **Estado** | APROBADO por el usuario (2026-08-27) |
| **Proyecto Supabase** | `hhyjremkguvphmjuaazp` |
| **Decisiones tomadas** | (1) Eliminación vía RPC `eliminar_servicio` SECURITY DEFINER (no DELETE directo por FK). (2) Bloqueo de borrado si el servicio tiene historial en `solicitudes`/`solicitud_detalles` (motivo `REFERENCIADO`). (3) Se limpian relaciones `servicio_especialidades` y `servicio_cuestionarios`, y `face_maps.servicio_id` pasa a NULL. (4) UI: botón de eliminar por servicio con confirmación y aviso si está referenciado. (5) La migración la aplica el usuario (patrón previo) o se le indica el archivo. |

## Contexto

El admin puede crear, editar y activar/desactivar servicios (`AdminCatalogScreen`), pero **no puede eliminarlos** (`grep` eliminar/delete/borrar en `catalog_services` → 0 coincidencias). Un DELETE directo a `servicios` fallaría por FKs sin `ON DELETE CASCADE`:
`servicios` ← `solicitud_detalles.servicio_id`, `solicitudes.servicio_id` (legacy),
`servicio_cuestionarios.servicio_id`, `servicio_especialidades.servicio_id` y
`face_maps.servicio_id` (migración `20260817010000`, FK sin ON DELETE).

El RLS ya permite DELETE al admin (`catalogo_servicios_admin_write` FOR ALL + GRANT DELETE en `20260819000000_catalog_admin_rls_relaciones.sql`).

## Actividades → implementación

### A. Migración BD (idempotente, aplicada por el usuario)

- [x] A1. `supabase/migrations/20260827000100_eliminar_servicio.sql`
  - Función `eliminar_servicio(p_servicio_id uuid)` RETURNS json SECURITY DEFINER:
    1. Si el servicio está referenciado en `solicitudes` o `solicitud_detalles` →
       `{ok:false, motivo:'REFERENCIADO'}` (historial de negocio inmutable).
    2. DELETE `servicio_especialidades` y `servicio_cuestionarios` del servicio.
    3. UPDATE `face_maps SET servicio_id = NULL WHERE servicio_id = p_servicio_id`.
    4. DELETE de `servicios` → `{ok:true, motivo:'OK'}`.
  - `GRANT EXECUTE ... TO authenticated`.

### B. Capa de datos (catalog_services)

- [x] B1. `catalog_services_supabase_datasource.dart`: `eliminarServicio(String id)` →
  RPC `eliminar_servicio` (param `p_servicio_id`), valida `ok == true`, lanza excepción
  con motivo si es `REFERENCIADO`.
- [x] B2. `i_catalog_repository.dart`: método `eliminarServicio(String id) → Future<Either<Failure, void>>`.
- [x] B3. `catalog_repository_impl.dart`: implementa el método.
- [x] B4. Nuevo usecase `eliminar_servicio.dart`: `EliminarServicio(ICatalogRepository)`.

### C. Cubit + DI

- [x] C1. `AdminCatalogCubit`: inyectar `EliminarServicio`; método `eliminarServicio(String id)`
  (trabajando, llama usecase, recarga `load()` o getServiciosAdmin, emite feedback 'Servicio eliminado').
- [x] C2. DI `_registerCatalogServices`: registrar `EliminarServicio` y pasarlo al cubit
  (regla: añadir SIEMPRE el nuevo usecase al constructor del cubit y a su registro).

### D. UI

- [x] D1. `admin_catalog_screen.dart`: `_ServiciosTab` recibe `onEliminar`; `_ServicioTile` muestra
  icono de papelera; diálogo de confirmación («¿Eliminar servicio?»); si el cubit devuelve
  error `REFERENCIADO` → SnackBar «No se puede eliminar: el servicio tiene solicitudes/historial.
  Desactívelo en su lugar.»

### E. Verificación y documentación

- [x] E1. `flutter analyze` 0 issues; `flutter test` 366/366.
- [x] E2. Plan actualizado con checkpoints `[x]`.

## Notas

- La migración la aplica el usuario desde el SQL Editor (orden ascendente de nombre).
- Se mantiene el patrón Either<Failure,T> y la inyección por nombre del cubit.
