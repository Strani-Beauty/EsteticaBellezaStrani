import 'package:equatable/equatable.dart';

/// Estados de una liquidación (`liquidaciones_especialistas.estado`).
enum EstadoLiquidacion {
  pendiente('PENDIENTE'),
  enRevision('EN_REVISION'),
  aprobada('APROBADA'),
  pagada('PAGADA'),
  anulada('ANULADA');

  const EstadoLiquidacion(this.db);

  final String db;

  String get toDb => db;

  static EstadoLiquidacion? fromDb(String? value) {
    for (final e in EstadoLiquidacion.values) {
      if (e.db == value) return e;
    }
    return null;
  }
}

/// Liquidación de un especialista (`liquidaciones_especialistas`).
class LiquidacionEntity extends Equatable {
  final String id;
  final String especialistaId;
  final String? especialistaNombre;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final double montoTotalServicios;
  final double montoComision;
  final double montoPagar;
  final EstadoLiquidacion? estado;
  final DateTime? fechaPago;

  const LiquidacionEntity({
    required this.id,
    required this.especialistaId,
    this.especialistaNombre,
    this.fechaInicio,
    this.fechaFin,
    this.montoTotalServicios = 0,
    this.montoComision = 0,
    this.montoPagar = 0,
    this.estado,
    this.fechaPago,
  });

  @override
  List<Object?> get props => [id, especialistaId, estado];
}

/// Pago a un especialista (`pagos_especialistas`).
class PagoEspecialistaEntity extends Equatable {
  final String id;
  final String liquidacionId;
  final String especialistaId;
  final String? especialistaNombre;
  final DateTime? fechaPago;
  final double montoPagado;
  final String? metodoPago;
  final String? referenciaPago;
  final String? comprobanteUrl;
  final String? notas;

  const PagoEspecialistaEntity({
    required this.id,
    required this.liquidacionId,
    required this.especialistaId,
    this.especialistaNombre,
    this.fechaPago,
    this.montoPagado = 0,
    this.metodoPago,
    this.referenciaPago,
    this.comprobanteUrl,
    this.notas,
  });

  @override
  List<Object?> get props => [id, liquidacionId, especialistaId];
}

/// Línea de detalle de una liquidación (`liquidacion_detalles`).
class DetalleLiquidacionEntity extends Equatable {
  final String id;
  final String liquidacionId;
  final String citaId;
  final double montoServicio;
  final double comisionAplicada;
  final double montoEspecialista;

  const DetalleLiquidacionEntity({
    required this.id,
    required this.liquidacionId,
    required this.citaId,
    this.montoServicio = 0,
    this.comisionAplicada = 0,
    this.montoEspecialista = 0,
  });

  @override
  List<Object?> get props => [id, liquidacionId, citaId];
}

/// Cita terminada elegible para liquidación (vista del corte semanal).
class CitaFinalizadaAdminEntity extends Equatable {
  final String citaId;
  final String? solicitudId;
  final String? especialistaId;
  final String? especialistaNombre;
  final DateTime? fechaFinalizacion;
  final double montoTotal;
  final double deposito;
  final double saldoPendiente;
  final String estadoPago;

  const CitaFinalizadaAdminEntity({
    required this.citaId,
    this.solicitudId,
    this.especialistaId,
    this.especialistaNombre,
    this.fechaFinalizacion,
    this.montoTotal = 0,
    this.deposito = 0,
    this.saldoPendiente = 0,
    this.estadoPago = '',
  });

  bool get estaPagada => saldoPendiente <= 0;

  @override
  List<Object?> get props => [citaId, solicitudId, especialistaId];
}