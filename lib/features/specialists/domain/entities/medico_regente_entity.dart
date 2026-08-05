import 'package:equatable/equatable.dart';

/// Entidad de dominio: `medicos_regentes`.
class MedicoRegenteEntity extends Equatable {
  final String id;               // uuid PK
  final String nombre;
  final String? numeroLicencia;
  final String estado;           // ej. 'ACTIVO' | 'INACTIVO'
  final String? telefono;
  final String? correo;
  final bool activo;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const MedicoRegenteEntity({
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

  MedicoRegenteEntity copyWith({String? estado, bool? activo, DateTime? updatedAt}) {
    return MedicoRegenteEntity(
      id: id,
      nombre: nombre,
      numeroLicencia: numeroLicencia,
      estado: estado ?? this.estado,
      telefono: telefono,
      correo: correo,
      activo: activo ?? this.activo,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, nombre, numeroLicencia, estado, activo];
}