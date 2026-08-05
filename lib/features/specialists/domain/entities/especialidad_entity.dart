import 'package:equatable/equatable.dart';

/// Entidad de dominio: `especialidades`.
class EspecialidadEntity extends Equatable {
  final String id;              // uuid PK
  final String nombre;
  final String? descripcion;
  final bool activo;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const EspecialidadEntity({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.activo,
    required this.createdAt,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [id, nombre, activo];
}

/// Entidad de dominio: `especialista_especialidades` (relación M:N).
class EspecialistaEspecialidadEntity extends Equatable {
  final String id;               // uuid PK
  final String especialistaId;   // FK especialistas.id
  final String especialidadId;   // FK especialidades.id
  final DateTime createdAt;

  const EspecialistaEspecialidadEntity({
    required this.id,
    required this.especialistaId,
    required this.especialidadId,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, especialistaId, especialidadId];
}