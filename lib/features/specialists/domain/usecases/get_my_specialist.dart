import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/especialista_entity.dart';
import '../repositories/i_specialists_repository.dart';

class GetMySpecialistParams {
  final String usuarioId;
  const GetMySpecialistParams(this.usuarioId);
}

/// Obtiene el especialista vinculado al usuario (por `usuario_id`).
/// Devuelve null si el usuario aún no tiene registro de especialista.
class GetMySpecialist extends UseCase<EspecialistaEntity?, GetMySpecialistParams> {
  final ISpecialistsRepository _repository;
  GetMySpecialist(this._repository);

  @override
  Future<Either<Failure, EspecialistaEntity?>> call(GetMySpecialistParams params) {
    return _repository.getEspecialistaByUsuarioId(params.usuarioId);
  }
}