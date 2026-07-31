import 'package:equatable/equatable.dart';

class EspecialidadEntity extends Equatable {
  final String id;       // UUID
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

/// Relación M:N especialista-especialidad
class EspecialistaEspecialidadEntity extends Equatable {
  final String especialistaId;
  final String especialidadId;
  final bool principal;   // ¿Es la especialidad principal?
  final DateTime createdAt;

  const EspecialistaEspecialidadEntity({
    required this.especialistaId,
    required this.especialidadId,
    required this.principal,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [especialistaId, especialidadId];
}
