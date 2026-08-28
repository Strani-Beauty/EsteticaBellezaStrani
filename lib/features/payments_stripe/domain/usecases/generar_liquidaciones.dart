import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../../domain/entities/detalle_financiero_entity.dart';
import '../../domain/repositories/i_payments_repository.dart';

class GenerarLiquidacionesParams {
  final DateTime fechaInicio;
  final DateTime fechaFin;

  const GenerarLiquidacionesParams({
    required this.fechaInicio,
    required this.fechaFin,
  });
}

/// Genera liquidaciones semanales por especialista vía RPC (solo admin).
class GenerarLiquidaciones
    extends UseCase<GenerarLiquidacionesEntity, GenerarLiquidacionesParams> {
  final IPaymentsRepository _repository;

  GenerarLiquidaciones(this._repository);

  @override
  Future<Either<Failure, GenerarLiquidacionesEntity>> call(
      GenerarLiquidacionesParams params) async {
    try {
      final resultado = await _repository.generarLiquidaciones(
        fechaInicio: params.fechaInicio,
        fechaFin: params.fechaFin,
      );
      return Right(resultado);
    } catch (e) {
      return Left(ServerFailure('No se pudieron generar las liquidaciones: $e'));
    }
  }
}