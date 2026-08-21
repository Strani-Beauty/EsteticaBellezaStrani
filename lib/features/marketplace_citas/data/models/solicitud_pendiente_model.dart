import '../../domain/entities/solicitud_pendiente_entity.dart';

/// Servicio dentro de una solicitud publicada (jsonb `servicios` del RPC).
class DetalleServicioSolicitudMapaModel {
  final String? servicioId;
  final String nombre;
  final int cantidad;
  final double precioUnitario;

  const DetalleServicioSolicitudMapaModel({
    this.servicioId,
    required this.nombre,
    required this.cantidad,
    required this.precioUnitario,
  });

  factory DetalleServicioSolicitudMapaModel.fromJson(
      Map<String, dynamic> json) {
    return DetalleServicioSolicitudMapaModel(
      servicioId: json['servicio_id']?.toString(),
      nombre: json['nombre']?.toString() ?? 'Servicio',
      cantidad: (json['cantidad'] as num?)?.toInt() ?? 1,
      precioUnitario: (json['precio_unitario'] as num?)?.toDouble() ?? 0,
    );
  }

  double get subtotal => precioUnitario * cantidad;
}

class SolicitudPendienteModel {
  final String id;
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
  final List<DetalleServicioSolicitudMapaModel> servicios;
  final double? precioTotal;
  final DateTime? fechaProgramada;

  const SolicitudPendienteModel({
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

  factory SolicitudPendienteModel.fromJson(Map<String, dynamic> json) {
    final serviciosRaw = json['servicios'];
    final servicios = <DetalleServicioSolicitudMapaModel>[];
    if (serviciosRaw is List) {
      for (final s in serviciosRaw) {
        if (s is Map<String, dynamic>) {
          servicios.add(DetalleServicioSolicitudMapaModel.fromJson(s));
        }
      }
    }
    final precio = (json['precio'] as num?)?.toDouble() ?? 0;

    return SolicitudPendienteModel(
      id: json['solicitud_id'] as String? ?? '',
      pacienteNombre: json['paciente_nombre'] as String? ?? 'Paciente',
      servicioNombre: json['servicio_nombre'] as String? ?? 'Servicio',
      precio: precio,
      // La dirección exacta NO se expone a especialistas no asignados (RN-018):
      // el RPC devuelve solo ubicación aproximada + ciudad.
      direccion: null,
      ciudad: json['ciudad'] as String?,
      latitud: (json['latitud_aprox'] as num?)?.toDouble(),
      longitud: (json['longitud_aprox'] as num?)?.toDouble(),
      fechaExpiracion: _parseDate(json['fecha_expiracion']),
      estado: json['estado'] as String? ?? '',
      radioBusqueda: (json['radio_busqueda'] as num?)?.toDouble(),
      servicios: servicios,
      precioTotal: (json['precio_total'] as num?)?.toDouble() ?? precio,
      fechaProgramada: _parseDate(json['fecha_programada']),
    );
  }

  SolicitudPendienteEntity toEntity() {
    return SolicitudPendienteEntity(
      id: id,
      pacienteNombre: pacienteNombre,
      servicioNombre: servicioNombre,
      precio: precio,
      direccion: direccion,
      ciudad: ciudad,
      latitud: latitud,
      longitud: longitud,
      fechaExpiracion: fechaExpiracion,
      estado: estado,
      radioBusqueda: radioBusqueda,
      servicios: servicios
          .map((s) => DetalleServicioSolicitudMapaEntity(
                servicioId: s.servicioId,
                nombre: s.nombre,
                cantidad: s.cantidad,
                precioUnitario: s.precioUnitario,
              ))
          .toList(),
      precioTotal: precioTotal,
      fechaProgramada: fechaProgramada,
    );
  }

  /// Total estimado de la solicitud (precio total agregado por el RPC).
  double get total => precioTotal ?? precio;

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
