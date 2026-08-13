import '../../domain/entities/solicitud_pendiente_entity.dart';

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
  });

  factory SolicitudPendienteModel.fromJson(Map<String, dynamic> json) {
    return SolicitudPendienteModel(
      id: json['solicitud_id'] as String? ?? '',
      pacienteNombre: json['paciente_nombre'] as String? ?? 'Paciente',
      servicioNombre: json['servicio_nombre'] as String? ?? 'Servicio',
      precio: (json['precio'] as num?)?.toDouble() ?? 0,
      // La dirección exacta NO se expone a especialistas no asignados (RN-018):
      // el RPC devuelve solo ubicación aproximada + ciudad.
      direccion: null,
      ciudad: json['ciudad'] as String?,
      latitud: (json['latitud_aprox'] as num?)?.toDouble(),
      longitud: (json['longitud_aprox'] as num?)?.toDouble(),
      fechaExpiracion: _parseDate(json['fecha_expiracion']),
      estado: json['estado'] as String? ?? '',
      radioBusqueda: (json['radio_busqueda'] as num?)?.toDouble(),
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
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
