import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/face_map_especialista_entity.dart';
import '../repositories/i_treatment_execution_repository.dart';

/// Obtiene el face map del especialista para un tratamiento (o el del paciente
/// pre-tratamiento si aún no hay uno del especialista), con sus puntos.
class GetFaceMapPorTratamiento
    extends UseCase<FaceMapEspecialistaEntity?, String> {
  final ITreatmentExecutionRepository _repository;
  GetFaceMapPorTratamiento(this._repository);

  @override
  Future<Either<Failure, FaceMapEspecialistaEntity?>> call(
      String tratamientoId) {
    return _repository.getFaceMapPorTratamiento(tratamientoId);
  }
}