import 'package:equatable/equatable.dart';

/// Entidad de dominio: roles
class RoleEntity extends Equatable {
  final int id;
  final String name;
  final String? description;
  final String? code;
  final bool activo;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const RoleEntity({
    required this.id,
    required this.name,
    this.description,
    this.code,
    required this.activo,
    required this.createdAt,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [id, name, code, activo];
}

/// Entidad de dominio: dispositivos_usuario
/// Registro de FCM tokens para notificaciones push (RN-006, RN-007)
class DispositivoUsuarioEntity extends Equatable {
  final String id;          // UUID
  final String profileId;   // FK profiles.id
  final String fcmToken;
  final String? plataforma; // 'android' | 'ios' | 'web'
  final bool activo;
  final DateTime createdAt;
  final DateTime? lastSeenAt;

  const DispositivoUsuarioEntity({
    required this.id,
    required this.profileId,
    required this.fcmToken,
    this.plataforma,
    required this.activo,
    required this.createdAt,
    this.lastSeenAt,
  });

  @override
  List<Object?> get props => [id, profileId, fcmToken, plataforma, activo];
}
