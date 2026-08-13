import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/entities/medico_regente_entity.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/create_medico_regente.dart';
import '../../mock_repository.dart';

void main() {
  late CreateMedicoRegente usecase;
  late MockISpecialistsRepository repository;

  setUp(() {
    repository = MockISpecialistsRepository();
    usecase = CreateMedicoRegente(repository);
  });

  final medico = MedicoRegenteEntity(
    id: 'med-1',
    nombre: 'Dr. Pérez',
    numeroLicencia: 'MED-123',
    estado: 'PENDIENTE',
    activo: false,
    createdAt: DateTime(2026, 8, 13),
  );

  test('registra el médico regente y retorna la entidad', () async {
    when(() => repository.createMedicoRegente(
          nombre: any(named: 'nombre'),
          numeroLicencia: any(named: 'numeroLicencia'),
          telefono: any(named: 'telefono'),
          correo: any(named: 'correo'),
        )).thenAnswer((_) async => Right(medico));

    final result = await usecase(const CreateMedicoRegenteParams(
      nombre: 'Dr. Pérez',
      numeroLicencia: 'MED-123',
    ));

    expect(result, Right(medico));
  });

  test('pasa los parámetros correctos al repo', () async {
    when(() => repository.createMedicoRegente(
          nombre: any(named: 'nombre'),
          numeroLicencia: any(named: 'numeroLicencia'),
          telefono: any(named: 'telefono'),
          correo: any(named: 'correo'),
        )).thenAnswer((_) async => Right(medico));

    await usecase(const CreateMedicoRegenteParams(
      nombre: 'Dr. Pérez',
      numeroLicencia: 'MED-123',
      telefono: '555-1234',
      correo: 'dr@example.com',
    ));

    verify(() => repository.createMedicoRegente(
          nombre: 'Dr. Pérez',
          numeroLicencia: 'MED-123',
          telefono: '555-1234',
          correo: 'dr@example.com',
        )).called(1);
  });

  test('retorna Failure cuando el repo falla', () async {
    when(() => repository.createMedicoRegente(
          nombre: any(named: 'nombre'),
          numeroLicencia: any(named: 'numeroLicencia'),
          telefono: any(named: 'telefono'),
          correo: any(named: 'correo'),
        )).thenAnswer((_) async => const Left(ServerFailure('error')));

    final result = await usecase(
        const CreateMedicoRegenteParams(nombre: 'Dr. Pérez'));

    expect(result, const Left(ServerFailure('error')));
  });
}
