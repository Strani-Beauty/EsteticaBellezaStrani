import 'package:flutter_test/flutter_test.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/data/models/fotografia_tratamiento_model.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/domain/entities/fotografia_tratamiento_entity.dart';

void main() {
  final jsonCompleto = {
    'id': 'foto-1',
    'tratamiento_id': 't-1',
    'tipo_fotografia': 'PRE',
    'archivo_url': 't-1/1729872000000_1.jpg',
    'fecha_captura': '2026-08-25T10:00:00.000Z',
    'descripcion': 'Foto pre-tratamiento',
    'created_at': '2026-08-25T10:00:00.000Z',
    'tipo_foto': 'pre',
  };

  group('FotografiaTratamientoModel', () {
    test('fromJson parsea todos los campos', () {
      final model = FotografiaTratamientoModel.fromJson(jsonCompleto);

      expect(model.id, 'foto-1');
      expect(model.tratamientoId, 't-1');
      expect(model.tipoFotografia, TipoFotografia.pre);
      expect(model.archivoUrl, 't-1/1729872000000_1.jpg');
      expect(model.fechaCaptura, DateTime.parse('2026-08-25T10:00:00.000Z'));
      expect(model.descripcion, 'Foto pre-tratamiento');
      expect(model.tipoFoto, 'pre');
    });

    test('fromJson usa otro para tipo desconocido y "" para url', () {
      final model = FotografiaTratamientoModel.fromJson({
        'id': 'foto-2',
        'tratamiento_id': 't-2',
        'tipo_fotografia': 'DESCONOCIDO',
        'created_at': '2026-08-25T10:00:00.000Z',
      });
      expect(model.tipoFotografia, TipoFotografia.otro);
      expect(model.archivoUrl, '');
    });

    test('toJson expone tratamiento_id, tipo y archivo_url', () {
      final model = FotografiaTratamientoModel(
        id: 'foto-1',
        tratamientoId: 't-1',
        tipoFotografia: TipoFotografia.post,
        archivoUrl: 't-1/1729872000000_2.jpg',
        fechaCaptura: DateTime.parse('2026-08-25T10:00:00.000Z'),
        createdAt: DateTime.parse('2026-08-25T10:00:00.000Z'),
        tipoFoto: 'post',
      );

      final json = model.toJson();
      expect(json['tratamiento_id'], 't-1');
      expect(json['tipo_fotografia'], 'POST');
      expect(json['archivo_url'], 't-1/1729872000000_2.jpg');
      expect(json['fecha_captura'], '2026-08-25T10:00:00.000Z');
      expect(json['tipo_foto'], 'post');
    });

    test('copyWith actualiza archivoUrl y conserva el resto', () {
      final model = FotografiaTratamientoModel.fromJson(jsonCompleto);
      final actualizado = model.copyWith(archivoUrl: 't-1/nuevo.jpg');

      expect(actualizado.archivoUrl, 't-1/nuevo.jpg');
      expect(actualizado.id, 'foto-1');
      expect(actualizado.tratamientoId, 't-1');
      expect(actualizado.tipoFotografia, TipoFotografia.pre);
    });

    test('toEntity conserva el vínculo con el tratamiento y el tipo', () {
      final model = FotografiaTratamientoModel.fromJson(jsonCompleto);
      final entity = model.toEntity();

      expect(entity, isA<FotografiaTratamientoEntity>());
      expect(entity.id, 'foto-1');
      expect(entity.tratamientoId, 't-1');
      expect(entity.tipoFotografia, TipoFotografia.pre);
      expect(entity.archivoUrl, 't-1/1729872000000_1.jpg');
      expect(entity.esPre, isTrue);
    });
  });

  group('TipoFotografia', () {
    test('mapea enum -> string BD', () {
      expect(TipoFotografia.pre.toDb, 'PRE');
      expect(TipoFotografia.post.toDb, 'POST');
      expect(TipoFotografia.otro.toDb, 'OTRO');
    });

    test('mapea string BD -> enum (case insensitive)', () {
      expect(TipoFotografia.fromDb('PRE'), TipoFotografia.pre);
      expect(TipoFotografia.fromDb('post'), TipoFotografia.post);
      expect(TipoFotografia.fromDb(null), isNull);
      expect(TipoFotografia.fromDb('DESCONOCIDO'), isNull);
    });
  });
}