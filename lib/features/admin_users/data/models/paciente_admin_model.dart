import 'package:esteticaybellezastrani/features/admin_users/domain/entities/paciente_admin_entity.dart';

/// Modelo de datos: fila de `pacientes` + perfil embebido (`profiles`).
class PacienteAdminModel {
  final String id;
  final String usuarioId;
  final bool activo;
  final String? fullName;
  final String? email;
  final String? phone;
  final bool profileActivo;

  const PacienteAdminModel({
    required this.id,
    required this.usuarioId,
    required this.activo,
    this.fullName,
    this.email,
    this.phone,
    required this.profileActivo,
  });

  factory PacienteAdminModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? profile;
    final profiles = json['profiles'];
    if (profiles is Map) {
      profile = Map<String, dynamic>.from(profiles);
    } else if (profiles is List && profiles.isNotEmpty) {
      profile = Map<String, dynamic>.from(profiles.first as Map);
    }

    return PacienteAdminModel(
      id: json['id']?.toString() ?? '',
      usuarioId: json['usuario_id']?.toString() ?? '',
      activo: json['activo'] == true,
      fullName: profile?['full_name'] as String?,
      email: profile?['email'] as String?,
      phone: profile?['phone'] as String?,
      profileActivo: profile?['activo'] == true,
    );
  }

  PacienteAdminEntity toEntity() => PacienteAdminEntity(
        id: id,
        usuarioId: usuarioId,
        activo: activo,
        fullName: fullName,
        email: email,
        phone: phone,
        profileActivo: profileActivo,
      );
}