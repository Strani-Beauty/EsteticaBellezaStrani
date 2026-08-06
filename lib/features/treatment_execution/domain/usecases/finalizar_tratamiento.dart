import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../repositories/i_treatment_execution_repository.dart';

class FinalizarTratamientoParams {
  final String citaId;
  final String tratamientoId;
  final String? observacionesFinales;
  final String? recomendacionesPostTratamiento;
  const FinalizarTratamientoParams({
    required this.citaId,
    required this.tratamientoId,
    this.observacionesFinales,
    this.recomendacionesPostTratamiento,
  });
}

/// Completa el tratamiento (COMPLETADO) y finaliza la cita (FINALIZADA).
class FinalizarTratamiento
    extends UseCase<void, FinalizarTratamientoParams> {
  final ITreatmentExecutionRepository _repository;
  FinalizarTratamiento(this._repository);

  @override
  Future<Either<Failure, void>> call(FinalizarTratamientoParams params) {
    return _repository.finalizarTratamiento(
      citaId: params.citaId,
      tratamientoId: params.tratamientoId,
      observacionesFinales: params.observacionesFinales,
      recomendacionesPostTratamiento: params.recomendacionesPostTratamiento,
    );
  }
}