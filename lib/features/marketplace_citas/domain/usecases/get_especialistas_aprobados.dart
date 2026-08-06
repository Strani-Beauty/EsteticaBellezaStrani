import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/especialista_mapa_entity.dart';
import '../repositories/i_marketplace_repository.dart';

/// Lista los especialistas aprobados con su última ubicación.
class GetEspecialistasAprobados
    extends NoParamsUseCase<List<EspecialistaMapaEntity>> {
  final IMarketplaceRepository _repository;
  GetEspecialistasAprobados(this._repository);

  @override
  Future<Either<Failure, List<EspecialistaMapaEntity>>> call() {
    return _repository.getEspecialistasAprobados();
  }
}
