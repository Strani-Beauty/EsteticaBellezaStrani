import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/domain/entities/fotografia_tratamiento_entity.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/domain/usecases/get_fotografias.dart';
import '../../mock_repository.dart';

void main() {
  late GetFotografias usecase;
  late MockITreatmentPhotosRepository repository;

  setUp(() {
    repository = MockITreatmentPhotosRepository();
    usecase = GetFotografias(repository);
  });

  final foto = FotografiaTratamientoEntity(
    id: 'foto-1',
    tratamientoId: 'trat-1',
    tipoFotografia: TipoFotografia.pre,
    archivoUrl: 'trat-1/123.png',
    fechaCaptura: DateTime(2026, 8, 25),
    createdAt: DateTime(2026, 8, 25),
  );

  test('delega en el repositorio y retorna las fotografías del tratamiento',
      () async {
    when(() => repository.getFotografias(any()))
        .thenAnswer((_) async => Right([foto]));

    final result = await usecase(const GetFotografiasParams('trat-1'));

    expect(result.getRight().toNullable(), [foto]);
    verify(() => repository.getFotografias('trat-1')).called(1);
  });

  test('retorna Failure cuando el repositorio falla', () async {
    when(() => repository.getFotografias(any()))
        .thenAnswer((_) async => const Left(ServerFailure('boom')));

    final result = await usecase(const GetFotografiasParams('trat-1'));

    expect(result, const Left(ServerFailure('boom')));
  });
}