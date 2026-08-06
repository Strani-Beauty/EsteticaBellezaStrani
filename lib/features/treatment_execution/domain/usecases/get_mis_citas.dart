import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/cita_ejecucion_entity.dart';
import '../repositories/i_treatment_execution_repository.dart';

class GetMisCitasParams {
  final String especialistaId;
  const GetMisCitasParams(this.especialistaId);
}

/// Citas asignadas al especialista pendientes de ejecución.
class GetMisCitas
    extends UseCase<List<CitaEjecucionEntity>, GetMisCitasParams> {
  final ITreatmentExecutionRepository _repository;
  GetMisCitas(this._repository);

  @override
  Future<Either<Failure, List<CitaEjecucionEntity>>> call(
      GetMisCitasParams params) {
    return _repository.getMisCitas(params.especialistaId);
  }
}
