import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../repositories/i_medical_interviews_repository.dart';

class RegistrarConsentimientoEntrevistaParams {
  final String entrevistaId;
  final Uint8List firmaBytes;

  const RegistrarConsentimientoEntrevistaParams({
    required this.entrevistaId,
    required this.firmaBytes,
  });
}

/// Sube la firma del paciente y registra su consentimiento (paciente dueño).
class RegistrarConsentimientoEntrevista
    extends UseCase<void, RegistrarConsentimientoEntrevistaParams> {
  final IMedicalInterviewsRepository _repository;
  RegistrarConsentimientoEntrevista(this._repository);

  @override
  Future<Either<Failure, void>> call(
          RegistrarConsentimientoEntrevistaParams params) =>
      _repository.registrarConsentimientoEntrevista(
        entrevistaId: params.entrevistaId,
        firmaBytes: params.firmaBytes,
      );
}
