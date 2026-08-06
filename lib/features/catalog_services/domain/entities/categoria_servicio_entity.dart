import 'package:equatable/equatable.dart';

/// Entidad de dominio: `categorias_servicio`.
/// Categoría parametrizable del catálogo de servicios.
class CategoriaServicioEntity extends Equatable {
  final int id;
  final String nombre;
  final String? descripcion;
  final bool activo;

  const CategoriaServicioEntity({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.activo,
  });

  @override
  List<Object?> get props => [id, nombre, descripcion, activo];
}
