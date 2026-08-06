import 'package:equatable/equatable.dart';

/// Estado del tratamiento (columna `estado` de `tratamientos`, enum DB
/// `estado_tratamiento_enum`).
enum EstadoTratamiento {
  iniciado,
  enProceso,
  pendienteFirma,
  completado,
  cancelado;

  static const Map<EstadoTratamiento, String> _db = {
    EstadoTratamiento.iniciado: 'INICIADO',
    EstadoTratamiento.enProceso: 'EN_PROCESO',
    EstadoTratamiento.pendienteFirma: 'PENDIENTE_FIRMA',
    EstadoTratamiento.completado: 'COMPLETADO',
    EstadoTratamiento.cancelado: 'CANCELADO',
  };

  String get toDb => _db[this]!;

  static EstadoTratamiento? fromDb(String? value) {
    for (final entry in _db.entries) {
      if (entry.value == value?.toUpperCase()) return entry.key;
    }
    return null;
  }
}

/// Entidad de dominio: `tratamientos`.
/// Se vincula a la `cita` (cita_id) y al especialista que lo ejecuta.
class TratamientoEntity extends Equatable {
  final String id;
  final String citaId;
  final String pacienteId;
  final String especialistaId;
  final EstadoTratamiento estado;
  final DateTime? fechaInicio;
  final DateTime? fechaFinalizacion;
  final String? evaluacionInicial;
  final String? observacionesFinales;
  final String? recomendacionesPostTratamiento;
  final DateTime createdAt;

  const TratamientoEntity({
    required this.id,
    required this.citaId,
    required this.pacienteId,
    required this.especialistaId,
    required this.estado,
    this.fechaInicio,
    this.fechaFinalizacion,
    this.evaluacionInicial,
    this.observacionesFinales,
    this.recomendacionesPostTratamiento,
    required this.createdAt,
  });

  bool get isCompletado => estado == EstadoTratamiento.completado;

  TratamientoEntity copyWith({
    EstadoTratamiento? estado,
    DateTime? fechaFinalizacion,
    String? evaluacionInicial,
    String? observacionesFinales,
    String? recomendacionesPostTratamiento,
  }) {
    return TratamientoEntity(
      id: id,
      citaId: citaId,
      pacienteId: pacienteId,
      especialistaId: especialistaId,
      estado: estado ?? this.estado,
      fechaInicio: fechaInicio,
      fechaFinalizacion: fechaFinalizacion ?? this.fechaFinalizacion,
      evaluacionInicial: evaluacionInicial ?? this.evaluacionInicial,
      observacionesFinales:
          observacionesFinales ?? this.observacionesFinales,
      recomendacionesPostTratamiento:
          recomendacionesPostTratamiento ?? this.recomendacionesPostTratamiento,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        citaId,
        pacienteId,
        especialistaId,
        estado,
        fechaInicio,
        fechaFinalizacion,
        evaluacionInicial,
        observacionesFinales,
        recomendacionesPostTratamiento,
        createdAt,
      ];
}
