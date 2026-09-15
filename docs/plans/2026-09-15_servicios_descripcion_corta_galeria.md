# Plan — Servicios: descripcion_corta + galería de 4 imágenes

Fecha: 2026-09-15
Estado: APROBADO por el usuario (m0114: "aprobado"). Sin commit.

## Objetivo

La tarjeta del catálogo (`services_dashboard_screen.dart`) muestra una **descripción
corta** del servicio (campo dedicado) visualizada **completa** en el recuadro. Además,
cada servicio guarda su **imagen principal en `imagen_url`** y **4 imágenes adicionales**
(URLs) en `imagen_url_2`..`imagen_url_5`. Nombres confirmados por el usuario (m0110):
`descripcion_corta` + `imagen_url_2.._5`; las 4 imágenes solo se guardan ahora (sin
miniatura en la tarjeta); backfill `descripcion → descripcion_corta`.

## Cambios

### 1. Migración `supabase/migrations/20260915000100_servicios_descripcion_corta_galeria.sql`
- `ADD COLUMN IF NOT EXISTS descripcion_corta text;`
- `ADD COLUMN IF NOT EXISTS imagen_url_2 text;` (ídem `_3`, `_4`, `_5`).
- Backfill idempotente: `UPDATE ... SET descripcion_corta = descripcion WHERE descripcion_corta IS NULL AND descripcion IS NOT NULL;`
- Sin RLS nuevo: `catalogo_servicios_public_select` (SELECT anon/authenticated) y
  `catalogo_servicios_admin_write` (escritura admin) ya cubren las columnas nuevas.
  Storage reutiliza bucket público `imagenes-servicios` y policy `servicio_imagen_admin_insert`.

### 2. Dominio/modelo
- `servicio_entity.dart`: `+ final String? descripcionCorta;` `+ final List<String> imagenesAdicionales;`
  (default `const []`, índices 0-3 → columnas `_2.._5`); añadir ambos a `props`.
- `servicio_model.dart`: `fromJson` parsea `descripcion_corta` e `imagen_url_2.._5`
  (filtra null/vacío); `toEntity` los propaga.

### 3. Usecases
- `guardar_servicio.dart`: `GuardarServicioParams` + `descripcionCorta` + `imagenesAdicionales`, passthrough.
- `subir_imagen_servicio.dart`: `SubirImagenServicioParams` + `columna` (default `'imagen_url'`), passthrough.

### 4. Datasource + repositorio
- `catalog_services_supabase_datasource.dart`: `insertServicio`/`updateServicio` incluyen
  `descripcion_corta` y `imagen_url_2.._5` (null si índice ausente o vacío).
  `subirImagenServicio({..., columna})`: `.update({columna: url})` y path
  `'$servicioId/imagen_${columna}_$ts$ext'`. Ya persiste la URL en la tabla (imagen principal y extra).
- `catalog_repository_impl.dart` + `ICatalogRepository`: firmas actualizadas.

### 5. Cubit admin (`admin_catalog_cubit.dart`)
- `guardarServicio` + `descripcionCorta`/`imagenesAdicionales`; `subirImagenServicio` + `columna` (passthrough).

### 6. Formulario admin (`admin_servicio_detail_screen.dart`)
- Controller `_descripcionCortaCtrl` prellenado `s?.descripcionCorta ?? s?.descripcion` +
  `TextFormField 'Descripción corta'` (maxLines 3) en datos básicos.
- `_seccionGaleria()` con 4 slots (URL existente o bytes pendientes + 'Seleccionar imagen' + quitar);
  estado `_galeriaUrls` (4), `_galeriaBytes` (4), `_galeriaNombres` (4).
- `_guardar`: pasa `descripcionCorta` y las 4 URLs; tras guardar, sube cada bytes pendiente
  con `columna: 'imagen_url_${index+2}'`.

### 7. Tarjeta catálogo (`services_dashboard_screen.dart`)
- `_ServiceCard`: descripción muestra `service.descripcionCorta ?? service.descripcion`
  (completa, sin truncar). Imagen principal sigue `service.imagenUrl`. Sin galería en la tarjeta.

## Verificación

- [x] `flutter analyze` limpio.
- [x] `flutter test` (366 tests: `servicio_model_test`, `admin_catalog_cubit_test`,
      `catalog_repository_impl_test` no se rompen, campos opcionales).
- [ ] Manual en `flutter run -d chrome`: panel admin → editar servicio → descripción corta
      persistida y visible completa en catálogo; subir 4 imágenes de galería → `imagen_url_2.._5`.
- [x] Migración aplicada al remoto (2026-09-15): el CLI no tiene sesión (`supabase db push` → 401),
      se aplicó por conexión directa al pooler con driver `pg` (patrón AGENTS.md). Verificado:
      las 5 columnas existen y los 35 servicios tienen `descripcion_corta` (backfill OK).

## Notas
- Sin commit (regla del proyecto: preguntar antes de commitear).