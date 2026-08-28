import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../../domain/entities/detalle_financiero_entity.dart';
import '../../domain/repositories/i_payments_repository.dart';

class GetDetalleFinancieroCitaParams {
  final String citaId;

  const GetDetalleFinancieroCitaParams({required this.citaId});
}

/// Detalle financiero de una cita: depósito, pago final, saldo y comisión.
class GetDetalleFinancieroCita
    extends UseCase<DetalleFinancieroCitaEntity?, GetDetalleFinancieroCitaParams> {
  final IPaymentsRepository _repository;

  GetDetalleFinancieroCita(this._repository);

  @override
  Future<Either<Failure, DetalleFinancieroCitaEntity?>> call(
      GetDetalleFinancieroCitaParams params) async {
    try {
      final detalle =
          await _repository.getDetalleFinancieroCita(params.citaId);
      return Right(detalle);
    } catch (e) {
      return Left(ServerFailure('No se pudo consultar el detalle: $e'));
    }
  }
}