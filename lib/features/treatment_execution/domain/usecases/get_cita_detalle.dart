import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/cita_ejecucion_entity.dart';
import '../repositories/i_treatment_execution_repository.dart';

class GetCitaDetalleParams {
  final String citaId;
  const GetCitaDetalleParams(this.citaId);
}

/// Detalle completo de una cita (paciente, servicio, tratamiento).
class GetCitaDetalle
    extends UseCase<CitaEjecucionEntity, GetCitaDetalleParams> {
  final ITreatmentExecutionRepository _repository;
  GetCitaDetalle(this._repository);

  @override
  Future<Either<Failure, CitaEjecucionEntity>> call(
      GetCitaDetalleParams params) {
    return _repository.getCitaDetalle(params.citaId);
  }
}
