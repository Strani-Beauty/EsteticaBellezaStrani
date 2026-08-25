import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/entities/consentimiento_tratamiento_entity.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/registrar_consentimiento.dart';
import '../../mock_repository.dart';

void main() {
  late RegistrarConsentimiento usecase;
  late MockITreatmentExecutionRepository repository;

  setUp(() {
    repository = MockITreatmentExecutionRepository();
    usecase = RegistrarConsentimiento(repository);
  });

  final consentimiento = ConsentimientoTratamientoEntity(
    id: 'cons-1',
    tratamientoId: 'trat-1',
    pacienteId: 'pac-1',
    tipoConsentimiento: 'TRATAMIENTO_ESTETICO',
    firmaUrl: 'trat-1/firma_1.png',
    createdAt: DateTime(2026, 8, 25),
  );

  test('delega en el repositorio y retorna el consentimiento registrado',
      () async {
    when(() => repository.registrarConsentimiento(
        tratamientoId: any(named: 'tratamientoId'),
        pacienteId: any(named: 'pacienteId'),
        tipoConsentimiento: any(named: 'tipoConsentimiento'),
        firmaUrl: any(named: 'firmaUrl')))
        .thenAnswer((_) async => Right(consentimiento));

    final result = await usecase(const RegistrarConsentimientoParams(
      tratamientoId: 'trat-1',
      pacienteId: 'pac-1',
      tipoConsentimiento: 'TRATAMIENTO_ESTETICO',
      firmaUrl: 'trat-1/firma_1.png',
    ));

    expect(result, Right(consentimiento));
    verify(() => repository.registrarConsentimiento(
        tratamientoId: 'trat-1',
        pacienteId: 'pac-1',
        tipoConsentimiento: 'TRATAMIENTO_ESTETICO',
        firmaUrl: 'trat-1/firma_1.png')).called(1);
  });

  test('retorna Failure cuando el repositorio falla', () async {
    when(() => repository.registrarConsentimiento(
        tratamientoId: any(named: 'tratamientoId'),
        pacienteId: any(named: 'pacienteId'),
        tipoConsentimiento: any(named: 'tipoConsentimiento'),
        firmaUrl: any(named: 'firmaUrl')))
        .thenAnswer((_) async => const Left(ServerFailure('boom')));

    final result = await usecase(const RegistrarConsentimientoParams(
      tratamientoId: 'trat-1',
      pacienteId: 'pac-1',
      tipoConsentimiento: 'TRATAMIENTO_ESTETICO',
      firmaUrl: 'trat-1/firma_1.png',
    ));

    expect(result, const Left(ServerFailure('boom')));
  });
}