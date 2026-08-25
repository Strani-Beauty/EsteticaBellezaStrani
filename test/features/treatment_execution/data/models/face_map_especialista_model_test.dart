import 'package:flutter_test/flutter_test.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/data/models/face_map_especialista_model.dart';
import 'package:esteticaybellezastrani/features/treatment_execution/domain/entities/face_map_especialista_entity.dart';

void main() {
  group('FaceMapEspecialistaModel', () {
    test('fromJson parsea los campos del mapa', () {
      final model = FaceMapEspecialistaModel.fromJson({
        'id': 'fm-1',
        'tratamiento_id': 't-1',
        'paciente_id': 'p-1',
        'servicio_id': 's-1',
        'tipo_mapa': 'ROSTRO',
        'imagen_base_url': 'https://bucket/fm.png',
        'observaciones': 'Puntos de relleno en pómulos',
      });

      expect(model.id, 'fm-1');
      expect(model.tratamientoId, 't-1');
      expect(model.pacienteId, 'p-1');
      expect(model.servicioId, 's-1');
      expect(model.tipoMapa, 'ROSTRO');
      expect(model.observaciones, 'Puntos de relleno en pómulos');
    });

    test('fromJson no parsea puntos (se cargan aparte)', () {
      final model = FaceMapEspecialistaModel.fromJson({
        'id': 'fm-2',
        'puntos': [
          {'zona_anatomica': 'pomulo'},
        ],
      });
      expect(model.puntos, isEmpty);
    });

    test('fromJson usa nulls cuando faltan campos', () {
      final model = FaceMapEspecialistaModel.fromJson({});
      expect(model.id, isNull);
      expect(model.tratamientoId, isNull);
      expect(model.tipoMapa, isNull);
      expect(model.observaciones, isNull);
    });

    test('toEntity conserva observaciones y puntos', () {
      final model = FaceMapEspecialistaModel(
        id: 'fm-1',
        tratamientoId: 't-1',
        pacienteId: 'p-1',
        tipoMapa: 'ROSTRO',
        observaciones: 'Notas clínicas',
        puntos: [
          {'zona_anatomica': 'frente', 'coordenada_x': 0.5},
        ],
      );

      final entity = model.toEntity();
      expect(entity, isA<FaceMapEspecialistaEntity>());
      expect(entity.id, 'fm-1');
      expect(entity.tratamientoId, 't-1');
      expect(entity.observaciones, 'Notas clínicas');
      expect(entity.puntos, [
        {'zona_anatomica': 'frente', 'coordenada_x': 0.5},
      ]);
    });
  });
}