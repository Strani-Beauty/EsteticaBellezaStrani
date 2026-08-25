import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/entities/cita_ejecucion_entity.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/entities/tratamiento_entity.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/get_cita_detalle.dart';
import '../../mock_repository.dart';

void main() {
  late GetCitaDetalle usecase;
  late MockITreatmentExecutionRepository repository;

  setUp(() {
    repository = MockITreatmentExecutionRepository();
    usecase = GetCitaDetalle(repository);
  });

  final cita = CitaEjecucionEntity(
    id: 'cita-1',
    estado: EstadoCitaEjecucion.enProceso,
    solicitudId: 'sol-1',
    tratamiento: TratamientoEntity(
      id: 'trat-1',
      citaId: 'cita-1',
      pacienteId: 'pac-1',
      especialistaId: 'esp-1',
      estado: EstadoTratamiento.enProceso,
      createdAt: DateTime(2026, 8, 25),
    ),
  );

  test('delega en el repositorio y retorna el detalle de la cita', () async {
    when(() => repository.getCitaDetalle(any()))
        .thenAnswer((_) async => Right(cita));

    final result = await usecase(const GetCitaDetalleParams('cita-1'));

    expect(result, Right(cita));
    verify(() => repository.getCitaDetalle('cita-1')).called(1);
  });

  test('retorna Failure cuando el repositorio falla', () async {
    when(() => repository.getCitaDetalle(any()))
        .thenAnswer((_) async => const Left(ServerFailure('boom')));

    final result = await usecase(const GetCitaDetalleParams('cita-1'));

    expect(result, const Left(ServerFailure('boom')));
  });
}