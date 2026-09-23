import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../repositories/i_patients_compliance_repository.dart';

class RegistrarAuditoriaExpedienteParams {
  final String pacienteId;
  final String accion;
  const RegistrarAuditoriaExpedienteParams({
    required this.pacienteId,
    required this.accion,
  });
}

/// Registra en `auditoria` el acceso/exportación del expediente de salud
/// (acciones `EXPEDIENTE_SALUD_VISTO` / `EXPEDIENTE_SALUD_PDF`).
class RegistrarAuditoriaExpediente
    extends UseCase<void, RegistrarAuditoriaExpedienteParams> {
  final IPatientsComplianceRepository _repository;
  RegistrarAuditoriaExpediente(this._repository);

  @override
  Future<Either<Failure, void>> call(RegistrarAuditoriaExpedienteParams params) =>
      _repository.registrarAuditoriaExpediente(
        pacienteId: params.pacienteId,
        accion: params.accion,
      );
}