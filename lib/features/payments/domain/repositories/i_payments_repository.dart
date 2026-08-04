/// Contrato del módulo de pagos y solicitudes.
/// La implementación vive en data/. Las pantallas migrarán de SupabaseService
/// a este contrato vía GetIt.
abstract class IPaymentsRepository {
  /// Crea la cadena solicitudes → pagos → transacciones al aprobarse Qualify.
  Future<String?> createSolicitudAndPayment({
    required String profileId,
    required String stripePaymentRef,
  });

  /// Registra el pago de la cuota inicial.
  Future<void> registerInitialPayment({
    required String profileId,
    required double amount,
    required String paymentReference,
  });
}
