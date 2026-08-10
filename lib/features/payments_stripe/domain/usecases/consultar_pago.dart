import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../../domain/repositories/i_payments_repository.dart';
import '../../domain/entities/pago_entity.dart';

class ConsultarPagoParams {
  final String solicitudId;

  const ConsultarPagoParams({required this.solicitudId});
}

/// Consulta la obligación (pago) de una solicitud.
class ConsultarPago extends UseCase<PagoEntity?, ConsultarPagoParams> {
  final IPaymentsRepository _repository;

  ConsultarPago(this._repository);

  @override
  Future<Either<Failure, PagoEntity?>> call(ConsultarPagoParams params) async {
    try {
      final pago = await _repository.consultarPago(solicitudId: params.solicitudId);
      return Right(pago);
    } catch (e) {
      return Left(ServerFailure('No se pudo consultar el pago: $e'));
    }
  }
}