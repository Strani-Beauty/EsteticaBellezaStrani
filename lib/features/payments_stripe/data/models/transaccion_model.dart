import '../../domain/entities/transaccion_entity.dart';

/// Modelo del registro `transacciones` (movimiento financiero real).
class TransaccionModel {
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

  const TransaccionModel({
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

  factory TransaccionModel.fromJson(Map<String, dynamic> json) {
    return TransaccionModel(
      id: json['id'] as String? ?? '',
      solicitudId: json['solicitud_id'] as String? ?? '',
      citaId: json['cita_id'] as String?,
      pacienteId: json['paciente_id'] as String? ?? '',
      tipo: TipoTransaccion.fromDb(json['tipo_transaccion']?.toString()) ??
          TipoTransaccion.ajuste,
      monto: (json['monto'] as num?)?.toDouble() ?? 0,
      moneda: json['moneda']?.toString() ?? 'USD',
      estado: EstadoTransaccion.fromDb(json['estado']?.toString()) ??
          EstadoTransaccion.pendiente,
      stripePaymentId: json['stripe_payment_id'] as String?,
      stripePaymentIntent: json['stripe_payment_intent'] as String?,
      fechaTransaccion:
          DateTime.tryParse(json['fecha_transaccion']?.toString() ?? '') ??
              DateTime.now(),
    );
  }

  TransaccionEntity toEntity() {
    return TransaccionEntity(
      id: id,
      solicitudId: solicitudId,
      citaId: citaId,
      pacienteId: pacienteId,
      tipo: tipo,
      monto: monto,
      moneda: moneda,
      estado: estado,
      stripePaymentId: stripePaymentId,
      stripePaymentIntent: stripePaymentIntent,
      fechaTransaccion: fechaTransaccion,
    );
  }
}