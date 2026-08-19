import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/servicio_cuestionario_entity.dart';
import '../repositories/i_catalog_repository.dart';

class GetRequisitosServicioParams {
  final String servicioId;
  const GetRequisitosServicioParams(this.servicioId);
}

/// Requisitos configurados de un servicio (especialidades + cuestionarios).
class GetRequisitosServicio
    extends UseCase<ServicioRequisitosEntity, GetRequisitosServicioParams> {
  final ICatalogRepository _repository;
  GetRequisitosServicio(this._repository);

  @override
  Future<Either<Failure, ServicioRequisitosEntity>> call(
      GetRequisitosServicioParams params) {
    return _repository.getRequisitosServicio(params.servicioId);
  }
}