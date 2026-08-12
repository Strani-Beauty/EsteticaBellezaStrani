import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/disponibilidad_entity.dart';
import '../repositories/i_specialists_repository.dart';

class SetDisponibilidadParams {
  final String especialistaId;
  final EstadoDisponibilidad estado;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  const SetDisponibilidadParams({
    required this.especialistaId,
    required this.estado,
    this.fechaInicio,
    this.fechaFin,
  });
}

/// Alterna la disponibilidad del especialista.
class SetDisponibilidad
    extends UseCase<DisponibilidadEntity, SetDisponibilidadParams> {
  final ISpecialistsRepository _repository;
  SetDisponibilidad(this._repository);

  @override
  Future<Either<Failure, DisponibilidadEntity>> call(SetDisponibilidadParams params) {
    return _repository.setDisponibilidad(
      params.especialistaId,
      params.estado,
      fechaInicio: params.fechaInicio,
      fechaFin: params.fechaFin,
    );
  }
}

/// Upsert lógico de disponibilidad: inserta o actualiza la fila vigente.
class UpsertDisponibilidad
    extends UseCase<DisponibilidadEntity, SetDisponibilidadParams> {
  final ISpecialistsRepository _repository;
  UpsertDisponibilidad(this._repository);

  @override
  Future<Either<Failure, DisponibilidadEntity>> call(SetDisponibilidadParams params) {
    return _repository.upsertDisponibilidad(
      params.especialistaId,
      params.estado,
      fechaInicio: params.fechaInicio,
      fechaFin: params.fechaFin,
    );
  }
}