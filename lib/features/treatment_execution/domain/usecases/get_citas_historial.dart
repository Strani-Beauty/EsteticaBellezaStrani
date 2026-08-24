import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/cita_ejecucion_entity.dart';import '../repositories/i_treatment_execution_repository.dart';

class GetCitasHistorialParams {
  final String especialistaId;
  const GetCitasHistorialParams(this.especialistaId);
}

/// Todas las citas del especialista (incluye finalizadas, canceladas y no
/// completadas), para el historial de "Mis citas".
class GetCitasHistorial
    extends UseCase<List<CitaEjecucionEntity>, GetCitasHistorialParams> {
  final ITreatmentExecutionRepository _repository;
  GetCitasHistorial(this._repository);

  @override
  Future<Either<Failure, List<CitaEjecucionEntity>>> call(
      GetCitasHistorialParams params) {
    return _repository.getCitasHistorial(params.especialistaId);
  }
}
