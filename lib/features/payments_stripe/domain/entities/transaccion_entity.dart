/// Tipos de transacción soportados (mapeo a `transacciones.tipo_transaccion`).
enum TipoTransaccion {
  deposito('DEPOSITO'),
  pagoTotal('PAGO_TOTAL'),
  saldo('SALDO'),
  reembolso('REEMBOLSO');

  final String db;
  const TipoTransaccion(this.db);

  static TipoTransaccion? fromDb(String? value) {
    for (final e in TipoTransaccion.values) {
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
  final DateTime fechaTransaccion;

  const TransaccionEntity({
    required this.id,
    required this.solicitudId,
    this.citaId,
    required this.pacienteId,
    required this.tipo,
    required this.monto,
    this.moneda = 'USD',
    required this.fechaTransaccion,
  });
}