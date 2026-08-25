import 'package:flutter_test/flutter_test.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/data/models/tratamiento_model.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/entities/tratamiento_entity.dart';

void main() {
  group('TratamientoModel', () {
    test('fromJson parsea todos los campos', () {
      final model = TratamientoModel.fromJson({
        'id': 't-1',
        'cita_id': 'c-1',
        'paciente_id': 'p-1',
        'especialista_id': 'e-1',
        'estado': 'PENDIENTE_FIRMA',
        'fecha_inicio': '2026-08-25T10:00:00.000Z',
        'fecha_finalizacion': '2026-08-25T12:00:00.000Z',
        'evaluacion_inicial': 'Área a tratar: frente',
        'observaciones_finales': 'Sin complicaciones',
        'recomendaciones_post_tratam': 'Evitar sol 24h',
        'created_at': '2026-08-25T10:00:00.000Z',
      });

      expect(model.id, 't-1');
      expect(model.citaId, 'c-1');
      expect(model.pacienteId, 'p-1');
      expect(model.especialistaId, 'e-1');
      expect(model.estado, 'PENDIENTE_FIRMA');
      expect(model.evaluacionInicial, 'Área a tratar: frente');
      expect(model.observacionesFinales, 'Sin complicaciones');
      expect(model.recomendacionesPostTratamiento, 'Evitar sol 24h');
    });

    test('fromJson usa valores por defecto cuando faltan campos', () {
      final model = TratamientoModel.fromJson({'id': 't-2'});
      expect(model.citaId, '');
      expect(model.pacienteId, '');
      expect(model.estado, 'INICIADO');
      expect(model.evaluacionInicial, isNull);
      expect(model.fechaInicio, isNull);
    });

    test('fromJson lee recomendaciones desde recomendaciones_post_tratam', () {
      final model = TratamientoModel.fromJson({
        'id': 't-3',
        'recomendaciones_post_tratam': 'Hidratar la zona',
      });
      expect(model.recomendacionesPostTratamiento, 'Hidratar la zona');
    });

    test('toEntity mapea estado y convierte fechas', () {
      final model = TratamientoModel(
        id: 't-1',
        citaId: 'c-1',
        pacienteId: 'p-1',
        especialistaId: 'e-1',
        estado: 'EN_PROCESO',
        fechaInicio: '2026-08-25T10:00:00.000Z',
        evaluacionInicial: 'Frente',
        createdAt: '2026-08-25T10:00:00.000Z',
      );

      final entity = model.toEntity();
      expect(entity, isA<TratamientoEntity>());
      expect(entity.id, 't-1');
      expect(entity.citaId, 'c-1');
      expect(entity.estado, EstadoTratamiento.enProceso);
      expect(entity.evaluacionInicial, 'Frente');
      expect(entity.fechaInicio,
          DateTime.parse('2026-08-25T10:00:00.000Z'));
    });

    test('toEntity usa EstadoTratamiento.iniciado para estado desconocido', () {
      final model = TratamientoModel(
        id: 't-4',
        citaId: 'c-4',
        pacienteId: 'p-4',
        especialistaId: 'e-4',
        estado: 'DESCONOCIDO',
        createdAt: '2026-08-25T10:00:00.000Z',
      );
      expect(model.toEntity().estado, EstadoTratamiento.iniciado);
    });
  });

  group('EstadoTratamiento', () {
    test('mapea enum -> string BD', () {
      expect(EstadoTratamiento.iniciado.toDb, 'INICIADO');
      expect(EstadoTratamiento.enProceso.toDb, 'EN_PROCESO');
      expect(EstadoTratamiento.pendienteFirma.toDb, 'PENDIENTE_FIRMA');
      expect(EstadoTratamiento.completado.toDb, 'COMPLETADO');
      expect(EstadoTratamiento.cancelado.toDb, 'CANCELADO');
    });

    test('mapea string BD -> enum (case insensitive)', () {
      expect(EstadoTratamiento.fromDb('PENDIENTE_FIRMA'),
          EstadoTratamiento.pendienteFirma);
      expect(EstadoTratamiento.fromDb('en_proceso'), EstadoTratamiento.enProceso);
      expect(EstadoTratamiento.fromDb(null), isNull);
      expect(EstadoTratamiento.fromDb('DESCONOCIDO'), isNull);
    });
  });
}