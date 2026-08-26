# Plan: Face Map con productos/cantidades, revisión final y cierre con evidencia mínima

| | |
|---|---|
| **Fecha** | 2026-08-26 |
| **Estado** | APROBADO por el usuario (2026-08-26) |
| **Proyecto Supabase** | `hhyjremkguvphmjuaazp` |
| **Decisiones tomadas** | (1) El Face Map guardado del paciente es la base del tratamiento (el especialista trabaja sobre esos puntos). (2) Interfaz nueva por punto: elegir insumo registrado o crear uno nuevo inline, con cantidad y unidad del producto/servicio. (3) Evidencia mínima de cierre: firma + ≥1 foto PRE + ≥1 foto POST + evaluación inicial + Face Map con ≥1 punto y cada punto con producto y cantidad > 0. (4) Pantalla dedicada de Revisión final. (5) Pruebas de precisión: unit + widget tests multi-tamaño. (6) La migración BD la aplica el usuario (no `supabase db push`). |

## Contexto

Revisión de las 14 actividades del módulo de ejecución (Face Map + cierre). Resultado:

| # | Actividad | Estado |
|---|-----------|--------|
| 1 | Face Map interactivo | ✅ IMPLEMENTADO |
| 2 | Coordenadas normalizadas X/Y | ✅ IMPLEMENTADO |
| 3 | Múltiples puntos por tratamiento | ✅ IMPLEMENTADO |
| 4 | Asociar punto ↔ producto aplicado | ❌ `face_map_puntos.producto_id` nunca se escribe |
| 5 | Cantidad por punto con unidad del producto | ❌ hardcoded `cantidad:1, unidad:'unidad'` en datasource |
| 6 | Editar/eliminar punto mientras abierto | ✅ toggle + re-guardado (delete+insert) |
| 7 | Mostrar puntos sobre el mapa | ✅ |
| 8 | Trazabilidad face_maps→puntos→productos_aplicados | ❌ sin vínculo, sin índice/FK sobre `producto_id` |
| 9 | Captura fotos post-tratamiento | ✅ (dropdown PRE/POST/OTRO + image_picker) |
| 10 | Storage privado + tipo_foto PRE/POST | ✅ (signed URLs, escribe `tipo_fotografia` y `tipo_foto`) |
| 11 | Evidencia mínima antes del cierre | ⚠️ hoy: firma + ≥1 PRE + evaluación. Faltan POST, face map, producto/cantidad |
| 12 | Pantalla revisión final | ❌ no existe |
| 13 | Cierre cita→FINALIZADA | ✅ (con cobro de saldo Stripe) |
| 14 | Pruebas de precisión multi-tamaño | ❌ sin tests |

## Decisiones

1. **Base de puntos = Face Map del paciente**: la pantalla del especialista abre con los
   puntos del paciente ya seleccionados (fallback existente en `fetchFaceMapPorTratamiento`,
   `tratamiento_id IS NULL`). El especialista los confirma/ajusta y asigna producto/cantidad.
   Optimización: filtrar el fallback por `servicio_id` del tratamiento (vía cita→solicitud→servicios).
   Al primer guardado se crea el `face_maps` del tratamiento (copia de los puntos).
   Si el paciente no tiene mapa, se dibuja desde cero.
2. **Interfaz nueva por punto (Act. 4/5)**: bottom sheet al tocar un punto → dropdown de
   insumos del tratamiento (`state.productos`), botón "Crear nuevo insumo" (form inline →
   `cubit.agregarProducto`), cantidad aplicada (unidad del producto o `_unidadSugerida(tipoPrecio)`),
   nota opcional. Puntos sin producto muestran badge "sin producto" (bloquean cierre, no guardado).
3. **Gate de cierre (Act. 11)**: firma + ≥1 foto PRE + ≥1 foto POST + evaluación inicial +
   Face Map con ≥1 punto y cada punto con producto y cantidad > 0.
4. **Revisión final (Act. 12)**: pantalla dedicada que consolida puntos/productos/cantidades/
   fotos/notas y desde ahí se confirma el cierre (pago de saldo + `cubit.finalizar`).
5. **Pruebas (Act. 14)**: helper puro de geometría + widget test del canvas multi-tamaño.

## Actividades → implementación

### A. Migración BD (idempotente, aplicada por el usuario)

- [x] A1. `supabase/migrations/20260826000100_face_map_puntos_producto_trazabilidad.sql`
  - FK `face_map_puntos.producto_id → productos_aplicados(id) ON DELETE SET NULL`
    (vía `DO $$` + `information_schema`, si no existe).
  - `CREATE INDEX IF NOT EXISTS face_map_puntos_producto_id_idx ON face_map_puntos(producto_id)`.
  - Sin RLS nueva (el especialista ya escribe `face_map_puntos` vía `20260825000200`).

### B. Capa de datos (treatment_execution)

- [x] B1. `treatment_execution_supabase_datasource.dart`:
  - `fetchFaceMapPorTratamiento`: filtrar fallback del paciente por `servicio_id`
    (obtener servicio vía cita→solicitud→servicios); select de `face_map_puntos` con
    embed `productos_aplicados(producto_nombre)`.
  - `guardarFaceMapPorTratamiento`: eliminar hardcoded `1/'unidad'`; persistir por fila
    `producto_id`, `cantidad`, `unidad_medida`, `observaciones` del map del punto.
- [x] B2. `FaceMapEspecialistaModel`/`Entity`: `puntos` como raw `List<Map>` enriquecido
  con `producto_id`, `producto_nombre`, `cantidad`, `unidad_medida`, `observaciones`.
- [x] B3. Usecase `GuardarFaceMapPorTratamientoParams`: sin cambio de firma; documentar campos.

### C. Cubit + DI

- [x] C1. `TreatmentExecutionCubit`: sin usecases nuevos; agregar derivados para conteo de
  puntos completos si conviene. Registro DI sin cambios salvo lo necesario.

### D. UI

- [x] D1. Refactor: extraer canvas interactivo a widget público `FaceMapCanvas`
  (`presentation/widgets/`) con props `{puntos, seleccionados, onTogglePunto, ...}`.
- [x] D2. Helper puro `face_map_geometry.dart`: `normalizarTap`, `esZonaProhibida`,
  `puntoCercano`, `enRegionCustom` (refactor de `_handleSilhouetteTap`).
- [x] D3. `face_map_especialista_screen.dart`: estado por punto
  `{productoId, productoNombre, cantidad, unidad, observaciones}` + bottom sheet
  (dropdown/crear/cantidad/nota) + badges por punto + `_guardar` con nuevos campos.
- [x] D4. Nueva `revision_final_screen.dart` (ruta `AppRoutes.revisionFinalDe(citaId, tratamientoId)`):
  secciones Puntos, Productos, Fotografías PRE/POST, Evaluación inicial, notas;
  observaciones finales + recomendaciones; "Confirmar cierre" → gate → pago saldo → `cubit.finalizar` → pop.
- [x] D5. `cita_detalle_screen.dart`: "Finalizar" navega a Revisión final (reemplaza
  `_dialogoFinalizar`); Card Face Map muestra resumen de puntos y pendientes.

### E. Verificación y documentación

- [x] E1. `test/features/treatment_execution/face_map_geometry_test.dart`: normalización en
  tamaños 280/400/480/800 px, precisión 3 decimales, rango 0..1, radios y zonas prohibidas.
- [x] E2. `test/features/treatment_execution/face_map_canvas_test.dart`: widget test del
  canvas a varios `physicalSize` (teléfono pequeño, tablet, landscape) sin overflow y taps correctos.
- [x] E3. `flutter analyze` + `flutter test` 0 issues.
- [x] E4. Plan actualizado con checkpoints `[x]`.
- [x] E5. Guía manual E2E en `docs/pruebas/` (cierre de Act 14).

## Notas

- La migración A1 la aplica el usuario desde el SQL Editor del Dashboard (aplicar en orden
  ascendente de nombre). No se ejecuta `supabase db push`.
- Se mantiene el patrón raw `List<Map<String,dynamic>>` para `puntos` (consistente con lo existente).
- El paciente sigue guardando su Face Map pre-tratamiento vía `SupabaseService` (legacy,
  `patients_compliance`); no se toca ese módulo.