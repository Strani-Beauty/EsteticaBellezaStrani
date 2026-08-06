import 'package:equatable/equatable.dart';

/// Entidad de dominio: `productos_aplicados` (insumos usados en un tratamiento).
class ProductoAplicadoEntity extends Equatable {
  final String id;
  final String tratamientoId;
  final String productoNombre;
  final String? fabricante;
  final String? lote;
  final double cantidadTotal;
  final String? unidadMedida;
  final DateTime? fechaVencimiento;
  final String? observaciones;
  final DateTime createdAt;

  const ProductoAplicadoEntity({
    required this.id,
    required this.tratamientoId,
    required this.productoNombre,
    this.fabricante,
    this.lote,
    this.cantidadTotal = 1,
    this.unidadMedida,
    this.fechaVencimiento,
    this.observaciones,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        tratamientoId,
        productoNombre,
        fabricante,
        lote,
        cantidadTotal,
        unidadMedida,
        fechaVencimiento,
        observaciones,
        createdAt,
      ];
}
