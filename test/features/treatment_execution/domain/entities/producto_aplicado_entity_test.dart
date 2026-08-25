import 'package:flutter_test/flutter_test.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/entities/producto_aplicado_entity.dart';

void main() {
  final createdAt = DateTime(2026, 8, 25, 10, 30);

  group('ProductoAplicadoEntity', () {
    test('expone cantidad y unidad de medida', () {
      final producto = ProductoAplicadoEntity(
        id: 'prod-1',
        tratamientoId: 't-1',
        productoNombre: 'Toxina Botulínica',
        cantidadTotal: 4,
        unidadMedida: 'unidades',
        createdAt: createdAt,
      );

      expect(producto.tratamientoId, 't-1');
      expect(producto.productoNombre, 'Toxina Botulínica');
      expect(producto.cantidadTotal, 4);
      expect(producto.unidadMedida, 'unidades');
    });

    test('cantidadTotal por defecto es 1', () {
      final producto = ProductoAplicadoEntity(
        id: 'prod-2',
        tratamientoId: 't-2',
        productoNombre: 'Solución salina',
        createdAt: createdAt,
      );
      expect(producto.cantidadTotal, 1);
      expect(producto.unidadMedida, isNull);
      expect(producto.fabricante, isNull);
    });

    test('la igualdad incluye todos los campos', () {
      final a = ProductoAplicadoEntity(
        id: 'prod-1',
        tratamientoId: 't-1',
        productoNombre: 'Toxina Botulínica',
        cantidadTotal: 4,
        unidadMedida: 'unidades',
        createdAt: createdAt,
      );
      final b = ProductoAplicadoEntity(
        id: 'prod-1',
        tratamientoId: 't-1',
        productoNombre: 'Toxina Botulínica',
        cantidadTotal: 4,
        unidadMedida: 'unidades',
        createdAt: createdAt,
      );
      expect(a, equals(b));
    });
  });
}