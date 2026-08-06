import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/consentimiento_tratamiento_entity.dart';
import '../repositories/i_treatment_execution_repository.dart';

class GetConsentimiento
    extends UseCase<ConsentimientoTratamientoEntity?, String> {
  final ITreatmentExecutionRepository _repository;
  GetConsentimiento(this._repository);

  @override
  Future<Either<Failure, ConsentimientoTratamientoEntity?>> call(
      String tratamientoId) {
    return _repository.getConsentimiento(tratamientoId);
  }
}