import 'package:equatable/equatable.dart';

/// Entidad de dominio: solicitud pendiente visible en el mapa del especialista.
/// Representa a un paciente que busca especialista (`PUBLICADA` / `BUSCANDO_ESPECIALISTA`).
class SolicitudPendienteEntity extends Equatable {
  final String id; // uuid PK
  final String pacienteNombre;
  final String servicioNombre;
  final double precio;
  final String? direccion;
  final String? ciudad;
  final double? latitud;
  final double? longitud;
  final DateTime? fechaExpiracion;
  final String estado;
  final double? radioBusqueda;

  const SolicitudPendienteEntity({
    required this.id,
    required this.pacienteNombre,
    required this.servicioNombre,
    required this.precio,
    this.direccion,
    this.ciudad,
    this.latitud,
    this.longitud,
    this.fechaExpiracion,
    required this.estado,
    this.radioBusqueda,
  });

  bool get expirada {
    if (fechaExpiracion == null) return false;
    return DateTime.now().isAfter(fechaExpiracion!);
  }

  @override
  List<Object?> get props => [id, pacienteNombre, servicioNombre, precio];
}
