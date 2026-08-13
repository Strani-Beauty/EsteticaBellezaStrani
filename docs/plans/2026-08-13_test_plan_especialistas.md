# Plan de Pruebas: Módulo de Especialistas

**Fecha:** 2026-08-13
**Módulo:** `lib/features/specialists/`
**Arquitectura:** Clean Architecture (Feature-First)

---

## Objetivo

Cubrir con pruebas las 8 funcionalidades del checklist de especialistas:

1. Registro como especialista
2. Creación de información profesional
3. Selección de especialidades
4. Registro de Médico Regente
5. Estado inicial Pendiente de Verificación
6. Completar y modificar información
7. Activar/desactivar disponibilidad
8. Registro de ubicación

---

## Estado

- [x] **Fase 1 — Tests críticos** (domain + repository): 40 tests nuevos
- [x] **Fase 2 — Tests del Cubit** (`SpecialistsCubit`): 8 tests nuevos
- [x] **Fase 3 — Widget tests**: 7 tests nuevos (`DisponibilidadCard`, `EspecialidadesSelector`)
- [x] **Fase 4 — Tests de mapeo de modelos** (capa de datos): 11 tests nuevos

## Nota sobre E2E en dispositivo

El flujo E2E real (registro → verificación) requiere un emulador/dispositivo y una
BD de prueba (`integration_test` + Supabase), no disponibles en este entorno. En su
lugar, la Fase 4 valida el mapeo `fromJson → toEntity` de los modelos contra el
esquema real de Supabase (columnas), que es donde típicamente se rompe la
integración. El E2E en dispositivo queda documentado como pendiente.

## Corrección de producción (Fase 3)

`EspecialistaEntity.props` ahora incluye `medicoRegenteId`, `numeroLicencia`,
`observacion`, fechas de verificación, `aprobadoPor`, `ultimaConexion`,
`nombreUsuario` y `emailUsuario`. Esto corrige que `actualizarDatosProfesionales`
emitiera un estado "igual" al actual (bloc descarta `state == _state`), dejando la
UI sin refrescar la licencia/regente hasta un refresh.

---

## Estrategia por capa

| Capa | Qué prueba | Mock | Prioridad |
|---|---|---|---|
| UseCases | Lógica de negocio pura | `ISpecialistsRepository` | Alta |
| Repository | Wrapping `Either<Failure, T>` | `SpecialistsSupabaseDataSource` | Alta |
| Cubit | Flujo de estados | UseCases | Media |
| Widget | UI/interacciones | Cubit | Media |
| Integration | Flujo E2E | Supabase | Baja (opcional) |

---

## Fase 1 — Tests críticos (COMPLETADA)

### Archivos implementados

```
test/features/specialists/
├── mock_repository.dart                        (MockISpecialistsRepository)
├── domain/
│   ├── entities/
│   │   └── especialista_entity_test.dart       (9 tests)
│   └── usecases/
│       ├── create_especialista_test.dart       (3 tests)
│       ├── update_especialista_test.dart       (4 tests)
│       ├── asignar_especialidades_test.dart    (3 tests)
│       ├── create_medico_regente_test.dart     (3 tests)
│       ├── set_disponibilidad_test.dart        (4 tests)
│       ├── save_ubicacion_test.dart            (3 tests)
│       └── solicitar_verificacion_test.dart    (2 tests)
└── data/
    └── repositories/
        └── specialists_repository_impl_test.dart (8 tests)
```

**Total Fase 1:** 39 tests.

### Cobertura por funcionalidad del checklist

| # | Funcionalidad | Test(s) |
|---|---|---|
| 1 | Registro como especialista | `create_especialista_test.dart`, repo `createEspecialista` |
| 2 | Información profesional | `update_especialista_test.dart` |
| 3 | Selección de especialidades | `asignar_especialidades_test.dart` |
| 4 | Médico Regente | `create_medico_regente_test.dart` |
| 5 | Estado PENDIENTE | `especialista_entity_test.dart` |
| 6 | Completar/modificar info | `update_especialista_test.dart` + `solicitar_verificacion_test.dart` |
| 7 | Disponibilidad | `set_disponibilidad_test.dart` |
| 8 | Ubicación | `save_ubicacion_test.dart`, repo `saveUbicacion` |

### Dependencias añadidas

- `mocktail: ^1.0.4` en `dev_dependencies` (mock de interfaces).

### Detalles técnicos

- `mocktail` exige `registerFallbackValue(...)` para enums usados con `any()`:
  `registerFallbackValue(EstadoDisponibilidad.disponible)` en `set_disponibilidad_test.dart`.
- El mock del datasource (`SpecialistsSupabaseDataSource`) es clase concreta; se mockea con `implements`.

---

## Fases pendientes

### E2E en dispositivo (pendiente)

- Flujo E2E de registro/verificación con `integration_test` + BD de prueba (requiere emulador).

---

## Verificación

```powershell
flutter analyze   # sin issues
flutter test      # 80/80 (13 route_guard + 1 placeholder + 66 especialistas)
```
