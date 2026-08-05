import '../../domain/entities/contrato_entity.dart';

class ContratoModel {
  final String id;
  final String especialistaId;
  final int versionContrato;
  final String? urlDocumento;
  final bool firmado;
  final DateTime? fechaFirma;
  final MetodoFirma? metodoFirma;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ContratoModel({
    required this.id,
    required this.especialistaId,
    required this.versionContrato,
    this.urlDocumento,
    required this.firmado,
    this.fechaFirma,
    this.metodoFirma,
    required this.createdAt,
    this.updatedAt,
  });

  factory ContratoModel.fromJson(Map<String, dynamic> json) {
    return ContratoModel(
      id: json['id'] as String,
      especialistaId: json['especialista_id'] as String,
      versionContrato: (json['version_contrato'] as num?)?.toInt() ?? 1,
      urlDocumento: json['url_documento'] as String?,
      firmado: json['firmado'] as bool? ?? false,
      fechaFirma: _parseDate(json['fecha_firma']),
      metodoFirma: MetodoFirma.fromDb(json['metodo_firma'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'especialista_id': especialistaId,
      'version_contrato': versionContrato,
      'url_documento': urlDocumento,
      'firmado': firmado,
      'fecha_firma': fechaFirma?.toIso8601String(),
      'metodo_firma': metodoFirma?.toDb,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  ContratoEntity toEntity() {
    return ContratoEntity(
      id: id,
      especialistaId: especialistaId,
      versionContrato: versionContrato,
      urlDocumento: urlDocumento,
      firmado: firmado,
      fechaFirma: fechaFirma,
      metodoFirma: metodoFirma,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}