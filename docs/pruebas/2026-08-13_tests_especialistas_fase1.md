# Resultados de Pruebas — Especialistas (Fase 1)

**Fecha:** 2026-08-13
**Rama:** `main` (sin commitear aún)
**Comando:** `flutter analyze` + `flutter test`

---

## Resultado global

- `flutter analyze`: **sin issues**.
- `flutter test`: **53/53** aprobados (14 previos + 39 nuevos).

---

## Tests nuevos (39)

### Entidades

| Archivo | Tests | Casos cubiertos |
|---|---|---|
| `especialista_entity_test.dart` | 9 | `toDb`/`fromDb` de `EstadoVerificacion`, `fromDb` con `null`/desconocido, `isPending`, `isApproved`, `copyWith` (cambio y conservación), `props` |

### UseCases

| Archivo | Tests | Casos cubiertos |
|---|---|---|
| `create_especialista_test.dart` | 3 | éxito, error, verificación de parámetros |
| `update_especialista_test.dart` | 4 | mapa de datos, estado+fecha, limpieza de observación, error |
| `asignar_especialidades_test.dart` | 3 | éxito, parámetros, error |
| `create_medico_regente_test.dart` | 3 | éxito, parámetros, error |
| `set_disponibilidad_test.dart` | 4 | `SetDisponibilidad` (éxito/error), `UpsertDisponibilidad` (éxito/error + parámetros) |
| `save_ubicacion_test.dart` | 3 | éxito, parámetros (default `precisionMetros=0`), error |
| `solicitar_verificacion_test.dart` | 2 | éxito + verificación de id, error |

### Repository

| Archivo | Tests | Casos cubiertos |
|---|---|---|
| `specialists_repository_impl_test.dart` | 8 | `getEspecialistaByUsuarioId` (Right, Right(null), Left), `createEspecialista` (Right, Left), `marcarPresencia` (Right), `saveUbicacion` (Right, Left) |

---

## Configuración de entorno

- Añadido `mocktail: ^1.0.4` a `dev_dependencies` en `pubspec.yaml`.
- `flutter pub get` ejecutado (resuelto `mocktail 1.0.5`).

### Notas técnicas

1. **`registerFallbackValue`**: mocktail exige registrar un valor de fallback para enums usados con `any()`. En `set_disponibilidad_test.dart`:
   ```dart
   setUpAll(() => registerFallbackValue(EstadoDisponibilidad.disponible));
   ```
2. **Mock del datasource**: `SpecialistsSupabaseDataSource` es clase concreta; se mockea con `implements`:
   ```dart
   class MockSpecialistsDataSource extends Mock
       implements SpecialistsSupabaseDataSource {}
   ```
3. **Import de `mocktail`** en los archivos de usecase (para `when`/`any`/`verify`); el mock del repositorio se centraliza en `test/features/specialists/mock_repository.dart`.

---

## Cobertura del checklist de especialistas

| # | Funcionalidad | Estado |
|---|---|---|
| 1 | Registro como especialista | ✔ cubierto |
| 2 | Información profesional | ✔ cubierto |
| 3 | Selección de especialidades | ✔ cubierto |
| 4 | Registro de Médico Regente | ✔ cubierto |
| 5 | Estado inicial PENDIENTE | ✔ cubierto |
| 6 | Completar/modificar información | ✔ cubierto |
| 7 | Activar/desactivar disponibilidad | ✔ cubierto |
| 8 | Registro de ubicación | ✔ cubierto |

---

## Pendientes (próximas fases)

- **Fase 2** — Tests del `SpecialistsCubit` (requiere `bloc_test`).
- **Fase 3** — Widget tests de screens/widgets.
- **Fase 4** — Integration tests E2E (opcional).

---

## Plan relacionado

- `docs/plans/2026-08-13_test_plan_especialistas.md`
