import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/entities/especialista_entity.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/solicitar_verificacion.dart';
import '../../mock_repository.dart';

void main() {
  late SolicitarVerificacion usecase;
  late MockISpecialistsRepository repository;

  setUp(() {
    repository = MockISpecialistsRepository();
    usecase = SolicitarVerificacion(repository);
  });

  final entity = EspecialistaEntity(
    id: 'esp-1',
    usuarioId: 'user-1',
    estadoVerificacion: EstadoVerificacion.enRevision,
    disponible: false,
    activo: false,
    createdAt: DateTime(2026, 8, 13),
  );

  test('marca la solicitud como EN_REVISION y retorna la entidad', () async {
    when(() => repository.solicitarVerificacion(any()))
        .thenAnswer((_) async => Right(entity));

    final result =
        await usecase(const SolicitarVerificacionParams('esp-1'));

    expect(result, Right(entity));
    verify(() => repository.solicitarVerificacion('esp-1')).called(1);
  });

  test('retorna Failure cuando el repo falla', () async {
    when(() => repository.solicitarVerificacion(any()))
        .thenAnswer((_) async => const Left(ServerFailure('error')));

    final result =
        await usecase(const SolicitarVerificacionParams('esp-1'));

    expect(result, const Left(ServerFailure('error')));
  });
}
