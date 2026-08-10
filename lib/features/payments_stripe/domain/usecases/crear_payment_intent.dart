import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../../domain/repositories/i_payments_repository.dart';
import '../../domain/entities/payment_intent_entity.dart';

class CrearPaymentIntentParams {
  final double amount;
  final String concepto;
  final String? solicitudId;
  final String? citaId;

  const CrearPaymentIntentParams({
    required this.amount,
    required this.concepto,
    this.solicitudId,
    this.citaId,
  });
}

/// Crea un PaymentIntent en el backend (edge function) para presentar el
/// PaymentSheet de Stripe.
class CrearPaymentIntent
    extends UseCase<PaymentIntentEntity, CrearPaymentIntentParams> {
  final IPaymentsRepository _repository;

  CrearPaymentIntent(this._repository);

  @override
  Future<Either<Failure, PaymentIntentEntity>> call(
      CrearPaymentIntentParams params) async {
    try {
      final intent = await _repository.crearPaymentIntent(
        amount: params.amount,
        concepto: params.concepto,
        solicitudId: params.solicitudId,
        citaId: params.citaId,
      );
      return Right(intent);
    } catch (e) {
      return Left(PaymentFailure('No se pudo iniciar el pago: $e'));
    }
  }
}