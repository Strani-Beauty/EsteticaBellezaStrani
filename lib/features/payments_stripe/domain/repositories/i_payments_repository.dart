import '../entities/adelanto_servicio_entity.dart';
import '../entities/pago_entity.dart';
import '../entities/payment_intent_entity.dart';

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

  /// Cobra el saldo restante al finalizar un tratamiento (transacción SALDO).
  /// Devuelve `false` si no había saldo pendiente.
  Future<bool> registrarPagoSaldo({
    required String citaId,
    required String solicitudId,
    required double monto,
    required String stripePaymentRef,
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
}