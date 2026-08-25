import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/entities/producto_aplicado_entity.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/get_productos.dart';
import '../../mock_repository.dart';

void main() {
  late GetProductos usecase;
  late MockITreatmentExecutionRepository repository;

  setUp(() {
    repository = MockITreatmentExecutionRepository();
    usecase = GetProductos(repository);
  });

  final producto = ProductoAplicadoEntity(
    id: 'prod-1',
    tratamientoId: 'trat-1',
    productoNombre: 'Ácido hialurónico',
    cantidadTotal: 2,
    unidadMedida: 'jeringas',
    createdAt: DateTime(2026, 8, 25),
  );

  test('delega en el repositorio y retorna los insumos del tratamiento',
      () async {
    when(() => repository.getProductos(any()))
        .thenAnswer((_) async => Right([producto]));

    final result = await usecase('trat-1');

    expect(result.getRight().toNullable(), [producto]);
    verify(() => repository.getProductos('trat-1')).called(1);
  });

  test('retorna Failure cuando el repositorio falla', () async {
    when(() => repository.getProductos(any()))
        .thenAnswer((_) async => const Left(ServerFailure('boom')));

    final result = await usecase('trat-1');

    expect(result, const Left(ServerFailure('boom')));
  });
}