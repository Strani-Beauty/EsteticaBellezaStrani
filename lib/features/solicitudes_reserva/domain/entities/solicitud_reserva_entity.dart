import 'package:equatable/equatable.dart';

/// Resultado de `crear_solicitud_reserva`: la solicitud queda PENDIENTE_PAGO
/// hasta que el depósito sea confirmado (webhook o simulado).
class SolicitudReservaEntity extends Equatable {
  final String solicitudId;
  final double total;
  final double depositoRequerido;
  final double saldoPendiente;
  final String moneda;

  const SolicitudReservaEntity({
    required this.solicitudId,
    required this.total,
    required this.depositoRequerido,
    required this.saldoPendiente,
    required this.moneda,
  });

  @override
  List<Object?> get props =>
      [solicitudId, total, depositoRequerido, saldoPendiente, moneda];
}
