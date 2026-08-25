import 'package:flutter_test/flutter_test.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/data/models/producto_aplicado_model.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/entities/producto_aplicado_entity.dart';

void main() {
  group('ProductoAplicadoModel', () {
    test('fromJson parsea todos los campos incluida cantidad y unidad', () {
      final model = ProductoAplicadoModel.fromJson({
        'id': 'prod-1',
        'tratamiento_id': 't-1',
        'producto_nombre': 'Ácido Hialurónico',
        'fabricante': 'Allergan',
        'lote': 'L-2026',
        'cantidad_total': 2.5,
        'unidad_medida': 'jeringas',
        'fecha_vencimiento': '2027-01-15T00:00:00.000Z',
        'observaciones': 'Cánula 25G',
        'created_at': '2026-08-25T10:30:00.000Z',
      });

      expect(model.id, 'prod-1');
      expect(model.tratamientoId, 't-1');
      expect(model.productoNombre, 'Ácido Hialurónico');
      expect(model.fabricante, 'Allergan');
      expect(model.lote, 'L-2026');
      expect(model.cantidadTotal, 2.5);
      expect(model.unidadMedida, 'jeringas');
      expect(model.observaciones, 'Cánula 25G');
    });

    test('fromJson usa valores por defecto cuando faltan campos', () {
      final model = ProductoAplicadoModel.fromJson({'id': 'prod-2'});
      expect(model.tratamientoId, '');
      expect(model.productoNombre, '');
      expect(model.cantidadTotal, 1);
      expect(model.unidadMedida, isNull);
      expect(model.fechaVencimiento, isNull);
    });

    test('toEntity conserva cantidad y unidad de medida', () {
      final model = ProductoAplicadoModel(
        id: 'prod-1',
        tratamientoId: 't-1',
        productoNombre: 'Toxina Botulínica',
        cantidadTotal: 4,
        unidadMedida: 'unidades',
        createdAt: '2026-08-25T10:30:00.000Z',
      );

      final entity = model.toEntity();
      expect(entity, isA<ProductoAplicadoEntity>());
      expect(entity.tratamientoId, 't-1');
      expect(entity.productoNombre, 'Toxina Botulínica');
      expect(entity.cantidadTotal, 4);
      expect(entity.unidadMedida, 'unidades');
    });
  });
}