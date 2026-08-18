import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../entities/paciente_entity.dart';
import '../repositories/i_patients_compliance_repository.dart';

/// Obtiene los datos del paciente del usuario autenticado.
class GetMiPaciente extends NoParamsUseCase<PacienteEntity?> {
  final IPatientsComplianceRepository _repository;
  GetMiPaciente(this._repository);

  @override
  Future<Either<Failure, PacienteEntity?>> call() => _repository.getMiPaciente();
}