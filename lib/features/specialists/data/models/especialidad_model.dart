import '../../domain/entities/especialidad_entity.dart';

class EspecialidadModel {
  final int id;
  final String nombre;
  final String? descripcion;
  final bool activo;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const EspecialidadModel({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.activo,
    required this.createdAt,
    this.updatedAt,
  });

  factory EspecialidadModel.fromJson(Map<String, dynamic> json) {
    return EspecialidadModel(
      id: (json['id'] as num).toInt(),
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String?,
      activo: json['activo'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'activo': activo,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  EspecialidadEntity toEntity() {
    return EspecialidadEntity(
      id: id,
      nombre: nombre,
      descripcion: descripcion,
      activo: activo,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

class EspecialistaEspecialidadModel {
  final int id;
  final String especialistaId;
  final int especialidadId;
  final DateTime createdAt;

  const EspecialistaEspecialidadModel({
    required this.id,
    required this.especialistaId,
    required this.especialidadId,
    required this.createdAt,
  });

  factory EspecialistaEspecialidadModel.fromJson(Map<String, dynamic> json) {
    return EspecialistaEspecialidadModel(
      id: (json['id'] as num).toInt(),
      especialistaId: json['especialista_id'] as String,
      especialidadId: (json['especialidad_id'] as num).toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'especialista_id': especialistaId,
      'especialidad_id': especialidadId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  EspecialistaEspecialidadEntity toEntity() {
    return EspecialistaEspecialidadEntity(
      id: id,
      especialistaId: especialistaId,
      especialidadId: especialidadId,
      createdAt: createdAt,
    );
  }
}