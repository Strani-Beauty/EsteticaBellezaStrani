import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../entities/evaluacion_salud_entity.dart';
import '../repositories/i_patients_compliance_repository.dart';

class RegistrarValidacionTelemedicinaParams {
  final bool aprobado;
  final String proveedor;
  final String? codigoReferencia;

  const RegistrarValidacionTelemedicinaParams({
    required this.aprobado,
    required this.proveedor,
    this.codigoReferencia,
  });
}

/// Registra la validación de telemedicina vía RPC segura con fecha de
/// aprobación (now) y vencimiento (+365 días).
class RegistrarValidacionTelemedicina
    extends UseCase<ValidacionTelemedicinaEntity, RegistrarValidacionTelemedicinaParams> {
  final IPatientsComplianceRepository _repository;
  RegistrarValidacionTelemedicina(this._repository);

  @override
  Future<Either<Failure, ValidacionTelemedicinaEntity>> call(
      RegistrarValidacionTelemedicinaParams params) {
    return _repository.registrarValidacionTelemedicina(
      aprobado: params.aprobado,
      proveedor: params.proveedor,
      codigoReferencia: params.codigoReferencia,
    );
  }
}