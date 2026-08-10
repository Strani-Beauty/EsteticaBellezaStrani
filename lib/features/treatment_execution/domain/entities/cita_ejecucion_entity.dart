import 'package:equatable/equatable.dart';
import 'tratamiento_entity.dart';

/// Estado de la cita en el ciclo de ejecución (columna `estado` de `citas`,
/// enum DB `estado_cita_enum`).
enum EstadoCitaEjecucion {
  programada,
  enCamino,
  llego,
  enProceso,
  finalizada,
  cancelada,
  noCompletada;

  static const Map<EstadoCitaEjecucion, String> _db = {
    EstadoCitaEjecucion.programada: 'PROGRAMADA',
    EstadoCitaEjecucion.enCamino: 'EN_CAMINO',
    EstadoCitaEjecucion.llego: 'LLEGO',
    EstadoCitaEjecucion.enProceso: 'EN_PROCESO',
    EstadoCitaEjecucion.finalizada: 'FINALIZADA',
    EstadoCitaEjecucion.cancelada: 'CANCELADA',
    EstadoCitaEjecucion.noCompletada: 'NO_COMPLETADA',
  };

  String get toDb => _db[this]!;

  static EstadoCitaEjecucion? fromDb(String? value) {
    for (final entry in _db.entries) {
      if (entry.value == value?.toUpperCase()) return entry.key;
    }
    return null;
  }

  /// Citas visibles para el especialista en "Mis citas" (no terminadas).
  bool get esPendienteDeEjecucion =>
      this == programada ||
      this == enCamino ||
      this == llego ||
      this == enProceso;
}

/// Entidad de dominio compuesta: una cita asignada al especialista con los
/// datos del paciente y del servicio (joins con solicitudes/pacientes/profiles).
class CitaEjecucionEntity extends Equatable {
  final String id;
  final EstadoCitaEjecucion estado;
  final DateTime? fechaAceptacion;
  final DateTime? fechaInicio;
  final DateTime? fechaFinalizacion;

  /// Solicitud origen de la cita (para consultar el saldo pendiente).
  final String? solicitudId;

  final String pacienteNombre;
  final String? pacienteTelefono;
  final String servicioNombre;
  final double precioBase;
  final String? direccion;
  final String? ciudad;
  final double? latitud;
  final double? longitud;

  /// Tratamiento asociado (puede no existir aún).
  final TratamientoEntity? tratamiento;

  const CitaEjecucionEntity({
    required this.id,
    required this.estado,
    this.fechaAceptacion,
    this.fechaInicio,
    this.fechaFinalizacion,
    this.solicitudId,
    this.pacienteNombre = 'Paciente',
    this.pacienteTelefono,
    this.servicioNombre = 'Servicio',
    this.precioBase = 0,
    this.direccion,
    this.ciudad,
    this.latitud,
    this.longitud,
    this.tratamiento,
  });

  CitaEjecucionEntity copyWith({TratamientoEntity? tratamiento}) {
    return CitaEjecucionEntity(
      id: id,
      estado: estado,
      fechaAceptacion: fechaAceptacion,
      fechaInicio: fechaInicio,
      fechaFinalizacion: fechaFinalizacion,
      solicitudId: solicitudId,
      pacienteNombre: pacienteNombre,
      pacienteTelefono: pacienteTelefono,
      servicioNombre: servicioNombre,
      precioBase: precioBase,
      direccion: direccion,
      ciudad: ciudad,
      latitud: latitud,
      longitud: longitud,
      tratamiento: tratamiento ?? this.tratamiento,
    );
  }

  @override
  List<Object?> get props => [
        id,
        estado,
        fechaAceptacion,
        fechaInicio,
        fechaFinalizacion,
        solicitudId,
        pacienteNombre,
        pacienteTelefono,
        servicioNombre,
        precioBase,
        direccion,
        ciudad,
        latitud,
        longitud,
        tratamiento,
      ];
}
