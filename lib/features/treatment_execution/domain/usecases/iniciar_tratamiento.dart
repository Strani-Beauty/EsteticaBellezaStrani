import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/tratamiento_entity.dart';
import '../repositories/i_treatment_execution_repository.dart';

class IniciarTratamientoParams {
  final String citaId;
  final String? evaluacionInicial;
  const IniciarTratamientoParams({
    required this.citaId,
    this.evaluacionInicial,
  });
}

/// Crea el tratamiento `INICIADO` vinculado a la cita (si no existe ya).
class IniciarTratamiento
    extends UseCase<TratamientoEntity, IniciarTratamientoParams> {
  final ITreatmentExecutionRepository _repository;
  IniciarTratamiento(this._repository);

  @override
  Future<Either<Failure, TratamientoEntity>> call(
      IniciarTratamientoParams params) {
    return _repository.iniciarTratamiento(
      citaId: params.citaId,
      evaluacionInicial: params.evaluacionInicial,
    );
  }
}