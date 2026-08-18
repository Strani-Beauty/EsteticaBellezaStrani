import '../../domain/entities/evaluacion_salud_entity.dart';

/// Modelo de `respuestas_salud`.
class RespuestaSaludModel {
  final String id;
  final String evaluacionId;
  final int preguntaId;
  final String? preguntaTexto;
  final String? respuestaTexto;
  final bool? respuestaBoolean;
  final num? respuestaNumero;
  final DateTime? respuestaFecha;
  final DateTime createdAt;

  const RespuestaSaludModel({
    required this.id,
    required this.evaluacionId,
    required this.preguntaId,
    this.preguntaTexto,
    this.respuestaTexto,
    this.respuestaBoolean,
    this.respuestaNumero,
    this.respuestaFecha,
    required this.createdAt,
  });

  factory RespuestaSaludModel.fromJson(Map<String, dynamic> json) =>
      RespuestaSaludModel(
        id: (json['id'] as String?) ?? '',
        evaluacionId: (json['evaluacion_id'] as String?) ?? '',
        preguntaId: (json['pregunta_id'] as num?)?.toInt() ?? 0,
        preguntaTexto: json['pregunta_texto'] as String?,
        respuestaTexto: json['respuesta_texto'] as String?,
        respuestaBoolean: json['respuesta_boolean'] as bool?,
        respuestaNumero: json['respuesta_numero'] as num?,
        respuestaFecha: json['respuesta_fecha'] != null
            ? DateTime.tryParse(json['respuesta_fecha'].toString())
            : null,
        createdAt:
            DateTime.tryParse((json['created_at'] as String?) ?? '') ?? DateTime.now(),
      );

  RespuestaSaludEntity toEntity() => RespuestaSaludEntity(
        id: id,
        evaluacionId: evaluacionId,
        preguntaId: preguntaId,
        preguntaTexto: preguntaTexto,
        respuestaTexto: respuestaTexto,
        respuestaBoolean: respuestaBoolean,
        respuestaNumero: respuestaNumero,
        respuestaFecha: respuestaFecha,
        createdAt: createdAt,
      );
}

/// Modelo de `evaluaciones_salud`.
class EvaluacionSaludModel {
  final String id;
  final String pacienteId;
  final int cuestionarioId;
  final int versionCuestionario;
  final DateTime fechaEvaluacion;
  final String estado;
  final ResultadoEvaluacion? resultado;
  final List<RiesgoDetectado> riesgos;
  final DateTime createdAt;

  const EvaluacionSaludModel({
    required this.id,
    required this.pacienteId,
    required this.cuestionarioId,
    required this.versionCuestionario,
    required this.fechaEvaluacion,
    required this.estado,
    this.resultado,
    this.riesgos = const [],
    required this.createdAt,
  });

  factory EvaluacionSaludModel.fromJson(Map<String, dynamic> json) =>
      EvaluacionSaludModel(
        id: (json['id'] as String?) ?? '',
        pacienteId: (json['paciente_id'] as String?) ?? '',
        cuestionarioId: (json['cuestionario_id'] as num?)?.toInt() ?? 0,
        versionCuestionario: (json['version_cuestionario'] as num?)?.toInt() ?? 1,
        fechaEvaluacion:
            DateTime.tryParse((json['fecha_evaluacion'] as String?) ?? '') ??
                DateTime.now(),
        estado: (json['estado'] as String?) ?? 'Pendiente',
        resultado: ResultadoEvaluacionX.fromDb(json['resultado'] as String?),
        riesgos: [
          for (final r in (json['riesgos'] as List? ?? []))
            if (r is Map<String, dynamic>) RiesgoDetectado.fromJson(r),
        ],
        createdAt:
            DateTime.tryParse((json['created_at'] as String?) ?? '') ?? DateTime.now(),
      );

  EvaluacionSaludEntity toEntity() => EvaluacionSaludEntity(
        id: id,
        pacienteId: pacienteId,
        cuestionarioId: cuestionarioId,
        versionCuestionario: versionCuestionario,
        fechaEvaluacion: fechaEvaluacion,
        estado: estado,
        resultado: resultado,
        riesgos: riesgos,
        createdAt: createdAt,
      );
}