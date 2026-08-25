import 'package:flutter_test/flutter_test.dart';
import 'package:esteticaybellezastrani/features/treatment_photos/domain/entities/fotografia_tratamiento_entity.dart';

void main() {
  final fecha = DateTime(2026, 8, 25, 10);

  FotografiaTratamientoEntity build(TipoFotografia tipo) {
    return FotografiaTratamientoEntity(
      id: 'foto-1',
      tratamientoId: 't-1',
      tipoFotografia: tipo,
      archivoUrl: 't-1/1729872000000_1.jpg',
      fechaCaptura: fecha,
      createdAt: fecha,
    );
  }

  group('TipoFotografia', () {
    test('mapea enum -> string BD', () {
      expect(TipoFotografia.pre.toDb, 'PRE');
      expect(TipoFotografia.post.toDb, 'POST');
      expect(TipoFotografia.otro.toDb, 'OTRO');
    });

    test('mapea string BD -> enum', () {
      expect(TipoFotografia.fromDb('PRE'), TipoFotografia.pre);
      expect(TipoFotografia.fromDb('post'), TipoFotografia.post);
      expect(TipoFotografia.fromDb(null), isNull);
    });
  });

  group('FotografiaTratamientoEntity', () {
    test('esPre es true solo para fotografías PRE', () {
      expect(build(TipoFotografia.pre).esPre, isTrue);
      expect(build(TipoFotografia.post).esPre, isFalse);
      expect(build(TipoFotografia.otro).esPre, isFalse);
    });

    test('esPost es true solo para fotografías POST', () {
      expect(build(TipoFotografia.post).esPost, isTrue);
      expect(build(TipoFotografia.pre).esPost, isFalse);
    });

    test('expone el vínculo con el tratamiento', () {
      final foto = build(TipoFotografia.pre);
      expect(foto.id, 'foto-1');
      expect(foto.tratamientoId, 't-1');
      expect(foto.archivoUrl, 't-1/1729872000000_1.jpg');
    });

    test('la igualdad considera los props del tratamiento', () {
      final pre = build(TipoFotografia.pre);
      final post = build(TipoFotografia.post);
      expect(pre, isNot(equals(post)));
    });
  });
}