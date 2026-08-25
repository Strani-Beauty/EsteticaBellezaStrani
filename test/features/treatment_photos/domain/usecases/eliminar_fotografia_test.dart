import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/domain/usecases/eliminar_fotografia.dart';
import '../../mock_repository.dart';

void main() {
  late EliminarFotografia usecase;
  late MockITreatmentPhotosRepository repository;

  setUp(() {
    repository = MockITreatmentPhotosRepository();
    usecase = EliminarFotografia(repository);
  });

  test('delega en el repositorio y elimina la fotografía', () async {
    when(() => repository.eliminarFotografia(any(),
            pathEnStorage: any(named: 'pathEnStorage')))
        .thenAnswer((_) async => const Right(null));

    final result =
        await usecase(const EliminarFotografiaParams('foto-1', pathEnStorage: 'trat-1/123.png'));

    expect(result, const Right(null));
    verify(() => repository.eliminarFotografia('foto-1',
        pathEnStorage: 'trat-1/123.png')).called(1);
  });

  test('retorna Failure cuando el repositorio falla', () async {
    when(() => repository.eliminarFotografia(any(),
            pathEnStorage: any(named: 'pathEnStorage')))
        .thenAnswer((_) async => const Left(ServerFailure('boom')));

    final result = await usecase(const EliminarFotografiaParams('foto-1'));

    expect(result, const Left(ServerFailure('boom')));
  });
}