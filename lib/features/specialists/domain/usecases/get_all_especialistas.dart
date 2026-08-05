import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/especialista_entity.dart';
import '../repositories/i_specialists_repository.dart';

/// Lista todos los especialistas (uso administrativo).
class GetAllEspecialistas
    extends UseCase<List<EspecialistaEntity>, NoParams> {
  final ISpecialistsRepository _repository;
  GetAllEspecialistas(this._repository);

  @override
  Future<Either<Failure, List<EspecialistaEntity>>> call(NoParams params) {
    return _repository.getEspecialistas();
  }
}
