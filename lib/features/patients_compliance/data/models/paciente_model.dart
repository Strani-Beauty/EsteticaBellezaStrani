import '../../domain/entities/paciente_entity.dart';

/// Modelo de la tabla `pacientes` (1:1 con `profiles` vía `usuario_id`).
class PacienteModel {
  final String id;
  final String profileId;
  final DateTime? fechaNacimiento;
  final String? genero;
  final String? grupoSanguineo;
  final String? alergias;
  final String? antecedentes;
  final bool activo;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const PacienteModel({
    required this.id,
    required this.profileId,
    this.fechaNacimiento,
    this.genero,
    this.grupoSanguineo,
    this.alergias,
    this.antecedentes,
    required this.activo,
    required this.createdAt,
    this.updatedAt,
  });

  factory PacienteModel.fromJson(Map<String, dynamic> json) => PacienteModel(
        id: (json['id'] as String?) ?? '',
        profileId: (json['usuario_id'] as String?) ?? '',
        fechaNacimiento: json['fecha_nacimiento'] != null
            ? DateTime.tryParse(json['fecha_nacimiento'].toString())
            : null,
        genero: json['genero'] as String?,
        grupoSanguineo: json['grupo_sanguineo'] as String?,
        alergias: json['alergias'] as String?,
        antecedentes: json['antecedentes'] as String?,
        activo: json['activo'] == true,
        createdAt: DateTime.tryParse((json['created_at'] as String?) ?? '') ??
            DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'].toString())
            : null,
      );

  Map<String, dynamic> toJson() => {
        if (fechaNacimiento != null)
          'fecha_nacimiento': fechaNacimiento!.toIso8601String().split('T').first,
        if (genero != null) 'genero': genero,
        if (grupoSanguineo != null) 'grupo_sanguineo': grupoSanguineo,
        if (alergias != null) 'alergias': alergias,
        if (antecedentes != null) 'antecedentes': antecedentes,
        if (activo) 'activo': activo,
        'updated_at': DateTime.now().toIso8601String(),
      };

  PacienteEntity toEntity() => PacienteEntity(
        id: id,
        profileId: profileId,
        fechaNacimiento: fechaNacimiento,
        genero: genero,
        grupoSanguineo: grupoSanguineo,
        alergias: alergias,
        antecedentes: antecedentes,
        activo: activo,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}