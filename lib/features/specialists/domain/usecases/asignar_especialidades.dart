import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/especialidad_entity.dart';
import '../repositories/i_specialists_repository.dart';

class AsignarEspecialidadesParams {
  final String especialistaId;
  final List<int> especialidadIds;
  const AsignarEspecialidadesParams({
    required this.especialistaId,
    required this.especialidadIds,
  });
}

/// Reemplaza el conjunto de especialidades que ofrece un especialista.
class AsignarEspecialidades
    extends UseCase<List<EspecialistaEspecialidadEntity>, AsignarEspecialidadesParams> {
  final ISpecialistsRepository _repository;
  AsignarEspecialidades(this._repository);

  @override
  Future<Either<Failure, List<EspecialistaEspecialidadEntity>>> call(
      AsignarEspecialidadesParams params) {
    return _repository.reemplazarEspecialidades(
      params.especialistaId,
      params.especialidadIds,
    );
  }
}
