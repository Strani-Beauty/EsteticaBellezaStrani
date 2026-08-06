import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/cita_ejecucion_entity.dart';
import '../repositories/i_treatment_execution_repository.dart';

class AvanzarEstadoCitaParams {
  final String citaId;
  final EstadoCitaEjecucion nuevoEstado;
  final String? observaciones;
  const AvanzarEstadoCitaParams({
    required this.citaId,
    required this.nuevoEstado,
    this.observaciones,
  });
}

/// Avanza el ciclo de la cita (EN_CAMINO, LLEGO, EN_PROCESO, FINALIZADA…)
/// y registra la transición en `historial_estados`.
class AvanzarEstadoCita
    extends UseCase<CitaEjecucionEntity, AvanzarEstadoCitaParams> {
  final ITreatmentExecutionRepository _repository;
  AvanzarEstadoCita(this._repository);

  @override
  Future<Either<Failure, CitaEjecucionEntity>> call(
      AvanzarEstadoCitaParams params) {
    return _repository.avanzarEstadoCita(
      citaId: params.citaId,
      nuevoEstado: params.nuevoEstado,
      observaciones: params.observaciones,
    );
  }
}
