import 'package:flutter_test/flutter_test.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/data/models/consentimiento_model.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/entities/consentimiento_tratamiento_entity.dart';

void main() {
  group('ConsentimientoModel', () {
    test('fromJson parsea todos los campos', () {
      final model = ConsentimientoModel.fromJson({
        'id': 'cons-1',
        'tratamiento_id': 't-1',
        'paciente_id': 'p-1',
        'tipo_consentimiento': 'TRATAMIENTO_ESTETICO',
        'documento_url': 'docs/consentimiento.pdf',
        'firma_url': 't-1/firma_123.png',
        'fecha_firma': '2026-08-25T10:30:00.000Z',
        'created_at': '2026-08-25T10:30:00.000Z',
      });

      expect(model.id, 'cons-1');
      expect(model.tratamientoId, 't-1');
      expect(model.pacienteId, 'p-1');
      expect(model.tipoConsentimiento, 'TRATAMIENTO_ESTETICO');
      expect(model.documentoUrl, 'docs/consentimiento.pdf');
      expect(model.firmaUrl, 't-1/firma_123.png');
    });

    test('fromJson usa valores por defecto cuando faltan campos', () {
      final model = ConsentimientoModel.fromJson({'id': 'cons-2'});
      expect(model.tratamientoId, '');
      expect(model.pacienteId, '');
      expect(model.tipoConsentimiento, '');
      expect(model.firmaUrl, isNull);
      expect(model.fechaFirma, isNull);
    });

    test('toEntity conserva la firma y queda firmado', () {
      final model = ConsentimientoModel(
        id: 'cons-1',
        tratamientoId: 't-1',
        pacienteId: 'p-1',
        tipoConsentimiento: 'TRATAMIENTO_ESTETICO',
        firmaUrl: 't-1/firma_123.png',
        fechaFirma: '2026-08-25T10:30:00.000Z',
        createdAt: '2026-08-25T10:30:00.000Z',
      );

      final entity = model.toEntity();
      expect(entity, isA<ConsentimientoTratamientoEntity>());
      expect(entity.tratamientoId, 't-1');
      expect(entity.tipoConsentimiento, 'TRATAMIENTO_ESTETICO');
      expect(entity.firmado, isTrue);
    });

    test('toEntity queda no firmado cuando firma_url es null o vacío', () {
      final conFirmaVacia = ConsentimientoModel(
        id: 'cons-2',
        tratamientoId: 't-2',
        pacienteId: 'p-2',
        tipoConsentimiento: 'TRATAMIENTO_ESTETICO',
        firmaUrl: '',
        createdAt: '2026-08-25T10:30:00.000Z',
      );
      expect(conFirmaVacia.toEntity().firmado, isFalse);

      final sinFirma = ConsentimientoModel(
        id: 'cons-3',
        tratamientoId: 't-3',
        pacienteId: 'p-3',
        tipoConsentimiento: 'TRATAMIENTO_ESTETICO',
        createdAt: '2026-08-25T10:30:00.000Z',
      );
      expect(sinFirma.toEntity().firmado, isFalse);
    });
  });
}