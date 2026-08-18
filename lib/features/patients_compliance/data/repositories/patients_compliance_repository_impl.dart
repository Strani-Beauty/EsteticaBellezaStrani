import 'package:fpdart/fpdart.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/network/supabase_service.dart';
import '../../domain/entities/cuestionario_entity.dart';
import '../../domain/entities/estado_salud_entity.dart';
import '../../domain/entities/evaluacion_salud_entity.dart';
import '../../domain/entities/paciente_entity.dart';
import '../../domain/repositories/i_patients_compliance_repository.dart';
import '../datasources/patients_compliance_supabase_datasource.dart';

/// Implementación del repositorio de compliance del paciente con Clean
/// Architecture: inyecta un datasource de Supabase y devuelve `Either`.
class PatientsComplianceRepositoryImpl implements IPatientsComplianceRepository {
  final PatientsComplianceSupabaseDataSource _datasource;

  const PatientsComplianceRepositoryImpl(this._datasource);

  // ── Paciente ───────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, PacienteEntity?>> getMiPaciente() async {
    try {
      final model = await _datasource.fetchMiPaciente();
      return Right(model?.toEntity());
    } catch (e) {
      return Left(ServerFailure('No se pudo consultar el paciente: $e'));
    }
  }

  @override
  Future<Either<Failure, PacienteEntity?>> updateMiPaciente({
    DateTime? fechaNacimiento,
    String? genero,
    String? grupoSanguineo,
    String? alergias,
    String? antecedentes,
    bool? activo,
  }) async {
    try {
      final model = await _datasource.updateMiPaciente(
        fechaNacimiento: fechaNacimiento,
        genero: genero,
        grupoSanguineo: grupoSanguineo,
        alergias: alergias,
        antecedentes: antecedentes,
        activo: activo,
      );
      return Right(model?.toEntity());
    } catch (e) {
      return Left(ServerFailure('No se pudo actualizar el paciente: $e'));
    }
  }

  // ── Cuestionarios y preguntas ─────────────────────────────────────────────

  @override
  Future<Either<Failure, List<CuestionarioEntity>>> getCuestionarios({
    bool soloActivos = false,
  }) async {
    try {
      final models = await _datasource.fetchCuestionarios(soloActivos: soloActivos);
      return Right([for (final m in models) m.toEntity()]);
    } catch (e) {
      return Left(ServerFailure('No se pudieron consultar los cuestionarios: $e'));
    }
  }

  @override
  Future<Either<Failure, CuestionarioEntity?>> getCuestionarioActivo() async {
    try {
      final model = await _datasource.fetchCuestionarioActivo();
      return Right(model?.toEntity());
    } catch (e) {
      return Left(ServerFailure('No se pudo consultar el cuestionario activo: $e'));
    }
  }

  @override
  Future<Either<Failure, List<PreguntaEntity>>> getCuestionarioPreguntas(
    int cuestionarioId,
  ) async {
    try {
      final models = await _datasource.fetchCuestionarioPreguntas(cuestionarioId);
      return Right([for (final m in models) m.toEntity()]);
    } catch (e) {
      return Left(ServerFailure('No se pudieron consultar las preguntas: $e'));
    }
  }

  @override
  Future<Either<Failure, CuestionarioEntity>> crearNuevaVersionCuestionario(
    int versionActualId,
  ) async {
    try {
      final model = await _datasource.crearNuevaVersion(versionActualId);
      return Right(model.toEntity());
    } catch (e) {
      return Left(ServerFailure('No se pudo crear la nueva versión: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> activarVersionCuestionario(int cuestionarioId) async {
    try {
      await _datasource.activarVersion(cuestionarioId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('No se pudo activar la versión: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updatePregunta({
    required int preguntaId,
    String? texto,
    String? tipoRespuesta,
    bool? obligatoria,
    List<String>? opciones,
    Map<String, dynamic>? riesgo,
    bool? activo,
  }) async {
    try {
      await _datasource.updatePregunta(
        preguntaId: preguntaId,
        texto: texto,
        tipoRespuesta: tipoRespuesta,
        obligatoria: obligatoria,
        opciones: opciones,
        riesgo: riesgo,
        activo: activo,
      );
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('No se pudo editar la pregunta: $e'));
    }
  }

  // ── Evaluación de salud ────────────────────────────────────────────────────

  @override
  Future<Either<Failure, ResultadoEvaluacionRegistrada>> guardarRespuestasEvaluacion({
    required int cuestionarioId,
    required Map<int, String> respuestas,
  }) async {
    try {
      final result = await _datasource.guardarRespuestasEvaluacion(
        cuestionarioId: cuestionarioId,
        respuestas: respuestas,
      );
      return Right(ResultadoEvaluacionRegistrada.fromJson(result));
    } catch (e) {
      return Left(ServerFailure('No se pudo guardar la evaluación de salud: $e'));
    }
  }

  @override
  Future<Either<Failure, EvaluacionSaludEntity?>> getUltimaEvaluacion() async {
    try {
      final model = await _datasource.fetchUltimaEvaluacion();
      return Right(model?.toEntity());
    } catch (e) {
      return Left(ServerFailure('No se pudo consultar la última evaluación: $e'));
    }
  }

  // ── Validación de telemedicina ─────────────────────────────────────────────

  @override
  Future<Either<Failure, ValidacionTelemedicinaEntity>> registrarValidacionTelemedicina({
    required bool aprobado,
    required String proveedor,
    String? codigoReferencia,
  }) async {
    try {
      final result = await _datasource.registrarValidacionTelemedicina(
        aprobado: aprobado,
        proveedor: proveedor,
        codigoReferencia: codigoReferencia,
      );
      return Right(ValidacionTelemedicinaEntity(
        id: (result['id'] as String?) ?? '',
        pacienteId: '',
        proveedor: (result['proveedor'] as String?) ?? proveedor,
        estado: (result['estado'] as String?) ?? 'PENDIENTE',
        codigoReferencia: result['codigo_referencia'] as String?,
        fechaValidacion: DateTime.tryParse(
            (result['fecha_validacion'] as String?) ?? ''),
        fechaVencimiento: DateTime.tryParse(
            (result['fecha_vencimiento'] as String?) ?? ''),
        createdAt: DateTime.now(),
      ));
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains('RN-020') || msg.toLowerCase().contains('rn-020')) {
        return Left(TelemedinaFailure('RN-020: no puedes solicitar este servicio sin validación vigente.', code: 'RN020'));
      }
      return Left(ServerFailure('No se pudo registrar la validación de telemedicina: $e'));
    } catch (e) {
      return Left(ServerFailure('No se pudo registrar la validación de telemedicina: $e'));
    }
  }

  @override
  Future<Either<Failure, ValidacionTelemedicinaEntity?>> getMiValidacion() async {
    try {
      final model = await _datasource.fetchMiValidacion();
      return Right(model?.toEntity());
    } catch (e) {
      return Left(ServerFailure('No se pudo consultar la validación de telemedicina: $e'));
    }
  }

  // ── Estado del flujo y acceso ──────────────────────────────────────────────

  @override
  Future<Either<Failure, EstadoSaludEntity>> consultarEstadoSalud() async {
    try {
      final profile = await _datasource.fetchMiProfile();
      final evaluacion = await _datasource.fetchUltimaEvaluacion();
      final validacion = await _datasource.fetchMiValidacion();

      String validacionEstado = validacion?.estado ?? 'PENDIENTE';
      if (validacionEstado == 'APROBADA' &&
          (validacion?.fechaVencimiento == null ||
              !validacion!.fechaVencimiento!.isAfter(DateTime.now()))) {
        validacionEstado = 'VENCIDA';
      }

      return Right(EstadoSaludEntity(
        paymentCompleted: profile?['payment_completed'] == true,
        cuestionarioCompletado: evaluacion != null,
        evaluacionResultado: evaluacion?.resultado?.toDb() ?? 'PENDIENTE',
        validacionEstado: validacionEstado,
        proveedor: validacion?.proveedor ?? 'Telemedicina',
        fechaVencimiento: validacion?.fechaVencimiento,
      ));
    } catch (e) {
      return Left(ServerFailure('No se pudo consultar el estado de salud: $e'));
    }
  }

  // ── Métodos legacy (pendientes de migrar por completo) ─────────────────────

  @override
  Future<LatLng?> geocodeAddress(String address) =>
      SupabaseService.geocodeAddress(address);

  @override
  Future<String?> savePatientAddress({
    required String profileId,
    required String address,
    required double latitude,
    required double longitude,
  }) =>
      SupabaseService.savePatientAddress(
        profileId: profileId,
        address: address,
        latitude: latitude,
        longitude: longitude,
      );

  /// Reimplementado sobre la RPC segura (el insert directo rompería RLS).
  @override
  Future<bool> saveHealthEvaluation({
    required String profileId,
    required String serviceName,
    required Map<String, String> answers,
  }) async {
    try {
      final cuestionario = await _datasource.fetchCuestionarioActivo();
      if (cuestionario == null) return false;
      final respuestas = <int, String>{};
      for (final entry in answers.entries) {
        final id = int.tryParse(entry.key);
        if (id != null) respuestas[id] = entry.value;
      }
      await _datasource.guardarRespuestasEvaluacion(
        cuestionarioId: cuestionario.id,
        respuestas: respuestas,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Reimplementado sobre la RPC segura (`registrar_validacion_telemedicina`).
  @override
  Future<void> saveQualifyTestValidation({
    required String profileId,
    required bool aprobado,
    String proveedor = 'Telemedicina',
  }) async {
    await _datasource.registrarValidacionTelemedicina(
      aprobado: aprobado,
      proveedor: proveedor,
    );
  }

  @override
  Future<bool> saveFaceMapRecord({
    required String profileId,
    String? tratamientoId,
    String? servicioId,
    required List<Map<String, dynamic>> puntos,
    String? notas,
  }) =>
      SupabaseService.saveFaceMapRecord(
        profileId: profileId,
        tratamientoId: tratamientoId,
        servicioId: servicioId,
        puntos: puntos,
        notas: notas,
      );

  @override
  Future<Map<String, dynamic>?> getFaceMapPorServicio({
    required String profileId,
    required String servicioId,
  }) =>
      SupabaseService.getFaceMapPorServicio(
        profileId: profileId,
        servicioId: servicioId,
      );

  @override
  Future<Map<String, dynamic>> checkPatientFlowStatus({
    required String profileId,
  }) =>
      SupabaseService.checkPatientFlowStatus(profileId: profileId);

  @override
  Future<Map<String, dynamic>> validateReservationRulesRN020({
    required String profileId,
  }) =>
      SupabaseService.validateReservationRulesRN020(profileId: profileId);
}