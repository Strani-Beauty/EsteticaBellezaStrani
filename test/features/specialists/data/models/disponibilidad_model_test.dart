import 'package:flutter_test/flutter_test.dart';
import 'package:esteticaybellezastrani/features/specialists/data/models/disponibilidad_model.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/entities/disponibilidad_entity.dart';

void main() {
  group('DisponibilidadModel (mapeo BD → entidad)', () {
    test('mapea estado y fechas', () {
      final json = <String, dynamic>{
        'id': 'disp-1',
        'especialista_id': 'esp-1',
        'estado': 'DISPONIBLE',
        'fecha_inicio': '2026-08-13T09:00:00.000Z',
        'fecha_fin': null,
        'created_at': '2026-08-13T00:00:00.000Z',
      };

      final entity = DisponibilidadModel.fromJson(json).toEntity();

      expect(entity.id, 'disp-1');
      expect(entity.especialistaId, 'esp-1');
      expect(entity.estado, EstadoDisponibilidad.disponible);
      expect(entity.isAvailable, isTrue);
      expect(entity.fechaInicio, DateTime.parse('2026-08-13T09:00:00.000Z'));
      expect(entity.fechaFin, isNull);
    });

    test('estado desconocido/ausente → noDisponible', () {
      final json = <String, dynamic>{
        'id': 'disp-1',
        'especialista_id': 'esp-1',
        'estado': 'ALGO',
        'created_at': '2026-08-13T00:00:00.000Z',
      };

      final entity = DisponibilidadModel.fromJson(json).toEntity();

      expect(entity.estado, EstadoDisponibilidad.noDisponible);
      expect(entity.isAvailable, isFalse);
    });
  });
}
