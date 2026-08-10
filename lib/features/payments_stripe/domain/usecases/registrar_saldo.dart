import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../../domain/repositories/i_payments_repository.dart';

class RegistrarSaldoParams {
  final String citaId;
  final String solicitudId;
  final double monto;
  final String stripePaymentRef;

  const RegistrarSaldoParams({
    required this.citaId,
    required this.solicitudId,
    required this.monto,
    required this.stripePaymentRef,
  });
}

/// Cobra el saldo restante de la solicitud al finalizar el tratamiento.
/// Devuelve `false` si no había saldo pendiente.
class RegistrarSaldo extends UseCase<bool, RegistrarSaldoParams> {
  final IPaymentsRepository _repository;

  RegistrarSaldo(this._repository);

  @override
  Future<Either<Failure, bool>> call(RegistrarSaldoParams params) async {
    try {
      final registrado = await _repository.registrarPagoSaldo(
        citaId: params.citaId,
        solicitudId: params.solicitudId,
        monto: params.monto,
        stripePaymentRef: params.stripePaymentRef,
      );
      return Right(registrado);
    } catch (e) {
      return Left(ServerFailure('No se pudo registrar el saldo: $e'));
    }
  }
}