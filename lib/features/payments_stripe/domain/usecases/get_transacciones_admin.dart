import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../../domain/entities/transaccion_entity.dart';
import '../../domain/repositories/i_payments_repository.dart';

class GetTransaccionesAdminParams {
  final String? estado;
  final String? tipo;
  final DateTime? desde;
  final DateTime? hasta;

  const GetTransaccionesAdminParams({
    this.estado,
    this.tipo,
    this.desde,
    this.hasta,
  });
}

/// Lista transacciones para conciliación admin con filtros opcionales.
class GetTransaccionesAdmin
    extends UseCase<List<TransaccionEntity>, GetTransaccionesAdminParams> {
  final IPaymentsRepository _repository;

  GetTransaccionesAdmin(this._repository);

  @override
  Future<Either<Failure, List<TransaccionEntity>>> call(
      GetTransaccionesAdminParams params) async {
    try {
      final transacciones = await _repository.getTransaccionesAdmin(
        estado: params.estado,
        tipo: params.tipo,
        desde: params.desde,
        hasta: params.hasta,
      );
      return Right(transacciones);
    } catch (e) {
      return Left(ServerFailure('No se pudieron cargar las transacciones: $e'));
    }
  }
}