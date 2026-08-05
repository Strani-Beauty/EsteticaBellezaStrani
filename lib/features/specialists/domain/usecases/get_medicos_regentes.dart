import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/medico_regente_entity.dart';
import '../repositories/i_specialists_repository.dart';

/// Lista los médicos regentes activos.
class GetMedicosRegentes extends NoParamsUseCase<List<MedicoRegenteEntity>> {
  final ISpecialistsRepository _repository;
  GetMedicosRegentes(this._repository);

  @override
  Future<Either<Failure, List<MedicoRegenteEntity>>> call() {
    return _repository.getMedicosRegentes();
  }
}