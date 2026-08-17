# Plan: Face map reutilizable por servicio (mostrar puntos si el tratamiento no cerró)

| | |
|---|---|
| **Fecha** | 2026-08-17 |
| **Origen** | Solicitud del usuario: al re-seleccionar un servicio inyectable con tratamiento aún no cerrado, el face map debe mostrar los puntos ya seleccionados por el paciente; solo se pide editar puntos al iniciar otro tratamiento del mismo tipo. |
| **Estado** | APROBADO por el usuario (2026-08-17). |
| **Proyecto Supabase** | `hhyjremkguvphmjuaazp` (bellezastrani@gmail.com). |

## Decisiones (confirmadas por el usuario)

- **"Tratamiento no cerrado"**: el `tratamientos` nace recién en la ejecución de la cita. Se considera **cerrado** solo cuando se aplicó el tratamiento indicado (todos los productos, todos los puntos, especialista informa) **y se pagó en su totalidad** → en BD: `tratamientos.estado = 'COMPLETADO'` para ese servicio **y** `pagos.saldo_pendiente = 0`. Cualquier otro caso (sin tratamiento, `INICIADO/EN_PROCESO/PENDIENTE_FIRMA`, `CANCELADO`) = **no cerrado**.
- **Modo lectura**: pantalla de solo lectura con los puntos sobre la cabeza + botón **"Continuar al Pago"** → abre el modal de pago del servicio.
- **Nuevo tratamiento del mismo tipo** (previo cerrado): face map **pre-cargado** con los puntos anteriores para ajustar/confirmar.

## Contexto verificado en el código

- `services_dashboard_screen.dart:98-105`: abre `/face-map-questionnaire` sin servicio → `face_maps` se guarda solo con `paciente_id` (`supabase_service.dart:1008`); `tratamiento_id` queda `null`.
- La solicitud/pago se crea después del face map (`payments_supabase_datasource.dart:190`) y **no** se retro-vincula al mapa (`face_maps.solicitud_id` queda `null`).
- RLS (`20260810000000`, aplicada en remoto): el paciente puede SELECT/INSERT/UPDATE sus propios `face_maps` y `face_map_puntos` → **no se tocan policies**.
- `face_maps` no tiene `servicio_id`; `face_map_puntos` no guarda el id del punto ni la vista (reconstrucción exacta imposible).

## Tareas

### 1. Migración `supabase/migrations/20260817010000_face_map_servicio_y_puntos.sql`
- `face_maps.servicio_id uuid NULL REFERENCES public.servicios(id)`.
- Índice `face_maps_paciente_servicio_idx ON face_maps (paciente_id, servicio_id)`.
- `face_map_puntos.punto_id text NULL`, `face_map_puntos.vista text NULL`.
- Índice `face_map_puntos_face_map_id_idx ON face_map_puntos (face_map_id)`.
- Todo idempotente (`ADD COLUMN IF NOT EXISTS` / `CREATE INDEX IF NOT EXISTS`).

### 2. Capa de datos (`supabase_service.dart`)
- `saveFaceMapRecord`: nuevo parámetro `String? servicioId` → payload con `servicio_id`; cada punto incluye `punto_id` y `vista` (además de `zona_anatomica`/coordenadas).
- Nuevo `getFaceMapPorServicio({profileId, servicioId})` → último `face_maps` del paciente+servicio (orden `created_at` desc), sus puntos de `face_map_puntos`, y flag `tratamientoCerrado` (consulta `citas→tratamientos` por `solicitud_id` + `pagos.saldo_pendiente`).

### 3. Repositorio `patients_compliance`
- `IPatientsComplianceRepository` + `PatientsComplianceRepositoryImpl`: espejar `saveFaceMapRecord(+servicioId)` y nuevo `getFaceMapPorServicio`.

### 4. Backfill en pago (`payments_supabase_datasource.dart`)
- En `createServicePayment`, tras insertar la solicitud: `UPDATE face_maps SET solicitud_id=... WHERE paciente_id=... AND servicio_id=... AND solicitud_id IS NULL` (RLS `own` lo permite; deja el mapa trazable hacia tratamiento/pago).

### 5. Face map screen (`face_map_questionnaire_screen.dart`)
- Nuevos params: `String? servicioId`, `bool soloLectura`, `List<InjectionPoint>? puntosIniciales`.
- initState: cargar `puntosIniciales` en `_selectedPoints`.
- **Modo lectura**: canvas rotatorio igual pero sin marcar/desmarcar; ocultar barra rápida, notas y chips de borrado; banner "Puntos ya registrados para tu tratamiento en curso"; botón **"Continuar al Pago"** → `Navigator.pop(context, 'continuar')`.
- **Modo edición**: si hay `puntosIniciales` (tratamiento cerrado previo) se pre-cargan para ajustar.
- Helper público de reconstrucción filas→`InjectionPoint` (usa `punto_id`/`vista`; fallback por label para filas viejas).
- `_saveFaceMap` envía `servicioId` y por punto `punto_id`+`vista`.

### 6. Ruta (`app_routes.dart`)
- `extra` pasa a ser `FaceMapParams { tratamientoId?, servicioId?, soloLectura?, puntosIniciales? }` (retro-compatible con el `String` viejo).

### 7. Catálogo (`services_dashboard_screen.dart`)
- Branch inyectable:
  - Consultar `getFaceMapPorServicio(profileId, servicioId)`.
  - Tiene mapa **y** no cerrado → push en **lectura**; si devuelve `'continuar'` → `_showPaymentOptionsModal(service)`.
  - Sin mapa **o** cerrado → push en **edición** (pre-cargado con el mapa previo si existe).

### 8. Verificación
- `flutter analyze` sin issues; `flutter test` (80/80).
- `supabase db push` para aplicar la migración (confirmación del usuario).
- Smoke manual: marcar puntos → guardar → re-seleccionar servicio → ver puntos en lectura → Continuar → pago; y tras tratamiento COMPLETADO+pagado → edición pre-cargada.

## Fuera de alcance
- Vista del face map para el especialista en ejecución (RLS ya lo permite; sin UI hoy).
- Evitar solicitudes duplicadas si el paciente vuelve a "Continuar al Pago" con una solicitud activa (decisión de negocio futura).

## Checklist
- [x] Plan persistido en `docs/plans/` (este archivo).
- [x] Migración `20260817010000_face_map_servicio_y_puntos.sql` creada.
- [x] `saveFaceMapRecord` con `servicioId` + `punto_id`/`vista`.
- [x] `getFaceMapPorServicio` con `tratamientoCerrado`.
- [x] Repositorio `patients_compliance` espejado.
- [x] Backfill `face_maps.solicitud_id` en `createServicePayment`.
- [x] Face map screen: modo lectura + pre-carga + reconstrucción.
- [x] `FaceMapParams` en la ruta.
- [x] Catálogo: lectura/edición según estado + continuar a pago.
- [x] `flutter analyze` sin issues; `flutter test` en verde (80/80).
- [x] Migración aplicada con `supabase db push` (remoto en `20260817010000`).