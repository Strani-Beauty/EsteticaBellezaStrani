import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/producto_aplicado_entity.dart';
import '../repositories/i_treatment_execution_repository.dart';

class GetProductos extends UseCase<List<ProductoAplicadoEntity>, String> {
  final ITreatmentExecutionRepository _repository;
  GetProductos(this._repository);

  @override
  Future<Either<Failure, List<ProductoAplicadoEntity>>> call(
      String tratamientoId) {
    return _repository.getProductos(tratamientoId);
  }
}