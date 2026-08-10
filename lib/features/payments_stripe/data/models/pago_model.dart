import '../../domain/entities/pago_entity.dart';

/// Modelo del registro `pagos` (obligación comercial de la solicitud).
class PagoModel {
  final String id;
  final String solicitudId;
  final double montoTotal;
  final double deposito;
  final double saldoPendiente;
  final PagoEstado estado;

  const PagoModel({
    required this.id,
    required this.solicitudId,
    required this.montoTotal,
    required this.deposito,
    required this.saldoPendiente,
    required this.estado,
  });

  factory PagoModel.fromJson(Map<String, dynamic> json) {
    return PagoModel(
      id: json['id'] as String? ?? '',
      solicitudId: json['solicitud_id'] as String? ?? '',
      montoTotal: (json['monto_total'] as num?)?.toDouble() ?? 0,
      deposito: (json['deposito'] as num?)?.toDouble() ?? 0,
      saldoPendiente: (json['saldo_pendiente'] as num?)?.toDouble() ?? 0,
      estado: PagoEstado.fromDb(json['estado']?.toString()) ?? PagoEstado.pendiente,
    );
  }

  PagoEntity toEntity() {
    return PagoEntity(
      id: id,
      solicitudId: solicitudId,
      montoTotal: montoTotal,
      deposito: deposito,
      saldoPendiente: saldoPendiente,
      estado: estado,
    );
  }
}