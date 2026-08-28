import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../../domain/repositories/i_payments_repository.dart';

class RegistrarPagoFallidoParams {
  final String citaId;
  final String solicitudId;
  final double monto;
  final String stripePaymentRef;
  final String motivo;
  final String tipo;

  const RegistrarPagoFallidoParams({
    required this.citaId,
    required this.solicitudId,
    required this.monto,
    required this.stripePaymentRef,
    required this.motivo,
    required this.tipo,
  });
}

/// Registra una transacción FALLIDA (pago rechazado/cancelado) sin marcar la
/// cita como financieramente completada. Devuelve el `motivo` del RPC.
class RegistrarPagoFallido extends UseCase<String, RegistrarPagoFallidoParams> {
  final IPaymentsRepository _repository;

  RegistrarPagoFallido(this._repository);

  @override
  Future<Either<Failure, String>> call(RegistrarPagoFallidoParams params) async {
    try {
      final motivo = await _repository.registrarPagoFallido(
        citaId: params.citaId,
        solicitudId: params.solicitudId,
        monto: params.monto,
        stripePaymentRef: params.stripePaymentRef,
        motivo: params.motivo,
        tipo: params.tipo,
      );
      return Right(motivo);
    } catch (e) {
      return Left(
          PaymentFailure('No se pudo registrar el pago fallido: $e'));
    }
  }
}