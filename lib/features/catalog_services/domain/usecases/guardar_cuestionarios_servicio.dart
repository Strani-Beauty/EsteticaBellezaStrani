import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/servicio_cuestionario_entity.dart';
import '../repositories/i_catalog_repository.dart';

class GuardarCuestionariosServicioParams {
  final String servicioId;
  final List<ServicioCuestionarioEntity> items;

  const GuardarCuestionariosServicioParams({
    required this.servicioId,
    required this.items,
  });
}

/// Reemplaza los cuestionarios de un servicio (RPC atómico, solo admin).
class GuardarCuestionariosServicio
    extends UseCase<void, GuardarCuestionariosServicioParams> {
  final ICatalogRepository _repository;
  GuardarCuestionariosServicio(this._repository);

  @override
  Future<Either<Failure, void>> call(
      GuardarCuestionariosServicioParams params) {
    return _repository.guardarCuestionariosServicio(
      params.servicioId,
      params.items,
    );
  }
}