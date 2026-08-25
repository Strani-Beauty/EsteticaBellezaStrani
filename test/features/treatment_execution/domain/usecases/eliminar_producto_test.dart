import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/eliminar_producto.dart';
import '../../mock_repository.dart';

void main() {
  late EliminarProducto usecase;
  late MockITreatmentExecutionRepository repository;

  setUp(() {
    repository = MockITreatmentExecutionRepository();
    usecase = EliminarProducto(repository);
  });

  test('delega en el repositorio y elimina el insumo', () async {
    when(() => repository.eliminarProducto(any()))
        .thenAnswer((_) async => const Right(null));

    final result = await usecase(const EliminarProductoParams('prod-1'));

    expect(result, const Right(null));
    verify(() => repository.eliminarProducto('prod-1')).called(1);
  });

  test('retorna Failure cuando el repositorio falla', () async {
    when(() => repository.eliminarProducto(any()))
        .thenAnswer((_) async => const Left(ServerFailure('boom')));

    final result = await usecase(const EliminarProductoParams('prod-1'));

    expect(result, const Left(ServerFailure('boom')));
  });
}