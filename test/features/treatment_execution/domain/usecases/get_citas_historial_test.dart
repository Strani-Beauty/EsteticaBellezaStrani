import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/entities/cita_ejecucion_entity.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/get_citas_historial.dart';
import '../../mock_repository.dart';

void main() {
  late GetCitasHistorial usecase;
  late MockITreatmentExecutionRepository repository;

  setUp(() {
    repository = MockITreatmentExecutionRepository();
    usecase = GetCitasHistorial(repository);
  });

  final cita = CitaEjecucionEntity(
    id: 'cita-1',
    estado: EstadoCitaEjecucion.finalizada,
    solicitudId: 'sol-1',
  );

  test('delega en el repositorio y retorna el historial del especialista',
      () async {
    when(() => repository.getCitasHistorial(any()))
        .thenAnswer((_) async => Right([cita]));

    final result = await usecase(const GetCitasHistorialParams('esp-1'));

    expect(result.getRight().toNullable(), [cita]);
    verify(() => repository.getCitasHistorial('esp-1')).called(1);
  });

  test('retorna Failure cuando el repositorio falla', () async {
    when(() => repository.getCitasHistorial(any()))
        .thenAnswer((_) async => const Left(ServerFailure('boom')));

    final result = await usecase(const GetCitasHistorialParams('esp-1'));

    expect(result, const Left(ServerFailure('boom')));
  });
}