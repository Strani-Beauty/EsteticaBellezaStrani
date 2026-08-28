import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../repositories/i_treatment_execution_repository.dart';

/// Indica si la simulación de llegada al domicilio está habilitada (pruebas).
class GetSimularLlegada extends NoParamsUseCase<bool> {
  final ITreatmentExecutionRepository _repository;

  GetSimularLlegada(this._repository);

  @override
  Future<Either<Failure, bool>> call() async {
    try {
      return await _repository.getSimularLlegada();
    } catch (e) {
      return Left(
          ServerFailure('No se pudo cargar la configuración de llegada: $e'));
    }
  }
}