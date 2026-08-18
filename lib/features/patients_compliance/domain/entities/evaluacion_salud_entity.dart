import 'package:equatable/equatable.dart';

/// Resultado de la evaluación sobre las respuestas (autoridad: RPC en BD).
enum ResultadoEvaluacion { apto, requiereRevision, noApto }

extension ResultadoEvaluacionX on ResultadoEvaluacion {
  String toDb() {
    switch (this) {
      case ResultadoEvaluacion.apto:
        return 'APTO';
      case ResultadoEvaluacion.requiereRevision:
        return 'REQUIERE_REVISION';
      case ResultadoEvaluacion.noApto:
        return 'NO_APTO';
    }
  }

  static ResultadoEvaluacion? fromDb(String? value) {
    switch ((value ?? '').toUpperCase()) {
      case 'APTO':
        return ResultadoEvaluacion.apto;
      case 'REQUIERE_REVISION':
        return ResultadoEvaluacion.requiereRevision;
      case 'NO_APTO':
        return ResultadoEvaluacion.noApto;
      default:
        return null;
    }
  }
}

/// Condición relevante detectada en las respuestas (sentinel de pregunta).
class RiesgoDetectado extends Equatable {
  final int preguntaId;
  final String etiqueta;
  final bool critico;

  const RiesgoDetectado({
    required this.preguntaId,
    required this.etiqueta,
    this.critico = false,
  });

  factory RiesgoDetectado.fromJson(Map<String, dynamic> json) => RiesgoDetectado(
        preguntaId: (json['pregunta_id'] as num?)?.toInt() ?? 0,
        etiqueta: (json['etiqueta'] as String?) ?? '',
        critico: json['critico'] == true,
      );

  @override
  List<Object?> get props => [preguntaId, etiqueta, critico];
}

/// Respuesta de salud con campos tipados (alineado a `respuestas_salud`).
class RespuestaSaludEntity extends Equatable {
  final String id; // uuid
  final String evaluacionId; // FK evaluaciones_salud.id
  final int preguntaId; // FK preguntas.id
  final String? preguntaTexto; // snapshot de la pregunta respondida
  final String? respuestaTexto;
  final bool? respuestaBoolean;
  final num? respuestaNumero;
  final DateTime? respuestaFecha;
  final DateTime createdAt;

  const RespuestaSaludEntity({
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

  /// Valor legible para mostrar en la UI.
  String get valorLegible {
    if (respuestaTexto != null && respuestaTexto!.isNotEmpty) return respuestaTexto!;
    if (respuestaBoolean != null) return respuestaBoolean! ? 'Sí' : 'No';
    if (respuestaNumero != null) return respuestaNumero!.toString();
    if (respuestaFecha != null) return respuestaFecha!.toIso8601String().split('T').first;
    return '—';
  }

  @override
  List<Object?> get props => [id, evaluacionId, preguntaId];
}

/// Evaluación completa de salud del paciente.
class EvaluacionSaludEntity extends Equatable {
  final String id; // uuid
  final String pacienteId; // FK pacientes.id
  final int cuestionarioId; // FK cuestionarios.id
  final int versionCuestionario;
  final DateTime fechaEvaluacion;
  final String estado; // 'Pendiente' | 'Completado'
  final ResultadoEvaluacion? resultado;
  final List<RiesgoDetectado> riesgos;
  final DateTime createdAt;

  const EvaluacionSaludEntity({
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

  @override
  List<Object?> get props => [id, pacienteId, cuestionarioId, versionCuestionario];
}

/// Validación médica externa (Qualify / Telemedicina / Medicina Interna).
class ValidacionTelemedicinaEntity extends Equatable {
  final String id; // uuid
  final String pacienteId; // FK pacientes.id
  final String proveedor;
  final String estado; // 'PENDIENTE' | 'APROBADA' | 'RECHAZADA'
  final String? codigoReferencia;
  final String? observaciones;
  final DateTime? fechaValidacion;
  final DateTime? fechaVencimiento;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ValidacionTelemedicinaEntity({
    required this.id,
    required this.pacienteId,
    required this.proveedor,
    required this.estado,
    this.codigoReferencia,
    this.observaciones,
    this.fechaValidacion,
    this.fechaVencimiento,
    required this.createdAt,
    this.updatedAt,
  });

  /// La validación está APROBADA y vigente (no vencida).
  bool get vigente =>
      estado == 'APROBADA' &&
      fechaVencimiento != null &&
      fechaVencimiento!.isAfter(DateTime.now());

  /// La validación está vencida (aunque hubiera sido aprobada).
  bool get vencida =>
      estado == 'APROBADA' && !vigente;

  /// RN-020 / RN-022: bloquea reserva si no es válida.
  bool get bloqueaReserva => !vigente;

  @override
  List<Object?> get props => [id, pacienteId, estado, fechaVencimiento];
}

/// Resultado devuelto por la RPC `guardar_respuestas_evaluacion`.
class ResultadoEvaluacionRegistrada extends Equatable {
  final String evaluacionId;
  final ResultadoEvaluacion resultado;
  final List<RiesgoDetectado> riesgos;
  final int versionCuestionario;
  final DateTime fechaEvaluacion;

  const ResultadoEvaluacionRegistrada({
    required this.evaluacionId,
    required this.resultado,
    required this.riesgos,
    required this.versionCuestionario,
    required this.fechaEvaluacion,
  });

  factory ResultadoEvaluacionRegistrada.fromJson(Map<String, dynamic> json) =>
      ResultadoEvaluacionRegistrada(
        evaluacionId: (json['id'] as String?) ?? '',
        resultado: ResultadoEvaluacionX.fromDb(json['resultado'] as String?) ??
            ResultadoEvaluacion.apto,
        riesgos: [
          for (final r in (json['riesgos'] as List? ?? []))
            if (r is Map<String, dynamic>) RiesgoDetectado.fromJson(r),
        ],
        versionCuestionario: (json['version_cuestionario'] as num?)?.toInt() ?? 1,
        fechaEvaluacion:
            DateTime.tryParse((json['fecha_evaluacion'] as String?) ?? '') ??
                DateTime.now(),
      );

  @override
  List<Object?> get props => [evaluacionId, resultado];
}