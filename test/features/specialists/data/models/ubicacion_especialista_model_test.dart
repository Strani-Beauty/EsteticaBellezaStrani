import 'package:flutter_test/flutter_test.dart';
import 'package:esteticaybellezastrani/features/specialists/data/models/ubicacion_especialista_model.dart';

void main() {
  group('UbicacionEspecialistaModel (mapeo BD → entidad)', () {
    test('mapea lat/lng/precision y fechas', () {
      final json = <String, dynamic>{
        'id': 'ubi-1',
        'especialista_id': 'esp-1',
        'latitud': 29.7604,
        'longitud': -95.3698,
        'precision_metros': 10,
        'fecha_actualizacion': '2026-08-13T10:00:00.000Z',
        'created_at': '2026-08-13T00:00:00.000Z',
      };

      final entity = UbicacionEspecialistaModel.fromJson(json).toEntity();

      expect(entity.id, 'ubi-1');
      expect(entity.especialistaId, 'esp-1');
      expect(entity.latitud, 29.7604);
      expect(entity.longitud, -95.3698);
      expect(entity.precisionMetros, 10);
      expect(entity.fechaActualizacion, DateTime.parse('2026-08-13T10:00:00.000Z'));
    });

    test('usa 0 como default si latitud/longitud ausentes', () {
      final json = <String, dynamic>{
        'id': 'ubi-1',
        'especialista_id': 'esp-1',
        'precision_metros': 0,
        'created_at': '2026-08-13T00:00:00.000Z',
      };

      final entity = UbicacionEspecialistaModel.fromJson(json).toEntity();

      expect(entity.latitud, 0);
      expect(entity.longitud, 0);
    });
  });
}
