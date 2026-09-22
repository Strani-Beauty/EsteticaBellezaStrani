# Plan — Gestión de preguntas del cuestionario (asociar / reordenar / desactivar)

Fecha: 2026-09-18
Estado: APROBADO por el usuario (m1736: "si"). Sin commit.

## Objetivo

Ampliar la vista admin `admin/cuestionario` para gestionar las preguntas de una
versión (activa o inactiva):

1. **Asociar una pregunta existente** del catálogo a la versión seleccionada.
2. **Reordenar** las preguntas con flechas subir/bajar.
3. **Desactivar (soft, reversible)** una pregunta en la versión vía
   `cuestionario_preguntas.activo`; se puede reactivar después.

Decisiones confirmadas (m1728, m1732):
- NO crear preguntas nuevas; solo asociar existentes.
- Catálogo de preguntas **compartido** entre versiones (sin cambios de modelo).
- Desactivar reversible (soft), no DELETE.
- Reordenar con flechas subir/bajar.

Hoy la vista solo permite crear versión, activar versión y editar preguntas
(`updatePregunta`). No hay forma de asociar, reordenar ni desactivar.

## Cambios

### 1. Capa de datos (`patients_compliance_supabase_datasource.dart`)
- `fetchCuestionarioPreguntas(cuestionarioId, {bool soloActivas = true})`:
  añade `.eq('activo', true)` si `soloActivas`; select pasa a
  `orden, activo, preguntas(...)`; en el merge usa la clave **`activa_en_version`**
  (no `activo`, que pertenece a `preguntas`) → `json['activa_en_version'] = row['activo']`.
- `fetchPreguntasCatalogo()`: `from('preguntas').select(...)` ordenado por texto.
- `asociarPregunta(cuestionarioId, preguntaId)`: `orden = max(orden)+1` de la
  versión y **upsert** (`onConflict: 'cuestionario_id,pregunta_id'`) con
  `activo: true` (re-asociar una desactivada la reactiva).
- `desactivarPregunta(cuestionarioId, preguntaId, {required bool activo})`:
  update de `activo` en la relación.
- `actualizarOrdenPregunta(cuestionarioId, preguntaId, orden)`: update de `orden`.

### 2. Capa de dominio
- `PreguntaEntity` + `final bool activaEnVersion;` (default true) → en `props`.
- `PreguntaModel` ídem, desde `activa_en_version`.
- `IPatientsComplianceRepository`: + `getPreguntasCatalogo()`, `asociarPregunta`,
  `desactivarPregunta`, `actualizarOrdenPregunta`; `getCuestionarioPreguntas` con
  `{bool soloActivas = true}`. Impl con `Either<Failure,T>`.
- Usecases nuevos: `GetPreguntasCatalogo`, `AsociarPregunta`, `DesactivarPregunta`,
  `ActualizarOrdenPregunta`; `GetCuestionarioPreguntasParams` + `soloActivas`.

### 3. Cubit (`admin_cuestionario_cubit.dart`)
- Estado `Loaded` + `List<PreguntaEntity> catalogo` (cargado en `load()`).
- `loadPreguntas` pasa `soloActivas: false` (admin ve las desactivadas).
- Métodos: `asociarPregunta`, `desactivarPregunta`,
  `moverPregunta(cuestionarioId, preguntaId, delta)` (swap de orden de dos vecinos
  y recarga), todos con feedback.
- DI (`injection.dart`): registrar los 4 usecases y pasarlos al cubit.

### 4. Pantalla (`admin_cuestionario_screen.dart`)
- `_PreguntaCard`: chip "Desactivada en esta versión" + botón **Reactivar** cuando
  `!activaEnVersion`; flechas subir/bajar (deshabilitadas en extremos) cuando
  activa; conserva Editar.
- Botón **"Asociar pregunta existente"** (habilitado con versión seleccionada) →
  `_AsociarPreguntaDialog`: lista el catálogo filtrando las ya asociadas (con
  búsqueda), selección → `cubit.asociarPregunta`.
- Confirmación al desactivar.

### Sin cambios
- BD/RLS (`cuestionario_pregunta_admin_write` ya permite todo al admin; unique
  `(cuestionario_id, pregunta_id)` e índice `(cuestionario_id, orden)` existen).
- `patient_health_cubit` (usa default `soloActivas: true` → el paciente solo ve
  las preguntas activas de la versión).

## Verificación

- [x] `flutter analyze` limpio.
- [x] `flutter test` (370).
- [ ] Manual en `flutter run -d chrome`: asociar/reordenar/desactivar/reactivar
      en admin; el paciente no ve las desactivadas.

## Notas

- Sin commit (regla del proyecto: preguntar antes).
- Modificar la versión **activa** impacta en vivo a los pacientes; se recomienda
  editar la versión inactiva y luego activarla.