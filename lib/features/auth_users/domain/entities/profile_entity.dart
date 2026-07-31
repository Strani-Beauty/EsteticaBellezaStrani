import 'package:equatable/equatable.dart';

/// Entidad de dominio: profiles
/// Vinculada 1:1 con auth.users (id = auth.users.id)
class ProfileEntity extends Equatable {
  final String id;             // UUID - FK auth.users.id
  final String email;
  final String? fullName;
  final String rolNombre;      // 'Paciente' | 'Especialista' | 'Administrador'
  final int? roleId;
  final String? phone;
  final String? avatarUrl;
  final String? address;
  final double? latitude;
  final double? longitude;
  final bool activo;
  final bool paymentCompleted;
  final bool evaluationPassed;
  final double? hourlyRate;    // Para especialistas
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ProfileEntity({
    required this.id,
    required this.email,
    this.fullName,
    required this.rolNombre,
    this.roleId,
    this.phone,
    this.avatarUrl,
    this.address,
    this.latitude,
    this.longitude,
    required this.activo,
    required this.paymentCompleted,
    required this.evaluationPassed,
    this.hourlyRate,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isAdmin       => rolNombre == 'Administrador';
  bool get isSpecialist  => rolNombre == 'Especialista';
  bool get isPatient     => rolNombre == 'Paciente';
  bool get profileComplete => activo && paymentCompleted;

  ProfileEntity copyWith({
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? address,
    double? latitude,
    double? longitude,
    bool? activo,
    bool? paymentCompleted,
    bool? evaluationPassed,
    double? hourlyRate,
    DateTime? updatedAt,
  }) {
    return ProfileEntity(
      id: id,
      email: email,
      fullName: fullName ?? this.fullName,
      rolNombre: rolNombre,
      roleId: roleId,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      activo: activo ?? this.activo,
      paymentCompleted: paymentCompleted ?? this.paymentCompleted,
      evaluationPassed: evaluationPassed ?? this.evaluationPassed,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id, email, fullName, rolNombre, roleId,
    phone, avatarUrl, address, latitude, longitude,
    activo, paymentCompleted, evaluationPassed,
    hourlyRate, createdAt, updatedAt,
  ];
}
