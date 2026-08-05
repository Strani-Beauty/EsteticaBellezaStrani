import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/especialidad_entity.dart';
import '../repositories/i_specialists_repository.dart';

/// Lista las especialidades activas del catálogo.
class GetEspecialidades extends NoParamsUseCase<List<EspecialidadEntity>> {
  final ISpecialistsRepository _repository;
  GetEspecialidades(this._repository);

  @override
  Future<Either<Failure, List<EspecialidadEntity>>> call() {
    return _repository.getEspecialidades();
  }
}

class GetEspecialistaEspecialidadesParams {
  final String especialistaId;
  const GetEspecialistaEspecialidadesParams(this.especialistaId);
}

/// Lista las especialidades asignadas a un especialista.
class GetEspecialistaEspecialidades
    extends UseCase<List<EspecialistaEspecialidadEntity>, GetEspecialistaEspecialidadesParams> {
  final ISpecialistsRepository _repository;
  GetEspecialistaEspecialidades(this._repository);

  @override
  Future<Either<Failure, List<EspecialistaEspecialidadEntity>>> call(
      GetEspecialistaEspecialidadesParams params) {
    return _repository.getEspecialistaEspecialidades(params.especialistaId);
  }
}