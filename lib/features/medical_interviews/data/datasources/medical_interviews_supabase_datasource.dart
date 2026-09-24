import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/config/app_constants.dart';
import '../models/entrevista_medica_model.dart';

/// Datasource de Supabase para el módulo de entrevistas médicas F2F (ePHI).
/// Solo habla con Supabase y devuelve Models (patrón Clean Architecture).
class MedicalInterviewsSupabaseDataSource {
  final SupabaseClient _client;

  MedicalInterviewsSupabaseDataSource(this._client);

  // ── Helpers ────────────────────────────────────────────────────────────────

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw Exception('RN: no hay sesión activa de usuario.');
    }
    return id;
  }

  Future<String?> _getPacienteId() async {
    final res = await _client
        .from('pacientes')
        .select('id')
        .eq('usuario_id', _userId)
        .maybeSingle();
    return res?['id'] as String?;
  }

  static const _selectJoin = '*, pacientes(usuario_id, profiles(full_name, email))';

  // ── Lecturas (admin) ───────────────────────────────────────────────────────

  /// Lista de entrevistas (admin), opcionalmente filtradas por estado.
  Future<List<EntrevistaMedicaModel>> fetchEntrevistas({String? estado}) async {
    var query = _client.from('entrevistas_medicas').select(_selectJoin);
    if (estado != null && estado.isNotEmpty) {
      query = query.eq('estado', estado);
    }
    final res = await query.order('fecha_programada', ascending: false);
    return [
      for (final r in res) EntrevistaMedicaModel.fromJson(r),
    ];
  }

  Future<EntrevistaMedicaModel?> fetchEntrevistaById(String id) async {
    final res = await _client
        .from('entrevistas_medicas')
        .select(_selectJoin)
        .eq('id', id)
        .maybeSingle();
    if (res == null) return null;
    return EntrevistaMedicaModel.fromJson(res);
  }

  /// Última entrevista del paciente autenticado (o `null`).
  Future<EntrevistaMedicaModel?> fetchMiEntrevista() async {
    final pacienteId = await _getPacienteId();
    if (pacienteId == null) return null;
    final res = await _client
        .from('entrevistas_medicas')
        .select(_selectJoin)
        .eq('paciente_id', pacienteId)
        .order('fecha_programada', ascending: false)
        .limit(1)
        .maybeSingle();
    if (res == null) return null;
    return EntrevistaMedicaModel.fromJson(res);
  }

  // ── RPCs (autoridad en BD) ────────────────────────────────────────────────

  /// Agenda una entrevista (RPC admin); el RPC solo devuelve `{id, sala_id,...}`,
  /// así que se re-consulta la fila para devolver el modelo completo.
  Future<EntrevistaMedicaModel> agendarEntrevista({
    required String pacienteId,
    required DateTime fechaProgramada,
    int duracionMin = 30,
    String? evaluacionSaludId,
  }) async {
    final res = await _client.rpc(
      'agendar_entrevista',
      params: {
        'p_paciente_id': pacienteId,
        'p_fecha_programada': fechaProgramada.toUtc().toIso8601String(),
        'p_duracion_min': duracionMin,
        'p_evaluacion_salud_id': ?evaluacionSaludId,
      },
    ) as Map<String, dynamic>;

    final id = res['id'] as String?;
    if (id == null) throw Exception('No se pudo agendar la entrevista.');

    final creada = await fetchEntrevistaById(id);
    if (creada == null) throw Exception('No se pudo leer la entrevista agendada.');
    return creada;
  }

  Future<void> iniciarEntrevista(String entrevistaId) async {
    await _client.rpc(
      'iniciar_entrevista',
      params: {'p_entrevista_id': entrevistaId},
    );
  }

  Future<void> emitirDictamenEntrevista({
    required String entrevistaId,
    required bool aprobado,
    required String observaciones,
    String? hallazgos,
  }) async {
    await _client.rpc(
      'emitir_dictamen_entrevista',
      params: {
        'p_entrevista_id': entrevistaId,
        'p_aprobado': aprobado,
        'p_observaciones': observaciones,
        'p_hallazgos': ?hallazgos,
      },
    );
  }

  Future<void> registrarConsentimientoEntrevista({
    required String entrevistaId,
    required String firmaUrl,
  }) async {
    await _client.rpc(
      'registrar_consentimiento_entrevista',
      params: {
        'p_entrevista_id': entrevistaId,
        'p_firma_url': firmaUrl,
      },
    );
  }

  Future<void> registrarGrabacionEntrevista({
    required String entrevistaId,
    required String path,
  }) async {
    await _client.rpc(
      'guardar_grabacion_entrevista',
      params: {'p_entrevista_id': entrevistaId, 'p_path': path},
    );
  }

  // ── Notas clínicas (admin, UPDATE directo permitido por RLS/trigger) ───────

  Future<void> updateNotasEntrevista({
    required String entrevistaId,
    required String notasClinicas,
    String? hallazgos,
  }) async {
    await _client.from('entrevistas_medicas').update({
      'notas_clinicas': notasClinicas,
      'hallazgos': ?hallazgos,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', entrevistaId);
  }

  // ── Storage (bucket privado `entrevistas-medicas`) ────────────────────────

  /// Sube la firma del paciente y devuelve el PATH del objeto en storage.
  Future<String> subirFirmaEntrevista({
    required String entrevistaId,
    required Uint8List bytes,
  }) async {
    final path =
        '$entrevistaId/firma_${DateTime.now().millisecondsSinceEpoch}.png';
    await _client.storage
        .from(AppConstants.bucketEntrevistas)
        .uploadBinary(path, bytes);
    return path;
  }

  /// Sube la grabación local (MediaRecorder) y devuelve el PATH del objeto.
  Future<String> subirGrabacionEntrevista({
    required String entrevistaId,
    required Uint8List bytes,
    String extension = 'webm',
  }) async {
    final ext = extension.replaceAll('.', '');
    final path =
        '$entrevistaId/grabacion_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage.from(AppConstants.bucketEntrevistas).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: 'video/$ext'),
        );
    return path;
  }

  /// Genera una URL firmada (3600 s) para un objeto del bucket de entrevistas.
  Future<String?> firmarUrlEntrevista(String path) async {
    if (path.isEmpty) return null;
    return _client.storage
        .from(AppConstants.bucketEntrevistas)
        .createSignedUrl(path, 3600);
  }
}
