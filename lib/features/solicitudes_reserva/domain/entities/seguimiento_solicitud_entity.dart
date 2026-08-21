import 'package:equatable/equatable.dart';

/// Detalle de servicio dentro de una solicitud (`solicitud_detalles`).
class DetalleServicioSolicitudEntity extends Equatable {
  final String id;
  final String servicioId;
  final String nombre;
  final int cantidad;
  final double precioUnitario;

  const DetalleServicioSolicitudEntity({
    required this.id,
    required this.servicioId,
    required this.nombre,
    required this.cantidad,
    required this.precioUnitario,
  });

  double get subtotal => precioUnitario * cantidad;

  @override
  List<Object?> get props => [id, servicioId, nombre, cantidad, precioUnitario];
}

/// Solicitud del paciente para seguimiento: servicios, obligación de pago,
/// dirección y cita asignada (si existe).
class SeguimientoSolicitudEntity extends Equatable {
  final String id;
  final String estado;
  final DateTime fechaSolicitud;
  final DateTime? fechaProgramada;
  final DateTime? fechaExpiracion;
  final List<DetalleServicioSolicitudEntity> servicios;
  final double montoTotal;
  final double deposito;
  final double saldoPendiente;
  final String? ciudad;
  final String? citaEstado;
  final DateTime? citaFechaAceptacion;
  final String? observaciones;

  const SeguimientoSolicitudEntity({
    required this.id,
    required this.estado,
    required this.fechaSolicitud,
    this.fechaProgramada,
    this.fechaExpiracion,
    this.servicios = const [],
    required this.montoTotal,
    required this.deposito,
    required this.saldoPendiente,
    this.ciudad,
    this.citaEstado,
    this.citaFechaAceptacion,
    this.observaciones,
  });

  bool get estaPublicada =>
      estado == 'PUBLICADA' || estado == 'BUSCANDO_ESPECIALISTA';

  bool get estaAceptada => estado == 'ACEPTADA';

  bool get pendientePago => estado == 'PENDIENTE_PAGO' || estado == 'BORRADOR';

  @override
  List<Object?> get props => [id, estado, fechaSolicitud];
}

/// Dirección principal del paciente para la zona de prestación.
class DireccionPrincipalEntity extends Equatable {
  final String id;
  final String direccion;
  final String? ciudad;
  final double latitud;
  final double longitud;

  const DireccionPrincipalEntity({
    required this.id,
    required this.direccion,
    this.ciudad,
    required this.latitud,
    required this.longitud,
  });

  @override
  List<Object?> get props => [id, direccion, latitud, longitud];
}

/// Configuración del flujo de reserva leída de `configuracion_sistema`.
class ConfigReservaEntity extends Equatable {
  final double radioKm;
  final bool enforcePagoReal;

  const ConfigReservaEntity({
    required this.radioKm,
    required this.enforcePagoReal,
  });

  @override
  List<Object?> get props => [radioKm, enforcePagoReal];
}
