import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:esteticaybellezastrani/features/patients_compliance/presentation/screens/face_map_questionnaire_screen.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/presentation/widgets/face_map_canvas.dart';

void main() {
  final puntos = <InjectionPoint>[
    InjectionPoint(
      id: 'frente',
      label: 'Frente',
      offsets: {HeadView.frente: const Offset(0.500, 0.220)},
    ),
    InjectionPoint(
      id: 'menton',
      label: 'Mentón',
      offsets: {HeadView.frente: const Offset(0.500, 0.730)},
    ),
  ];

  const zonas = <ForbiddenRegion>[
    ForbiddenRegion(
      id: 'ojo_derecho',
      title: 'Cavidad Ocular Derecha',
      reason: 'Prohibido por la FDA',
      bounds: {HeadView.frente: Rect.fromLTRB(0.550, 0.380, 0.630, 0.460)},
    ),
  ];

  Future<void> pumpCanvas(
    WidgetTester tester, {
    required Size size,
    List<InjectionPoint> seleccionados = const [],
    void Function(InjectionPoint punto)? onTogglePunto,
    void Function(ForbiddenRegion region)? onZonaProhibida,
    Widget Function(InjectionPoint punto)? buildBadge,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FaceMapCanvas(
              puntos: puntos,
              zonasProhibidas: zonas,
              seleccionados: seleccionados,
              onTogglePunto: onTogglePunto ?? (_) {},
              onCustomPunto: (_) {},
              onZonaProhibida: onZonaProhibida ?? (_) {},
              buildBadge: buildBadge,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const sizes = [Size(320, 640), Size(400, 800), Size(768, 1024), Size(1024, 768)];

  testWidgets('renderiza sin overflow ni excepciones en múltiples tamaños',
      (tester) async {
    for (final size in sizes) {
      await pumpCanvas(tester, size: size);
      expect(tester.takeException(), isNull, reason: 'tamaño: $size');
      expect(find.byType(FaceMapCanvas), findsOneWidget);
    }
  });

  testWidgets('tocar un punto predefinido lo selecciona en distintos tamaños',
      (tester) async {
    for (final size in sizes) {
      InjectionPoint? tocado;
      await pumpCanvas(tester, size: size, onTogglePunto: (p) => tocado = p);
      final rect = tester.getRect(find.byType(PageView));
      final target = rect.topLeft +
          Offset(0.500 * rect.width, 0.220 * rect.height);
      await tester.tapAt(target);
      await tester.pump();
      expect(tocado?.id, 'frente', reason: 'tamaño: $size');
      expect(tester.takeException(), isNull, reason: 'tamaño: $size');
    }
  });

  testWidgets('tocar un pin ya seleccionado dispara onTogglePunto (editar)',
      (tester) async {
    InjectionPoint? tocado;
    await pumpCanvas(
      tester,
      size: const Size(400, 800),
      seleccionados: [puntos.first],
      onTogglePunto: (p) => tocado = p,
    );
    final rect = tester.getRect(find.byType(PageView));
    final target = rect.topLeft + Offset(0.500 * rect.width, 0.220 * rect.height);
    await tester.tapAt(target);
    await tester.pump();
    expect(tocado?.id, 'frente');
  });

  testWidgets('tocar una zona prohibida dispara onZonaProhibida (FDA)',
      (tester) async {
    ForbiddenRegion? zona;
    await pumpCanvas(
      tester,
      size: const Size(400, 800),
      onZonaProhibida: (r) => zona = r,
    );
    final rect = tester.getRect(find.byType(PageView));
    final target = rect.topLeft + Offset(0.590 * rect.width, 0.420 * rect.height);
    await tester.tapAt(target);
    await tester.pump();
    expect(zona?.id, 'ojo_derecho');
  });

  testWidgets('muestra el badge de producto/cantidad bajo un pin seleccionado',
      (tester) async {
    await pumpCanvas(
      tester,
      size: const Size(400, 800),
      seleccionados: [puntos.first],
      buildBadge: (p) => const Text('15 unidades'),
    );
    expect(find.text('15 unidades'), findsOneWidget);
  });
}