# Resultados de Pruebas — Especialistas (Fase 4: Mapeo de modelos)

**Fecha:** 2026-08-13
**Rama:** `main` (sin commitear aún)
**Comando:** `flutter analyze` + `flutter test`

---

## Resultado global

- `flutter analyze`: **sin issues**.
- `flutter test`: **80/80** aprobados (13 route_guard + 1 placeholder + 66 especialistas).

---

## Alcance de la Fase 4

El E2E real (registro → verificación) requiere `integration_test` + emulador + BD
de prueba, no disponibles en este entorno. Se implementó en su lugar la validación
del **mapeo de modelos** (`fromJson → toEntity`) contra el esquema real de Supabase,
que es el punto típico de rotura de la integración (nombres de columnas, enums,
tipos).

---

## Tests nuevos (11)

| Archivo | Tests | Validación |
|---|---|---|
| `especialista_model_test.dart` | 3 | columnas + join `profiles`, ausencia de `profiles`, default de `en_linea` |
| `disponibilidad_model_test.dart` | 2 | enum `estado`, `isAvailable`, fecha_inicio/fin, estado desconocido → `noDisponible` |
| `ubicacion_especialista_model_test.dart` | 2 | lat/lng/precision/fechas, default 0 si coords ausentes |
| `medico_regente_model_test.dart` | 2 | columnas, default `ACTIVO` |
| `especialidad_model_test.dart` | 2 | `EspecialidadModel` y `EspecialistaEspecialidadModel` (relación M:N) |

---

## Cobertura acumulada del checklist

| # | Funcionalidad | F1 (domain/repo) | F2 (cubit) | F3 (widget) | F4 (model) |
|---|---|---|---|---|---|
| 1 | Registro | ✔ | ✔ | — | ✔ |
| 2 | Información profesional | ✔ | ✔ | — | ✔ |
| 3 | Especialidades | ✔ | ✔ | ✔ | ✔ |
| 4 | Médico Regente | ✔ | ✔ | — | ✔ |
| 5 | Estado PENDIENTE | ✔ | — | — | ✔ |
| 6 | Modificar info | ✔ | ✔ | — | ✔ |
| 7 | Disponibilidad | ✔ | ✔ | ✔ | ✔ |
| 8 | Ubicación | ✔ | ✔ | — | ✔ |

---

## Resumen final de la suite de especialistas (66 tests)

- **Entities**: 10
- **Usecases**: 22
- **Repository**: 8
- **Models (mapeo BD)**: 11
- **Cubit**: 8
- **Widgets**: 7

## Pendiente (documentado)

- E2E en dispositivo (`integration_test`) — requiere emulador + BD de prueba.

---

## Plan relacionado

- `docs/plans/2026-08-13_test_plan_especialistas.md`
- `docs/pruebas/2026-08-13_tests_especialistas_fase1.md` (Fase 1)
- `docs/pruebas/2026-08-13_tests_especialistas_fase2.md` (Fase 2)
- `docs/pruebas/2026-08-13_tests_especialistas_fase3.md` (Fase 3 + fix props)
