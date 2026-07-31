import 'package:equatable/equatable.dart';

/// Ubicación geográfica del especialista.
/// Usa geography(Point,4326) en PostGIS (RN-017)
class UbicacionEspecialistaEntity extends Equatable {
  final String id;              // UUID
  final String especialistaId; // FK especialistas.id
  final double latitud;         // WGS84
  final double longitud;        // WGS84
  final double radioCobertura;  // km
  final DateTime updatedAt;

  const UbicacionEspecialistaEntity({
    required this.id,
    required this.especialistaId,
    required this.latitud,
    required this.longitud,
    required this.radioCobertura,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [id, especialistaId, latitud, longitud];
}
