/// Tipos de transacción soportados (mapeo a `transacciones.tipo_transaccion`).
enum TipoTransaccion {
  deposito('DEPOSITO'),
  pagoTotal('PAGO_TOTAL'),
  saldo('SALDO'),
  reembolso('REEMBOLSO'),
  ajuste('AJUSTE');

  final String db;
  const TipoTransaccion(this.db);

  static TipoTransaccion? fromDb(String? value) {
    for (final e in TipoTransaccion.values) {
      if (e.db == value) return e;
    }
    return null;
  }
}

/// Estados del ciclo de vida de una transacción (`transacciones.estado`).
enum EstadoTransaccion {
  pendiente('PENDIENTE'),
  procesada('PROCESADA'),
  aprobado('APROBADO'),
  fallida('FALLIDA'),
  reembolsada('REEMBOLSADA');

  final String db;
  const EstadoTransaccion(this.db);

  static EstadoTransaccion? fromDb(String? value) {
    for (final e in EstadoTransaccion.values) {
      if (e.db == value) return e;
    }
    return null;
  }
}

/// Movimiento financiero real de un pago (`transacciones`).
class TransaccionEntity {
  final String id;
  final String solicitudId;
  final String? citaId;
  final String pacienteId;
  final TipoTransaccion tipo;
  final double monto;
  final String moneda;
  final EstadoTransaccion estado;
  final String? stripePaymentId;
  final String? stripePaymentIntent;
  final DateTime fechaTransaccion;

  const TransaccionEntity({
    required this.id,
    required this.solicitudId,
    this.citaId,
    required this.pacienteId,
    required this.tipo,
    required this.monto,
    this.moneda = 'USD',
    required this.estado,
    this.stripePaymentId,
    this.stripePaymentIntent,
    required this.fechaTransaccion,
  });
}