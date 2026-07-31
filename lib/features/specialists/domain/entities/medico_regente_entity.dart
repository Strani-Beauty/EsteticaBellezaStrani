import 'package:equatable/equatable.dart';

class MedicoRegenteEntity extends Equatable {
  final String id;          // UUID
  final String nombre;
  final String? licencia;
  final String? especialidad;
  final String? email;
  final String? phone;
  final bool activo;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const MedicoRegenteEntity({
    required this.id,
    required this.nombre,
    this.licencia,
    this.especialidad,
    this.email,
    this.phone,
    required this.activo,
    required this.createdAt,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [id, nombre, activo];
}
