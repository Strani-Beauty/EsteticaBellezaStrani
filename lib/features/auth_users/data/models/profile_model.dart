import 'package:esteticaybellezastrani/features/auth_users/domain/entities/profile_entity.dart';

/// Data Model para la tabla `profiles` en Supabase.
/// No extiende ProfileEntity directamente para evitar conflictos con const super.
/// En su lugar, implementa la conversión fromJson/toJson y produce ProfileEntity.
class ProfileModel {
  final String id;
  final String email;
  final String? fullName;
  final String rolNombre;
  final int? roleId;
  final String? phone;
  final String? avatarUrl;
  final String? address;
  final double? latitude;
  final double? longitude;
  final bool activo;
  final bool paymentCompleted;
  final bool evaluationPassed;
  final double? hourlyRate;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ProfileModel({
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

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id:               json['id'] as String,
      email:            json['email'] as String? ?? '',
      fullName:         json['full_name'] as String?,
      rolNombre:        _extractRolNombre(json),
      roleId:           _parseInt(json['role_id']),
      phone:            json['phone'] as String?,
      avatarUrl:        json['avatar_url'] as String?,
      address:          json['address'] as String?,
      latitude:         _parseDouble(json['latitude']),
      longitude:        _parseDouble(json['longitude']),
      activo:           _parseBool(json['activo']),
      paymentCompleted: _parseBool(json['payment_completed']),
      evaluationPassed: _parseBool(json['evaluation_passed']),
      hourlyRate:       _parseDouble(json['hourly_rate']),
      createdAt:        _parseDateTime(json['created_at']) ?? DateTime.now(),
      updatedAt:        _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id':                id,
    'email':             email,
    'full_name':         fullName,
    'role_id':           roleId,
    'phone':             phone,
    'avatar_url':        avatarUrl,
    'address':           address,
    'latitude':          latitude,
    'longitude':         longitude,
    'activo':            activo,
    'payment_completed': paymentCompleted,
    'evaluation_passed': evaluationPassed,
    'hourly_rate':       hourlyRate,
    'updated_at':        DateTime.now().toIso8601String(),
  };

  Map<String, dynamic> toUpsertJson() {
    final map = <String, dynamic>{'id': id};
    if (fullName != null)   map['full_name'] = fullName;
    if (phone != null)      map['phone'] = phone;
    if (address != null)    map['address'] = address;
    if (latitude != null)   map['latitude'] = latitude;
    if (longitude != null)  map['longitude'] = longitude;
    map['activo'] = activo;
    map['payment_completed'] = paymentCompleted;
    map['evaluation_passed'] = evaluationPassed;
    map['updated_at'] = DateTime.now().toIso8601String();
    return map;
  }

  /// Convierte al entity de dominio puro
  ProfileEntity toEntity() => ProfileEntity(
    id:               id,
    email:            email,
    fullName:         fullName,
    rolNombre:        rolNombre,
    roleId:           roleId,
    phone:            phone,
    avatarUrl:        avatarUrl,
    address:          address,
    latitude:         latitude,
    longitude:        longitude,
    activo:           activo,
    paymentCompleted: paymentCompleted,
    evaluationPassed: evaluationPassed,
    hourlyRate:       hourlyRate,
    createdAt:        createdAt,
    updatedAt:        updatedAt,
  );

  // ── Helpers de parsing con type safety ─────────────────────
  static String _extractRolNombre(Map<String, dynamic> json) {
    if (json['roles'] is Map) {
      return (json['roles'] as Map<String, dynamic>)['name'] as String? ?? 'Paciente';
    }
    return json['rol_nombre'] as String?
        ?? json['role'] as String?
        ?? 'Paciente';
  }

  static double? _parseDouble(dynamic val) {
    if (val == null) return null;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    if (val is String) return double.tryParse(val);
    return null;
  }

  static int? _parseInt(dynamic val) {
    if (val == null) return null;
    if (val is int) return val;
    if (val is String) return int.tryParse(val);
    return null;
  }

  static bool _parseBool(dynamic val) {
    if (val == null) return false;
    if (val is bool) return val;
    if (val is int) return val == 1;
    if (val is String) return val.toLowerCase() == 'true';
    return false;
  }

  static DateTime? _parseDateTime(dynamic val) {
    if (val == null) return null;
    if (val is DateTime) return val;
    if (val is String) return DateTime.tryParse(val);
    return null;
  }
}
