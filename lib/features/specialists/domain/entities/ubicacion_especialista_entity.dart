import 'package:equatable/equatable.dart';

/// Entidad de dominio: `ubicaciones_especialista`.
/// El campo geográfico `ubicacion` (geography(Point,4326)) se representa
/// mediante `latitud`/`longitud`.
class UbicacionEspecialistaEntity extends Equatable {
  final String id;                // uuid PK
  final String especialistaId;    // FK especialistas.id
  final double latitud;           // WGS84
  final double longitud;          // WGS84
  final double precisionMetros;   // exactitud GPS en metros
  final DateTime? fechaActualizacion;
  final DateTime createdAt;

  const UbicacionEspecialistaEntity({
    required this.id,
    required this.especialistaId,
    required this.latitud,
    required this.longitud,
    required this.precisionMetros,
    this.fechaActualizacion,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, especialistaId, latitud, longitud];
}