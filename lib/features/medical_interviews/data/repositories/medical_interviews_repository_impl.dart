import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../domain/entities/entrevista_medica_entity.dart';
import '../../domain/repositories/i_medical_interviews_repository.dart';
import '../datasources/medical_interviews_supabase_datasource.dart';

/// Implementación del repositorio de entrevistas médicas F2F.
/// Envuelve las excepciones del datasource en `Failure` (patrón del proyecto).
class MedicalInterviewsRepositoryImpl implements IMedicalInterviewsRepository {
  final MedicalInterviewsSupabaseDataSource _datasource;

  const MedicalInterviewsRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, List<EntrevistaMedicaEntity>>> getEntrevistas({
    String? estado,
  }) async {
    try {
      final rows = await _datasource.fetchEntrevistas(estado: estado);
      return Right([for (final r in rows) r.toEntity()]);
    } catch (e) {
      return Left(ServerFailure(
        mensajeDeErrorAmigable('No se pudieron cargar las entrevistas', e),
      ));
    }
  }

  @override
  Future<Either<Failure, EntrevistaMedicaEntity?>> getMiEntrevista() async {
    try {
      final row = await _datasource.fetchMiEntrevista();
      return Right(row?.toEntity());
    } catch (e) {
      return Left(ServerFailure(
        mensajeDeErrorAmigable('No se pudo cargar tu entrevista', e),
      ));
    }
  }

  @override
  Future<Either<Failure, EntrevistaMedicaEntity>> agendarEntrevista({
    required String pacienteId,
    required DateTime fechaProgramada,
    int duracionMin = 30,
    String? evaluacionSaludId,
  }) async {
    try {
      final row = await _datasource.agendarEntrevista(
        pacienteId: pacienteId,
        fechaProgramada: fechaProgramada,
        duracionMin: duracionMin,
        evaluacionSaludId: evaluacionSaludId,
      );
      return Right(row.toEntity());
    } catch (e) {
      return Left(ServerFailure(
        mensajeDeErrorAmigable('No se pudo agendar la entrevista', e),
      ));
    }
  }

  @override
  Future<Either<Failure, void>> iniciarEntrevista(String entrevistaId) async {
    try {
      await _datasource.iniciarEntrevista(entrevistaId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(
        mensajeDeErrorAmigable('No se pudo iniciar la entrevista', e),
      ));
    }
  }

  @override
  Future<Either<Failure, void>> emitirDictamenEntrevista({
    required String entrevistaId,
    required bool aprobado,
    required String observaciones,
    String? hallazgos,
  }) async {
    try {
      await _datasource.emitirDictamenEntrevista(
        entrevistaId: entrevistaId,
        aprobado: aprobado,
        observaciones: observaciones,
        hallazgos: hallazgos,
      );
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(
        mensajeDeErrorAmigable('No se pudo emitir el dictamen', e),
      ));
    }
  }

  @override
  Future<Either<Failure, void>> registrarConsentimientoEntrevista({
    required String entrevistaId,
    required Uint8List firmaBytes,
  }) async {
    try {
      final path = await _datasource.subirFirmaEntrevista(
        entrevistaId: entrevistaId,
        bytes: firmaBytes,
      );
      await _datasource.registrarConsentimientoEntrevista(
        entrevistaId: entrevistaId,
        firmaUrl: path,
      );
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(
        mensajeDeErrorAmigable('No se pudo registrar el consentimiento', e),
      ));
    }
  }

  @override
  Future<Either<Failure, void>> guardarGrabacionEntrevista({
    required String entrevistaId,
    required Uint8List bytes,
    String extension = 'webm',
  }) async {
    try {
      final path = await _datasource.subirGrabacionEntrevista(
        entrevistaId: entrevistaId,
        bytes: bytes,
        extension: extension,
      );
      await _datasource.registrarGrabacionEntrevista(
        entrevistaId: entrevistaId,
        path: path,
      );
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(
        mensajeDeErrorAmigable('No se pudo guardar la grabación', e),
      ));
    }
  }

  @override
  Future<Either<Failure, void>> guardarNotasEntrevista({
    required String entrevistaId,
    required String notasClinicas,
    String? hallazgos,
  }) async {
    try {
      await _datasource.updateNotasEntrevista(
        entrevistaId: entrevistaId,
        notasClinicas: notasClinicas,
        hallazgos: hallazgos,
      );
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(
        mensajeDeErrorAmigable('No se pudieron guardar las notas', e),
      ));
    }
  }

  @override
  Future<Either<Failure, String?>> firmarUrlEntrevista(String path) async {
    try {
      final url = await _datasource.firmarUrlEntrevista(path);
      return Right(url);
    } catch (e) {
      return Left(ServerFailure(
        mensajeDeErrorAmigable('No se pudo generar el enlace del archivo', e),
      ));
    }
  }
}
