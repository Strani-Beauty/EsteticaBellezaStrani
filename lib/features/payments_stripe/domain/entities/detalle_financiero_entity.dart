/// Resultado de generar liquidaciones (respuesta de `generar_liquidaciones`).
class GenerarLiquidacionesEntity {
  final bool ok;
  final String motivo;
  final int especialistas;
  final int citas;
  final double montoTotal;
  final double montoComision;
  final double montoPagar;

  const GenerarLiquidacionesEntity({
    required this.ok,
    required this.motivo,
    this.especialistas = 0,
    this.citas = 0,
    this.montoTotal = 0,
    this.montoComision = 0,
    this.montoPagar = 0,
  });

  factory GenerarLiquidacionesEntity.fromJson(Map<String, dynamic> json) {
    return GenerarLiquidacionesEntity(
      ok: json['ok'] == true,
      motivo: json['motivo']?.toString() ?? '',
      especialistas: (json['especialistas'] as num?)?.toInt() ?? 0,
      citas: (json['citas'] as num?)?.toInt() ?? 0,
      montoTotal: (json['monto_total'] as num?)?.toDouble() ?? 0,
      montoComision: (json['monto_comision'] as num?)?.toDouble() ?? 0,
      montoPagar: (json['monto_pagar'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Detalle financiero consolidado de una cita: depósito, pago final, saldo,
/// comisión de la plataforma y neto para el especialista.
class DetalleFinancieroCitaEntity {
  final String citaId;
  final String solicitudId;
  final double montoTotal;
  final double deposito;
  final double saldoPendiente;
  final double montoPagoFinal;
  final double porcentajeComision;
  final double montoComision;
  final double montoEspecialista;

  const DetalleFinancieroCitaEntity({
    required this.citaId,
    required this.solicitudId,
    required this.montoTotal,
    required this.deposito,
    required this.saldoPendiente,
    required this.montoPagoFinal,
    required this.porcentajeComision,
    required this.montoComision,
    required this.montoEspecialista,
  });

  bool get estaCompleta => saldoPendiente <= 0;

  factory DetalleFinancieroCitaEntity.fromJson(Map<String, dynamic> json) {
    final pago = json['pagos'] is List && (json['pagos'] as List).isNotEmpty
        ? Map<String, dynamic>.from((json['pagos'] as List).first as Map)
        : <String, dynamic>{};
    final montoTotal = (pago['monto_total'] as num?)?.toDouble() ?? 0;
    final deposito = (pago['deposito'] as num?)?.toDouble() ?? 0;
    final saldo = (pago['saldo_pendiente'] as num?)?.toDouble() ?? montoTotal;
    final pagoFinal = (montoTotal - deposito - saldo).clamp(0.0, double.infinity);
    final pct = (json['porcentaje_comision'] as num?)?.toDouble() ?? 0;
    final comision = montoTotal * pct / 100;
    return DetalleFinancieroCitaEntity(
      citaId: json['cita_id']?.toString() ?? '',
      solicitudId: json['solicitud_id']?.toString() ?? '',
      montoTotal: montoTotal,
      deposito: deposito,
      saldoPendiente: saldo,
      montoPagoFinal: pagoFinal,
      porcentajeComision: pct,
      montoComision: comision,
      montoEspecialista: montoTotal - comision,
    );
  }
}