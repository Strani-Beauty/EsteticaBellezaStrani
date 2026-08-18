import '../../domain/entities/contrato_entity.dart';
import '../../domain/entities/documento_especialista_entity.dart';
import '../../domain/entities/medico_regente_entity.dart';
import 'documentos_requeridos.dart';

/// Estado del expediente habilitante de un especialista. La habilitación
/// (estado Verificado/APROBADO) exige cumplir TODAS las condiciones:
///   * documentos obligatorios APROBADOS (identificación, licencia y formación)
///   * datos profesionales: médico regente activo + al menos una especialidad
///   * contrato firmado antes de Verificado
/// El trigger `trg_validar_habilitacion_especialista` lo exige también en BD.
class ExpedienteEspecialista {
  final List<DocumentoEspecialistaEntity> documentos;
  final String? medicoRegenteId;
  final List<MedicoRegenteEntity> medicosRegentes;
  final int numeroEspecialidades;
  final ContratoEntity? contrato;

  const ExpedienteEspecialista({
    required this.documentos,
    this.medicoRegenteId,
    this.medicosRegentes = const [],
    this.numeroEspecialidades = 0,
    this.contrato,
  });

  bool get documentosAprobados =>
      tieneDocumentosAprobadosRequeridos(documentos);

  bool get medicoRegenteActivo => medicosRegentes.any(
        (m) => m.activo && m.id == medicoRegenteId,
      );

  bool get tieneEspecialidades => numeroEspecialidades > 0;

  bool get contratoFirmado => contrato?.firmado == true;

  bool get cumple =>
      documentosAprobados &&
      medicoRegenteActivo &&
      tieneEspecialidades &&
      contratoFirmado;

  /// Lista de pendientes (para mostrar al admin y al especialista qué falta).
  List<String> get pendientes => [
        if (!documentosAprobados) 'Documentos obligatorios aprobados',
        if (!medicoRegenteActivo) 'Médico regente activo',
        if (!tieneEspecialidades) 'Al menos una especialidad',
        if (!contratoFirmado) 'Contrato firmado',
      ];
}