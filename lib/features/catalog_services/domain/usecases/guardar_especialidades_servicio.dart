import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../repositories/i_catalog_repository.dart';

class GuardarEspecialidadesServicioParams {
  final String servicioId;
  final List<int> especialidadIds;

  const GuardarEspecialidadesServicioParams({
    required this.servicioId,
    required this.especialidadIds,
  });
}

/// Reemplaza las especialidades de un servicio (RPC atómico, solo admin).
class GuardarEspecialidadesServicio
    extends UseCase<void, GuardarEspecialidadesServicioParams> {
  final ICatalogRepository _repository;
  GuardarEspecialidadesServicio(this._repository);

  @override
  Future<Either<Failure, void>> call(
      GuardarEspecialidadesServicioParams params) {
    return _repository.guardarEspecialidadesServicio(
      params.servicioId,
      params.especialidadIds,
    );
  }
}