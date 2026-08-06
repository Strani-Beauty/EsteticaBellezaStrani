import 'package:equatable/equatable.dart';

/// Entidad de dominio: `consentimientos_tratamiento`.
/// Vincula un tratamiento con el consentimiento firmado por el paciente.
class ConsentimientoTratamientoEntity extends Equatable {
  final String id;
  final String tratamientoId;
  final String pacienteId;
  final String tipoConsentimiento;
  final String? documentoUrl;
  final String? firmaUrl;
  final DateTime? fechaFirma;
  final DateTime createdAt;

  const ConsentimientoTratamientoEntity({
    required this.id,
    required this.tratamientoId,
    required this.pacienteId,
    required this.tipoConsentimiento,
    this.documentoUrl,
    this.firmaUrl,
    this.fechaFirma,
    required this.createdAt,
  });

  bool get firmado => firmaUrl != null && firmaUrl!.isNotEmpty;

  @override
  List<Object?> get props => [
        id,
        tratamientoId,
        pacienteId,
        tipoConsentimiento,
        documentoUrl,
        firmaUrl,
        fechaFirma,
        createdAt,
      ];
}
