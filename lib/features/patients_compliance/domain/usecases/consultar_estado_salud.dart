import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../entities/estado_salud_entity.dart';
import '../repositories/i_patients_compliance_repository.dart';

/// Consulta el estado integral de salud del paciente (requisito 13).
/// Fuente del gate RN-020 (requisito 12): `EstadoSaludEntity.habilitado`.
class ConsultarEstadoSalud extends NoParamsUseCase<EstadoSaludEntity> {
  final IPatientsComplianceRepository _repository;
  ConsultarEstadoSalud(this._repository);

  @override
  Future<Either<Failure, EstadoSaludEntity>> call() =>
      _repository.consultarEstadoSalud();
}