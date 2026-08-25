import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/registrar_llegada.dart';
import '../../mock_repository.dart';

void main() {
  late RegistrarLlegada usecase;
  late MockITreatmentExecutionRepository repository;

  setUp(() {
    repository = MockITreatmentExecutionRepository();
    usecase = RegistrarLlegada(repository);
  });

  test('delega en el repositorio y retorna la distancia recorrida', () async {
    when(() => repository.registrarLlegada(
        citaId: any(named: 'citaId'),
        latitud: any(named: 'latitud'),
        longitud: any(named: 'longitud')))
        .thenAnswer((_) async => const Right(235.5));

    final result = await usecase(const RegistrarLlegadaParams(
      citaId: 'cita-1',
      latitud: 19.4,
      longitud: -99.1,
    ));

    expect(result, const Right(235.5));
    verify(() => repository.registrarLlegada(
        citaId: 'cita-1', latitud: 19.4, longitud: -99.1)).called(1);
  });

  test('retorna Right(null) cuando no se pudo calcular la distancia', () async {
    when(() => repository.registrarLlegada(
        citaId: any(named: 'citaId'),
        latitud: any(named: 'latitud'),
        longitud: any(named: 'longitud')))
        .thenAnswer((_) async => const Right(null));

    final result = await usecase(const RegistrarLlegadaParams(
      citaId: 'cita-1',
      latitud: 19.4,
      longitud: -99.1,
    ));

    expect(result, const Right(null));
  });

  test('retorna Failure cuando el repositorio falla', () async {
    when(() => repository.registrarLlegada(
        citaId: any(named: 'citaId'),
        latitud: any(named: 'latitud'),
        longitud: any(named: 'longitud')))
        .thenAnswer((_) async => const Left(ServerFailure('boom')));

    final result = await usecase(const RegistrarLlegadaParams(
      citaId: 'cita-1',
      latitud: 19.4,
      longitud: -99.1,
    ));

    expect(result, const Left(ServerFailure('boom')));
  });
}