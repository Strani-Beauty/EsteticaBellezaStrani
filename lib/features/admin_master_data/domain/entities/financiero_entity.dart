import 'package:equatable/equatable.dart';

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
  final String? estado;
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
    this.notas,
  });

  @override
  List<Object?> get props => [id, liquidacionId, especialistaId];
}
