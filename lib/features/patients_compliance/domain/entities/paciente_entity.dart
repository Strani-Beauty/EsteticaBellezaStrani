import 'package:equatable/equatable.dart';

class PacienteEntity extends Equatable {
  final String id;           // UUID
  final String profileId;    // FK profiles.id (1:1)
  final DateTime? fechaNacimiento;
  final String? sexo;        // 'M' | 'F' | 'O'
  final String? grupoSanguineo;
  final String? alergias;    // texto libre
  final String? antecedentes; // texto libre
  final bool activo;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const PacienteEntity({
    required this.id,
    required this.profileId,
    this.fechaNacimiento,
    this.sexo,
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
