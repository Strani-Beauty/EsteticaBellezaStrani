import '../entities/adelanto_servicio_entity.dart';
import '../entities/comision_entity.dart';
import '../entities/detalle_financiero_entity.dart';
import '../entities/pago_entity.dart';
import '../entities/payment_intent_entity.dart';
import '../entities/transaccion_entity.dart';

/// Contrato del módulo de pagos y solicitudes.
/// La implementación vive en data/. Las pantallas migran de SupabaseService
/// a este contrato vía GetIt.
abstract class IPaymentsRepository {
  /// Crea la cadena solicitudes → pagos → transacciones al aprobarse Qualify
  /// (depósito $30 previamente cobrado en la cuota inicial).
  Future<String?> createSolicitudAndPayment({
    required String profileId,
    required String stripePaymentRef,
    String? servicioId,
  });

  /// Registra el pago de la cuota inicial (payment_completed + activo).
  Future<void> registerInitialPayment({
    required String profileId,
    required double amount,
    required String paymentReference,
  });

  /// Reserva un servicio del catálogo (adelanto parcial o pago total).
  /// `montoAPagar` es el monto ya cobrado por Stripe.
  Future<String?> createServicePayment({
    required String profileId,
    required String servicioId,
    required double servicePrice,
    required bool payFullAmount,
    required double montoAPagar,
    required String stripePaymentRef,
  });

  /// Calcula el adelanto de un servicio (porcentaje configurado del total).
  Future<AdelantoServicioEntity> calcularAdelanto(double servicePrice);

  /// Confirma el cobro del saldo pendiente vía RPC `confirmar_pago_saldo`.
  /// Devuelve el `motivo` del RPC: 'OK', 'YA_REGISTRADA', 'MONTO_INCORRECTO',
  /// 'NO_ENCONTRADO' o 'NO_AUTORIZADO'.
  Future<String> confirmarPagoSaldo({
    required String citaId,
    required String solicitudId,
    required double monto,
    required String stripePaymentRef,
  });

  /// Registra una transacción FALLIDA (pago rechazado/cancelado) sin marcar
  /// la cita como financieramente completada. Devuelve el `motivo` del RPC.
  Future<String> registrarPagoFallido({
    required String citaId,
    required String solicitudId,
    required double monto,
    required String stripePaymentRef,
    required String motivo,
    required String tipo,
  });

  /// Consulta la obligación (pago) de una solicitud.
  Future<PagoEntity?> consultarPago({required String solicitudId});

  /// Invoca la edge function `create-payment-intent` y devuelve el client_secret.
  Future<PaymentIntentEntity> crearPaymentIntent({
    required double amount,
    required String concepto,
    String? solicitudId,
    String? citaId,
  });

  /// Transacciones para conciliación admin con filtros opcionales.
  Future<List<TransaccionEntity>> getTransaccionesAdmin({
    String? estado,
    String? tipo,
    DateTime? desde,
    DateTime? hasta,
  });

  /// Comisiones de la plataforma registradas.
  Future<List<ComisionEntity>> getComisionesAdmin();

  /// Detalle financiero de una cita (depósito, pago final, saldo, comisión).
  Future<DetalleFinancieroCitaEntity?> getDetalleFinancieroCita(String citaId);

  /// Genera liquidaciones semanales por especialista (solo admin).
  Future<GenerarLiquidacionesEntity> generarLiquidaciones({
    required DateTime fechaInicio,
    required DateTime fechaFin,
  });
}