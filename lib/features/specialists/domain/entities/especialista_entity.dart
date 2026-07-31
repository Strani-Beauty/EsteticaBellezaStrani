import 'package:equatable/equatable.dart';

enum EstadoVerificacion { pendiente, enRevision, aprobado, rechazado, bloqueado }

class EspecialistaEntity extends Equatable {
  final String id;                    // UUID
  final String profileId;             // FK profiles.id
  final String? medicoRegenteId;      // FK medicos_regentes.id (DA-002)
  final String? nombreComercial;
  final String? rif;
  final String? licenciaMedica;
  final EstadoVerificacion estadoVerificacion;
  final double comisionPorcentaje;    // % comisión plataforma
  final bool activo;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const EspecialistaEntity({
    required this.id,
    required this.profileId,
    this.medicoRegenteId,
    this.nombreComercial,
    this.rif,
    this.licenciaMedica,
    required this.estadoVerificacion,
    required this.comisionPorcentaje,
    required this.activo,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isApproved => estadoVerificacion == EstadoVerificacion.aprobado;

  @override
  List<Object?> get props => [id, profileId, estadoVerificacion, activo];
}
