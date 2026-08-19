import 'package:fpdart/fpdart.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/core/error/failures.dart';
import '../entities/cuestionario_entity.dart';
import '../entities/estado_salud_entity.dart';
import '../entities/evaluacion_salud_entity.dart';
import '../entities/paciente_entity.dart';

/// Contrato del módulo de salud/compliance del paciente.
/// La implementación vive en data/ y usa un datasource de Supabase
/// (patrón Clean Architecture). El método `consultarEstadoSalud` es la fuente
/// de la pantalla de estado (requisito 13) y el gate RN-020 (requisito 12).
abstract class IPatientsComplianceRepository {
  // ── Paciente ───────────────────────────────────────────────────────────────

  /// Datos del paciente del usuario autenticado.
  Future<Either<Failure, PacienteEntity?>> getMiPaciente();

  /// Actualiza la información básica/clínica del paciente autenticado.
  Future<Either<Failure, PacienteEntity?>> updateMiPaciente({
    DateTime? fechaNacimiento,
    String? genero,
    String? grupoSanguineo,
    String? alergias,
    String? antecedentes,
    bool? activo,
  });

  // ── Cuestionarios y preguntas ──────────────────────────────────────────────

  /// Cuestionarios (con sus versiones). `soloActivos` filtra por activo.
  Future<Either<Failure, List<CuestionarioEntity>>> getCuestionarios({
    bool soloActivos = false,
  });

  /// Cuestionario activo (producto: un solo cuestionario de salud).
  Future<Either<Failure, CuestionarioEntity?>> getCuestionarioActivo();

  /// Preguntas de un cuestionario (join `cuestionario_preguntas` -> `preguntas`),
  /// ordenadas y con sus opciones/riesgo.
  Future<Either<Failure, List<PreguntaEntity>>> getCuestionarioPreguntas(
    int cuestionarioId,
  );

  /// Crea una nueva versión (fila) de un cuestionario a partir de la actual
  /// (copiando la relación de preguntas). La nueva nace inactiva.
  Future<Either<Failure, CuestionarioEntity>> crearNuevaVersionCuestionario(
    int versionActualId,
  );

  /// Activa una versión de cuestionario (desactiva las demás del mismo nombre).
  Future<Either<Failure, void>> activarVersionCuestionario(int cuestionarioId);

  /// Edita una pregunta del catálogo (solo admin). Campos opcionales: solo los
  /// provistos se actualizan.
  Future<Either<Failure, void>> updatePregunta({
    required int preguntaId,
    String? texto,
    String? tipoRespuesta,
    bool? obligatoria,
    List<String>? opciones,
    Map<String, dynamic>? riesgo,
    bool? activo,
  });

  // ── Evaluación de salud ────────────────────────────────────────────────────

  /// Persiste respuestas vía RPC segura (`guardar_respuestas_evaluacion`):
  /// conserva la versión del cuestionario, snapshot del texto y computa
  /// sentinelas -> resultado/riesgos (autoridad en BD).
  Future<Either<Failure, ResultadoEvaluacionRegistrada>> guardarRespuestasEvaluacion({
    required int cuestionarioId,
    required Map<int, String> respuestas,
  });

  /// Última evaluación de salud del paciente.
  Future<Either<Failure, EvaluacionSaludEntity?>> getUltimaEvaluacion();

  /// ¿El paciente autenticado tiene una evaluación con resultado APTO para el
  /// cuestionario indicado? (se usa para validar requisitos por servicio).
  Future<Either<Failure, bool>> tieneEvaluacionAptaDeCuestionario(
    int cuestionarioId,
  );

  // ── Validación de telemedicina ─────────────────────────────────────────────

  /// Registra la validación de telemedicina vía RPC segura
  /// (`registrar_validacion_telemedicina`): fija fecha de aprobación (now) y
  /// fecha de vencimiento (+365 días).
  Future<Either<Failure, ValidacionTelemedicinaEntity>> registrarValidacionTelemedicina({
    required bool aprobado,
    required String proveedor,
    String? codigoReferencia,
  });

  /// Validación de telemedicina actual del paciente.
  Future<Either<Failure, ValidacionTelemedicinaEntity?>> getMiValidacion();

  // ── Estado del flujo y acceso ──────────────────────────────────────────────

  /// Estado integral de salud del paciente (pago, cuestionario, evaluación,
  /// validación) para la consulta del requisito 13.
  Future<Either<Failure, EstadoSaludEntity>> consultarEstadoSalud();

  // ── Métodos legacy (pendientes de migrar por completo) ─────────────────────

  Future<LatLng?> geocodeAddress(String address);

  Future<String?> savePatientAddress({
    required String profileId,
    required String address,
    required double latitude,
    required double longitude,
  });

  Future<bool> saveHealthEvaluation({
    required String profileId,
    required String serviceName,
    required Map<String, String> answers,
  });

  Future<void> saveQualifyTestValidation({
    required String profileId,
    required bool aprobado,
    String proveedor = 'Telemedicina',
  });

  Future<bool> saveFaceMapRecord({
    required String profileId,
    String? tratamientoId,
    String? servicioId,
    required List<Map<String, dynamic>> puntos,
    String? notas,
  });

  Future<Map<String, dynamic>?> getFaceMapPorServicio({
    required String profileId,
    required String servicioId,
  });

  Future<Map<String, dynamic>> checkPatientFlowStatus({
    required String profileId,
  });

  Future<Map<String, dynamic>> validateReservationRulesRN020({
    required String profileId,
  });
}