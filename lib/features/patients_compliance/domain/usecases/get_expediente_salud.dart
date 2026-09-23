import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../entities/expediente_salud_entity.dart';
import '../repositories/i_patients_compliance_repository.dart';

class GetExpedienteSaludParams {
  final String usuarioId;
  const GetExpedienteSaludParams({required this.usuarioId});
}

/// Obtiene el expediente de salud completo de un paciente (uso admin).
class GetExpedienteSalud extends UseCase<ExpedienteSaludEntity?, GetExpedienteSaludParams> {
  final IPatientsComplianceRepository _repository;
  GetExpedienteSalud(this._repository);

  @override
  Future<Either<Failure, ExpedienteSaludEntity?>> call(GetExpedienteSaludParams params) =>
      _repository.getExpedienteSalud(usuarioId: params.usuarioId);
}