# Plan: Imagen de servicio gestionable por el administrador (storage)

| | |
|---|---|
| **Fecha** | 2026-08-27 |
| **Estado** | APROBADO por el usuario (2026-08-27) |
| **Proyecto Supabase** | `hhyjremkguvphmjuaazp` |
| **Decisiones tomadas** | (1) El fallback por slug (asset local) se mantiene; la URL guardada gana si existe. (2) El admin sube un archivo a storage (no solo URL). (3) La migración la aplico yo con `supabase db push` (password ya verificado). |

## Contexto

Las imágenes de servicios son **assets locales** `assets/images/service_<slug>.<ext>` resueltas por
`_ServiceHeroImage` en `services_dashboard_screen.dart` (prueba `.jpg/.jfif/.jpeg/.png/.webp` y cae a
gradiente + ícono). El admin **no puede gestionar la imagen** de un servicio: no hay columna en BD,
ni bucket de storage, ni campo en el formulario.

**Cambio solicitado**: que el administrador pueda cargar una imagen a un servicio y el sistema la guarde.
Se añade `servicios.imagen_url` + bucket público `imagenes-servicios` + subida desde el formulario admin.

## Actividades → implementación

### A. Migración BD (idempotente, aplicada con `supabase db push`)

- [x] A1. `supabase/migrations/20260827000200_servicios_imagen_url.sql`
  - `ALTER TABLE public.servicios ADD COLUMN IF NOT EXISTS imagen_url text;`
  - Bucket `imagenes-servicios` con `public = TRUE` (imágenes de catálogo, no sensibles).
  - Storage policy `servicio_imagen_admin_insert` (INSERT solo admin vía `profiles.role='Administrador'`).
  - Lectura pública por el bucket público (no aplica signed URLs).

### B. Capa de datos (catalog_services)

- [x] B1. `ServicioEntity` / `ServicioModel`: nuevo campo `String? imagenUrl` (parse `imagen_url`, añadir a props).
- [x] B2. `catalog_services_supabase_datasource.dart`:
  - `insertServicio` / `updateServicio` ganan `String? imagenUrl` (`'imagen_url': (imagenUrl==null||isEmpty) ? null : imagenUrl`).
  - Nuevo `subirImagenServicio({servicioId, bytes, nombreArchivo})` → uploadBinary al bucket
    `imagenes-servicios` path `<servicioId>/imagen_<ts>.<ext>`, `getPublicUrl`, UPDATE `servicios.imagen_url`.
- [x] B3. `i_catalog_repository.dart`: `guardarServicio` gana `imagenUrl`; nuevo
  `subirImagenServicio({servicioId, bytes, nombreArchivo}) → Either<Failure, String>`.
- [x] B4. `catalog_repository_impl.dart`: implementa el método.
- [x] B5. Nuevo usecase `subir_imagen_servicio.dart`: `SubirImagenServicio` (patrón UseCase<String, Params>).
- [x] B6. `GuardarServicioParams` gana `imagenUrl`.
- [x] B7. `AppConstants.bucketImagenesServicios = 'imagenes-servicios'`.

### C. Cubit + DI

- [x] C1. `AdminCatalogCubit.guardarServicio` gana `String? imagenUrl`; nuevo método
  `subirImagenServicio({servicioId, bytes, nombreArchivo}) → Future<bool>` (saving, fold, reload, feedback).
  Inyectar `SubirImagenServicio` por nombre.
- [x] C2. DI `_registerCatalogServices`: registrar `SubirImagenServicio` y pasarlo al cubit
  (regla: añadir SIEMPRE el nuevo usecase al constructor del cubit y a su registro).

### D. UI

- [x] D1. `admin_servicio_detail_screen.dart`: sección "Imagen del servicio" — botón 'Seleccionar imagen'
  (`file_picker` jpg/png/webp) → bytes en estado; preview (Image.memory si bytes pendientes /
  Image.network si `imagenUrl` / placeholder); botón 'Quitar imagen' (→ imagenUrl null).
  En `_guardar`: tras guardarServicio exitoso (entity con id), si hay bytes → `cubit.subirImagenServicio(...)`;
  si quitó → `imagenUrl: null`.
- [x] D2. `services_dashboard_screen.dart` `_buildHero`: si `service.imagenUrl` trim no vacío →
  `Image.network(fit: cover, errorBuilder → _buildHeroFallback)`; si no → asset por slug actual (sin cambio).

### E. Verificación y documentación

- [x] E1. `admin_catalog_cubit_test.dart`: mock de `SubirImagenServicio` + `imagenUrl` en guardarServicio
  (mismo patrón que EliminarServicio).
- [x] E2. `flutter analyze` 0 issues; `flutter test` 366/366.
- [x] E3. Migración aplicada con `supabase db push`.
- [x] E4. Plan actualizado con checkpoints `[x]`.

## Notas

- Deuda técnica documentada: al reemplazar una imagen no se borra el objeto anterior del bucket.
- El catálogo público sigue usando assets como fallback; la URL gana si existe (`imagen_url`).