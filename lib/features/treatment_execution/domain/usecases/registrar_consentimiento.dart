import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/consentimiento_tratamiento_entity.dart';
import '../repositories/i_treatment_execution_repository.dart';

class RegistrarConsentimientoParams {
  final String tratamientoId;
  final String pacienteId;
  final String tipoConsentimiento;
  final String firmaUrl;
  const RegistrarConsentimientoParams({
    required this.tratamientoId,
    required this.pacienteId,
    required this.tipoConsentimiento,
    required this.firmaUrl,
  });
}

/// Registra el consentimiento firmado por el paciente (firma ya subida a
/// storage; este use case guarda la fila).
class RegistrarConsentimiento
    extends UseCase<ConsentimientoTratamientoEntity, RegistrarConsentimientoParams> {
  final ITreatmentExecutionRepository _repository;
  RegistrarConsentimiento(this._repository);

  @override
  Future<Either<Failure, ConsentimientoTratamientoEntity>> call(
      RegistrarConsentimientoParams params) {
    return _repository.registrarConsentimiento(
      tratamientoId: params.tratamientoId,
      pacienteId: params.pacienteId,
      tipoConsentimiento: params.tipoConsentimiento,
      firmaUrl: params.firmaUrl,
    );
  }
}