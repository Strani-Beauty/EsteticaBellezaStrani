import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../entities/entrevista_medica_entity.dart';
import '../repositories/i_medical_interviews_repository.dart';

class GetEntrevistasParams {
  final String? estado;
  const GetEntrevistasParams({this.estado});
}

/// Lista las entrevistas médicas (uso admin), opcionalmente por estado.
class GetEntrevistas
    extends UseCase<List<EntrevistaMedicaEntity>, GetEntrevistasParams> {
  final IMedicalInterviewsRepository _repository;
  GetEntrevistas(this._repository);

  @override
  Future<Either<Failure, List<EntrevistaMedicaEntity>>> call(
          GetEntrevistasParams params) =>
      _repository.getEntrevistas(estado: params.estado);
}
