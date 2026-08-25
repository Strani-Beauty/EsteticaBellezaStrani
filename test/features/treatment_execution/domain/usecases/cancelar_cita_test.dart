import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/cancelar_cita.dart';
import '../../mock_repository.dart';

void main() {
  late CancelarCita usecase;
  late MockITreatmentExecutionRepository repository;

  setUp(() {
    repository = MockITreatmentExecutionRepository();
    usecase = CancelarCita(repository);
  });

  test('delega en el repositorio y cancela la cita', () async {
    when(() => repository.cancelarCita(
        citaId: any(named: 'citaId'), motivo: any(named: 'motivo')))
        .thenAnswer((_) async => const Right(null));

    final result = await usecase(const CancelarCitaParams(
        citaId: 'cita-1', motivo: 'emergencia'));

    expect(result, const Right(null));
    verify(() => repository.cancelarCita(
        citaId: 'cita-1', motivo: 'emergencia')).called(1);
  });

  test('retorna Failure cuando el repositorio falla', () async {
    when(() => repository.cancelarCita(
        citaId: any(named: 'citaId'), motivo: any(named: 'motivo')))
        .thenAnswer((_) async => const Left(ServerFailure('boom')));

    final result = await usecase(const CancelarCitaParams(citaId: 'cita-1'));

    expect(result, const Left(ServerFailure('boom')));
  });
}