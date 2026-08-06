import 'package:flutter/material.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import '../../domain/entities/producto_aplicado_entity.dart';

/// Tarjeta de un insumo aplicado en el tratamiento.
class ProductoCard extends StatelessWidget {
  final ProductoAplicadoEntity producto;
  final VoidCallback? onDelete;
  const ProductoCard({super.key, required this.producto, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final detalles = <String>[
      if (producto.lote != null) 'Lote ${producto.lote}',
      if (producto.unidadMedida != null) producto.unidadMedida!,
      if (producto.fabricante != null) producto.fabricante!,
    ];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        dense: true,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: AppTheme.cBrandGreen,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.science_outlined, color: Colors.white, size: 18),
        ),
        title: Text(producto.productoNombre,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${producto.cantidadTotal}${producto.unidadMedida ?? ' u'}'
          '${detalles.isNotEmpty ? ' · ${detalles.join(' · ')}' : ''}',
        ),
        trailing: onDelete == null
            ? null
            : IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline,
                    color: Colors.redAccent),
              ),
      ),
    );
  }
}