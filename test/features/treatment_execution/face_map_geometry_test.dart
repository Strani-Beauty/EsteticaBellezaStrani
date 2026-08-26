import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:esteticaybellezastrani/features/patients_compliance/presentation/screens/face_map_questionnaire_screen.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/presentation/widgets/face_map_geometry.dart';

void main() {
  group('normalizarTap — independencia del tamaño de pantalla (Act. 14)', () {
    test('origen → (0,0)', () {
      final p = normalizarTap(const Offset(0, 0), const Size(400, 400));
      expect(p.dx, 0.0);
      expect(p.dy, 0.0);
    });

    test('extremo → (1,1)', () {
      final p = normalizarTap(const Offset(400, 400), const Size(400, 400));
      expect(p.dx, 1.0);
      expect(p.dy, 1.0);
    });

    test('centro → (0.5, 0.5)', () {
      final p = normalizarTap(const Offset(200, 200), const Size(400, 400));
      expect(p.dx, closeTo(0.5, 1e-6));
      expect(p.dy, closeTo(0.5, 1e-6));
    });

    test('el mismo punto relativo en distintos tamaños produce la misma '
        'coordenada normalizada', () {
      for (final size in const [
        Size(280, 280),
        Size(400, 400),
        Size(480, 480),
        Size(800, 800),
      ]) {
        final p = normalizarTap(
          Offset(size.width * 0.356, size.height * 0.235),
          size,
        );
        expect(p.dx, closeTo(0.356, 1e-6));
        expect(p.dy, closeTo(0.235, 1e-6));
      }
    });

    test('clampa taps fuera del canvas a 0..1', () {
      final p = normalizarTap(const Offset(-20, 420), const Size(400, 400));
      expect(p.dx, 0.0);
      expect(p.dy, 1.0);
    });

    test('tamaño inválido devuelve Offset.zero', () {
      expect(normalizarTap(const Offset(10, 10), const Size(0, 0)), Offset.zero);
      expect(
        normalizarTap(const Offset(10, 10), const Size(-1, 5)),
        Offset.zero,
      );
    });
  });

  group('puntoCercano', () {
    final punto = InjectionPoint(
      id: 'frente',
      label: 'Frente',
      offsets: {HeadView.frente: const Offset(0.500, 0.220)},
    );

    test('detecta el punto dentro del radio por defecto', () {
      final hit =
          puntoCercano(const Offset(0.51, 0.23), HeadView.frente, [punto]);
      expect(hit?.id, 'frente');
    });

    test('devuelve null fuera del radio', () {
      expect(
        puntoCercano(const Offset(0.5, 0.5), HeadView.frente, [punto]),
        isNull,
      );
    });

    test('respeta un radio configurable', () {
      final p2 = InjectionPoint(
        id: 'p2',
        label: 'P2',
        offsets: {HeadView.izq: const Offset(0.1, 0.1)},
      );
      expect(
        puntoCercano(const Offset(0.16, 0.1), HeadView.izq, [p2], radio: 0.3)
            ?.id,
        'p2',
      );
    });

    test('usa solo la vista correcta del punto', () {
      expect(puntoCercano(const Offset(0.1, 0.1), HeadView.der, [punto]), isNull);
    });
  });

  group('zonaProhibidaEn', () {
    const zona = ForbiddenRegion(
      id: 'ojo_derecho',
      title: 'Cavidad Ocular Derecha',
      reason: 'Prohibido por la FDA',
      bounds: {HeadView.frente: Rect.fromLTRB(0.550, 0.380, 0.630, 0.460)},
    );

    test('detecta un toque dentro de la zona', () {
      expect(
        zonaProhibidaEn(const Offset(0.59, 0.42), HeadView.frente, const [zona])
            ?.id,
        'ojo_derecho',
      );
    });

    test('devuelve null fuera de la zona', () {
      expect(
        zonaProhibidaEn(const Offset(0.5, 0.2), HeadView.frente, const [zona]),
        isNull,
      );
    });

    test('devuelve null si la zona no cubre la vista actual', () {
      expect(
        zonaProhibidaEn(const Offset(0.59, 0.42), HeadView.der, const [zona]),
        isNull,
      );
    });
  });

  group('enRegionCustom', () {
    test('acepta un punto dentro de la región válida', () {
      expect(enRegionCustom(const Offset(0.5, 0.5)), isTrue);
    });

    test('rechaza fuera por el borde vertical', () {
      expect(enRegionCustom(const Offset(0.5, 0.05)), isFalse);
      expect(enRegionCustom(const Offset(0.5, 0.95)), isFalse);
    });

    test('rechaza fuera por el borde horizontal', () {
      expect(enRegionCustom(const Offset(0.05, 0.5)), isFalse);
      expect(enRegionCustom(const Offset(0.95, 0.5)), isFalse);
    });
  });
}