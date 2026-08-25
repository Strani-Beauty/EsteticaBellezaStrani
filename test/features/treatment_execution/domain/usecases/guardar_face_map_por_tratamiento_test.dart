import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/guardar_face_map_por_tratamiento.dart';
import '../../mock_repository.dart';

void main() {
  late GuardarFaceMapPorTratamiento usecase;
  late MockITreatmentExecutionRepository repository;

  setUp(() {
    repository = MockITreatmentExecutionRepository();
    usecase = GuardarFaceMapPorTratamiento(repository);
  });

  final puntos = [
    {'punto_id': 'p1', 'vista': 'frente', 'coordenada_x': 0.5, 'coordenada_y': 0.2},
  ];

  test('delega en el repositorio y guarda el face map', () async {
    when(() => repository.guardarFaceMapPorTratamiento(
        tratamientoId: any(named: 'tratamientoId'),
        pacienteId: any(named: 'pacienteId'),
        puntos: any(named: 'puntos'),
        observaciones: any(named: 'observaciones')))
        .thenAnswer((_) async => const Right(null));

    final result = await usecase(const GuardarFaceMapPorTratamientoParams(
      tratamientoId: 'trat-1',
      pacienteId: 'pac-1',
      puntos: [],
    ));

    expect(result, const Right(null));
    verify(() => repository.guardarFaceMapPorTratamiento(
        tratamientoId: 'trat-1',
        pacienteId: 'pac-1',
        puntos: [],
        observaciones: null)).called(1);
  });

  test('propaga puntos y observaciones al repositorio', () async {
    when(() => repository.guardarFaceMapPorTratamiento(
        tratamientoId: any(named: 'tratamientoId'),
        pacienteId: any(named: 'pacienteId'),
        puntos: any(named: 'puntos'),
        observaciones: any(named: 'observaciones')))
        .thenAnswer((_) async => const Right(null));

    await usecase(GuardarFaceMapPorTratamientoParams(
      tratamientoId: 'trat-1',
      pacienteId: 'pac-1',
      puntos: puntos,
      observaciones: 'pómulos marcados',
    ));

    verify(() => repository.guardarFaceMapPorTratamiento(
        tratamientoId: 'trat-1',
        pacienteId: 'pac-1',
        puntos: puntos,
        observaciones: 'pómulos marcados')).called(1);
  });

  test('retorna Failure cuando el repositorio falla', () async {
    when(() => repository.guardarFaceMapPorTratamiento(
        tratamientoId: any(named: 'tratamientoId'),
        pacienteId: any(named: 'pacienteId'),
        puntos: any(named: 'puntos'),
        observaciones: any(named: 'observaciones')))
        .thenAnswer((_) async => const Left(ServerFailure('boom')));

    final result = await usecase(const GuardarFaceMapPorTratamientoParams(
      tratamientoId: 'trat-1',
      pacienteId: 'pac-1',
      puntos: [],
    ));

    expect(result, const Left(ServerFailure('boom')));
  });
}