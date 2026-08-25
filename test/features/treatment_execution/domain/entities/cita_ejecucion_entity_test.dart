import 'package:flutter_test/flutter_test.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/entities/cita_ejecucion_entity.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/entities/tratamiento_entity.dart';

void main() {
  const cita = CitaEjecucionEntity(
    id: 'c-1',
    estado: EstadoCitaEjecucion.llego,
    solicitudId: 's-1',
    pacienteNombre: 'María Pérez',
    servicioNombre: 'Toxina Botulínica',
    precioBase: 150.5,
  );

  group('EstadoCitaEjecucion', () {
    test('mapea enum -> string BD', () {
      expect(EstadoCitaEjecucion.programada.toDb, 'PROGRAMADA');
      expect(EstadoCitaEjecucion.enCamino.toDb, 'EN_CAMINO');
      expect(EstadoCitaEjecucion.llego.toDb, 'LLEGO');
      expect(EstadoCitaEjecucion.enProceso.toDb, 'EN_PROCESO');
      expect(EstadoCitaEjecucion.finalizada.toDb, 'FINALIZADA');
      expect(EstadoCitaEjecucion.cancelada.toDb, 'CANCELADA');
      expect(EstadoCitaEjecucion.noCompletada.toDb, 'NO_COMPLETADA');
    });

    test('mapea string BD -> enum (case insensitive)', () {
      expect(EstadoCitaEjecucion.fromDb('LLEGO'), EstadoCitaEjecucion.llego);
      expect(EstadoCitaEjecucion.fromDb('en_proceso'),
          EstadoCitaEjecucion.enProceso);
      expect(EstadoCitaEjecucion.fromDb(null), isNull);
      expect(EstadoCitaEjecucion.fromDb('DESCONOCIDO'), isNull);
    });

    test('esPendienteDeEjecucion es true solo en estados en curso', () {
      expect(EstadoCitaEjecucion.programada.esPendienteDeEjecucion, isTrue);
      expect(EstadoCitaEjecucion.enCamino.esPendienteDeEjecucion, isTrue);
      expect(EstadoCitaEjecucion.llego.esPendienteDeEjecucion, isTrue);
      expect(EstadoCitaEjecucion.enProceso.esPendienteDeEjecucion, isTrue);
      expect(EstadoCitaEjecucion.finalizada.esPendienteDeEjecucion, isFalse);
      expect(EstadoCitaEjecucion.cancelada.esPendienteDeEjecucion, isFalse);
      expect(EstadoCitaEjecucion.noCompletada.esPendienteDeEjecucion, isFalse);
    });
  });

  group('CitaEjecucionEntity', () {
    test('usa valores por defecto para paciente/servicio', () {
      const sinDatos = CitaEjecucionEntity(
        id: 'c-2',
        estado: EstadoCitaEjecucion.programada,
      );
      expect(sinDatos.pacienteNombre, 'Paciente');
      expect(sinDatos.servicioNombre, 'Servicio');
      expect(sinDatos.precioBase, 0);
      expect(sinDatos.solicitudId, isNull);
    });

    test('copyWith reemplaza el tratamiento asociado', () {
      final trat = TratamientoEntity(
        id: 't-1',
        citaId: 'c-1',
        pacienteId: 'p-1',
        especialistaId: 'e-1',
        estado: EstadoTratamiento.pendienteFirma,
        createdAt: DateTime(2026, 8, 25),
      );

      final actualizada = cita.copyWith(tratamiento: trat);
      expect(actualizada.tratamiento, trat);
      expect(actualizada.id, 'c-1');
      expect(actualizada.pacienteNombre, 'María Pérez');
      expect(actualizada.estado, EstadoCitaEjecucion.llego);
    });

    test('copyWith conserva el tratamiento si no se pasa uno nuevo', () {
      final trat = TratamientoEntity(
        id: 't-1',
        citaId: 'c-1',
        pacienteId: 'p-1',
        especialistaId: 'e-1',
        estado: EstadoTratamiento.enProceso,
        createdAt: DateTime(2026, 8, 25),
      );
      final conTrat = cita.copyWith(tratamiento: trat);
      final sinCambio = conTrat.copyWith();
      expect(sinCambio.tratamiento, trat);
    });

    test('la igualdad de props incluye todos los campos relevantes', () {
      final copia = CitaEjecucionEntity(
        id: 'c-1',
        estado: EstadoCitaEjecucion.llego,
        solicitudId: 's-1',
        pacienteNombre: 'María Pérez',
        servicioNombre: 'Toxina Botulínica',
        precioBase: 150.5,
      );
      expect(cita, equals(copia));
      expect(cita.props.length, 16);
    });
  });
}