import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../repositories/i_treatment_execution_repository.dart';

class EliminarProductoParams {
  final String productoId;
  const EliminarProductoParams(this.productoId);
}

/// Elimina un insumo aplicado del tratamiento.
class EliminarProducto extends UseCase<void, EliminarProductoParams> {
  final ITreatmentExecutionRepository _repository;
  EliminarProducto(this._repository);

  @override
  Future<Either<Failure, void>> call(EliminarProductoParams params) {
    return _repository.eliminarProducto(params.productoId);
  }
}