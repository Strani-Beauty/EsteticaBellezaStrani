import 'package:flutter_test/flutter_test.dart';
import 'package:esteticaybellezastrani/features/specialists/data/models/medico_regente_model.dart';

void main() {
  group('MedicoRegenteModel (mapeo BD → entidad)', () {
    test('mapea columnas y usa ACTIVO por defecto', () {
      final json = <String, dynamic>{
        'id': 'med-1',
        'nombre': 'Dr. Pérez',
        'numero_licencia': 'MED-123',
        'estado': 'PENDIENTE',
        'telefono': '555-1234',
        'correo': 'dr@example.com',
        'activo': false,
        'created_at': '2026-08-13T00:00:00.000Z',
      };

      final entity = MedicoRegenteModel.fromJson(json).toEntity();

      expect(entity.id, 'med-1');
      expect(entity.nombre, 'Dr. Pérez');
      expect(entity.numeroLicencia, 'MED-123');
      expect(entity.estado, 'PENDIENTE');
      expect(entity.activo, isFalse);
      expect(entity.telefono, '555-1234');
      expect(entity.correo, 'dr@example.com');
    });

    test('estado ausente → ACTIVO', () {
      final json = <String, dynamic>{
        'id': 'med-1',
        'nombre': 'Dr. Pérez',
        'activo': true,
        'created_at': '2026-08-13T00:00:00.000Z',
      };

      final entity = MedicoRegenteModel.fromJson(json).toEntity();

      expect(entity.estado, 'ACTIVO');
    });
  });
}
