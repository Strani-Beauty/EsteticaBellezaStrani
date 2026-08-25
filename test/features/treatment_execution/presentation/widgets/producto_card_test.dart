import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/entities/producto_aplicado_entity.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/presentation/widgets/producto_card.dart';

void main() {
  final producto = ProductoAplicadoEntity(
    id: 'prod-1',
    tratamientoId: 'trat-1',
    productoNombre: 'Ácido hialurónico',
    lote: 'L-2026',
    cantidadTotal: 1,
    unidadMedida: 'ml',
    fabricante: 'Dermalab',
    createdAt: DateTime(2026, 8, 25, 10, 0),
  );

  Widget pumpProducto({VoidCallback? onDelete}) => MaterialApp(
        home: Scaffold(
          body: ProductoCard(producto: producto, onDelete: onDelete),
        ),
      );

  testWidgets('ProductoCard muestra nombre, cantidad y unidad del producto',
      (tester) async {
    await tester.pumpWidget(pumpProducto());
    expect(find.text('Ácido hialurónico'), findsOneWidget);
    expect(find.textContaining('1.0ml'), findsOneWidget);
    expect(find.textContaining('L-2026'), findsOneWidget);
    expect(find.textContaining('Dermalab'), findsOneWidget);
  });

  testWidgets('ProductoCard usa "u" cuando no hay unidad de medida',
      (tester) async {
    final sinUnidad = ProductoAplicadoEntity(
      id: 'prod-2',
      tratamientoId: 'trat-1',
      productoNombre: 'Solución antiséptica',
      cantidadTotal: 3,
      createdAt: DateTime(2026, 8, 25, 10, 0),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProductoCard(producto: sinUnidad)),
      ),
    );
    expect(find.textContaining('3.0 u'), findsOneWidget);
  });

  testWidgets('ProductoCard no muestra botón eliminar sin onDelete',
      (tester) async {
    await tester.pumpWidget(pumpProducto());
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('ProductoCard muestra botón eliminar y lo invoca al pulsarlo',
      (tester) async {
    var eliminado = false;
    await tester.pumpWidget(pumpProducto(onDelete: () => eliminado = true));
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_outline));
    expect(eliminado, isTrue);
  });
}