# Plan — Asociar automáticamente la nueva pregunta al cuestionario abierto

Fecha: 2026-09-23
Estado: APROBADO por el usuario (m1991: "si"). Sin commit.

## Objetivo

En Admin → Cuestionario, al crear una **pregunta nueva** se guardaba solo en el
catálogo (`preguntas`) y **no** se asociaba al cuestionario/versión abierto,
obligando a asociarla luego a mano. Se debe asociar automáticamente a la versión
seleccionada; si no hay ninguna abierta, se conserva el comportamiento actual
(solo catálogo).

## Causa

`AdminCuestionarioCubit.crearPregunta` descartaba el id devuelto por el usecase
(`(_) async`) y nunca llamaba a `asociarPregunta`. La infraestructura para
asociar ya existe (`AsociarPregunta` → upsert `cuestionario_preguntas` con
`activo: true` y `orden = max+1`).

## Cambios

### 1. `presentation/cubits/admin_cuestionario_cubit.dart`
- `crearPregunta`: nuevo parámetro opcional `int? cuestionarioId`.
- En el fold de éxito capturar el id nuevo (`(nuevoId) async`) y, si
  `cuestionarioId != null`, llamar a
  `_asociarPregunta(AsociarPreguntaParams(cuestionarioId: cuestionarioId, preguntaId: nuevoId))`.
- Feedback: `'Pregunta creada y asociada a la versión.'` si se asoció;
  `'Pregunta creada en el catálogo.'` si no.
- Tras crear: `_cargarCatalogo()` y, si hay cuestionario, `loadPreguntas(cuestionarioId)`.

### 2. `presentation/screens/admin_cuestionario_screen.dart`
- Botón "Nueva pregunta": `_nuevaPregunta(context, cubit, seleccionada)`.
- `_nuevaPregunta(BuildContext, AdminCuestionarioCubit, CuestionarioEntity?)`
  reenvía `cuestionarioId: seleccionada?.id`.

### Sin cambios
Datasource/repositorio/usecases, BD/RLS. Reutiliza `asociarPregunta`.

## Verificación

- [x] `flutter analyze` limpio.
- [x] `flutter test` (370, ALL PASSED).
- [ ] Manual: con una versión abierta, crear pregunta → aparece al final de la
      lista de preguntas de esa versión sin asociarla a mano.

## Notas

- Sin commit (regla del proyecto: preguntar antes).
