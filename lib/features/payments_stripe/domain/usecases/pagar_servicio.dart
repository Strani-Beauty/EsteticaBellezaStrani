import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../../domain/repositories/i_payments_repository.dart';

class PagarServicioParams {
  final String profileId;
  final String servicioId;
  final String serviceTitle;
  final double servicePrice;
  final bool payFullAmount;
  final double montoAPagar;
  final String stripePaymentRef;

  const PagarServicioParams({
    required this.profileId,
    required this.servicioId,
    required this.serviceTitle,
    required this.servicePrice,
    required this.payFullAmount,
    required this.montoAPagar,
    required this.stripePaymentRef,
  });
}

/// Reserva un servicio del catálogo pagando adelanto o totalidad.
class PagarServicio extends UseCase<String?, PagarServicioParams> {
  final IPaymentsRepository _repository;

  PagarServicio(this._repository);

  @override
  Future<Either<Failure, String?>> call(PagarServicioParams params) async {
    try {
      final solicitudId = await _repository.createServicePayment(
        profileId: params.profileId,
        servicioId: params.servicioId,
        servicePrice: params.servicePrice,
        payFullAmount: params.payFullAmount,
        montoAPagar: params.montoAPagar,
        stripePaymentRef: params.stripePaymentRef,
      );
      return Right(solicitudId);
    } catch (e) {
      return Left(
          ServerFailure('No se pudo registrar el pago del servicio: $e'));
    }
  }
}