import 'package:flutter_test/flutter_test.dart';
import 'package:esteticaybellezastrani/features/solicitudes_reserva/data/models/seguimiento_solicitud_model.dart';

void main() {
  group('SeguimientoSolicitudModel', () {
    test('fromJson parsea servicios, pago, cita y dirección', () {
      final model = SeguimientoSolicitudModel.fromJson({
        'id': 'sol-1',
        'estado': 'PUBLICADA',
        'fecha_solicitud': '2026-08-21T12:00:00.000Z',
        'fecha_programada': '2026-08-22T15:30:00.000Z',
        'fecha_expiracion': '2026-08-23T12:00:00.000Z',
        'observaciones_paciente': 'Por favor temprano',
        'solicitud_detalles': [
          {
            'id': 'det-1',
            'servicio_id': 'svc-1',
            'cantidad': 2,
            'precio_unitario': 50.0,
            'servicios': {'nombre': 'Toxina Botulínica'},
          },
          {
            'id': 'det-2',
            'servicio_id': 'svc-2',
            'cantidad': 1,
            'precio_unitario': 80.0,
            'servicios': {'nombre': 'Mesoterapia'},
          },
        ],
        'pagos': {
          'monto_total': 180.0,
          'deposito': 90.0,
          'saldo_pendiente': 90.0,
          'estado': 'PARCIAL',
        },
        'citas': [
          {
            'estado': 'PROGRAMADA',
            'fecha_aceptacion': '2026-08-21T18:00:00.000Z',
          },
        ],
        'direcciones_paciente': {'ciudad': 'Houston'},
      });

      expect(model.id, 'sol-1');
      expect(model.estado, 'PUBLICADA');
      expect(model.fechaProgramada, isNotNull);
      expect(model.fechaExpiracion, isNotNull);
      expect(model.observaciones, 'Por favor temprano');
      expect(model.servicios.length, 2);
      expect(model.servicios.first.nombre, 'Toxina Botulínica');
      expect(model.servicios.first.cantidad, 2);
      expect(model.servicios.first.subtotal, 100.0);
      expect(model.montoTotal, 180.0);
      expect(model.deposito, 90.0);
      expect(model.saldoPendiente, 90.0);
      expect(model.ciudad, 'Houston');
      expect(model.citaEstado, 'PROGRAMADA');
      expect(model.citaFechaAceptacion, isNotNull);
    });

    test('fromJson usa defaults cuando faltan joins', () {
      final model = SeguimientoSolicitudModel.fromJson({
        'id': 'sol-2',
        'estado': 'PENDIENTE_PAGO',
        'fecha_solicitud': '2026-08-21T12:00:00.000Z',
      });

      expect(model.servicios, isEmpty);
      expect(model.montoTotal, 0);
      expect(model.citaEstado, isNull);
      expect(model.ciudad, isNull);
    });

    test('toEntity conserva los valores', () {
      final model = SeguimientoSolicitudModel(
        id: 'sol-3',
        estado: 'ACEPTADA',
        fechaSolicitud: DateTime.utc(2026, 8, 21),
        montoTotal: 100,
        deposito: 50,
        saldoPendiente: 50,
      );

      final entity = model.toEntity();
      expect(entity.id, 'sol-3');
      expect(entity.estado, 'ACEPTADA');
      expect(entity.estaAceptada, isTrue);
      expect(entity.saldoPendiente, 50);
    });
  });
}
