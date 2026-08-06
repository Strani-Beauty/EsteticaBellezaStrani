import '../../domain/entities/consentimiento_tratamiento_entity.dart';

/// Modelo de `consentimientos_tratamiento`.
class ConsentimientoModel {
  final String id;
  final String tratamientoId;
  final String pacienteId;
  final String tipoConsentimiento;
  final String? documentoUrl;
  final String? firmaUrl;
  final String? fechaFirma;
  final String? createdAt;

  const ConsentimientoModel({
    required this.id,
    required this.tratamientoId,
    required this.pacienteId,
    required this.tipoConsentimiento,
    this.documentoUrl,
    this.firmaUrl,
    this.fechaFirma,
    this.createdAt,
  });

  factory ConsentimientoModel.fromJson(Map<String, dynamic> json) {
    return ConsentimientoModel(
      id: json['id'] as String? ?? '',
      tratamientoId: json['tratamiento_id'] as String? ?? '',
      pacienteId: json['paciente_id'] as String? ?? '',
      tipoConsentimiento: json['tipo_consentimiento'] as String? ?? '',
      documentoUrl: json['documento_url'] as String?,
      firmaUrl: json['firma_url'] as String?,
      fechaFirma: json['fecha_firma']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }

  ConsentimientoTratamientoEntity toEntity() {
    return ConsentimientoTratamientoEntity(
      id: id,
      tratamientoId: tratamientoId,
      pacienteId: pacienteId,
      tipoConsentimiento: tipoConsentimiento,
      documentoUrl: documentoUrl,
      firmaUrl: firmaUrl,
      fechaFirma: _parseDate(fechaFirma),
      createdAt: _parseDate(createdAt) ?? DateTime.now(),
    );
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}