/// Entidad de dominio: paciente (`pacientes`) visto por el admin.
class PacienteAdminEntity {
  final String id;
  final String usuarioId;
  final bool activo;
  final String? fullName;
  final String? email;
  final String? phone;
  final bool profileActivo;

  const PacienteAdminEntity({
    required this.id,
    required this.usuarioId,
    required this.activo,
    this.fullName,
    this.email,
    this.phone,
    required this.profileActivo,
  });

  /// Nombre a mostrar (fallback al email).
  String get nombre => (fullName == null || fullName!.isEmpty)
      ? (email ?? 'Paciente')
      : fullName!;
}