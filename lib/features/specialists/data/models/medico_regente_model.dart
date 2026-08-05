import '../../domain/entities/medico_regente_entity.dart';

class MedicoRegenteModel {
  final String id;
  final String nombre;
  final String? numeroLicencia;
  final String estado;
  final String? telefono;
  final String? correo;
  final bool activo;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const MedicoRegenteModel({
    required this.id,
    required this.nombre,
    this.numeroLicencia,
    required this.estado,
    this.telefono,
    this.correo,
    required this.activo,
    required this.createdAt,
    this.updatedAt,
  });

  factory MedicoRegenteModel.fromJson(Map<String, dynamic> json) {
    return MedicoRegenteModel(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      numeroLicencia: json['numero_licencia'] as String?,
      estado: json['estado'] as String? ?? 'ACTIVO',
      telefono: json['telefono'] as String?,
      correo: json['correo'] as String?,
      activo: json['activo'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'numero_licencia': numeroLicencia,
      'estado': estado,
      'telefono': telefono,
      'correo': correo,
      'activo': activo,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  MedicoRegenteEntity toEntity() {
    return MedicoRegenteEntity(
      id: id,
      nombre: nombre,
      numeroLicencia: numeroLicencia,
      estado: estado,
      telefono: telefono,
      correo: correo,
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