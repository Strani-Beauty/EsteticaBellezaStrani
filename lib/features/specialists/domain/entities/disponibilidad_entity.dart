import 'package:equatable/equatable.dart';

/// Estado de disponibilidad (columna `estado` de `disponibilidad_especialista`).
enum EstadoDisponibilidad {
  disponible,
  noDisponible,
  ocupado;

  static const Map<EstadoDisponibilidad, String> _db = {
    EstadoDisponibilidad.disponible: 'DISPONIBLE',
    EstadoDisponibilidad.noDisponible: 'NO_DISPONIBLE',
    EstadoDisponibilidad.ocupado: 'OCUPADO',
  };

  String get toDb => _db[this]!;

  static EstadoDisponibilidad? fromDb(String? value) {
    for (final entry in _db.entries) {
      if (entry.value == value?.toUpperCase()) return entry.key;
    }
    return null;
  }
}

/// Entidad de dominio: `disponibilidad_especialista`.
class DisponibilidadEntity extends Equatable {
  final String id;               // uuid PK
  final String especialistaId;   // FK especialistas.id
  final EstadoDisponibilidad estado;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final DateTime createdAt;

  const DisponibilidadEntity({
    required this.id,
    required this.especialistaId,
    required this.estado,
    this.fechaInicio,
    this.fechaFin,
    required this.createdAt,
  });

  bool get isAvailable => estado == EstadoDisponibilidad.disponible;

  DisponibilidadEntity copyWith({
    EstadoDisponibilidad? estado,
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) {
    return DisponibilidadEntity(
      id: id,
      especialistaId: especialistaId,
      estado: estado ?? this.estado,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaFin: fechaFin ?? this.fechaFin,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [id, especialistaId, estado];
}