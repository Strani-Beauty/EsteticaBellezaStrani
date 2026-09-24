import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../repositories/i_medical_interviews_repository.dart';

class FirmarUrlEntrevistaParams {
  final String path;
  const FirmarUrlEntrevistaParams({required this.path});
}

/// Genera una URL firmada (3600 s) para un objeto del bucket de entrevistas.
class FirmarUrlEntrevista extends UseCase<String?, FirmarUrlEntrevistaParams> {
  final IMedicalInterviewsRepository _repository;
  FirmarUrlEntrevista(this._repository);

  @override
  Future<Either<Failure, String?>> call(FirmarUrlEntrevistaParams params) =>
      _repository.firmarUrlEntrevista(params.path);
}
