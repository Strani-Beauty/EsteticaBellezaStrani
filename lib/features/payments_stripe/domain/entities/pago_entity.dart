/// Estados de un pago según la BD (`pagos.estado`).
enum PagoEstado {
  pendiente('PENDIENTE'),
  parcial('PARCIAL'),
  pagado('PAGADO'),
  cancelado('CANCELADO');

  final String db;
  const PagoEstado(this.db);

  static PagoEstado? fromDb(String? value) {
    for (final e in PagoEstado.values) {
      if (e.db == value) return e;
    }
    return null;
  }
}

/// Obligación comercial de una solicitud (`pagos`).
class PagoEntity {
  final String id;
  final String solicitudId;
  final double montoTotal;
  final double deposito;
  final double saldoPendiente;
  final PagoEstado estado;

  const PagoEntity({
    required this.id,
    required this.solicitudId,
    required this.montoTotal,
    required this.deposito,
    required this.saldoPendiente,
    required this.estado,
  });

  bool get estaPagado => estado == PagoEstado.pagado;
}