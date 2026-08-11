import 'package:esteticaybellezastrani/features/admin_users/domain/entities/usuario_admin_entity.dart';

/// Modelo de datos: fila de `profiles` (textarea para el panel admin).
class UsuarioAdminModel {
  final String id;
  final String email;
  final String? fullName;
  final String? phone;
  final String role;
  final bool activo;
  final DateTime? createdAt;

  const UsuarioAdminModel({
    required this.id,
    required this.email,
    this.fullName,
    this.phone,
    required this.role,
    required this.activo,
    this.createdAt,
  });

  factory UsuarioAdminModel.fromJson(Map<String, dynamic> json) {
    return UsuarioAdminModel(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String?,
      phone: json['phone'] as String?,
      role: json['role'] as String? ?? '',
      activo: json['activo'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  UsuarioAdminEntity toEntity() => UsuarioAdminEntity(
        id: id,
        email: email,
        fullName: fullName,
        phone: phone,
        role: role,
        activo: activo,
        createdAt: createdAt,
      );
}