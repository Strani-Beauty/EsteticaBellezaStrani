# Resultados de Pruebas — Especialistas (Fase 2: Cubit)

**Fecha:** 2026-08-13
**Rama:** `main` (sin commitear aún)
**Comando:** `flutter analyze` + `flutter test`

---

## Resultado global

- `flutter analyze`: **sin issues**.
- `flutter test`: **61/61** aprobados (13 route_guard + 1 placeholder + 39 Fase 1 + 8 Fase 2).

---

## Tests nuevos (8) — `SpecialistsCubit`

**Archivo:** `test/features/specialists/presentation/cubits/specialists_cubit_test.dart`

| Test | Caso cubierto |
|---|---|
| `createSpecialist` (éxito) | emite `Loading` → `Loaded` con el especialista creado |
| `createSpecialist` (error) | emite `Loading` → `Error` |
| `toggleDisponibilidad` (éxito) | activa disponibilidad + sincroniza `especialista.disponible` |
| `toggleDisponibilidad` (error) | emite `Error` cuando el upsert falla |
| `saveLocation` | refleja la ubicación guardada en el estado |
| `createMedicoRegente` | agrega el médico a la lista del estado |
| `guardarEspecialidades` | reemplaza `especialidadIds` en el estado |
| `actualizarDatosProfesionales` | delega en `updateEspecialista` con el mapa correcto (`verify`) |

---

## Enfoque técnico

- El cubit se construye con **usecases reales** respaldados por un único
  `MockISpecialistsRepository` (`test/features/specialists/mock_repository.dart`),
  evitando mockear 22 usecases individuales.
- Se usa `blocTest` con `seed` para arrancar en `SpecialistsLoaded` (métodos que
  exigen ese estado) y `verify` para aserciones sobre el repositorio.
- Dependencia añadida: `bloc_test: ^9.1.7`.

### Mocktail y `registerFallbackValue`

- `registerFallbackValue(EstadoDisponibilidad.disponible)` en `setUpAll` (enum usado en `any()`).
- `String`/`Map`/`List` no requieren fallback (tipos con default en mocktail).

---

## Hallazgo relevante

`EspecialistaEntity.props` no incluye `numeroLicencia`, `medicoRegenteId`,
`observacion` ni fechas. `Cubit.emit` (bloc 8.x) descarta estados iguales
(`if (state == _state && _emitted) return;`), por lo que
`actualizarDatosProfesionales` emite un estado "igual" al actual cuando solo
cambian licencia/regente → la UI no se re-renderiza hasta un refresh.

- El test correspondiente se validó vía `verify` sobre `repo.updateEspecialista`
  (verifica el mapa de datos), no sobre la emisión de estado.
- **Pendiente**: decidir si se amplía `props` (fix de producción) o se acepta la
  recarga manual como comportamiento actual.

---

## Cobertura acumulada del checklist

| # | Funcionalidad | Fase 1 (domain/repo) | Fase 2 (cubit) |
|---|---|---|---|
| 1 | Registro | ✔ | ✔ |
| 2 | Información profesional | ✔ | ✔ |
| 3 | Especialidades | ✔ | ✔ |
| 4 | Médico Regente | ✔ | ✔ |
| 5 | Estado PENDIENTE | ✔ | — (entidad) |
| 6 | Modificar info | ✔ | ✔ |
| 7 | Disponibilidad | ✔ | ✔ |
| 8 | Ubicación | ✔ | ✔ |

---

## Plan relacionado

- `docs/plans/2026-08-13_test_plan_especialistas.md`
- `docs/pruebas/2026-08-13_tests_especialistas_fase1.md`
