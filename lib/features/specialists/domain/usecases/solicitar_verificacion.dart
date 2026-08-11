import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/especialista_entity.dart';
import '../repositories/i_specialists_repository.dart';

class SolicitarVerificacionParams {
  final String especialistaId;
  const SolicitarVerificacionParams(this.especialistaId);
}

/// Marca la solicitud de verificación como EN_REVISION: el especialista ya
/// completó sus datos profesionales y documentos y queda a la espera de que
/// el administrador valide.
class SolicitarVerificacion
    extends UseCase<EspecialistaEntity, SolicitarVerificacionParams> {
  final ISpecialistsRepository _repository;
  SolicitarVerificacion(this._repository);

  @override
  Future<Either<Failure, EspecialistaEntity>> call(SolicitarVerificacionParams params) {
    return _repository.solicitarVerificacion(params.especialistaId);
  }
}