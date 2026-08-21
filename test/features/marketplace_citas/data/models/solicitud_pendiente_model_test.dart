import 'package:flutter_test/flutter_test.dart';
import 'package:esteticaybellezastrani/features/marketplace_citas/data/models/solicitud_pendiente_model.dart';

void main() {
  group('SolicitudPendienteModel (multi-servicio)', () {
    test('fromJson parsea servicios jsonb, precio total y fecha programada', () {
      final model = SolicitudPendienteModel.fromJson({
        'solicitud_id': 'sol-1',
        'paciente_nombre': 'Ana',
        'servicio_nombre': 'Toxina Botulínica, Mesoterapia',
        'precio': 180.0,
        'precio_total': 180.0,
        'latitud_aprox': 29.760,
        'longitud_aprox': -95.369,
        'ciudad': 'Houston',
        'radio_busqueda': 10,
        'fecha_programada': '2026-08-22T15:30:00.000Z',
        'fecha_expiracion': '2026-08-23T12:00:00.000Z',
        'estado': 'PUBLICADA',
        'servicios': [
          {
            'servicio_id': 'svc-1',
            'nombre': 'Toxina Botulínica',
            'cantidad': 2,
            'precio_unitario': 50.0,
          },
          {
            'servicio_id': 'svc-2',
            'nombre': 'Mesoterapia',
            'cantidad': 1,
            'precio_unitario': 80.0,
          },
        ],
      });

      expect(model.id, 'sol-1');
      expect(model.servicios.length, 2);
      expect(model.servicios.first.nombre, 'Toxina Botulínica');
      expect(model.servicios.first.subtotal, 100.0);
      expect(model.precioTotal, 180.0);
      expect(model.total, 180.0);
      expect(model.fechaProgramada, isNotNull);
      expect(model.radioBusqueda, 10);
      // RN-018: la dirección exacta nunca se expone.
      expect(model.direccion, isNull);
    });

    test('fromJson usa el servicio principal como fallback sin detalles', () {
      final model = SolicitudPendienteModel.fromJson({
        'solicitud_id': 'sol-2',
        'paciente_nombre': 'Luis',
        'servicio_nombre': 'Limpieza Facial',
        'precio': 45.0,
        'estado': 'BUSCANDO_ESPECIALISTA',
      });

      expect(model.servicios, isEmpty);
      expect(model.precioTotal, 45.0);
      expect(model.total, 45.0);
      expect(model.fechaProgramada, isNull);
    });

    test('toEntity conserva servicios y total', () {
      final model = SolicitudPendienteModel(
        id: 'sol-3',
        pacienteNombre: 'Ana',
        servicioNombre: 'Servicio',
        precio: 100,
        estado: 'PUBLICADA',
        servicios: const [],
        precioTotal: 100,
      );

      final entity = model.toEntity();
      expect(entity.id, 'sol-3');
      expect(entity.total, 100);
      expect(entity.expirada, isFalse);
    });
  });
}
