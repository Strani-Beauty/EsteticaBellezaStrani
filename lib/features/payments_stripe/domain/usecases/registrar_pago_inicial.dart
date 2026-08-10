import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../../domain/repositories/i_payments_repository.dart';

class RegistrarPagoInicialParams {
  final String profileId;
  final double amount;
  final String paymentReference;

  const RegistrarPagoInicialParams({
    required this.profileId,
    required this.amount,
    required this.paymentReference,
  });
}

/// Registra la cuota inicial ($30) del onboarding: payment_completed + activo.
class RegistrarPagoInicial
    extends UseCase<void, RegistrarPagoInicialParams> {
  final IPaymentsRepository _repository;

  RegistrarPagoInicial(this._repository);

  @override
  Future<Either<Failure, void>> call(RegistrarPagoInicialParams params) async {
    try {
      await _repository.registerInitialPayment(
        profileId: params.profileId,
        amount: params.amount,
        paymentReference: params.paymentReference,
      );
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('No se pudo registrar el pago inicial: $e'));
    }
  }
}