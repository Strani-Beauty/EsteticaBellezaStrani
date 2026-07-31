import 'package:equatable/equatable.dart';

enum TipoPregunta { abierta, boolean, seleccionMultiple, escala }

class CuestionarioEntity extends Equatable {
  final String id;           // UUID
  final String nombre;
  final String? descripcion;
  final bool activo;
  final DateTime createdAt;

  const CuestionarioEntity({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.activo,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, nombre, activo];
}

class PreguntaEntity extends Equatable {
  final String id;             // UUID
  final String texto;
  final TipoPregunta tipo;
  final List<String>? opciones; // Para seleccion multiple
  final bool obligatoria;
  final bool activo;
  final DateTime createdAt;

  const PreguntaEntity({
    required this.id,
    required this.texto,
    required this.tipo,
    this.opciones,
    required this.obligatoria,
    required this.activo,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, texto, tipo];
}

/// Relación M:N cuestionario-pregunta con orden
class CuestionarioPreguntaEntity extends Equatable {
  final String cuestionarioId;
  final String preguntaId;
  final int orden;

  const CuestionarioPreguntaEntity({
    required this.cuestionarioId,
    required this.preguntaId,
    required this.orden,
  });

  @override
  List<Object?> get props => [cuestionarioId, preguntaId, orden];
}
