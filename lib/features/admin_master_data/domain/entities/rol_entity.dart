import 'package:equatable/equatable.dart';

/// Permiso del catálogo RBAC (`permisos`).
class PermisoEntity extends Equatable {
  final int id;
  final String codigo;
  final String nombre;
  final String? modulo;
  final String? descripcion;

  const PermisoEntity({
    required this.id,
    required this.codigo,
    required this.nombre,
    this.modulo,
    this.descripcion,
  });

  @override
  List<Object?> get props => [id, codigo, nombre, modulo];
}

/// Rol del catálogo RBAC (`roles`) con sus permisos asignados.
class RolEntity extends Equatable {
  final int id;
  final String nombre;
  final String? descripcion;
  final String? codigo;
  final bool activo;
  final List<PermisoEntity> permisos;

  const RolEntity({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.codigo,
    this.activo = true,
    this.permisos = const [],
  });

  @override
  List<Object?> get props => [id, nombre, codigo, activo];
}
