import 'package:flutter_test/flutter_test.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/entities/tratamiento_entity.dart';

void main() {
  final createdAt = DateTime(2026, 8, 25, 10);

  group('TratamientoEntity', () {
    test('expone citaId y especialistaId que lo vinculan a la cita', () {
      final trat = TratamientoEntity(
        id: 't-1',
        citaId: 'c-1',
        pacienteId: 'p-1',
        especialistaId: 'e-1',
        estado: EstadoTratamiento.pendienteFirma,
        createdAt: createdAt,
      );

      expect(trat.id, 't-1');
      expect(trat.citaId, 'c-1');
      expect(trat.pacienteId, 'p-1');
      expect(trat.especialistaId, 'e-1');
      expect(trat.estado, EstadoTratamiento.pendienteFirma);
    });

    test('isCompletado es true solo para completado', () {
      final completado = TratamientoEntity(
        id: 't-1',
        citaId: 'c-1',
        pacienteId: 'p-1',
        especialistaId: 'e-1',
        estado: EstadoTratamiento.completado,
        createdAt: createdAt,
      );
      expect(completado.isCompletado, isTrue);

      final enProceso = TratamientoEntity(
        id: 't-2',
        citaId: 'c-2',
        pacienteId: 'p-2',
        especialistaId: 'e-2',
        estado: EstadoTratamiento.enProceso,
        createdAt: createdAt,
      );
      expect(enProceso.isCompletado, isFalse);
    });

    test('copyWith actualiza estado y notas del especialista', () {
      final trat = TratamientoEntity(
        id: 't-1',
        citaId: 'c-1',
        pacienteId: 'p-1',
        especialistaId: 'e-1',
        estado: EstadoTratamiento.pendienteFirma,
        evaluacionInicial: 'Anamnesis inicial',
        createdAt: createdAt,
      );

      final actualizado = trat.copyWith(
        estado: EstadoTratamiento.enProceso,
        evaluacionInicial: 'Área a tratar: frente',
        observacionesFinales: 'Sin complicaciones',
        recomendacionesPostTratamiento: 'Evitar sol 24h',
        fechaFinalizacion: DateTime(2026, 8, 25, 12),
      );

      expect(actualizado.estado, EstadoTratamiento.enProceso);
      expect(actualizado.evaluacionInicial, 'Área a tratar: frente');
      expect(actualizado.observacionesFinales, 'Sin complicaciones');
      expect(actualizado.recomendacionesPostTratamiento, 'Evitar sol 24h');
      expect(actualizado.fechaFinalizacion, DateTime(2026, 8, 25, 12));
      expect(actualizado.id, 't-1');
    });

    test('copyWith conserva valores no pasados', () {
      final trat = TratamientoEntity(
        id: 't-1',
        citaId: 'c-1',
        pacienteId: 'p-1',
        especialistaId: 'e-1',
        estado: EstadoTratamiento.pendienteFirma,
        evaluacionInicial: 'Anamnesis',
        createdAt: createdAt,
      );

      final actualizado = trat.copyWith(estado: EstadoTratamiento.enProceso);
      expect(actualizado.evaluacionInicial, 'Anamnesis');
      expect(actualizado.fechaFinalizacion, isNull);
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

    test('mapea string BD -> enum', () {
      expect(EstadoTratamiento.fromDb('PENDIENTE_FIRMA'),
          EstadoTratamiento.pendienteFirma);
      expect(EstadoTratamiento.fromDb('COMPLETADO'),
          EstadoTratamiento.completado);
      expect(EstadoTratamiento.fromDb('desconocido'), isNull);
    });
  });
}