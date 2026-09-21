import '../../domain/entities/ventas_entities.dart';

/// Modelo del json de `dashboard_ventas_resumen`.
class ResumenVentasModel {
  final double montosRecibidos;
  final double montosPagados;
  final double comisionPorcentaje;
  final double netoEspecialistas;
  final int citasRealizadas;
  final int serviciosAplicados;
  final int solicitudes;
  final int usuariosActivos;

  const ResumenVentasModel({
    required this.montosRecibidos,
    required this.montosPagados,
    required this.comisionPorcentaje,
    required this.netoEspecialistas,
    required this.citasRealizadas,
    required this.serviciosAplicados,
    required this.solicitudes,
    required this.usuariosActivos,
  });

  factory ResumenVentasModel.fromJson(Map<String, dynamic> json) {
    return ResumenVentasModel(
      montosRecibidos: _toDouble(json['montos_recibidos']),
      montosPagados: _toDouble(json['montos_pagados']),
      comisionPorcentaje: _toDouble(json['comision_porcentaje'], fallback: 20),
      netoEspecialistas: _toDouble(json['neto_especialistas']),
      citasRealizadas: _toInt(json['citas_realizadas']),
      serviciosAplicados: _toInt(json['servicios_aplicados']),
      solicitudes: _toInt(json['solicitudes']),
      usuariosActivos: _toInt(json['usuarios_activos']),
    );
  }

  ResumenVentasEntity toEntity() {
    return ResumenVentasEntity(
      montosRecibidos: montosRecibidos,
      montosPagados: montosPagados,
      comisionPorcentaje: comisionPorcentaje,
      netoEspecialistas: netoEspecialistas,
      citasRealizadas: citasRealizadas,
      serviciosAplicados: serviciosAplicados,
      solicitudes: solicitudes,
      usuariosActivos: usuariosActivos,
    );
  }
}

/// Modelo de una fila de `dashboard_ventas_por_servicio`.
class VentaPorServicioModel {
  final String servicioId;
  final String servicioNombre;
  final int cantidad;
  final double montoTotal;
  final double montoComision;

  const VentaPorServicioModel({
    required this.servicioId,
    required this.servicioNombre,
    required this.cantidad,
    required this.montoTotal,
    required this.montoComision,
  });

  factory VentaPorServicioModel.fromJson(Map<String, dynamic> json) {
    return VentaPorServicioModel(
      servicioId: json['servicio_id'] as String? ?? '',
      servicioNombre: json['servicio_nombre'] as String? ?? '—',
      cantidad: _toInt(json['cantidad']),
      montoTotal: _toDouble(json['monto_total']),
      montoComision: _toDouble(json['monto_comision']),
    );
  }

  VentaPorServicioEntity toEntity() {
    return VentaPorServicioEntity(
      servicioId: servicioId,
      servicioNombre: servicioNombre,
      cantidad: cantidad,
      montoTotal: montoTotal,
      montoComision: montoComision,
    );
  }
}

/// Modelo de una fila de `dashboard_ventas_por_especialista`.
class VentaPorEspecialistaModel {
  final String especialistaId;
  final String especialistaNombre;
  final int citas;
  final int servicios;
  final double montoTotal;
  final double montoComision;
  final double montoEspecialista;

  const VentaPorEspecialistaModel({
    required this.especialistaId,
    required this.especialistaNombre,
    required this.citas,
    required this.servicios,
    required this.montoTotal,
    required this.montoComision,
    required this.montoEspecialista,
  });

  factory VentaPorEspecialistaModel.fromJson(Map<String, dynamic> json) {
    return VentaPorEspecialistaModel(
      especialistaId: json['especialista_id'] as String? ?? '',
      especialistaNombre: json['especialista_nombre'] as String? ?? '—',
      citas: _toInt(json['citas']),
      servicios: _toInt(json['servicios']),
      montoTotal: _toDouble(json['monto_total']),
      montoComision: _toDouble(json['monto_comision']),
      montoEspecialista: _toDouble(json['monto_especialista']),
    );
  }

  VentaPorEspecialistaEntity toEntity() {
    return VentaPorEspecialistaEntity(
      especialistaId: especialistaId,
      especialistaNombre: especialistaNombre,
      citas: citas,
      servicios: servicios,
      montoTotal: montoTotal,
      montoComision: montoComision,
      montoEspecialista: montoEspecialista,
    );
  }
}

/// Modelo de un punto de `dashboard_ventas_serie`.
class PuntoSerieVentasModel {
  final DateTime periodo;
  final double montoRecibido;
  final double montoPagado;
  final int citas;

  const PuntoSerieVentasModel({
    required this.periodo,
    required this.montoRecibido,
    required this.montoPagado,
    required this.citas,
  });

  factory PuntoSerieVentasModel.fromJson(Map<String, dynamic> json) {
    return PuntoSerieVentasModel(
      periodo: DateTime.tryParse(json['periodo'] as String? ?? '') ??
          DateTime(2000),
      montoRecibido: _toDouble(json['monto_recibido']),
      montoPagado: _toDouble(json['monto_pagado']),
      citas: _toInt(json['citas']),
    );
  }

  PuntoSerieVentasEntity toEntity() {
    return PuntoSerieVentasEntity(
      periodo: periodo,
      montoRecibido: montoRecibido,
      montoPagado: montoPagado,
      citas: citas,
    );
  }
}

double _toDouble(dynamic value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

int _toInt(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}