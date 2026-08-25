import 'package:flutter_test/flutter_test.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/data/models/cita_ejecucion_model.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/data/models/tratamiento_model.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/entities/cita_ejecucion_entity.dart';

void main() {
  final jsonCompleto = {
    'id': 'c-1',
    'estado': 'LLEGO',
    'fecha_aceptacion': '2026-08-25T09:00:00.000Z',
    'fecha_inicio': '2026-08-25T10:00:00.000Z',
    'fecha_finalizacion': '2026-08-25T12:00:00.000Z',
    'solicitudes': {
      'id': 's-1',
      'servicios': {
        'nombre': 'Toxina Botulínica',
        'precio_base': 150.5,
        'tipo_precio': 'POR_UNIDAD',
      },
      'pacientes': {
        'profiles': {
          'full_name': 'María Pérez',
          'phone': '555-1234',
        },
      },
      'direcciones_paciente': {
        'direccion': 'Av. Siempre Viva 123',
        'ciudad': 'Lima',
        'latitud': -12.0464,
        'longitud': -77.0428,
      },
    },
    'tratamientos': {
      'id': 't-1',
      'cita_id': 'c-1',
      'paciente_id': 'p-1',
      'especialista_id': 'e-1',
      'estado': 'PENDIENTE_FIRMA',
    },
  };

  group('CitaEjecucionModel', () {
    test('fromJson parsea todos los campos con joins embebidos', () {
      final model = CitaEjecucionModel.fromJson(jsonCompleto);

      expect(model.id, 'c-1');
      expect(model.estado, 'LLEGO');
      expect(model.solicitudId, 's-1');
      expect(model.pacienteNombre, 'María Pérez');
      expect(model.pacienteTelefono, '555-1234');
      expect(model.servicioNombre, 'Toxina Botulínica');
      expect(model.precioBase, 150.5);
      expect(model.tipoPrecio, 'POR_UNIDAD');
      expect(model.direccion, 'Av. Siempre Viva 123');
      expect(model.ciudad, 'Lima');
      expect(model.latitud, -12.0464);
      expect(model.longitud, -77.0428);
      expect(model.tratamiento, isA<TratamientoModel>());
      expect(model.tratamiento!.id, 't-1');
      expect(model.tratamiento!.estado, 'PENDIENTE_FIRMA');
    });

    test('fromJson acepta tratamientos como lista y toma el primero', () {
      final json = Map<String, dynamic>.from(jsonCompleto);
      json['tratamientos'] = [
        {'id': 't-1', 'estado': 'EN_PROCESO'},
        {'id': 't-2', 'estado': 'COMPLETADO'},
      ];

      final model = CitaEjecucionModel.fromJson(json);
      expect(model.tratamiento!.id, 't-1');
      expect(model.tratamiento!.estado, 'EN_PROCESO');
    });

    test('fromJson usa valores por defecto cuando faltan joins', () {
      final model = CitaEjecucionModel.fromJson({'id': 'c-2', 'estado': 'EN_PROCESO'});
      expect(model.solicitudId, isNull);
      expect(model.pacienteNombre, 'Paciente');
      expect(model.servicioNombre, 'Servicio');
      expect(model.precioBase, 0);
      expect(model.direccion, isNull);
      expect(model.tratamiento, isNull);
    });

    test('toEntity mapea estado, datos de la cita y su tratamiento', () {
      final model = CitaEjecucionModel.fromJson(jsonCompleto);
      final entity = model.toEntity();

      expect(entity, isA<CitaEjecucionEntity>());
      expect(entity.id, 'c-1');
      expect(entity.estado, EstadoCitaEjecucion.llego);
      expect(entity.solicitudId, 's-1');
      expect(entity.pacienteNombre, 'María Pérez');
      expect(entity.servicioNombre, 'Toxina Botulínica');
      expect(entity.precioBase, 150.5);
      expect(entity.tratamiento, isNotNull);
      expect(entity.tratamiento!.citaId, 'c-1');
    });

    test('toEntity usa programada para estado desconocido', () {
      final model = CitaEjecucionModel.fromJson({
        'id': 'c-3',
        'estado': 'DESCONOCIDO',
      });
      expect(model.toEntity().estado, EstadoCitaEjecucion.programada);
    });
  });
}