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
    final direccionRaw = json['direcciones_paciente'];
    final servicioRaw = json['servicios'];
    final pacienteRaw = json['pacientes'];

    String? pacienteNombre;
    if (pacienteRaw is Map<String, dynamic>) {
      final profile = pacienteRaw['profiles'];
      if (profile is Map<String, dynamic>) {
        pacienteNombre = profile['full_name'] as String?;
      }
      pacienteNombre ??= pacienteRaw['nombre'] as String?;
    }

    final dir = direccionRaw is Map<String, dynamic> ? direccionRaw : null;
    final servicio =
        servicioRaw is Map<String, dynamic> ? servicioRaw : null;

    return SolicitudPendienteModel(
      id: json['id'] as String? ?? '',
      pacienteNombre: pacienteNombre ?? 'Paciente',
      servicioNombre: servicio?['nombre'] as String? ?? 'Servicio',
      precio: (servicio?['precio_base'] as num?)?.toDouble() ?? 0,
      direccion: dir?['direccion'] as String?,
      ciudad: dir?['ciudad'] as String?,
      latitud: (dir?['latitud'] as num?)?.toDouble(),
      longitud: (dir?['longitud'] as num?)?.toDouble(),
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
