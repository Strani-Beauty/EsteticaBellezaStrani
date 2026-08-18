import 'package:equatable/equatable.dart';

/// Tipo de respuesta de una pregunta, alineado al enum `public.tipo_respuesta_enum`.
enum TipoRespuestaPregunta { siNo, texto, numero, decimal, fecha, lista, multiple, archivo, imagen }

extension TipoRespuestaPreguntaX on TipoRespuestaPregunta {
  /// Valor en la BD (`tipo_respuesta_enum`).
  String toDb() {
    switch (this) {
      case TipoRespuestaPregunta.siNo:
        return 'SI_NO';
      case TipoRespuestaPregunta.texto:
        return 'TEXTO';
      case TipoRespuestaPregunta.numero:
        return 'NUMERO';
      case TipoRespuestaPregunta.decimal:
        return 'DECIMAL';
      case TipoRespuestaPregunta.fecha:
        return 'FECHA';
      case TipoRespuestaPregunta.lista:
        return 'LISTA';
      case TipoRespuestaPregunta.multiple:
        return 'MULTIPLE';
      case TipoRespuestaPregunta.archivo:
        return 'ARCHIVO';
      case TipoRespuestaPregunta.imagen:
        return 'IMAGEN';
    }
  }

  static TipoRespuestaPregunta fromDb(String? value) {
    switch ((value ?? '').toUpperCase()) {
      case 'SI_NO':
        return TipoRespuestaPregunta.siNo;
      case 'TEXTO':
        return TipoRespuestaPregunta.texto;
      case 'NUMERO':
        return TipoRespuestaPregunta.numero;
      case 'DECIMAL':
        return TipoRespuestaPregunta.decimal;
      case 'FECHA':
        return TipoRespuestaPregunta.fecha;
      case 'LISTA':
        return TipoRespuestaPregunta.lista;
      case 'MULTIPLE':
        return TipoRespuestaPregunta.multiple;
      case 'ARCHIVO':
        return TipoRespuestaPregunta.archivo;
      case 'IMAGEN':
        return TipoRespuestaPregunta.imagen;
      default:
        return TipoRespuestaPregunta.texto;
    }
  }

  /// Etiqueta legible en la UI.
  String get label {
    switch (this) {
      case TipoRespuestaPregunta.siNo:
        return 'Sí / No';
      case TipoRespuestaPregunta.texto:
        return 'Texto';
      case TipoRespuestaPregunta.numero:
        return 'Número';
      case TipoRespuestaPregunta.decimal:
        return 'Decimal';
      case TipoRespuestaPregunta.fecha:
        return 'Fecha';
      case TipoRespuestaPregunta.lista:
        return 'Selección única';
      case TipoRespuestaPregunta.multiple:
        return 'Selección múltiple';
      case TipoRespuestaPregunta.archivo:
        return 'Archivo';
      case TipoRespuestaPregunta.imagen:
        return 'Imagen';
    }
  }
}

/// Regla de riesgo configurable por pregunta (sentinel).
/// Si la respuesta coincide (SI_NO: valor = detonante; TEXTO: patrón regex;
/// resto: valor = detonante), se marca la etiqueta en la evaluación.
class RiesgoSentinel extends Equatable {
  final String? detonante;
  final String? patron;
  final String etiqueta;
  final bool critico;

  const RiesgoSentinel({
    this.detonante,
    this.patron,
    required this.etiqueta,
    this.critico = false,
  });

  factory RiesgoSentinel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const RiesgoSentinel(etiqueta: '');
    return RiesgoSentinel(
      detonante: json['detonante'] as String?,
      patron: json['patron'] as String?,
      etiqueta: (json['etiqueta'] as String?) ?? '',
      critico: json['critico'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        if (detonante != null) 'detonante': detonante,
        if (patron != null) 'patron': patron,
        'etiqueta': etiqueta,
        'critico': critico,
      };

  @override
  List<Object?> get props => [detonante, patron, etiqueta, critico];
}

class CuestionarioEntity extends Equatable {
  final int id; // bigint
  final String nombre;
  final String? descripcion;
  final bool activo;
  final int version;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const CuestionarioEntity({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.activo,
    required this.version,
    required this.createdAt,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [id, nombre, version, activo];
}

class PreguntaEntity extends Equatable {
  final int id; // bigint
  final String texto;
  final TipoRespuestaPregunta tipo;
  final List<String> opciones;
  final RiesgoSentinel? riesgo;
  final bool obligatoria;
  final bool activo;
  final int orden; // desde cuestionario_preguntas
  final DateTime createdAt;

  const PreguntaEntity({
    required this.id,
    required this.texto,
    required this.tipo,
    this.opciones = const [],
    this.riesgo,
    required this.obligatoria,
    this.activo = true,
    this.orden = 0,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, texto, tipo, orden];
}

/// Relación M:N cuestionario-pregunta con orden.
class CuestionarioPreguntaEntity extends Equatable {
  final int cuestionarioId;
  final int preguntaId;
  final int orden;

  const CuestionarioPreguntaEntity({
    required this.cuestionarioId,
    required this.preguntaId,
    required this.orden,
  });

  @override
  List<Object?> get props => [cuestionarioId, preguntaId, orden];
}