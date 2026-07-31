import 'package:equatable/equatable.dart';

/// Disponibilidad tipo Uber para especialistas.
enum EstadoDisponibilidad { disponible, noDisponible, ocupado }

class DisponibilidadEntity extends Equatable {
  final String id;              // UUID
  final String especialistaId; // FK especialistas.id
  final EstadoDisponibilidad estado;
  final DateTime? inicioDisponibilidad;
  final DateTime? finDisponibilidad;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const DisponibilidadEntity({
    required this.id,
    required this.especialistaId,
    required this.estado,
    this.inicioDisponibilidad,
    this.finDisponibilidad,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isAvailable => estado == EstadoDisponibilidad.disponible;

  @override
  List<Object?> get props => [id, especialistaId, estado];
}
