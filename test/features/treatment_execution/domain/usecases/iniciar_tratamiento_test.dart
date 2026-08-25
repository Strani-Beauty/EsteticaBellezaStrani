import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/entities/tratamiento_entity.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/iniciar_tratamiento.dart';
import '../../mock_repository.dart';

void main() {
  late IniciarTratamiento usecase;
  late MockITreatmentExecutionRepository repository;

  setUp(() {
    repository = MockITreatmentExecutionRepository();
    usecase = IniciarTratamiento(repository);
  });

  final tratamiento = TratamientoEntity(
    id: 'trat-1',
    citaId: 'cita-1',
    pacienteId: 'pac-1',
    especialistaId: 'esp-1',
    estado: EstadoTratamiento.pendienteFirma,
    createdAt: DateTime(2026, 8, 25),
  );

  test('delega en el repositorio y retorna el tratamiento creado', () async {
    when(() => repository.iniciarTratamiento(
        citaId: any(named: 'citaId'),
        evaluacionInicial: any(named: 'evaluacionInicial')))
        .thenAnswer((_) async => Right(tratamiento));

    final result = await usecase(const IniciarTratamientoParams(citaId: 'cita-1'));

    expect(result, Right(tratamiento));
    verify(() => repository.iniciarTratamiento(
        citaId: 'cita-1', evaluacionInicial: null)).called(1);
  });

  test('propaga la evaluación inicial al repositorio', () async {
    when(() => repository.iniciarTratamiento(
        citaId: any(named: 'citaId'),
        evaluacionInicial: any(named: 'evaluacionInicial')))
        .thenAnswer((_) async => Right(tratamiento));

    await usecase(const IniciarTratamientoParams(
        citaId: 'cita-1', evaluacionInicial: 'frente'));

    verify(() => repository.iniciarTratamiento(
        citaId: 'cita-1', evaluacionInicial: 'frente')).called(1);
  });

  test('retorna Failure cuando el repositorio falla', () async {
    when(() => repository.iniciarTratamiento(
        citaId: any(named: 'citaId'),
        evaluacionInicial: any(named: 'evaluacionInicial')))
        .thenAnswer((_) async => const Left(ServerFailure('boom')));

    final result = await usecase(const IniciarTratamientoParams(citaId: 'cita-1'));

    expect(result, const Left(ServerFailure('boom')));
  });
}