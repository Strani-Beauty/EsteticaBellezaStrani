import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../repositories/i_solicitudes_reserva_repository.dart';

class ConfirmarPagoDepositoParams {
  final String solicitudId;
  final String stripePaymentId;
  final String concepto;
  final double monto;

  const ConfirmarPagoDepositoParams({
    required this.solicitudId,
    required this.stripePaymentId,
    required this.concepto,
    required this.monto,
  });
}

/// Confirma el depósito y publica la solicitud. Devuelve el motivo:
/// 'CONFIRMADA' (publicada) o 'PENDIENTE_WEBHOOK' cuando la producción exige
/// confirmación por webhook (el pago ya fue cobrado, la publicación llegará
/// en unos segundos).
class ConfirmarPagoDeposito
    extends UseCase<String, ConfirmarPagoDepositoParams> {
  final ISolicitudesReservaRepository _repository;

  ConfirmarPagoDeposito(this._repository);

  @override
  Future<Either<Failure, String>> call(ConfirmarPagoDepositoParams params) async {
    try {
      return await _repository.confirmarPagoDeposito(
        solicitudId: params.solicitudId,
        stripePaymentId: params.stripePaymentId,
        concepto: params.concepto,
        monto: params.monto,
      );
    } catch (e) {
      return Left(PaymentFailure('No se pudo confirmar el pago: $e'));
    }
  }
}
