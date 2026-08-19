import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/categoria_servicio_entity.dart';
import '../repositories/i_catalog_repository.dart';

/// Lista todas las categorías (incl. inactivas) — mantenimiento admin.
class GetCategoriasAdmin
    extends NoParamsUseCase<List<CategoriaServicioEntity>> {
  final ICatalogRepository _repository;
  GetCategoriasAdmin(this._repository);

  @override
  Future<Either<Failure, List<CategoriaServicioEntity>>> call() {
    return _repository.getCategoriasAdmin();
  }
}