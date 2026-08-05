import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/disponibilidad_entity.dart';
import '../repositories/i_specialists_repository.dart';

class GetDisponibilidadParams {
  final String especialistaId;
  const GetDisponibilidadParams(this.especialistaId);
}

/// Obtiene la disponibilidad vigente del especialista.
class GetDisponibilidad
    extends UseCase<DisponibilidadEntity?, GetDisponibilidadParams> {
  final ISpecialistsRepository _repository;
  GetDisponibilidad(this._repository);

  @override
  Future<Either<Failure, DisponibilidadEntity?>> call(GetDisponibilidadParams params) {
    return _repository.getDisponibilidad(params.especialistaId);
  }
}