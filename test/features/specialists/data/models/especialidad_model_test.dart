import 'package:flutter_test/flutter_test.dart';
import 'package:esteticaybellezastrani/features/specialists/data/models/especialidad_model.dart';

void main() {
  group('EspecialidadModel', () {
    test('mapea columnas de BD a entidad', () {
      final json = <String, dynamic>{
        'id': 10,
        'nombre': 'Facial',
        'descripcion': 'Limpieza facial',
        'activo': true,
        'created_at': '2026-08-13T00:00:00.000Z',
      };

      final entity = EspecialidadModel.fromJson(json).toEntity();

      expect(entity.id, 10);
      expect(entity.nombre, 'Facial');
      expect(entity.descripcion, 'Limpieza facial');
      expect(entity.activo, isTrue);
    });
  });

  group('EspecialistaEspecialidadModel', () {
    test('mapea la relación M:N', () {
      final json = <String, dynamic>{
        'id': 1,
        'especialista_id': 'esp-1',
        'especialidad_id': 10,
        'created_at': '2026-08-13T00:00:00.000Z',
      };

      final entity = EspecialistaEspecialidadModel.fromJson(json).toEntity();

      expect(entity.id, 1);
      expect(entity.especialistaId, 'esp-1');
      expect(entity.especialidadId, 10);
    });
  });
}
