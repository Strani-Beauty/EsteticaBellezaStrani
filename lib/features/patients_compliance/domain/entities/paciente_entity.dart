import 'package:equatable/equatable.dart';

class PacienteEntity extends Equatable {
  final String id; // UUID de `pacientes`
  final String profileId; // FK profiles.id (usuario_id)
  final DateTime? fechaNacimiento;
  final String? genero; // 'M' | 'F' | 'O' | libre
  final String? grupoSanguineo;
  final String? alergias;
  final String? antecedentes;
  final bool activo;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const PacienteEntity({
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

  int? get edad {
    if (fechaNacimiento == null) return null;
    final hoy = DateTime.now();
    int age = hoy.year - fechaNacimiento!.year;
    if (hoy.month < fechaNacimiento!.month ||
        (hoy.month == fechaNacimiento!.month && hoy.day < fechaNacimiento!.day)) {
      age--;
    }
    return age;
  }

  @override
  List<Object?> get props => [id, profileId, activo];
}