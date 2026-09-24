import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../entities/entrevista_medica_entity.dart';
import '../repositories/i_medical_interviews_repository.dart';

class AgendarEntrevistaParams {
  final String pacienteId;
  final DateTime fechaProgramada;
  final int duracionMin;
  final String? evaluacionSaludId;

  const AgendarEntrevistaParams({
    required this.pacienteId,
    required this.fechaProgramada,
    this.duracionMin = 30,
    this.evaluacionSaludId,
  });
}

/// Agenda una entrevista médica F2F (admin).
class AgendarEntrevista
    extends UseCase<EntrevistaMedicaEntity, AgendarEntrevistaParams> {
  final IMedicalInterviewsRepository _repository;
  AgendarEntrevista(this._repository);

  @override
  Future<Either<Failure, EntrevistaMedicaEntity>> call(
          AgendarEntrevistaParams params) =>
      _repository.agendarEntrevista(
        pacienteId: params.pacienteId,
        fechaProgramada: params.fechaProgramada,
        duracionMin: params.duracionMin,
        evaluacionSaludId: params.evaluacionSaludId,
      );
}
