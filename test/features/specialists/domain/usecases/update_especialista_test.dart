import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/entities/especialista_entity.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/update_especialista.dart';
import '../../mock_repository.dart';

void main() {
  late UpdateEspecialista usecase;
  late MockISpecialistsRepository repository;

  setUp(() {
    repository = MockISpecialistsRepository();
    usecase = UpdateEspecialista(repository);
  });

  final entity = EspecialistaEntity(
    id: 'esp-1',
    usuarioId: 'user-1',
    numeroLicencia: 'LIC-123',
    estadoVerificacion: EstadoVerificacion.enRevision,
    disponible: true,
    activo: true,
    createdAt: DateTime(2026, 8, 13),
  );

  test('construye el mapa de datos y retorna la entidad actualizada', () async {
    when(() => repository.updateEspecialista(any(), any()))
        .thenAnswer((_) async => Right(entity));

    final result = await usecase(UpdateEspecialistaParams(
      id: 'esp-1',
      numeroLicencia: 'LIC-123',
      medicoRegenteId: 'med-9',
      disponible: true,
    ));

    expect(result, Right(entity));
    verify(() => repository.updateEspecialista('esp-1', {
          'numero_licencia': 'LIC-123',
          'medico_regente_id': 'med-9',
          'disponible': true,
        })).called(1);
  });

  test('incluye estado de verificación y fecha en el mapa', () async {
    final fecha = DateTime(2026, 8, 13, 12);
    when(() => repository.updateEspecialista(any(), any()))
        .thenAnswer((_) async => Right(entity));

    await usecase(UpdateEspecialistaParams(
      id: 'esp-1',
      estadoVerificacion: EstadoVerificacion.aprobado.toDb,
      fechaVerificacion: fecha,
      aprobadoPor: 'admin-1',
    ));

    verify(() => repository.updateEspecialista('esp-1', {
          'estado_verificacion': 'APROBADO',
          'fecha_verificacion': fecha.toIso8601String(),
          'aprobado_por': 'admin-1',
        })).called(1);
  });

  test('limpia la observación cuando limpiarObservacion es true', () async {
    when(() => repository.updateEspecialista(any(), any()))
        .thenAnswer((_) async => Right(entity));

    await usecase(const UpdateEspecialistaParams(
      id: 'esp-1',
      observacion: 'motivo viejo',
      limpiarObservacion: true,
    ));

    verify(() => repository.updateEspecialista('esp-1', {'observacion': null}))
        .called(1);
  });

  test('retorna Failure cuando el repo falla', () async {
    when(() => repository.updateEspecialista(any(), any()))
        .thenAnswer((_) async => const Left(ServerFailure('error')));

    final result = await usecase(
        const UpdateEspecialistaParams(id: 'esp-1', disponible: false));

    expect(result, const Left(ServerFailure('error')));
  });
}
