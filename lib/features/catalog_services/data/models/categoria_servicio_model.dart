import '../../domain/entities/categoria_servicio_entity.dart';

class CategoriaServicioModel {
  final int id;
  final String nombre;
  final String? descripcion;
  final bool activo;

  const CategoriaServicioModel({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.activo,
  });

  factory CategoriaServicioModel.fromJson(Map<String, dynamic> json) {
    return CategoriaServicioModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String?,
      activo: json['activo'] as bool? ?? true,
    );
  }

  CategoriaServicioEntity toEntity() {
    return CategoriaServicioEntity(
      id: id,
      nombre: nombre,
      descripcion: descripcion,
      activo: activo,
    );
  }
}
