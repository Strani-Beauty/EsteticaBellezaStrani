import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/entities/tratamiento_entity.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/actualizar_tratamiento.dart';
import '../../mock_repository.dart';

void main() {
  late ActualizarTratamiento usecase;
  late MockITreatmentExecutionRepository repository;

  setUp(() {
    repository = MockITreatmentExecutionRepository();
    usecase = ActualizarTratamiento(repository);
  });

  final tratamiento = TratamientoEntity(
    id: 'trat-1',
    citaId: 'cita-1',
    pacienteId: 'pac-1',
    especialistaId: 'esp-1',
    estado: EstadoTratamiento.enProceso,
    evaluacionInicial: 'frente',
    createdAt: DateTime(2026, 8, 25),
  );

  test('delega en el repositorio y retorna el tratamiento actualizado', () async {
    when(() => repository.actualizarTratamiento(
        tratamientoId: any(named: 'tratamientoId'),
        evaluacionInicial: any(named: 'evaluacionInicial'),
        observacionesFinales: any(named: 'observacionesFinales'),
        recomendacionesPostTratamiento: any(named: 'recomendacionesPostTratamiento'),
        estado: any(named: 'estado')))
        .thenAnswer((_) async => Right(tratamiento));

    final result = await usecase(const ActualizarTratamientoParams(
      tratamientoId: 'trat-1',
      evaluacionInicial: 'frente',
    ));

    expect(result, Right(tratamiento));
    verify(() => repository.actualizarTratamiento(
        tratamientoId: 'trat-1',
        evaluacionInicial: 'frente',
        observacionesFinales: null,
        recomendacionesPostTratamiento: null,
        estado: null)).called(1);
  });

  test('propaga observaciones, recomendaciones y estado al repositorio', () async {
    when(() => repository.actualizarTratamiento(
        tratamientoId: any(named: 'tratamientoId'),
        evaluacionInicial: any(named: 'evaluacionInicial'),
        observacionesFinales: any(named: 'observacionesFinales'),
        recomendacionesPostTratamiento: any(named: 'recomendacionesPostTratamiento'),
        estado: any(named: 'estado')))
        .thenAnswer((_) async => Right(tratamiento));

    await usecase(const ActualizarTratamientoParams(
      tratamientoId: 'trat-1',
      observacionesFinales: 'sin reacciones',
      recomendacionesPostTratamiento: 'hidratar',
      estado: 'COMPLETADO',
    ));

    verify(() => repository.actualizarTratamiento(
        tratamientoId: 'trat-1',
        evaluacionInicial: null,
        observacionesFinales: 'sin reacciones',
        recomendacionesPostTratamiento: 'hidratar',
        estado: 'COMPLETADO')).called(1);
  });

  test('retorna Failure cuando el repositorio falla', () async {
    when(() => repository.actualizarTratamiento(
        tratamientoId: any(named: 'tratamientoId'),
        evaluacionInicial: any(named: 'evaluacionInicial'),
        observacionesFinales: any(named: 'observacionesFinales'),
        recomendacionesPostTratamiento: any(named: 'recomendacionesPostTratamiento'),
        estado: any(named: 'estado')))
        .thenAnswer((_) async => const Left(ServerFailure('boom')));

    final result = await usecase(const ActualizarTratamientoParams(
        tratamientoId: 'trat-1', evaluacionInicial: 'frente'));

    expect(result, const Left(ServerFailure('boom')));
  });
}