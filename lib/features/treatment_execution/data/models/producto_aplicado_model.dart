import '../../domain/entities/producto_aplicado_entity.dart';

/// Modelo de `productos_aplicados`.
class ProductoAplicadoModel {
  final String id;
  final String tratamientoId;
  final String productoNombre;
  final String? fabricante;
  final String? lote;
  final double cantidadTotal;
  final String? unidadMedida;
  final String? fechaVencimiento;
  final String? observaciones;
  final String? createdAt;

  const ProductoAplicadoModel({
    required this.id,
    required this.tratamientoId,
    required this.productoNombre,
    this.fabricante,
    this.lote,
    this.cantidadTotal = 1,
    this.unidadMedida,
    this.fechaVencimiento,
    this.observaciones,
    this.createdAt,
  });

  factory ProductoAplicadoModel.fromJson(Map<String, dynamic> json) {
    return ProductoAplicadoModel(
      id: json['id'] as String? ?? '',
      tratamientoId: json['tratamiento_id'] as String? ?? '',
      productoNombre: json['producto_nombre'] as String? ?? '',
      fabricante: json['fabricante'] as String?,
      lote: json['lote'] as String?,
      cantidadTotal: (json['cantidad_total'] as num?)?.toDouble() ?? 1,
      unidadMedida: json['unidad_medida'] as String?,
      fechaVencimiento: json['fecha_vencimiento']?.toString(),
      observaciones: json['observaciones'] as String?,
      createdAt: json['created_at']?.toString(),
    );
  }

  ProductoAplicadoEntity toEntity() {
    return ProductoAplicadoEntity(
      id: id,
      tratamientoId: tratamientoId,
      productoNombre: productoNombre,
      fabricante: fabricante,
      lote: lote,
      cantidadTotal: cantidadTotal,
      unidadMedida: unidadMedida,
      fechaVencimiento: _parseDate(fechaVencimiento),
      observaciones: observaciones,
      createdAt: _parseDate(createdAt) ?? DateTime.now(),
    );
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
