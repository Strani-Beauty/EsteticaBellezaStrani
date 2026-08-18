import '../../domain/entities/cuestionario_entity.dart';

/// Modelo de la tabla `cuestionarios`.
class CuestionarioModel {
  final int id;
  final String nombre;
  final String? descripcion;
  final bool activo;
  final int version;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const CuestionarioModel({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.activo,
    required this.version,
    required this.createdAt,
    this.updatedAt,
  });

  factory CuestionarioModel.fromJson(Map<String, dynamic> json) =>
      CuestionarioModel(
        id: (json['id'] as num?)?.toInt() ?? 0,
        nombre: (json['nombre'] as String?) ?? '',
        descripcion: json['descripcion'] as String?,
        activo: json['activo'] == true,
        version: (json['version'] as num?)?.toInt() ?? 1,
        createdAt:
            DateTime.tryParse((json['created_at'] as String?) ?? '') ?? DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'].toString())
            : null,
      );

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        if (descripcion != null) 'descripcion': descripcion,
        'activo': activo,
        'version': version,
        'updated_at': DateTime.now().toIso8601String(),
      };

  CuestionarioEntity toEntity() => CuestionarioEntity(
        id: id,
        nombre: nombre,
        descripcion: descripcion,
        activo: activo,
        version: version,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

/// Modelo de la tabla `preguntas` (con `orden` desde `cuestionario_preguntas`).
class PreguntaModel {
  final int id;
  final String pregunta;
  final TipoRespuestaPregunta tipoRespuesta;
  final bool obligatoria;
  final String? ayuda;
  final List<String> opciones;
  final RiesgoSentinel? riesgo;
  final bool activo;
  final int orden;
  final DateTime createdAt;

  const PreguntaModel({
    required this.id,
    required this.pregunta,
    required this.tipoRespuesta,
    required this.obligatoria,
    this.ayuda,
    this.opciones = const [],
    this.riesgo,
    this.activo = true,
    this.orden = 0,
    required this.createdAt,
  });

  factory PreguntaModel.fromJson(Map<String, dynamic> json) => PreguntaModel(
        id: (json['id'] as num?)?.toInt() ?? 0,
        pregunta: (json['pregunta'] as String?) ?? '',
        tipoRespuesta: TipoRespuestaPreguntaX.fromDb(json['tipo_respuesta'] as String?),
        obligatoria: json['obligatoria'] == true,
        ayuda: json['ayuda'] as String?,
        opciones: [
          for (final o in (json['opciones'] as List? ?? []))
            if (o is String) o,
        ],
        riesgo: RiesgoSentinel.fromJson(json['riesgo'] as Map<String, dynamic>?),
        activo: json['activo'] != false,
        orden: (json['orden'] as num?)?.toInt() ?? 0,
        createdAt:
            DateTime.tryParse((json['created_at'] as String?) ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'pregunta': pregunta,
        'tipo_respuesta': tipoRespuesta.toDb(),
        'obligatoria': obligatoria,
        if (ayuda != null) 'ayuda': ayuda,
        if (opciones.isNotEmpty) 'opciones': opciones,
        if (riesgo != null) 'riesgo': riesgo!.toJson(),
        'activo': activo,
        'updated_at': DateTime.now().toIso8601String(),
      };

  PreguntaEntity toEntity() => PreguntaEntity(
        id: id,
        texto: pregunta,
        tipo: tipoRespuesta,
        opciones: opciones,
        riesgo: riesgo,
        obligatoria: obligatoria,
        activo: activo,
        orden: orden,
        createdAt: createdAt,
      );
}

/// Modelo de la tabla puente `cuestionario_preguntas`.
class CuestionarioPreguntaModel {
  final int id;
  final int cuestionarioId;
  final int preguntaId;
  final int orden;
  final bool activo;

  const CuestionarioPreguntaModel({
    required this.id,
    required this.cuestionarioId,
    required this.preguntaId,
    required this.orden,
    this.activo = true,
  });

  factory CuestionarioPreguntaModel.fromJson(Map<String, dynamic> json) =>
      CuestionarioPreguntaModel(
        id: (json['id'] as num?)?.toInt() ?? 0,
        cuestionarioId: (json['cuestionario_id'] as num?)?.toInt() ?? 0,
        preguntaId: (json['pregunta_id'] as num?)?.toInt() ?? 0,
        orden: (json['orden'] as num?)?.toInt() ?? 0,
        activo: json['activo'] != false,
      );

  Map<String, dynamic> toJson() => {
        'cuestionario_id': cuestionarioId,
        'pregunta_id': preguntaId,
        'orden': orden,
        'activo': activo,
      };

  CuestionarioPreguntaEntity toEntity() => CuestionarioPreguntaEntity(
        cuestionarioId: cuestionarioId,
        preguntaId: preguntaId,
        orden: orden,
      );
}