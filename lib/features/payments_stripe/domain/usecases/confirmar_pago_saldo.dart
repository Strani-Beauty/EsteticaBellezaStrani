import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../../domain/repositories/i_payments_repository.dart';

class ConfirmarPagoSaldoParams {
  final String citaId;
  final String solicitudId;
  final double monto;
  final String stripePaymentRef;

  const ConfirmarPagoSaldoParams({
    required this.citaId,
    required this.solicitudId,
    required this.monto,
    required this.stripePaymentRef,
  });
}

/// Confirma el cobro del saldo final vía RPC `confirmar_pago_saldo`.
/// Devuelve el `motivo` del RPC ('OK', 'YA_REGISTRADA', 'MONTO_INCORRECTO', ...).
class ConfirmarPagoSaldo extends UseCase<String, ConfirmarPagoSaldoParams> {
  final IPaymentsRepository _repository;

  ConfirmarPagoSaldo(this._repository);

  @override
  Future<Either<Failure, String>> call(ConfirmarPagoSaldoParams params) async {
    try {
      final motivo = await _repository.confirmarPagoSaldo(
        citaId: params.citaId,
        solicitudId: params.solicitudId,
        monto: params.monto,
        stripePaymentRef: params.stripePaymentRef,
      );
      return Right(motivo);
    } catch (e) {
      return Left(PaymentFailure('No se pudo confirmar el pago del saldo: $e'));
    }
  }
}