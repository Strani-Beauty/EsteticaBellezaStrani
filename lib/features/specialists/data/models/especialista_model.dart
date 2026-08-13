import '../../domain/entities/especialista_entity.dart';

class EspecialistaModel {
  final String id;
  final String usuarioId;
  final String? medicoRegenteId;
  final String? numeroLicencia;
  final EstadoVerificacion estadoVerificacion;
  final DateTime? fechaSolicitudVerificacion;
  final DateTime? fechaVerificacion;
  final DateTime? fechaAprobacion;
  final String? aprobadoPor;
  final String? observacion;
  final bool disponible;
  final bool activo;
  final bool enLinea;
  final DateTime? ultimaConexion;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? nombreUsuario;
  final String? emailUsuario;

  const EspecialistaModel({
    required this.id,
    required this.usuarioId,
    this.medicoRegenteId,
    this.numeroLicencia,
    required this.estadoVerificacion,
    this.fechaSolicitudVerificacion,
    this.fechaVerificacion,
    this.fechaAprobacion,
    this.aprobadoPor,
    this.observacion,
    required this.disponible,
    required this.activo,
    this.enLinea = false,
    this.ultimaConexion,
    required this.createdAt,
    this.updatedAt,
    this.nombreUsuario,
    this.emailUsuario,
  });

  factory EspecialistaModel.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return EspecialistaModel(
      id: json['id'] as String,
      usuarioId: json['usuario_id'] as String,
      medicoRegenteId: json['medico_regente_id'] as String?,
      numeroLicencia: json['numero_licencia'] as String?,
      estadoVerificacion: EstadoVerificacion.fromDb(json['estado_verificacion'] as String?) ??
          EstadoVerificacion.pendiente,
      fechaSolicitudVerificacion:
          _parseDate(json['fecha_solicitud_verificacion']),
      fechaVerificacion: _parseDate(json['fecha_verificacion']),
      fechaAprobacion: _parseDate(json['fecha_aprobacion']),
      aprobadoPor: json['aprobado_por'] as String?,
      observacion: json['observacion'] as String?,
      disponible: json['disponible'] as bool? ?? false,
      activo: json['activo'] as bool? ?? false,
      enLinea: json['en_linea'] as bool? ?? false,
      ultimaConexion: _parseDate(json['ultima_conexion']),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: _parseDate(json['updated_at']),
      nombreUsuario: profile?['full_name'] as String?,
      emailUsuario: profile?['email'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'usuario_id': usuarioId,
      'medico_regente_id': medicoRegenteId,
      'numero_licencia': numeroLicencia,
      'estado_verificacion': estadoVerificacion.toDb,
      'fecha_solicitud_verificacion': _marshalDate(fechaSolicitudVerificacion),
      'fecha_verificacion': _marshalDate(fechaVerificacion),
      'fecha_aprobacion': _marshalDate(fechaAprobacion),
      'aprobado_por': aprobadoPor,
      'observacion': observacion,
      'disponible': disponible,
      'activo': activo,
      'en_linea': enLinea,
      'ultima_conexion': _marshalDate(ultimaConexion),
      'created_at': createdAt.toIso8601String(),
      'updated_at': _marshalDate(updatedAt),
    };
  }

  EspecialistaEntity toEntity() {
    return EspecialistaEntity(
      id: id,
      usuarioId: usuarioId,
      medicoRegenteId: medicoRegenteId,
      numeroLicencia: numeroLicencia,
      estadoVerificacion: estadoVerificacion,
      fechaSolicitudVerificacion: fechaSolicitudVerificacion,
      fechaVerificacion: fechaVerificacion,
      fechaAprobacion: fechaAprobacion,
      aprobadoPor: aprobadoPor,
      observacion: observacion,
      disponible: disponible,
      activo: activo,
      enLinea: enLinea,
      ultimaConexion: ultimaConexion,
      createdAt: createdAt,
      updatedAt: updatedAt,
      nombreUsuario: nombreUsuario,
      emailUsuario: emailUsuario,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static String? _marshalDate(DateTime? value) => value?.toIso8601String();
}