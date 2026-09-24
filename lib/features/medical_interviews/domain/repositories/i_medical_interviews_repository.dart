import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../entities/entrevista_medica_entity.dart';

/// Contrato del repositorio de entrevistas médicas F2F (ePHI).
abstract class IMedicalInterviewsRepository {
  /// Lista las entrevistas (admin), opcionalmente filtradas por estado.
  Future<Either<Failure, List<EntrevistaMedicaEntity>>> getEntrevistas({
    String? estado,
  });

  /// Última entrevista del paciente autenticado (o `null`).
  Future<Either<Failure, EntrevistaMedicaEntity?>> getMiEntrevista();

  /// Agenda una entrevista (RPC admin) y devuelve la fila creada.
  Future<Either<Failure, EntrevistaMedicaEntity>> agendarEntrevista({
    required String pacienteId,
    required DateTime fechaProgramada,
    int duracionMin,
    String? evaluacionSaludId,
  });

  /// Marca la entrevista como `EN_CURSO`.
  Future<Either<Failure, void>> iniciarEntrevista(String entrevistaId);

  /// Emite el dictamen del examen médico total (desbloquea RN-020).
  Future<Either<Failure, void>> emitirDictamenEntrevista({
    required String entrevistaId,
    required bool aprobado,
    required String observaciones,
    String? hallazgos,
  });

  /// Sube la firma del paciente al bucket privado y registra su consentimiento.
  Future<Either<Failure, void>> registrarConsentimientoEntrevista({
    required String entrevistaId,
    required Uint8List firmaBytes,
  });

  /// Sube la grabación local al bucket privado y la liga a la entrevista.
  Future<Either<Failure, void>> guardarGrabacionEntrevista({
    required String entrevistaId,
    required Uint8List bytes,
    String extension,
  });

  /// Guarda notas clínicas / hallazgos del médico (admin).
  Future<Either<Failure, void>> guardarNotasEntrevista({
    required String entrevistaId,
    required String notasClinicas,
    String? hallazgos,
  });

  /// Genera una URL firmada (3600 s) para un objeto del bucket de entrevistas.
  Future<Either<Failure, String?>> firmarUrlEntrevista(String path);
}
