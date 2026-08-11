import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/medico_regente_entity.dart';
import '../repositories/i_specialists_repository.dart';

class AprobarMedicoRegenteParams {
  final String id;
  const AprobarMedicoRegenteParams(this.id);
}

/// Valida un médico regente (PENDIENTE -> ACTIVO) desde el panel de admin.
class AprobarMedicoRegente
    extends UseCase<MedicoRegenteEntity, AprobarMedicoRegenteParams> {
  final ISpecialistsRepository _repository;
  AprobarMedicoRegente(this._repository);

  @override
  Future<Either<Failure, MedicoRegenteEntity>> call(
      AprobarMedicoRegenteParams params) {
    return _repository.aprobarMedicoRegente(params.id);
  }
}
