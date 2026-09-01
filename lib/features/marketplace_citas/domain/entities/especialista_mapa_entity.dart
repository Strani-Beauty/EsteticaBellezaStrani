import 'package:equatable/equatable.dart';

/// Entidad de dominio: especialista aprobado visible en el mapa con su última ubicación.
class EspecialistaMapaEntity extends Equatable {
  final String id; // uuid PK
  final String? nombre; // profiles.full_name
  final double? latitud;
  final double? longitud;
  final bool disponible;
  final bool enLinea;
  final double? promedio;
  final int totalEvaluaciones;

  const EspecialistaMapaEntity({
    required this.id,
    this.nombre,
    this.latitud,
    this.longitud,
    required this.disponible,
    this.enLinea = false,
    this.promedio,
    this.totalEvaluaciones = 0,
  });

  @override
  List<Object?> get props => [
        id,
        nombre,
        latitud,
        longitud,
        disponible,
        enLinea,
        promedio,
        totalEvaluaciones,
      ];
}
