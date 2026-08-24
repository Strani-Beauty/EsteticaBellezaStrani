import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../repositories/i_treatment_execution_repository.dart';

class CancelarCitaParams {
  final String citaId;
  final String? motivo;
  const CancelarCitaParams({required this.citaId, this.motivo});
}

/// Cancela la cita registrando el motivo y el usuario responsable.
class CancelarCita extends UseCase<void, CancelarCitaParams> {
  final ITreatmentExecutionRepository _repository;
  CancelarCita(this._repository);

  @override
  Future<Either<Failure, void>> call(CancelarCitaParams params) {
    return _repository.cancelarCita(citaId: params.citaId, motivo: params.motivo);
  }
}
