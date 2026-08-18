import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../entities/evaluacion_salud_entity.dart';
import '../repositories/i_patients_compliance_repository.dart';

/// Obtiene la última evaluación de salud del paciente autenticado.
class GetUltimaEvaluacion extends NoParamsUseCase<EvaluacionSaludEntity?> {
  final IPatientsComplianceRepository _repository;
  GetUltimaEvaluacion(this._repository);

  @override
  Future<Either<Failure, EvaluacionSaludEntity?>> call() =>
      _repository.getUltimaEvaluacion();
}