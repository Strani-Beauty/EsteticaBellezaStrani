import 'package:equatable/equatable.dart';

enum TipoFirma { touch, digital }
enum EstadoContrato { pendiente, firmado, vencido, cancelado }

class ContratoEntity extends Equatable {
  final String id;               // UUID
  final String especialistaId;  // FK especialistas.id
  final String? templateUrl;    // URL al template PDF en Storage
  final String? firmaUrl;       // URL a imagen de firma en Storage
  final TipoFirma? tipoFirma;
  final EstadoContrato estado;
  final DateTime? fechaFirma;
  final DateTime? fechaVencimiento;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ContratoEntity({
    required this.id,
    required this.especialistaId,
    this.templateUrl,
    this.firmaUrl,
    this.tipoFirma,
    required this.estado,
    this.fechaFirma,
    this.fechaVencimiento,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isSigned => estado == EstadoContrato.firmado && firmaUrl != null;

  @override
  List<Object?> get props => [id, especialistaId, estado];
}
