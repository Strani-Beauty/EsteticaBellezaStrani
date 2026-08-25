# Pruebas de control — Ejecución de tratamientos (11 puntos)

**Fecha**: 2026-08-25
**Estado**: en progreso
**Módulos**: `treatment_execution`, `treatment_photos` (ambos 100% reales)
**Decisiones del usuario**: (1) tests de datasource mockeando SupabaseClient, set acotado; (2) NO tocar producción para el punto 10; (3) sin widget tests del gating UI.

## Objetivo

Traducir el checklist manual de 11 puntos de control a pruebas automatizadas (unit tests) con los patrones del repo: `flutter_test` + `mocktail` + `bloc_test` (sin mockito/build_runner), nombres en español, imports relativos, `Right/Left` (fpdart).

## Mapa punto de control → cobertura

| # | Punto | Cobertura |
|---|---|---|
| 1 | Tratamiento creado desde la cita | cubit `iniciarTratamiento`; repo `iniciarTratamiento`; `CitaEjecucionModel` (join `tratamientos`); datasource INSERT `estado=PENDIENTE_FIRMA` |
| 2 | No se inicia sin consentimiento | entity `firmado`; cubit `PENDIENTE_FIRMA`→solo `firmarConsulta`→`EN_PROCESO` |
| 3 | Firma digital | cubit `firmarConsulta`; usecases `subir_firma`, `registrar_consentimiento` |
| 4 | Firma almacenada | repo `subirFirma`/`registrarConsentimiento`; `ConsentimientoModel`; datasource bucket `firmas-consentimiento` + `firma_url` |
| 5 | Foto pre-tratamiento | `TreatmentPhotosCubit.subirFotografia`; usecase; modelo `PRE`; entity `esPre`; datasource bucket `fotografias-tratamiento` |
| 6 | Foto vinculada al tratamiento | entity/model `tratamientoId`; cubit `loadDetalle`; usecase/repo `get_fotografias`; datasource `.eq('tratamiento_id', x)` |
| 7 | Registrar productos | cubit `agregarProducto`; usecase; repo; modelo |
| 8 | Cantidad y unidad | modelo (`cantidad_total`, `unidad_medida`); cubit args; `ProductoCard` |
| 9 | Notas del especialista | cubit `guardarEvaluacion`; usecase `actualizar_tratamiento`; `TratamientoModel` (`recomendaciones_post_tratam`) |
| 10 | No avanza si faltan requisitos | cubit/usecase `finalizar` (delegación). Sin refactor: `faltantes` sin cobertura directa |
| 11 | Todo vinculado a la cita | `CitaEjecucionModel`; `TratamientoEntity.citaId`; cubit `loadDetalle`; datasource payloads con FK |

## Archivos a crear

### treatment_execution (`test/features/treatment_execution/`)
- [x] `mock_repository.dart` — Mocks `ITreatmentExecutionRepository`, `ITreatmentPhotosRepository`
- [ ] `data/datasources/treatment_execution_datasource_test.dart` (set acotado: puntos 1, 4, 11)
- [ ] `data/repositories/treatment_execution_repository_impl_test.dart`
- [ ] `data/models/cita_ejecucion_model_test.dart`
- [ ] `data/models/tratamiento_model_test.dart`
- [ ] `data/models/consentimiento_model_test.dart`
- [ ] `data/models/producto_aplicado_model_test.dart`
- [ ] `data/models/face_map_especialista_model_test.dart`
- [ ] `domain/entities/cita_ejecucion_entity_test.dart`
- [ ] `domain/entities/tratamiento_entity_test.dart`
- [ ] `domain/entities/consentimiento_tratamiento_entity_test.dart`
- [ ] `domain/entities/producto_aplicado_entity_test.dart`
- [ ] `domain/usecases/` (17): get_mis_citas, get_cita_detalle, get_citas_historial, get_productos, get_consentimiento, avanzar_estado_cita, iniciar_tratamiento, actualizar_tratamiento, agregar_producto, eliminar_producto, registrar_consentimiento, subir_firma, finalizar_tratamiento, registrar_llegada, cancelar_cita, get_face_map_por_tratamiento, guardar_face_map_por_tratamiento
- [ ] `presentation/cubits/treatment_execution_cubit_test.dart`
- [ ] `presentation/widgets/estado_chip_test.dart`
- [ ] `presentation/widgets/producto_card_test.dart`

### treatment_photos (`test/features/treatment_photos/`)
- [x] `mock_repository.dart`
- [ ] `data/datasources/treatment_photos_datasource_test.dart` (puntos 5, 6)
- [ ] `data/repositories/treatment_photos_repository_impl_test.dart`
- [ ] `data/models/fotografia_tratamiento_model_test.dart`
- [ ] `domain/entities/fotografia_tratamiento_entity_test.dart`
- [ ] `domain/usecases/` (4): get_fotografias, subir_fotografia, registrar_fotografia_por_url, eliminar_fotografia
- [ ] `presentation/cubits/treatment_photos_cubit_test.dart`

## Notas de implementación

- Repository tests mockean el DATASOURCE (patrón `catalog_repository_impl_test`); `registerFallbackValue` para enums en `setUpAll`.
- Cubit tests con `blocTest` + helper `_buildCubit` que inyecta TODOS los usecases.
- Datasource tests: mockear `SupabaseClient` + builders PostgREST + Storage (patrón nuevo, frágil por diseño — aceptado). Confirmar tipos de retorno contra `pubspec.lock`.
- `TreatmentPhotosRepositoryImpl`: `subirFotografia`→`StorageFailure`; resto→`ServerFailure`.

## Verificación

```powershell
flutter analyze
flutter test
```

## Checkpoints

- [x] Plan aprobado y persistido
- [x] `mock_repository.dart` (ambos módulos)
- [x] Modelos y entidades (9 archivos)
- [x] Usecases (21)
- [x] Repository impl tests (2)
- [x] Cubit tests (2)
- [x] Datasource tests (2, set acotado)
- [x] Widget tests (2)
- [x] `flutter analyze` + `flutter test` verdes