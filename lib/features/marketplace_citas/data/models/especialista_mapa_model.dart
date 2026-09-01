import '../../domain/entities/especialista_mapa_entity.dart';

class EspecialistaMapaModel {
  final String id;
  final String? nombre;
  final double? latitud;
  final double? longitud;
  final bool disponible;
  final bool enLinea;
  final double? promedio;
  final int totalEvaluaciones;

  const EspecialistaMapaModel({
    required this.id,
    this.nombre,
    this.latitud,
    this.longitud,
    required this.disponible,
    this.enLinea = false,
    this.promedio,
    this.totalEvaluaciones = 0,
  });

  factory EspecialistaMapaModel.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'];
    String? nombre;
    if (profile is Map<String, dynamic>) {
      nombre = profile['full_name'] as String?;
    }

    // `ubicaciones_especialista` llega como lista sin orden garantizado
    // (el orden/limit embebido no lo soporta esta versión de PostgREST);
    // ordenamos por `created_at` desc y usamos la más reciente.
    double? latitud;
    double? longitud;
    final ubicaciones = json['ubicaciones_especialista'];
    if (ubicaciones is List && ubicaciones.isNotEmpty) {
      final filas = ubicaciones
          .whereType<Map<String, dynamic>>()
          .toList()
        ..sort((a, b) {
          final ta = DateTime.tryParse('${a['created_at'] ?? ''}');
          final tb = DateTime.tryParse('${b['created_at'] ?? ''}');
          final cero = DateTime.fromMillisecondsSinceEpoch(0);
          return (tb ?? cero).compareTo(ta ?? cero);
        });
      final first = filas.isNotEmpty ? filas.first : null;
      if (first != null) {
        latitud = (first['latitud'] as num?)?.toDouble();
        longitud = (first['longitud'] as num?)?.toDouble();
      }
    }

    double? promedio;
    var totalEvaluaciones = 0;
    final evaluaciones = json['evaluaciones_servicio'];
    if (evaluaciones is List && evaluaciones.isNotEmpty) {
      final puntuaciones = <double>[];
      for (final ev in evaluaciones) {
        if (ev is Map<String, dynamic>) {
          final p = (ev['puntuacion'] as num?)?.toDouble();
          if (p != null) puntuaciones.add(p);
        }
      }
      totalEvaluaciones = puntuaciones.length;
      if (totalEvaluaciones > 0) {
        promedio = puntuaciones.reduce((a, b) => a + b) / totalEvaluaciones;
      }
    }

    return EspecialistaMapaModel(
      id: json['id'] as String? ?? '',
      nombre: nombre,
      latitud: latitud,
      longitud: longitud,
      disponible: json['disponible'] as bool? ?? false,
      enLinea: json['en_linea'] as bool? ?? false,
      promedio: promedio,
      totalEvaluaciones: totalEvaluaciones,
    );
  }

  EspecialistaMapaEntity toEntity() {
    return EspecialistaMapaEntity(
      id: id,
      nombre: nombre,
      latitud: latitud,
      longitud: longitud,
      disponible: disponible,
      enLinea: enLinea,
      promedio: promedio,
      totalEvaluaciones: totalEvaluaciones,
    );
  }
}
