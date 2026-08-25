import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/entities/consentimiento_tratamiento_entity.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/get_consentimiento.dart';
import '../../mock_repository.dart';

void main() {
  late GetConsentimiento usecase;
  late MockITreatmentExecutionRepository repository;

  setUp(() {
    repository = MockITreatmentExecutionRepository();
    usecase = GetConsentimiento(repository);
  });

  final consentimiento = ConsentimientoTratamientoEntity(
    id: 'cons-1',
    tratamientoId: 'trat-1',
    pacienteId: 'pac-1',
    tipoConsentimiento: 'TRATAMIENTO_ESTETICO',
    firmaUrl: 'trat-1/firma_1.png',
    createdAt: DateTime(2026, 8, 25),
  );

  test('delega en el repositorio y retorna el consentimiento', () async {
    when(() => repository.getConsentimiento(any()))
        .thenAnswer((_) async => Right(consentimiento));

    final result = await usecase('trat-1');

    expect(result, Right(consentimiento));
    verify(() => repository.getConsentimiento('trat-1')).called(1);
  });

  test('retorna Right(null) cuando aún no hay consentimiento', () async {
    when(() => repository.getConsentimiento(any()))
        .thenAnswer((_) async => const Right(null));

    final result = await usecase('trat-1');

    expect(result, const Right(null));
  });

  test('retorna Failure cuando el repositorio falla', () async {
    when(() => repository.getConsentimiento(any()))
        .thenAnswer((_) async => const Left(ServerFailure('boom')));

    final result = await usecase('trat-1');

    expect(result, const Left(ServerFailure('boom')));
  });
}