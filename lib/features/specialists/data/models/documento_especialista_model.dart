import '../../domain/entities/documento_especialista_entity.dart';

class DocumentoEspecialistaModel {
  final String id;
  final String especialistaId;
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

  const DocumentoEspecialistaModel({
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

  factory DocumentoEspecialistaModel.fromJson(Map<String, dynamic> json) {
    return DocumentoEspecialistaModel(
      id: json['id'] as String,
      especialistaId: json['especialista_id'] as String,
      tipoDocumento: TipoDocumento.fromDb(json['tipo_documento'] as String?) ??
          TipoDocumento.otro,
      nombreArchivo: json['nombre_archivo'] as String?,
      urlArchivo: json['url_archivo'] as String?,
      estadoRevision: EstadoRevisionDocumento.fromDb(json['estado_revision'] as String?) ??
          EstadoRevisionDocumento.pendiente,
      observacionRevision: json['observacion_revision'] as String?,
      revisadoPor: json['revisado_por'] as String?,
      fechaRevision: _parseDate(json['fecha_revision']),
      versionDocumento: (json['version_documento'] as num?)?.toInt() ?? 1,
      activo: json['activo'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'especialista_id': especialistaId,
      'tipo_documento': tipoDocumento.toDb,
      'nombre_archivo': nombreArchivo,
      'url_archivo': urlArchivo,
      'estado_revision': estadoRevision.toDb,
      'observacion_revision': observacionRevision,
      'revisado_por': revisadoPor,
      'fecha_revision': fechaRevision?.toIso8601String(),
      'version_documento': versionDocumento,
      'activo': activo,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  DocumentoEspecialistaEntity toEntity() {
    return DocumentoEspecialistaEntity(
      id: id,
      especialistaId: especialistaId,
      tipoDocumento: tipoDocumento,
      nombreArchivo: nombreArchivo,
      urlArchivo: urlArchivo,
      estadoRevision: estadoRevision,
      observacionRevision: observacionRevision,
      revisadoPor: revisadoPor,
      fechaRevision: fechaRevision,
      versionDocumento: versionDocumento,
      activo: activo,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}