import 'package:equatable/equatable.dart';

/// Entidad de dominio: `especialidades`.
class EspecialidadEntity extends Equatable {
  final int id;                 // bigint PK (identity)
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
  final int id;                 // bigint PK (identity)
  final String especialistaId;  // FK especialistas.id
  final int especialidadId;     // FK especialidades.id (bigint)
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