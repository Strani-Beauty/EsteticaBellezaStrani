import '../../domain/entities/cita_ejecucion_entity.dart';
import 'tratamiento_model.dart';

/// Modelo de una cita de ejecución con joins (solicitud → servicio/paciente/
/// dirección) y su tratamiento asociado.
class CitaEjecucionModel {
  final String id;
  final String estado;
  final String? fechaAceptacion;
  final String? fechaInicio;
  final String? fechaFinalizacion;

  /// Id de la solicitud origen (join solicitudes.id).
  final String? solicitudId;

  final String pacienteNombre;
  final String? pacienteTelefono;
  final String servicioNombre;
  final double precioBase;
  final String? tipoPrecio;
  final String? direccion;
  final String? ciudad;
  final double? latitud;
  final double? longitud;

  final TratamientoModel? tratamiento;

  const CitaEjecucionModel({
    required this.id,
    required this.estado,
    this.fechaAceptacion,
    this.fechaInicio,
    this.fechaFinalizacion,
    this.solicitudId,
    this.pacienteNombre = 'Paciente',
    this.pacienteTelefono,
    this.servicioNombre = 'Servicio',
    this.precioBase = 0,
    this.tipoPrecio,
    this.direccion,
    this.ciudad,
    this.latitud,
    this.longitud,
    this.tratamiento,
  });

  factory CitaEjecucionModel.fromJson(Map<String, dynamic> json) {
    final solicitud = json['solicitudes'];
    final servicio = solicitud is Map<String, dynamic>
        ? solicitud['servicios']
        : null;
    final paciente = solicitud is Map<String, dynamic>
        ? solicitud['pacientes']
        : null;
    final dir = solicitud is Map<String, dynamic>
        ? solicitud['direcciones_paciente']
        : null;

    String? pacienteNombre;
    String? telefono;
    if (paciente is Map<String, dynamic>) {
      final profile = paciente['profiles'];
      if (profile is Map<String, dynamic>) {
        pacienteNombre = profile['full_name'] as String?;
        telefono = profile['phone'] as String?;
      }
      pacienteNombre ??= paciente['nombre'] as String?;
    }

    final mDireccion = dir is Map<String, dynamic> ? dir : null;

    final tratamientoRaw = json['tratamientos'];
    TratamientoModel? tratamiento;
    if (tratamientoRaw is Map<String, dynamic>) {
      tratamiento = TratamientoModel.fromJson(tratamientoRaw);
    } else if (tratamientoRaw is List && tratamientoRaw.isNotEmpty) {
      final first = tratamientoRaw.first;
      if (first is Map<String, dynamic>) {
        tratamiento = TratamientoModel.fromJson(first);
      }
    }

    return CitaEjecucionModel(
      id: json['id'] as String? ?? '',
      estado: json['estado'] as String? ?? '',
      fechaAceptacion: json['fecha_aceptacion']?.toString(),
      fechaInicio: json['fecha_inicio']?.toString(),
      fechaFinalizacion: json['fecha_finalizacion']?.toString(),
      solicitudId: solicitud is Map<String, dynamic>
          ? solicitud['id'] as String?
          : null,
      pacienteNombre: pacienteNombre ?? 'Paciente',
      pacienteTelefono: telefono,
      servicioNombre: servicio is Map<String, dynamic>
          ? servicio['nombre'] as String? ?? 'Servicio'
          : 'Servicio',
      precioBase: servicio is Map<String, dynamic>
          ? (servicio['precio_base'] as num?)?.toDouble() ?? 0
          : 0,
      tipoPrecio: servicio is Map<String, dynamic>
          ? servicio['tipo_precio'] as String?
          : null,
      direccion: mDireccion?['direccion'] as String?,
      ciudad: mDireccion?['ciudad'] as String?,
      latitud: (mDireccion?['latitud'] as num?)?.toDouble(),
      longitud: (mDireccion?['longitud'] as num?)?.toDouble(),
      tratamiento: tratamiento,
    );
  }

  CitaEjecucionEntity toEntity() {
    return CitaEjecucionEntity(
      id: id,
      estado: EstadoCitaEjecucion.fromDb(estado) ?? EstadoCitaEjecucion.programada,
      fechaAceptacion: _parseDate(fechaAceptacion),
      fechaInicio: _parseDate(fechaInicio),
      fechaFinalizacion: _parseDate(fechaFinalizacion),
      solicitudId: solicitudId,
      pacienteNombre: pacienteNombre,
      pacienteTelefono: pacienteTelefono,
      servicioNombre: servicioNombre,
      precioBase: precioBase,
      tipoPrecio: tipoPrecio,
      direccion: direccion,
      ciudad: ciudad,
      latitud: latitud,
      longitud: longitud,
      tratamiento: tratamiento?.toEntity(),
    );
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}