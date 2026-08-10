import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../../domain/repositories/i_payments_repository.dart';

class CrearSolicitudDepositoParams {
  final String profileId;
  final String stripePaymentRef;
  final String? servicioId;

  const CrearSolicitudDepositoParams({
    required this.profileId,
    required this.stripePaymentRef,
    this.servicioId,
  });
}

/// Crea la cadena solicitud → pago → transacción al aprobarse Qualify.
class CrearSolicitudDeposito
    extends UseCase<String?, CrearSolicitudDepositoParams> {
  final IPaymentsRepository _repository;

  CrearSolicitudDeposito(this._repository);

  @override
  Future<Either<Failure, String?>> call(CrearSolicitudDepositoParams params) async {
    try {
      final solicitudId = await _repository.createSolicitudAndPayment(
        profileId: params.profileId,
        stripePaymentRef: params.stripePaymentRef,
        servicioId: params.servicioId,
      );
      return Right(solicitudId);
    } catch (e) {
      return Left(ServerFailure('No se pudo crear la solicitud: $e'));
    }
  }
}