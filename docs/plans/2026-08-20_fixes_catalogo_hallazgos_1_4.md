# Plan: Fixes post-E2E del catálogo — hallazgos 1-4 (2026-08-20)

| | |
|---|---|
| **Fecha** | 2026-08-20 |
| **Estado** | APROBADO por el usuario (2026-08-20) |
| **Proyecto Supabase** | `hhyjremkguvphmjuaazp` |
| **Origen** | Reporte `docs/pruebas/2026-08-20_catalogos_servicios_e2e.md` (hallazgos 1-4) |

## Contexto

El E2E del catálogo (Act. 12-13) quedó verificado. El reporte dejó 4 hallazgos de
deuda técnica/menores que el usuario pidió implementar ahora:

1. **Listado admin no refresca tras guardar servicio** (UI).
2. **Sin feedback de error al guardar servicio** (UI): `_guardar` retorna
   silenciosamente si el INSERT falla (ej. `categoria_id` NOT NULL → 23502).
3. **Post-face map nuevo no abre el modal de pago** (flujo paciente): al completar
   un face map **nuevo** (rama `else` de `_onServiceSelected`), el usuario debe volver
   a tocar el servicio; en modo solo lectura sí continúa.
4. **Nota 1 — re-link de 5 servicios inactivos al cuestionario v2 (id=5)** (BD).

## Hallazgo 3 — análisis del flujo face map

En `services_dashboard_screen.dart` (`_onServiceSelected`):

- Rama con mapa existente y tratamiento abierto → `soloLectura: true` →
  `pop('continuar')` → `_showPaymentOptionsModal` si `resultado == 'continuar'`.
- Rama **else** (mapa nuevo o tratamiento cerrado) → `context.push(faceMapQuestionnaire)`
  **sin capturar el resultado**: tras guardar, `_saveFaceMap` muestra el diálogo
  "Mapeo Registrado" cuyo "Aceptar" hace `Navigator.pop(context)` **sin valor**
  (`face_map_questionnaire_screen.dart:503-513`) → el dashboard no continúa.

Fix: en `_saveFaceMap` el "Aceptar" debe hacer `pop('continuar')` y en la rama `else`
del dashboard capturar el resultado y, si es `'continuar'`, abrir el modal de pago.

## Hallazgos 1 y 2 — análisis del guardado admin

En `admin_catalog_screen.dart` (`_ServiciosTab`) la lista se construye del estado
`AdminCatalogLoaded.servicios`. `AdminCatalogCubit.guardarServicio` ya re-fetcha
`_getServiciosAdmin()` y emite el estado nuevo, pero **la pantalla de detalle se
navega con `context.push`** (nueva ruta sobre el catalog); al volver, el listado
sigue mostrando la lista anterior (el estado emitido ocurre bajo la ruta de detalle
y la lista no se reconstruye al hacer pop).

En `admin_servicio_detail_screen.dart` (`_guardar`): si `guardarServicio` devuelve
`null` (fallo), hace `setState(_guardando=false)` y `return` **sin snackbar** → el
usuario no sabe qué pasó.

Fix:
- **1**: al hacer `Navigator.pop()` desde la pantalla de detalle, refrescar el
  catálogo. Alternativa robusta: en `_AdminCatalogViewState` re-cargar al volver de
  la ruta de detalle (p.ej. `await context.push(...)` y luego `cubit.load()`), o
  que `guardarServicio` emita el estado nuevo con la lista ya re-fetchada y que la
  pantalla de detalle devuelva el servicio al pop. Se elige: la pantalla de detalle
  hace `Navigator.pop(context, creado)` y el catalog, tras `await push`, si el
  resultado es `ServicioEntity` dispara `cubit.load()` (simple y reusa el patrón).
- **2**: en `_guardar`, si `creado == null`, leer `cubit.state` (AdminCatalogLoaded
  con `error`) y mostrar snackbar con el mensaje; no retornar mudo. También cubrir
  fallos de `guardarEspecialidadesServicio`/`guardarCuestionariosServicio` (que ya
  emiten `error` en el estado) mostrando snackbar.

## Actividades → ejecución

### 1. Fix 3 — continuar al pago tras face map nuevo
- [x] `face_map_questionnaire_screen.dart`: el "Aceptar" del diálogo "Mapeo
      Registrado" → `Navigator.pop(context, 'continuar')` (fallback `context.go('/services')`).
- [x] `services_dashboard_screen.dart`: rama `else` del face map → capturar resultado
      del `push`; si `== 'continuar'` y `mounted` → `_showPaymentOptionsModal(service)`.

### 2. Fix 1 — refresco del listado admin tras guardar
- [x] `admin_servicio_detail_screen.dart`: `Navigator.pop(context, creado)` (devuelve
      el servicio creado/editado).
- [x] `admin_catalog_screen.dart`: en el FAB de servicios (`context.push(...)`) y en
      `_ServiciosTab.onAbrir` capturar el resultado; si es `ServicioEntity` →
      `cubit.load()` para refrescar la lista (y también cuando vuelve de la edición).

### 3. Fix 2 — feedback de error en el guardado
- [x] `admin_servicio_detail_screen.dart` `_guardar`: si `creado == null`, obtener
      `error` del estado del cubit y mostrar snackbar ("No se pudo guardar... {error}");
      si falla `guardarEspecialidadesServicio`/`guardarCuestionariosServicio` (retorno
      `false`), mostrar el `error` del estado del cubit sin cerrar la pantalla.

### 4. Nota 1 — re-link 5 servicios inactivos a v2 (id=5)
- [x] Nueva migración `supabase/migrations/20260820000400_relink_servicios_cuestionario_v2.sql`
      (idempotente): `UPDATE ... SET cuestionario_id = 5 WHERE cuestionario_id = 4 AND NOT EXISTS ...`
      (conserva `obligatorio`/`orden`; respeta `servicio_cuestionarios_servicio_cuestionario_idx`).
      Afecta: Toxina Botulínica, Ácido Hialurónico, Peelings Médicos, Microneedling,
      Lipólisis Alta Frecuencia (todos inactivos, sin fila previa a id=5).
- [x] `supabase db push` + verificación por API: 0 filas con `cuestionario_id=4`; 18
      filas con `cuestionario_id=5` (incluye los 5 re-enlazados).

### 5. Cierre
- [x] `flutter analyze` 0 issues + `flutter test` 130/130 en verde.
- [x] Actualizar reporte E2E (hallazgos 1-4 → resueltos) y este plan.
- [x] Anotar la migración nueva en `supabase migration list` (Local == Remote, 44).

## Entorno / comandos

- E2E manual: `flutter run -d web-server --web-port 8080` (el usuario lo ejecuta).
- Verificación: `flutter analyze` + `flutter test`; migración con `supabase db push`.