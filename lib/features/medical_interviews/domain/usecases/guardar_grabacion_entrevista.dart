import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../repositories/i_medical_interviews_repository.dart';

class GuardarGrabacionEntrevistaParams {
  final String entrevistaId;
  final Uint8List bytes;
  final String extension;

  const GuardarGrabacionEntrevistaParams({
    required this.entrevistaId,
    required this.bytes,
    this.extension = 'webm',
  });
}

/// Sube la grabación local de la entrevista y la liga (admin).
class GuardarGrabacionEntrevista
    extends UseCase<void, GuardarGrabacionEntrevistaParams> {
  final IMedicalInterviewsRepository _repository;
  GuardarGrabacionEntrevista(this._repository);

  @override
  Future<Either<Failure, void>> call(GuardarGrabacionEntrevistaParams params) =>
      _repository.guardarGrabacionEntrevista(
        entrevistaId: params.entrevistaId,
        bytes: params.bytes,
        extension: params.extension,
      );
}
