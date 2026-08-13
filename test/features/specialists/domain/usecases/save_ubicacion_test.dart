import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/entities/ubicacion_especialista_entity.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/usecases/save_ubicacion.dart';
import '../../mock_repository.dart';

void main() {
  late SaveUbicacion usecase;
  late MockISpecialistsRepository repository;

  setUp(() {
    repository = MockISpecialistsRepository();
    usecase = SaveUbicacion(repository);
  });

  final ubicacion = UbicacionEspecialistaEntity(
    id: 'ubi-1',
    especialistaId: 'esp-1',
    latitud: 29.7604,
    longitud: -95.3698,
    precisionMetros: 10,
    createdAt: DateTime(2026, 8, 13),
  );

  test('guarda la ubicación y retorna la entidad', () async {
    when(() => repository.saveUbicacion(
          any(),
          latitud: any(named: 'latitud'),
          longitud: any(named: 'longitud'),
          precisionMetros: any(named: 'precisionMetros'),
        )).thenAnswer((_) async => Right(ubicacion));

    final result = await usecase(const SaveUbicacionParams(
      especialistaId: 'esp-1',
      latitud: 29.7604,
      longitud: -95.3698,
      precisionMetros: 10,
    ));

    expect(result, Right(ubicacion));
  });

  test('pasa los parámetros correctos al repo', () async {
    when(() => repository.saveUbicacion(
          any(),
          latitud: any(named: 'latitud'),
          longitud: any(named: 'longitud'),
          precisionMetros: any(named: 'precisionMetros'),
        )).thenAnswer((_) async => Right(ubicacion));

    await usecase(const SaveUbicacionParams(
      especialistaId: 'esp-1',
      latitud: 29.7604,
      longitud: -95.3698,
    ));

    verify(() => repository.saveUbicacion(
          'esp-1',
          latitud: 29.7604,
          longitud: -95.3698,
          precisionMetros: 0,
        )).called(1);
  });

  test('retorna Failure cuando el repo falla', () async {
    when(() => repository.saveUbicacion(
          any(),
          latitud: any(named: 'latitud'),
          longitud: any(named: 'longitud'),
          precisionMetros: any(named: 'precisionMetros'),
        )).thenAnswer((_) async => const Left(ServerFailure('error')));

    final result = await usecase(const SaveUbicacionParams(
      especialistaId: 'esp-1',
      latitud: 29.7604,
      longitud: -95.3698,
    ));

    expect(result, const Left(ServerFailure('error')));
  });
}
