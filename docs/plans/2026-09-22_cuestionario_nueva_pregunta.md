# Plan — Crear preguntas nuevas en el catálogo (admin)

Fecha: 2026-09-22
Estado: APROBADO por el usuario (m1816: "si"). Sin commit.

## Objetivo

Añadir la opción **"Nueva pregunta"** en el panel de Cuestionario del admin para
crear una pregunta en el catálogo general (`preguntas`) con **selector de tipo de
respuesta**. La pregunta NO se asocia automáticamente a la versión (decisión
m1814: "Crear solo en catálogo"); el admin la asocia después con el botón
"Asociar pregunta existente" que ya existe.

## Cambios

### 1. Datasource `patients_compliance_supabase_datasource.dart`
- `crearPregunta({required String texto, required String tipoRespuesta,
  bool obligatoria = false, List<String>? opciones,
  Map<String, dynamic>? riesgo, bool activo = true})` → insert en `preguntas`
  (`pregunta, tipo_respuesta, obligatoria, opciones, riesgo, activo,
  created_at, updated_at`) `.select('id').maybeSingle()` → devuelve el `id` nuevo.
  (`preguntas` SÍ tiene `updated_at`, confirmado en el seed `20260818000300`.)

### 2. Dominio
- `IPatientsComplianceRepository` + impl: `crearPregunta(...)` → `Either<Failure, int>`.
- Nuevo usecase `domain/usecases/crear_pregunta.dart`:
  `CrearPreguntaParams{texto, tipo (TipoRespuestaPregunta), obligatoria,
  opciones, riesgo, activo}` → repo con `tipo.toDb()`.

### 3. Cubit `admin_cuestionario_cubit.dart`
- `crearPregunta(...)` → usecase; en éxito: `_cargarCatalogo()` (la nueva
  pregunta aparece en "Asociar") + feedback `'Pregunta creada en el catálogo.'`;
  en error → `AdminCuestionarioError`.

### 4. Pantalla `admin_cuestionario_screen.dart`
- Botón **"Nueva pregunta"** (`FilledButton.icon` con `add_rounded`) en el Wrap
  de acciones, junto a "Asociar pregunta existente".
- Nuevo `_NuevaPreguntaDialog` (similar a `_EditarPreguntaDialog` pero con):
  - `DropdownButtonFormField<TipoRespuestaPregunta>` con los 9 tipos
    (`siNo, texto, numero, decimal, fecha, lista, multiple, archivo, imagen`)
    usando `tipo.label`.
  - Bloque de opciones **solo visible** cuando el tipo es `lista`/`multiple`
    (misma mecánica de chips del diálogo de edición).
  - `SwitchListTile` Obligatoria + Activa; validación de texto no vacío.
- `_nuevaPregunta(context, cubit)`: `showDialog` → `cubit.crearPregunta(...)`.

### 5. DI `injection.dart`
- Registrar `CrearPregunta` y pasarlo a `AdminCuestionarioCubit`.

## Sin cambios
RLS (ya existe `pregunta_admin_write` FOR ALL admin; sin migración). Flujo
paciente: la pregunta solo se ve en el cuestionario si se asocia y está activa
en la versión.

## Verificación

- [x] `flutter analyze` limpio.
- [x] `flutter test` (370, ALL PASSED).
- [ ] Manual en `flutter run -d chrome`: crear pregunta tipo Lista, verla en
      catálogo, asociarla a la versión y confirmar que el paciente la ve.

## Notas

- Sin commit (regla del proyecto: preguntar antes).