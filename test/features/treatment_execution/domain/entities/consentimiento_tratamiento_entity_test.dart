import 'package:flutter_test/flutter_test.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/entities/consentimiento_tratamiento_entity.dart';

void main() {
  final createdAt = DateTime(2026, 8, 25, 10);

  ConsentimientoTratamientoEntity build({
    String? firmaUrl,
  }) {
    return ConsentimientoTratamientoEntity(
      id: 'cons-1',
      tratamientoId: 't-1',
      pacienteId: 'p-1',
      tipoConsentimiento: 'TRATAMIENTO_ESTETICO',
      firmaUrl: firmaUrl,
      fechaFirma: DateTime(2026, 8, 25, 10, 30),
      createdAt: createdAt,
    );
  }

  group('ConsentimientoTratamientoEntity', () {
    test('firmado es true cuando hay firma_url', () {
      expect(build(firmaUrl: 't-1/firma_123.png').firmado, isTrue);
    });

    test('firmado es false cuando firma_url es null', () {
      expect(build().firmado, isFalse);
    });

    test('firmado es false cuando firma_url es vacío', () {
      expect(build(firmaUrl: '').firmado, isFalse);
    });

    test('expone tratamientoId, pacienteId y tipo de consentimiento', () {
      final cons = build(firmaUrl: 't-1/firma_123.png');
      expect(cons.tratamientoId, 't-1');
      expect(cons.pacienteId, 'p-1');
      expect(cons.tipoConsentimiento, 'TRATAMIENTO_ESTETICO');
      expect(cons.fechaFirma, DateTime(2026, 8, 25, 10, 30));
    });

    test('la igualdad incluye la firma en los props', () {
      final a = build(firmaUrl: 't-1/firma_1.png');
      final b = build(firmaUrl: 't-1/firma_2.png');
      expect(a, isNot(equals(b)));
    });
  });
}