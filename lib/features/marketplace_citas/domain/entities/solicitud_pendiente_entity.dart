import 'package:equatable/equatable.dart';

/// Servicio dentro de una solicitud publicada (jsonb `servicios` del RPC).
class DetalleServicioSolicitudMapaEntity extends Equatable {
  final String? servicioId;
  final String nombre;
  final int cantidad;
  final double precioUnitario;

  const DetalleServicioSolicitudMapaEntity({
    this.servicioId,
    required this.nombre,
    required this.cantidad,
    required this.precioUnitario,
  });

  double get subtotal => precioUnitario * cantidad;

  @override
  List<Object?> get props => [servicioId, nombre, cantidad, precioUnitario];
}

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
  final List<DetalleServicioSolicitudMapaEntity> servicios;
  final double? precioTotal;
  final DateTime? fechaProgramada;

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
    this.servicios = const [],
    this.precioTotal,
    this.fechaProgramada,
  });

  bool get expirada {
    if (fechaExpiracion == null) return false;
    return DateTime.now().isAfter(fechaExpiracion!);
  }

  double get total => precioTotal ?? precio;

  @override
  List<Object?> get props => [id, pacienteNombre, servicioNombre, precio];
}
