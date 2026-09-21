import 'package:equatable/equatable.dart';

/// Resumen financiero del dashboard de ventas por período.
///
/// Mapea el json de `dashboard_ventas_resumen`.
class ResumenVentasEntity extends Equatable {
  final double montosRecibidos;
  final double montosPagados;
  final double comisionPorcentaje;
  final double netoEspecialistas;
  final int citasRealizadas;
  final int serviciosAplicados;
  final int solicitudes;
  final int usuariosActivos;

  const ResumenVentasEntity({
    this.montosRecibidos = 0,
    this.montosPagados = 0,
    this.comisionPorcentaje = 20,
    this.netoEspecialistas = 0,
    this.citasRealizadas = 0,
    this.serviciosAplicados = 0,
    this.solicitudes = 0,
    this.usuariosActivos = 0,
  });

  @override
  List<Object?> get props => [
        montosRecibidos,
        montosPagados,
        comisionPorcentaje,
        netoEspecialistas,
        citasRealizadas,
        serviciosAplicados,
        solicitudes,
        usuariosActivos,
      ];
}

/// Ventas agregadas por servicio (una fila por servicio con cantidades y montos).
///
/// Mapea `dashboard_ventas_por_servicio`.
class VentaPorServicioEntity extends Equatable {
  final String servicioId;
  final String servicioNombre;
  final int cantidad;
  final double montoTotal;
  final double montoComision;

  const VentaPorServicioEntity({
    required this.servicioId,
    required this.servicioNombre,
    this.cantidad = 0,
    this.montoTotal = 0,
    this.montoComision = 0,
  });

  @override
  List<Object?> get props =>
      [servicioId, servicioNombre, cantidad, montoTotal, montoComision];
}

/// Ventas agregadas por especialista.
///
/// Mapea `dashboard_ventas_por_especialista`.
class VentaPorEspecialistaEntity extends Equatable {
  final String especialistaId;
  final String especialistaNombre;
  final int citas;
  final int servicios;
  final double montoTotal;
  final double montoComision;
  final double montoEspecialista;

  const VentaPorEspecialistaEntity({
    required this.especialistaId,
    required this.especialistaNombre,
    this.citas = 0,
    this.servicios = 0,
    this.montoTotal = 0,
    this.montoComision = 0,
    this.montoEspecialista = 0,
  });

  @override
  List<Object?> get props => [
        especialistaId,
        especialistaNombre,
        citas,
        servicios,
        montoTotal,
        montoComision,
        montoEspecialista,
      ];
}

/// Punto de la serie temporal (día/semana/mes) con montos y citas.
///
/// Mapea `dashboard_ventas_serie`.
class PuntoSerieVentasEntity extends Equatable {
  final DateTime periodo;
  final double montoRecibido;
  final double montoPagado;
  final int citas;

  const PuntoSerieVentasEntity({
    required this.periodo,
    this.montoRecibido = 0,
    this.montoPagado = 0,
    this.citas = 0,
  });

  @override
  List<Object?> get props => [periodo, montoRecibido, montoPagado, citas];
}