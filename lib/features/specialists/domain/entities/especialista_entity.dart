import 'package:equatable/equatable.dart';

/// Estado de verificación del especialista (columna `estado_verificacion`).
enum EstadoVerificacion {
  pendiente,
  enRevision,
  aprobado,
  rechazado,
  bloqueado;

  static const Map<EstadoVerificacion, String> _db = {
    EstadoVerificacion.pendiente: 'PENDIENTE',
    EstadoVerificacion.enRevision: 'EN_REVISION',
    EstadoVerificacion.aprobado: 'APROBADO',
    EstadoVerificacion.rechazado: 'RECHAZADO',
    EstadoVerificacion.bloqueado: 'BLOQUEADO',
  };

  String get toDb => _db[this]!;

  static EstadoVerificacion? fromDb(String? value) {
    for (final entry in _db.entries) {
      if (entry.value == value?.toUpperCase()) return entry.key;
    }
    return null;
  }
}

/// Entidad de dominio: `especialistas`.
/// Se vincula a `profiles.id` mediante `usuario_id`.
class EspecialistaEntity extends Equatable {
  final String id;                       // uuid PK
  final String usuarioId;                // FK profiles.id (auth.users.id)
  final String? medicoRegenteId;         // FK medicos_regentes.id
  final String? numeroLicencia;
  final EstadoVerificacion estadoVerificacion;
  final DateTime? fechaSolicitudVerificacion;
  final DateTime? fechaVerificacion;
  final DateTime? fechaAprobacion;
  final String? aprobadoPor;             // uuid
  final String? observacion;             // motivo de rechazo/bloqueo (admin)
  final bool disponible;
  final bool activo;
  final bool enLinea;                    // presencia: app en foreground
  final DateTime? ultimaConexion;        // último heartbeat
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? nombreUsuario;           // join con profiles.full_name
  final String? emailUsuario;            // join con profiles.email

  const EspecialistaEntity({
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

  bool get isApproved => estadoVerificacion == EstadoVerificacion.aprobado;
  bool get isPending => estadoVerificacion == EstadoVerificacion.pendiente;

  EspecialistaEntity copyWith({
    String? medicoRegenteId,
    String? numeroLicencia,
    EstadoVerificacion? estadoVerificacion,
    DateTime? fechaSolicitudVerificacion,
    DateTime? fechaVerificacion,
    DateTime? fechaAprobacion,
    String? aprobadoPor,
    String? observacion,
    bool? disponible,
    bool? activo,
    bool? enLinea,
    DateTime? ultimaConexion,
    DateTime? updatedAt,
    String? nombreUsuario,
    String? emailUsuario,
  }) {
    return EspecialistaEntity(
      id: id,
      usuarioId: usuarioId,
      medicoRegenteId: medicoRegenteId ?? this.medicoRegenteId,
      numeroLicencia: numeroLicencia ?? this.numeroLicencia,
      estadoVerificacion: estadoVerificacion ?? this.estadoVerificacion,
      fechaSolicitudVerificacion:
          fechaSolicitudVerificacion ?? this.fechaSolicitudVerificacion,
      fechaVerificacion: fechaVerificacion ?? this.fechaVerificacion,
      fechaAprobacion: fechaAprobacion ?? this.fechaAprobacion,
      aprobadoPor: aprobadoPor ?? this.aprobadoPor,
      observacion: observacion ?? this.observacion,
      disponible: disponible ?? this.disponible,
      activo: activo ?? this.activo,
      enLinea: enLinea ?? this.enLinea,
      ultimaConexion: ultimaConexion ?? this.ultimaConexion,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      nombreUsuario: nombreUsuario ?? this.nombreUsuario,
      emailUsuario: emailUsuario ?? this.emailUsuario,
    );
  }

  @override
  List<Object?> get props => [
        id,
        usuarioId,
        estadoVerificacion,
        disponible,
        activo,
        enLinea,
      ];
}