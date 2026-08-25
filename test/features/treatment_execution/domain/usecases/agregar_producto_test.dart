import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/entities/producto_aplicado_entity.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/usecases/agregar_producto.dart';
import '../../mock_repository.dart';

void main() {
  late AgregarProducto usecase;
  late MockITreatmentExecutionRepository repository;

  setUp(() {
    repository = MockITreatmentExecutionRepository();
    usecase = AgregarProducto(repository);
  });

  final producto = ProductoAplicadoEntity(
    id: 'prod-1',
    tratamientoId: 'trat-1',
    productoNombre: 'Ácido hialurónico',
    cantidadTotal: 2,
    unidadMedida: 'jeringas',
    createdAt: DateTime(2026, 8, 25),
  );

  test('delega en el repositorio y retorna el insumo agregado', () async {
    when(() => repository.agregarProducto(
        tratamientoId: any(named: 'tratamientoId'),
        productoNombre: any(named: 'productoNombre'),
        fabricante: any(named: 'fabricante'),
        lote: any(named: 'lote'),
        cantidadTotal: any(named: 'cantidadTotal'),
        unidadMedida: any(named: 'unidadMedida'),
        fechaVencimiento: any(named: 'fechaVencimiento'),
        observaciones: any(named: 'observaciones')))
        .thenAnswer((_) async => Right(producto));

    final result = await usecase(const AgregarProductoParams(
      tratamientoId: 'trat-1',
      productoNombre: 'Ácido hialurónico',
      cantidadTotal: 2,
      unidadMedida: 'jeringas',
    ));

    expect(result, Right(producto));
    verify(() => repository.agregarProducto(
        tratamientoId: 'trat-1',
        productoNombre: 'Ácido hialurónico',
        fabricante: null,
        lote: null,
        cantidadTotal: 2,
        unidadMedida: 'jeringas',
        fechaVencimiento: null,
        observaciones: null)).called(1);
  });

  test('usa la cantidad por defecto 1 cuando no se especifica', () async {
    when(() => repository.agregarProducto(
        tratamientoId: any(named: 'tratamientoId'),
        productoNombre: any(named: 'productoNombre'),
        fabricante: any(named: 'fabricante'),
        lote: any(named: 'lote'),
        cantidadTotal: any(named: 'cantidadTotal'),
        unidadMedida: any(named: 'unidadMedida'),
        fechaVencimiento: any(named: 'fechaVencimiento'),
        observaciones: any(named: 'observaciones')))
        .thenAnswer((_) async => Right(producto));

    await usecase(const AgregarProductoParams(
        tratamientoId: 'trat-1', productoNombre: 'Toxina'));

    verify(() => repository.agregarProducto(
        tratamientoId: 'trat-1',
        productoNombre: 'Toxina',
        fabricante: null,
        lote: null,
        cantidadTotal: 1,
        unidadMedida: null,
        fechaVencimiento: null,
        observaciones: null)).called(1);
  });

  test('retorna Failure cuando el repositorio falla', () async {
    when(() => repository.agregarProducto(
        tratamientoId: any(named: 'tratamientoId'),
        productoNombre: any(named: 'productoNombre'),
        fabricante: any(named: 'fabricante'),
        lote: any(named: 'lote'),
        cantidadTotal: any(named: 'cantidadTotal'),
        unidadMedida: any(named: 'unidadMedida'),
        fechaVencimiento: any(named: 'fechaVencimiento'),
        observaciones: any(named: 'observaciones')))
        .thenAnswer((_) async => const Left(ServerFailure('boom')));

    final result = await usecase(const AgregarProductoParams(
        tratamientoId: 'trat-1', productoNombre: 'Toxina'));

    expect(result, const Left(ServerFailure('boom')));
  });
}