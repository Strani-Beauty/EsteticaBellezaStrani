import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/medico_regente_entity.dart';
import '../repositories/i_specialists_repository.dart';

class GetMedicosRegentesParams {
  final bool soloActivos;
  const GetMedicosRegentesParams({this.soloActivos = true});
}

/// Lista los médicos regentes. Por defecto solo los activos (validados),
/// lo que permite al especialista elegir un médico regente aprobado.
class GetMedicosRegentes
    extends UseCase<List<MedicoRegenteEntity>, GetMedicosRegentesParams> {
  final ISpecialistsRepository _repository;
  GetMedicosRegentes(this._repository);

  @override
  Future<Either<Failure, List<MedicoRegenteEntity>>> call(
      GetMedicosRegentesParams params) {
    return _repository.getMedicosRegentes(soloActivos: params.soloActivos);
  }
}
