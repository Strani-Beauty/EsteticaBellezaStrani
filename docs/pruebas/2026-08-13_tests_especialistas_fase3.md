# Resultados de Pruebas — Especialistas (Fase 3: Widgets + fix de props)

**Fecha:** 2026-08-13
**Rama:** `main` (sin commitear aún)
**Comando:** `flutter analyze` + `flutter test`

---

## Resultado global

- `flutter analyze`: **sin issues**.
- `flutter test`: **69/69** aprobados (13 route_guard + 1 placeholder + 40 Fase 1 + 8 Fase 2 + 7 Fase 3).

---

## Corrección de producción: `EspecialistaEntity.props`

**Problema** (detectado en Fase 2): `props` solo contenía
`id, usuarioId, estadoVerificacion, disponible, activo, enLinea`. Como
`Cubit.emit` (bloc 8.x) descarta estados iguales
(`if (state == _state && _emitted) return;`), `actualizarDatosProfesionales`
emitía un estado "igual" cuando solo cambiaban `numeroLicencia`/`medicoRegenteId`,
dejando la UI sin refrescar hasta un refresh manual.

**Fix**: se amplió `props` para incluir `medicoRegenteId`, `numeroLicencia`,
`observacion`, `fechaSolicitudVerificacion`, `fechaVerificacion`,
`fechaAprobacion`, `aprobadoPor`, `ultimaConexion`, `nombreUsuario` y
`emailUsuario`.

- Se añadió el test `dos entidades con distinta licencia no son iguales`.

---

## Tests nuevos (7) — Widgets

### `DisponibilidadCard` (3 tests)
**Archivo:** `test/features/specialists/presentation/widgets/disponibilidad_card_test.dart`

| Test | Caso |
|---|---|
| muestra "Disponible para citas" | estado disponible → switch ON |
| muestra "No disponible" | disponibilidad nula → switch OFF |
| al tocar el switch | llama `toggleDisponibilidad` (verify) |

### `EspecialidadesSelector` (4 tests)
**Archivo:** `test/features/specialists/presentation/widgets/especialidades_selector_test.dart`

| Test | Caso |
|---|---|
| lista vacía | muestra mensaje "Aún no hay especialidades…" |
| con especialidades | un `FilterChip` por especialidad |
| seleccionar chip | `onChanged` recibe el set actualizado |
| deseleccionar chip | quita el id del set |

---

## Notas técnicas

- `EspecialidadesSelector` es puro (sin cubit) → test directo sin `BlocProvider`.
- `DisponibilidadCard` usa `context.read<SpecialistsCubit>()` → se mockea el cubit
  con mocktail (`MockSpecialistsCubit implements SpecialistsCubit`) y se provee con
  `BlocProvider.value`. **Importante**: hay que stubear `stream`
  (`when(() => cubit.stream).thenAnswer((_) => const Stream<SpecialistsState>.empty())`)
  porque `BlocProvider` se suscribe a `stream` al resolver `read`.

---

## Cobertura acumulada del checklist

| # | Funcionalidad | Fase 1 | Fase 2 | Fase 3 |
|---|---|---|---|---|
| 1 | Registro | ✔ | ✔ | — |
| 2 | Información profesional | ✔ | ✔ | — |
| 3 | Especialidades | ✔ | ✔ | ✔ (selector) |
| 4 | Médico Regente | ✔ | ✔ | — |
| 5 | Estado PENDIENTE | ✔ | — | — |
| 6 | Modificar info | ✔ | ✔ | — |
| 7 | Disponibilidad | ✔ | ✔ | ✔ (card) |
| 8 | Ubicación | ✔ | ✔ | — |

---

## Plan relacionado

- `docs/plans/2026-08-13_test_plan_especialistas.md`
- `docs/pruebas/2026-08-13_tests_especialistas_fase1.md`
- `docs/pruebas/2026-08-13_tests_especialistas_fase2.md`
