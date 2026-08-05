import 'package:equatable/equatable.dart';

/// Estado de revisión del documento (columna `estado_revision`).
enum EstadoRevisionDocumento {
  pendiente,
  aprobado,
  rechazado;

  static const Map<EstadoRevisionDocumento, String> _db = {
    EstadoRevisionDocumento.pendiente: 'PENDIENTE',
    EstadoRevisionDocumento.aprobado: 'APROBADO',
    EstadoRevisionDocumento.rechazado: 'RECHAZADO',
  };

  String get toDb => _db[this]!;

  static EstadoRevisionDocumento? fromDb(String? value) {
    for (final entry in _db.entries) {
      if (entry.value == value?.toUpperCase()) return entry.key;
    }
    return null;
  }
}

/// Tipo de documento (columna `tipo_documento`).
enum TipoDocumento {
  cedula,
  licencia,
  diploma,
  seguro;

  static const Map<TipoDocumento, String> _db = {
    TipoDocumento.cedula: 'CEDULA',
    TipoDocumento.licencia: 'LICENCIA',
    TipoDocumento.diploma: 'DIPLOMA',
    TipoDocumento.seguro: 'SEGURO',
  };

  String get toDb => _db[this]!;

  static TipoDocumento? fromDb(String? value) {
    for (final entry in _db.entries) {
      if (entry.value == value?.toUpperCase()) return entry.key;
    }
    return null;
  }
}

/// Entidad de dominio: `documentos_especialista`.
class DocumentoEspecialistaEntity extends Equatable {
  final String id;                 // uuid PK
  final String especialistaId;     // FK especialistas.id
  final TipoDocumento tipoDocumento;
  final String? nombreArchivo;
  final String? urlArchivo;
  final EstadoRevisionDocumento estadoRevision;
  final String? observacionRevision;
  final String? revisadoPor;
  final DateTime? fechaRevision;
  final int versionDocumento;
  final bool activo;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const DocumentoEspecialistaEntity({
    required this.id,
    required this.especialistaId,
    required this.tipoDocumento,
    this.nombreArchivo,
    this.urlArchivo,
    required this.estadoRevision,
    this.observacionRevision,
    this.revisadoPor,
    this.fechaRevision,
    required this.versionDocumento,
    required this.activo,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isAprobado => estadoRevision == EstadoRevisionDocumento.aprobado;

  @override
  List<Object?> get props => [id, especialistaId, tipoDocumento, versionDocumento, estadoRevision];
}