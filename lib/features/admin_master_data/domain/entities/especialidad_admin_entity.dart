import 'package:equatable/equatable.dart';

/// Especialidad del catálogo (`especialidades`) para gestión admin.
class EspecialidadAdminEntity extends Equatable {
  final int id;
  final String nombre;
  final String? descripcion;
  final bool activo;

  const EspecialidadAdminEntity({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.activo = true,
  });

  @override
  List<Object?> get props => [id, nombre, activo];
}
