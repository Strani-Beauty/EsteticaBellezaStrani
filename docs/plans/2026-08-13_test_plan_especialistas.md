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
- [x] **Fase 5 — E2E configurado**: `integration_test/app_test.dart` (smoke test de arranque + navegación)

## Nota sobre E2E en dispositivo

El test de humo E2E quedó **configurado** (`integration_test/app_test.dart`): arranque
real de la app + navegación bienvenida → login. Requiere un emulador/dispositivo y el
`.env` bundlado para **ejecutarse**:

```powershell
flutter test integration_test/app_test.dart -d DEVICE_ID
```

Los flujos E2E completos (registro → verificación → mapa) requieren una BD de prueba
separada y credenciales; no se incluyen para no tocar producción.

### Estado del dispositivo (bloqueado)

El smoke test **no se ha podido ejecutar** por falta de dispositivo:

- **Emulador Pixel 10 Pro**: no arranca. `emulator -accel-check` → código 6
  ("Android Emulator hypervisor driver is not installed"). CPU Intel con
  virtualización habilitada, Hyper-V apagado, sin Docker/WSL2. AEHD no descargado y
  `sdkmanager` no instala.
- **POCO X3**: `DELETE_FAILED_INTERNAL_ERROR` al desinstalar (restricción MIUI).

Solución prioritaria: habilitar **WHPX** (Windows 10 Pro) en "Activar o desactivar
características de Windows" → reiniciar. Detalle completo en
`docs/pruebas/2026-08-13_e2e_setup.md`.

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

### E2E completo (flujo de registro/verificación)

- Requiere emulador + BD de prueba; el smoke test base ya está configurado.

---

## Verificación

```powershell
flutter analyze   # sin issues
flutter test      # 80/80 (13 route_guard + 1 placeholder + 66 especialistas)
```

## E2E (configurado, requiere dispositivo)

```powershell
flutter test integration_test/app_test.dart -d DEVICE_ID
```
