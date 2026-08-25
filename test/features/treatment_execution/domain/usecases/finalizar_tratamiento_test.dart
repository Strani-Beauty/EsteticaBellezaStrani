import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/finalizar_tratamiento.dart';
import '../../mock_repository.dart';

void main() {
  late FinalizarTratamiento usecase;
  late MockITreatmentExecutionRepository repository;

  setUp(() {
    repository = MockITreatmentExecutionRepository();
    usecase = FinalizarTratamiento(repository);
  });

  test('delega en el repositorio y finaliza el tratamiento', () async {
    when(() => repository.finalizarTratamiento(
        citaId: any(named: 'citaId'),
        tratamientoId: any(named: 'tratamientoId'),
        observacionesFinales: any(named: 'observacionesFinales'),
        recomendacionesPostTratamiento:
            any(named: 'recomendacionesPostTratamiento')))
        .thenAnswer((_) async => const Right(null));

    final result = await usecase(const FinalizarTratamientoParams(
      citaId: 'cita-1',
      tratamientoId: 'trat-1',
    ));

    expect(result, const Right(null));
    verify(() => repository.finalizarTratamiento(
        citaId: 'cita-1',
        tratamientoId: 'trat-1',
        observacionesFinales: null,
        recomendacionesPostTratamiento: null)).called(1);
  });

  test('propaga observaciones finales y recomendaciones al repositorio',
      () async {
    when(() => repository.finalizarTratamiento(
        citaId: any(named: 'citaId'),
        tratamientoId: any(named: 'tratamientoId'),
        observacionesFinales: any(named: 'observacionesFinales'),
        recomendacionesPostTratamiento:
            any(named: 'recomendacionesPostTratamiento')))
        .thenAnswer((_) async => const Right(null));

    await usecase(const FinalizarTratamientoParams(
      citaId: 'cita-1',
      tratamientoId: 'trat-1',
      observacionesFinales: 'sin reacciones',
      recomendacionesPostTratamiento: 'hidratar',
    ));

    verify(() => repository.finalizarTratamiento(
        citaId: 'cita-1',
        tratamientoId: 'trat-1',
        observacionesFinales: 'sin reacciones',
        recomendacionesPostTratamiento: 'hidratar')).called(1);
  });

  test('retorna Failure cuando el repositorio falla', () async {
    when(() => repository.finalizarTratamiento(
        citaId: any(named: 'citaId'),
        tratamientoId: any(named: 'tratamientoId'),
        observacionesFinales: any(named: 'observacionesFinales'),
        recomendacionesPostTratamiento:
            any(named: 'recomendacionesPostTratamiento')))
        .thenAnswer((_) async => const Left(ServerFailure('boom')));

    final result = await usecase(const FinalizarTratamientoParams(
      citaId: 'cita-1',
      tratamientoId: 'trat-1',
    ));

    expect(result, const Left(ServerFailure('boom')));
  });
}