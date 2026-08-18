import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../entities/evaluacion_salud_entity.dart';
import '../repositories/i_patients_compliance_repository.dart';

/// Obtiene la validación de telemedicina actual del paciente autenticado.
class GetMiValidacion extends NoParamsUseCase<ValidacionTelemedicinaEntity?> {
  final IPatientsComplianceRepository _repository;
  GetMiValidacion(this._repository);

  @override
  Future<Either<Failure, ValidacionTelemedicinaEntity?>> call() =>
      _repository.getMiValidacion();
}