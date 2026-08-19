import 'package:flutter_test/flutter_test.dart';
import 'package:esteticaybellezastrani/features/catalog_services/data/models/categoria_servicio_model.dart';
import 'package:esteticaybellezastrani/features/catalog_services/data/models/servicio_model.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/entities/categoria_servicio_entity.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/entities/servicio_entity.dart';

void main() {
  group('TipoPrecio', () {
    test('mapea enum -> string BD', () {
      expect(TipoPrecio.precioFijo.toDb, 'PRECIO_FIJO');
      expect(TipoPrecio.porUnidad.toDb, 'POR_UNIDAD');
      expect(TipoPrecio.porJeringa.toDb, 'POR_JERINGA');
      expect(TipoPrecio.porSesion.toDb, 'POR_SESION');
      expect(TipoPrecio.porPlan.toDb, 'POR_PLAN');
    });

    test('mapea string BD -> enum (case insensitive)', () {
      expect(TipoPrecio.fromDb('PRECIO_FIJO'), TipoPrecio.precioFijo);
      expect(TipoPrecio.fromDb('por_jeringa'), TipoPrecio.porJeringa);
      expect(TipoPrecio.fromDb(null), isNull);
      expect(TipoPrecio.fromDb('DESCONOCIDO'), isNull);
    });
  });

  group('CategoriaServicioModel', () {
    test('fromJson parsea correctamente', () {
      final model = CategoriaServicioModel.fromJson({
        'id': 7,
        'nombre': 'Inyectables',
        'descripcion': 'Toxina botulínica y rellenos',
        'activo': true,
      });

      expect(model.id, 7);
      expect(model.nombre, 'Inyectables');
      expect(model.descripcion, 'Toxina botulínica y rellenos');
      expect(model.activo, isTrue);
    });

    test('toEntity convierte correctamente', () {
      final model = CategoriaServicioModel(
        id: 7,
        nombre: 'Inyectables',
        descripcion: null,
        activo: false,
      );

      expect(model.toEntity(),
          isA<CategoriaServicioEntity>());
      expect(model.toEntity().id, 7);
      expect(model.toEntity().activo, isFalse);
    });

    test('fromJson usa valores por defecto cuando faltan campos', () {
      final model = CategoriaServicioModel.fromJson({'id': 3, 'nombre': 'Facial'});
      expect(model.descripcion, isNull);
      expect(model.activo, isTrue);
    });
  });

  group('ServicioModel', () {
    test('fromJson parsea todos los campos', () {
      final model = ServicioModel.fromJson({
        'id': 'uuid-1',
        'categoria_id': 7,
        'nombre': 'Toxina Botulínica',
        'descripcion': 'Unidades por arrugas dinámicas',
        'precio_base': 150.5,
        'tipo_precio': 'POR_UNIDAD',
        'duracion_estimada': 30,
        'requiere_telemedicina': true,
        'requiere_face_map': true,
        'requiere_fotos': false,
        'requiere_consentimiento': true,
        'activo': false,
        'categorias_servicio': {
          'id': 7,
          'nombre': 'Inyectables',
          'descripcion': null,
          'activo': true,
        },
      });

      expect(model.id, 'uuid-1');
      expect(model.categoriaId, 7);
      expect(model.nombre, 'Toxina Botulínica');
      expect(model.descripcion, 'Unidades por arrugas dinámicas');
      expect(model.precioBase, 150.5);
      expect(model.tipoPrecio, TipoPrecio.porUnidad);
      expect(model.duracionEstimada, 30);
      expect(model.requiereTelemedicina, isTrue);
      expect(model.requiereFaceMap, isTrue);
      expect(model.requiereFotos, isFalse);
      expect(model.requiereConsentimiento, isTrue);
      expect(model.activo, isFalse);
      expect(model.categoria?.nombre, 'Inyectables');
    });

    test('toEntity conserva los valores', () {
      final model = ServicioModel(
        id: 'uuid-1',
        categoriaId: 7,
        nombre: 'Mesoterapia',
        descripcion: null,
        precioBase: 80,
        tipoPrecio: TipoPrecio.porSesion,
        duracionEstimada: 45,
        requiereTelemedicina: true,
        requiereFaceMap: false,
        requiereFotos: true,
        requiereConsentimiento: false,
        activo: true,
        categoria: const CategoriaServicioEntity(
          id: 7,
          nombre: 'Corporal',
          activo: true,
        ),
      );

      final entity = model.toEntity();
      expect(entity, isA<ServicioEntity>());
      expect(entity.id, 'uuid-1');
      expect(entity.nombre, 'Mesoterapia');
      expect(entity.precioBase, 80);
      expect(entity.tipoPrecio, TipoPrecio.porSesion);
      expect(entity.duracionEstimada, 45);
      expect(entity.requiereTelemedicina, isTrue);
      expect(entity.requiereFotos, isTrue);
      expect(entity.nombreCategoria, 'Corporal');
    });

    test('fromJson usa defaults cuando faltan campos', () {
      final model = ServicioModel.fromJson({'id': 'x', 'nombre': 'Servicio'});
      expect(model.precioBase, 0);
      expect(model.tipoPrecio, TipoPrecio.precioFijo);
      expect(model.duracionEstimada, isNull);
      expect(model.requiereTelemedicina, isFalse);
      expect(model.activo, isTrue);
      expect(model.categoria, isNull);
    });
  });
}