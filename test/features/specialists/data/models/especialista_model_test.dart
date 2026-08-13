import 'package:flutter_test/flutter_test.dart';
import 'package:esteticaybellezastrani/features/specialists/data/models/especialista_model.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/entities/especialista_entity.dart';

void main() {
  group('EspecialistaModel (mapeo BD → entidad)', () {
    final json = <String, dynamic>{
      'id': 'esp-1',
      'usuario_id': 'user-1',
      'medico_regente_id': 'med-9',
      'numero_licencia': 'LIC-123',
      'estado_verificacion': 'PENDIENTE',
      'fecha_solicitud_verificacion': '2026-08-13T10:00:00.000Z',
      'observacion': null,
      'disponible': false,
      'activo': false,
      'en_linea': true,
      'ultima_conexion': '2026-08-13T10:00:00.000Z',
      'created_at': '2026-08-13T00:00:00.000Z',
      'updated_at': '2026-08-13T01:00:00.000Z',
      'profiles': {'full_name': 'Dra. Ana', 'email': 'ana@example.com'},
    };

    test('mapea todas las columnas y el join a profiles', () {
      final entity = EspecialistaModel.fromJson(json).toEntity();

      expect(entity.id, 'esp-1');
      expect(entity.usuarioId, 'user-1');
      expect(entity.medicoRegenteId, 'med-9');
      expect(entity.numeroLicencia, 'LIC-123');
      expect(entity.estadoVerificacion, EstadoVerificacion.pendiente);
      expect(entity.disponible, isFalse);
      expect(entity.activo, isFalse);
      expect(entity.enLinea, isTrue);
      expect(entity.ultimaConexion, DateTime.parse('2026-08-13T10:00:00.000Z'));
      expect(entity.nombreUsuario, 'Dra. Ana');
      expect(entity.emailUsuario, 'ana@example.com');
    });

    test('sin profiles deja nombre/email nulos', () {
      final jsonSinProfile = Map<String, dynamic>.from(json)..remove('profiles');
      final entity = EspecialistaModel.fromJson(jsonSinProfile).toEntity();

      expect(entity.nombreUsuario, isNull);
      expect(entity.emailUsuario, isNull);
    });

    test('usa false por defecto si en_linea está ausente', () {
      final jsonSinLinea = Map<String, dynamic>.from(json)..remove('en_linea');
      final entity = EspecialistaModel.fromJson(jsonSinLinea).toEntity();

      expect(entity.enLinea, isFalse);
    });
  });
}
