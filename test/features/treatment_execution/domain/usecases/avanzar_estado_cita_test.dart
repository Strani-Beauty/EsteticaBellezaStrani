import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/entities/cita_ejecucion_entity.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/avanzar_estado_cita.dart';
import '../../mock_repository.dart';

void main() {
  late AvanzarEstadoCita usecase;
  late MockITreatmentExecutionRepository repository;

  setUpAll(() {
    registerFallbackValue(EstadoCitaEjecucion.enCamino);
  });

  setUp(() {
    repository = MockITreatmentExecutionRepository();
    usecase = AvanzarEstadoCita(repository);
  });

  final cita = CitaEjecucionEntity(
    id: 'cita-1',
    estado: EstadoCitaEjecucion.enCamino,
    solicitudId: 'sol-1',
  );

  test('delega en el repositorio y retorna la cita avanzada', () async {
    when(() => repository.avanzarEstadoCita(
        citaId: any(named: 'citaId'),
        nuevoEstado: any(named: 'nuevoEstado'),
        observaciones: any(named: 'observaciones'))).thenAnswer((_) async => Right(cita));

    final result = await usecase(const AvanzarEstadoCitaParams(
      citaId: 'cita-1',
      nuevoEstado: EstadoCitaEjecucion.enCamino,
    ));

    expect(result, Right(cita));
    verify(() => repository.avanzarEstadoCita(
        citaId: 'cita-1',
        nuevoEstado: EstadoCitaEjecucion.enCamino,
        observaciones: null)).called(1);
  });

  test('propaga las observaciones al repositorio', () async {
    when(() => repository.avanzarEstadoCita(
        citaId: any(named: 'citaId'),
        nuevoEstado: any(named: 'nuevoEstado'),
        observaciones: any(named: 'observaciones'))).thenAnswer((_) async => Right(cita));

    await usecase(const AvanzarEstadoCitaParams(
      citaId: 'cita-1',
      nuevoEstado: EstadoCitaEjecucion.enProceso,
      observaciones: 'llegó a tiempo',
    ));

    verify(() => repository.avanzarEstadoCita(
        citaId: 'cita-1',
        nuevoEstado: EstadoCitaEjecucion.enProceso,
        observaciones: 'llegó a tiempo')).called(1);
  });

  test('retorna Failure cuando el repositorio falla', () async {
    when(() => repository.avanzarEstadoCita(
        citaId: any(named: 'citaId'),
        nuevoEstado: any(named: 'nuevoEstado'),
        observaciones: any(named: 'observaciones')))
        .thenAnswer((_) async => const Left(ServerFailure('boom')));

    final result = await usecase(const AvanzarEstadoCitaParams(
      citaId: 'cita-1',
      nuevoEstado: EstadoCitaEjecucion.enCamino,
    ));

    expect(result, const Left(ServerFailure('boom')));
  });
}