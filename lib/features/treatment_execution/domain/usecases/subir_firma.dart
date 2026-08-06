import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../repositories/i_treatment_execution_repository.dart';

class SubirFirmaParams {
  final String tratamientoId;
  final Uint8List bytes;
  const SubirFirmaParams({
    required this.tratamientoId,
    required this.bytes,
  });
}

/// Sube la firma del paciente al bucket `firmas-consentimiento`.
class SubirFirma extends UseCase<String, SubirFirmaParams> {
  final ITreatmentExecutionRepository _repository;
  SubirFirma(this._repository);

  @override
  Future<Either<Failure, String>> call(SubirFirmaParams params) {
    return _repository.subirFirma(
      tratamientoId: params.tratamientoId,
      bytes: params.bytes,
    );
  }
}