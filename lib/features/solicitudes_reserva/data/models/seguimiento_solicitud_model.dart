import '../../domain/entities/seguimiento_solicitud_entity.dart';

/// Modelo de una solicitud del paciente con sus joins embebidos
/// (detalles, pago, cita y dirección) para la pantalla "Mis solicitudes".
class SeguimientoSolicitudModel {
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
  final String? citaId;
  final bool yaEvaluado;
  final String? observaciones;

  const SeguimientoSolicitudModel({
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
    this.citaId,
    this.yaEvaluado = false,
    this.observaciones,
  });

  factory SeguimientoSolicitudModel.fromJson(Map<String, dynamic> json) {
    final detallesRaw = json['solicitud_detalles'];
    final pagosRaw = json['pagos'];
    final citasRaw = json['citas'];
    final dirRaw = json['direcciones_paciente'];

    final detalles = <DetalleServicioSolicitudEntity>[];
    if (detallesRaw is List) {
      for (final d in detallesRaw) {
        if (d is! Map<String, dynamic>) continue;
        final servicio = d['servicios'];
        detalles.add(DetalleServicioSolicitudEntity(
          id: d['id']?.toString() ?? '',
          servicioId: d['servicio_id']?.toString() ?? '',
          nombre: servicio is Map<String, dynamic>
              ? servicio['nombre']?.toString() ?? 'Servicio'
              : 'Servicio',
          cantidad: (d['cantidad'] as num?)?.toInt() ?? 1,
          precioUnitario: (d['precio_unitario'] as num?)?.toDouble() ?? 0,
        ));
      }
    }

    Map<String, dynamic>? pago;
    if (pagosRaw is Map<String, dynamic>) {
      pago = pagosRaw;
    } else if (pagosRaw is List && pagosRaw.isNotEmpty) {
      final first = pagosRaw.first;
      if (first is Map<String, dynamic>) pago = first;
    }

    Map<String, dynamic>? cita;
    if (citasRaw is Map<String, dynamic>) {
      cita = citasRaw;
    } else if (citasRaw is List && citasRaw.isNotEmpty) {
      final first = citasRaw.first;
      if (first is Map<String, dynamic>) cita = first;
    }

    Map<String, dynamic>? dir;
    if (dirRaw is Map<String, dynamic>) {
      dir = dirRaw;
    } else if (dirRaw is List && dirRaw.isNotEmpty) {
      final first = dirRaw.first;
      if (first is Map<String, dynamic>) dir = first;
    }

    return SeguimientoSolicitudModel(
      id: json['id']?.toString() ?? '',
      estado: json['estado']?.toString() ?? '',
      fechaSolicitud: _parseDate(json['fecha_solicitud']) ?? DateTime.now(),
      fechaProgramada: _parseDate(json['fecha_programada']),
      fechaExpiracion: _parseDate(json['fecha_expiracion']),
      servicios: detalles,
      montoTotal: (pago?['monto_total'] as num?)?.toDouble() ?? 0,
      deposito: (pago?['deposito'] as num?)?.toDouble() ?? 0,
      saldoPendiente: (pago?['saldo_pendiente'] as num?)?.toDouble() ?? 0,
      ciudad: dir?['ciudad']?.toString(),
      citaEstado: cita?['estado']?.toString(),
      citaFechaAceptacion: _parseDate(cita?['fecha_aceptacion']),
      citaId: cita?['id']?.toString(),
      yaEvaluado: _yaEvaluado(cita?['evaluaciones_servicio']),
      observaciones: json['observaciones_paciente']?.toString(),
    );
  }

  static bool _yaEvaluado(dynamic evaluaciones) {
    if (evaluaciones is List && evaluaciones.isNotEmpty) return true;
    return evaluaciones is Map<String, dynamic> && evaluaciones.isNotEmpty;
  }

  SeguimientoSolicitudEntity toEntity() {
    return SeguimientoSolicitudEntity(
      id: id,
      estado: estado,
      fechaSolicitud: fechaSolicitud,
      fechaProgramada: fechaProgramada,
      fechaExpiracion: fechaExpiracion,
      servicios: servicios,
      montoTotal: montoTotal,
      deposito: deposito,
      saldoPendiente: saldoPendiente,
      ciudad: ciudad,
      citaEstado: citaEstado,
      citaFechaAceptacion: citaFechaAceptacion,
      citaId: citaId,
      yaEvaluado: yaEvaluado,
      observaciones: observaciones,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
