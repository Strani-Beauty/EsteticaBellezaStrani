import 'package:esteticaybellezastrani/features/payments_stripe/domain/repositories/i_payments_repository.dart';
import 'package:esteticaybellezastrani/app/core/network/supabase_service.dart';

/// ImplementaciÃ³n del repositorio de pagos.
/// Por ahora delega en [SupabaseService]; en una iteraciÃ³n posterior el
/// servicio monolÃ­tico migrarÃ¡ a datasources y este impl dejarÃ¡ de delegar.
class PaymentsRepositoryImpl implements IPaymentsRepository {
  const PaymentsRepositoryImpl();

  @override
  Future<String?> createSolicitudAndPayment({
    required String profileId,
    required String stripePaymentRef,
  }) =>
      SupabaseService.createSolicitudAndPayment(
        profileId: profileId,
        stripePaymentRef: stripePaymentRef,
      );

  @override
  Future<void> registerInitialPayment({
    required String profileId,
    required double amount,
    required String paymentReference,
  }) =>
      SupabaseService.registerInitialPayment(
        profileId: profileId,
        amount: amount,
        paymentReference: paymentReference,
      );
}
