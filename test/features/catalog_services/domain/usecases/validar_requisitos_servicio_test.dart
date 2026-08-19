import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/entities/servicio_cuestionario_entity.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/repositories/i_catalog_repository.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/usecases/validar_requisitos_servicio.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/domain/repositories/i_patients_compliance_repository.dart';

class MockICatalogRepository extends Mock implements ICatalogRepository {}
class MockIPatientsComplianceRepository extends Mock
    implements IPatientsComplianceRepository {}

void main() {
  late MockICatalogRepository catalogRepo;
  late MockIPatientsComplianceRepository complianceRepo;
  late ValidarRequisitosServicio usecase;

  setUp(() {
    catalogRepo = MockICatalogRepository();
    complianceRepo = MockIPatientsComplianceRepository();
    usecase = ValidarRequisitosServicio(catalogRepo, complianceRepo);
  });

  final sinRequisitos = ServicioRequisitosEntity();
  final conCuestionarios = ServicioRequisitosEntity(
    cuestionarios: const [
      ServicioCuestionarioEntity(
        cuestionarioId: 4,
        nombre: 'Cuestionario de Salud',
        obligatorio: true,
        orden: 0,
      ),
      ServicioCuestionarioEntity(
        cuestionarioId: 9,
        nombre: 'Facial',
        obligatorio: false,
        orden: 1,
      ),
    ],
  );

  test('cumple = true cuando no hay cuestionarios obligatorios', () async {
    when(() => catalogRepo.getRequisitosServicio(any()))
        .thenAnswer((_) async => Right(sinRequisitos));

    final result = await usecase(ValidarRequisitosServicioParams(
      servicioId: 'uuid-1',
    ));

    final r = result.getRight().toNullable()!;
    expect(r.cumple, isTrue);
    expect(r.cuestionariosPendientes, isEmpty);
  });

  test('cumple = true cuando todas las evaluaciones obligatorias son APTO',
      () async {
    when(() => catalogRepo.getRequisitosServicio(any()))
        .thenAnswer((_) async => Right(conCuestionarios));
    when(() => complianceRepo.tieneEvaluacionAptaDeCuestionario(any()))
        .thenAnswer((_) async => const Right(true));

    final result = await usecase(ValidarRequisitosServicioParams(
      servicioId: 'uuid-1',
    ));

    final r = result.getRight().toNullable()!;
    expect(r.cumple, isTrue);
    expect(r.cuestionariosPendientes, isEmpty);
  });

  test('cumple = false y reporta pendientes si falta una evaluación APTO',
      () async {
    when(() => catalogRepo.getRequisitosServicio(any()))
        .thenAnswer((_) async => Right(conCuestionarios));
    when(() => complianceRepo.tieneEvaluacionAptaDeCuestionario(4))
        .thenAnswer((_) async => const Right(false));
    when(() => complianceRepo.tieneEvaluacionAptaDeCuestionario(9))
        .thenAnswer((_) async => const Right(true));

    final result = await usecase(ValidarRequisitosServicioParams(
      servicioId: 'uuid-1',
    ));

    final r = result.getRight().toNullable()!;
    expect(r.cumple, isFalse);
    expect(r.cuestionariosPendientes.length, 1);
    expect(r.cuestionariosPendientes.single.cuestionarioId, 4);
  });

  test('ignora los cuestionarios no obligatorios aunque no estén APTO',
      () async {
    when(() => catalogRepo.getRequisitosServicio(any()))
        .thenAnswer((_) async => Right(conCuestionarios));
    when(() => complianceRepo.tieneEvaluacionAptaDeCuestionario(any()))
        .thenAnswer((_) async => const Right(false));

    final result = await usecase(ValidarRequisitosServicioParams(
      servicioId: 'uuid-1',
    ));

    final r = result.getRight().toNullable()!;
    expect(r.cumple, isFalse);
    expect(r.cuestionariosPendientes.length, 1);
    expect(r.cuestionariosPendientes.single.cuestionarioId, 4);
  });

  test('propaga los flags informativos de fotos y consentimiento', () async {
    when(() => catalogRepo.getRequisitosServicio(any()))
        .thenAnswer((_) async => Right(sinRequisitos));

    final result = await usecase(ValidarRequisitosServicioParams(
      servicioId: 'uuid-1',
      requiereFotos: true,
      requiereConsentimiento: true,
    ));

    final r = result.getRight().toNullable()!;
    expect(r.cumple, isTrue);
    expect(r.requiereFotos, isTrue);
    expect(r.requiereConsentimiento, isTrue);
  });

  test('retorna Left si falla la consulta de requisitos', () async {
    when(() => catalogRepo.getRequisitosServicio(any()))
        .thenAnswer((_) async => Left(ServerFailure('boom')));

    final result = await usecase(ValidarRequisitosServicioParams(
      servicioId: 'uuid-1',
    ));

    expect(result, isA<Left<Failure, ValidarRequisitosServicioResult>>());
  });
}