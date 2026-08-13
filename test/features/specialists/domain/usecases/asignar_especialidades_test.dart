import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/entities/especialidad_entity.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/asignar_especialidades.dart';
import '../../mock_repository.dart';

void main() {
  late AsignarEspecialidades usecase;
  late MockISpecialistsRepository repository;

  setUp(() {
    repository = MockISpecialistsRepository();
    usecase = AsignarEspecialidades(repository);
  });

  final relaciones = [
    EspecialistaEspecialidadEntity(
      id: 1,
      especialistaId: 'esp-1',
      especialidadId: 10,
      createdAt: DateTime(2026, 8, 13),
    ),
  ];

  test('reemplaza las especialidades y retorna las relaciones', () async {
    when(() => repository.reemplazarEspecialidades(any(), any()))
        .thenAnswer((_) async => Right(relaciones));

    final result = await usecase(
        const AsignarEspecialidadesParams(especialistaId: 'esp-1', especialidadIds: [10]));

    expect(result, Right(relaciones));
  });

  test('pasa los parámetros correctos al repo', () async {
    when(() => repository.reemplazarEspecialidades(any(), any()))
        .thenAnswer((_) async => Right(relaciones));

    await usecase(const AsignarEspecialidadesParams(
        especialistaId: 'esp-1', especialidadIds: [10, 20]));

    verify(() => repository.reemplazarEspecialidades('esp-1', [10, 20]))
        .called(1);
  });

  test('retorna Failure cuando el repo falla', () async {
    when(() => repository.reemplazarEspecialidades(any(), any()))
        .thenAnswer((_) async => const Left(ServerFailure('error')));

    final result = await usecase(const AsignarEspecialidadesParams(
        especialistaId: 'esp-1', especialidadIds: []));

    expect(result, const Left(ServerFailure('error')));
  });
}
