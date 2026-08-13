import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/entities/especialista_entity.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/create_especialista.dart';
import '../../mock_repository.dart';

void main() {
  late CreateEspecialista usecase;
  late MockISpecialistsRepository repository;

  setUp(() {
    repository = MockISpecialistsRepository();
    usecase = CreateEspecialista(repository);
  });

  final entity = EspecialistaEntity(
    id: 'esp-1',
    usuarioId: 'user-1',
    numeroLicencia: 'LIC-123',
    estadoVerificacion: EstadoVerificacion.pendiente,
    disponible: false,
    activo: false,
    createdAt: DateTime(2026, 8, 13),
  );

  test('crea el especialista y retorna la entidad cuando el repo tiene éxito', () async {
    when(() => repository.createEspecialista(
          usuarioId: any(named: 'usuarioId'),
          numeroLicencia: any(named: 'numeroLicencia'),
          medicoRegenteId: any(named: 'medicoRegenteId'),
        )).thenAnswer((_) async => Right(entity));

    final result = await usecase(const CreateEspecialistaParams(
      usuarioId: 'user-1',
      numeroLicencia: 'LIC-123',
    ));

    expect(result, Right(entity));
  });

  test('retorna Failure cuando el repo falla', () async {
    when(() => repository.createEspecialista(
          usuarioId: any(named: 'usuarioId'),
          numeroLicencia: any(named: 'numeroLicencia'),
          medicoRegenteId: any(named: 'medicoRegenteId'),
        )).thenAnswer((_) async => const Left(ServerFailure('error')));

    final result = await usecase(const CreateEspecialistaParams(usuarioId: 'user-1'));

    expect(result, const Left(ServerFailure('error')));
  });

  test('pasa los parámetros correctos al repo', () async {
    when(() => repository.createEspecialista(
          usuarioId: any(named: 'usuarioId'),
          numeroLicencia: any(named: 'numeroLicencia'),
          medicoRegenteId: any(named: 'medicoRegenteId'),
        )).thenAnswer((_) async => Right(entity));

    await usecase(const CreateEspecialistaParams(
      usuarioId: 'user-1',
      numeroLicencia: 'LIC-123',
      medicoRegenteId: 'med-9',
    ));

    verify(() => repository.createEspecialista(
          usuarioId: 'user-1',
          numeroLicencia: 'LIC-123',
          medicoRegenteId: 'med-9',
        )).called(1);
  });
}
