import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/config/app_constants.dart';
import '../../domain/entities/evaluacion_entity.dart';

/// Datasource de Supabase para el módulo de calificaciones.
/// Solo habla con Supabase y devuelve entidades.
class CalificacionesSupabaseDataSource {
  final SupabaseClient _client;

  CalificacionesSupabaseDataSource(this._client);

  /// Registra una evaluación vía RPC `registrar_evaluacion`.
  /// Devuelve el id de la evaluación creada.
  Future<String> fetchRegistrarEvaluacion({
    required String citaId,
    required int puntuacion,
    String? comentario,
  }) async {
    final res = await _client.rpc(
      AppConstants.rpcRegistrarEvaluacion,
      params: {
        'p_cita_id': citaId,
        'p_puntuacion': puntuacion,
        if (comentario != null && comentario.isNotEmpty)
          'p_comentario': comentario,
      },
    );
    final map = res == null
        ? const <String, dynamic>{}
        : Map<String, dynamic>.from(res as Map);
    final ok = map['ok'] == true;
    if (!ok) {
      throw Exception(map['motivo']?.toString() ?? 'NO_EVALUADO');
    }
    return map['evaluacion_id']?.toString() ?? '';
  }

  /// Promedio y total de calificaciones recibidas por un especialista.
  Future<PromedioEspecialistaEntity> fetchPromedioEspecialista(
      String especialistaId) async {
    final res = await _client.rpc(
      AppConstants.rpcGetPromedioEspecialista,
      params: {'p_especialista_id': especialistaId},
    );
    if (res == null) {
      return const PromedioEspecialistaEntity();
    }
    final map = Map<String, dynamic>.from(res as Map);
    return PromedioEspecialistaEntity(
      promedio: (map['promedio'] as num?)?.toDouble() ?? 0,
      total: (map['total'] as num?)?.toInt() ?? 0,
    );
  }
}