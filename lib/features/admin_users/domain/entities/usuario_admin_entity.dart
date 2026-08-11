/// Entidad de dominio: usuario del sistema (`profiles`) visto por el admin.
class UsuarioAdminEntity {
  final String id;
  final String email;
  final String? fullName;
  final String? phone;
  final String role;
  final bool activo;
  final DateTime? createdAt;

  const UsuarioAdminEntity({
    required this.id,
    required this.email,
    this.fullName,
    this.phone,
    required this.role,
    required this.activo,
    this.createdAt,
  });
}