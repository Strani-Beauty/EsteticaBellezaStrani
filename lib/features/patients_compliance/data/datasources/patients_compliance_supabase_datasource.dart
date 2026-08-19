import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cuestionario_model.dart';
import '../models/evaluacion_salud_model.dart';
import '../models/paciente_model.dart';
import '../models/validacion_telemedicina_model.dart';

/// Datasource de Supabase para el módulo de salud/compliance del paciente.
/// Solo habla con Supabase y devuelve Models (patrón Clean Architecture).
class PatientsComplianceSupabaseDataSource {
  final SupabaseClient _client;

  PatientsComplianceSupabaseDataSource(this._client);

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

  // ── Paciente ───────────────────────────────────────────────────────────────

  /// Flags del perfil del usuario autenticado (`profiles`).
  Future<Map<String, dynamic>?> fetchMiProfile() async {
    final res = await _client
        .from('profiles')
        .select('payment_completed, activo, evaluation_passed')
        .eq('id', _userId)
        .maybeSingle();
    return res;
  }

  Future<PacienteModel?> fetchMiPaciente() async {
    final res = await _client
        .from('pacientes')
        .select()
        .eq('usuario_id', _userId)
        .maybeSingle();
    if (res == null) return null;
    return PacienteModel.fromJson(res);
  }

  Future<PacienteModel?> updateMiPaciente({
    DateTime? fechaNacimiento,
    String? genero,
    String? grupoSanguineo,
    String? alergias,
    String? antecedentes,
    bool? activo,
  }) async {
    final payload = <String, dynamic>{
      if (fechaNacimiento != null)
        'fecha_nacimiento': fechaNacimiento.toIso8601String().split('T').first,
      'genero': ?genero,
      'grupo_sanguineo': ?grupoSanguineo,
      'alergias': ?alergias,
      'antecedentes': ?antecedentes,
      'activo': ?activo,
      'updated_at': DateTime.now().toIso8601String(),
    };
    final res = await _client
        .from('pacientes')
        .update(payload)
        .eq('usuario_id', _userId)
        .select()
        .maybeSingle();
    return res == null ? null : PacienteModel.fromJson(res);
  }

  // ── Cuestionarios y preguntas ─────────────────────────────────────────────

  Future<List<CuestionarioModel>> fetchCuestionarios({bool soloActivos = false}) async {
    var query = _client.from('cuestionarios').select();
    if (soloActivos) query = query.eq('activo', true);
    final res = await query.order('nombre', ascending: true).order('version', ascending: false);
    return [
      for (final r in res) CuestionarioModel.fromJson(r),
    ];
  }

  /// Devuelve el cuestionario activo (producto: un solo cuestionario de salud).
  Future<CuestionarioModel?> fetchCuestionarioActivo() async {
    final res = await _client
        .from('cuestionarios')
        .select()
        .eq('activo', true)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (res == null) return null;
    return CuestionarioModel.fromJson(res);
  }

  Future<List<PreguntaModel>> fetchCuestionarioPreguntas(int cuestionarioId) async {
    final res = await _client
        .from('cuestionario_preguntas')
        .select('orden, preguntas(id, pregunta, tipo_respuesta, obligatoria, ayuda, opciones, riesgo, activo, created_at)')
        .eq('cuestionario_id', cuestionarioId)
        .order('orden', ascending: true);

    final List<PreguntaModel> preguntas = [];
    for (final row in res) {
      final p = row['preguntas'];
      if (p is Map<String, dynamic>) {
        final json = Map<String, dynamic>.from(p);
        json['orden'] = row['orden'];
        preguntas.add(PreguntaModel.fromJson(json));
      }
    }
    return preguntas;
  }

  Future<CuestionarioModel> crearNuevaVersion(int versionActualId) async {
    final origen = await _client
        .from('cuestionarios')
        .select()
        .eq('id', versionActualId)
        .maybeSingle();
    if (origen == null) {
      throw Exception('RN: no se encontró el cuestionario origen.');
    }

    final maxVersion = await _client
        .from('cuestionarios')
        .select('version')
        .eq('nombre', origen['nombre'])
        .order('version', ascending: false)
        .limit(1)
        .maybeSingle();
    final nuevaVersion = ((maxVersion?['version'] as num?)?.toInt() ?? 0) + 1;

    final nueva = await _client.from('cuestionarios').insert({
      'nombre': origen['nombre'],
      'descripcion': origen['descripcion'],
      'activo': false,
      'version': nuevaVersion,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).select().maybeSingle();
    if (nueva == null) {
      throw Exception('RN: no se pudo crear la nueva versión.');
    }

    // Copia la relación de preguntas (catálogo compartido de preguntas).
    final relaciones = await _client
        .from('cuestionario_preguntas')
        .select('pregunta_id, orden')
        .eq('cuestionario_id', versionActualId);
    for (final rel in relaciones) {
      await _client.from('cuestionario_preguntas').insert({
        'cuestionario_id': nueva['id'],
        'pregunta_id': rel['pregunta_id'],
        'orden': rel['orden'],
        'activo': true,
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    return CuestionarioModel.fromJson(nueva);
  }

  Future<void> activarVersion(int cuestionarioId) async {
    final objetivo = await _client
        .from('cuestionarios')
        .select('nombre')
        .eq('id', cuestionarioId)
        .maybeSingle();
    if (objetivo == null) {
      throw Exception('RN: no se encontró la versión a activar.');
    }
    // Desactiva las otras versiones del mismo cuestionario y activa la elegida.
    await _client
        .from('cuestionarios')
        .update({'activo': false, 'updated_at': DateTime.now().toIso8601String()})
        .eq('nombre', objetivo['nombre']);
    await _client
        .from('cuestionarios')
        .update({'activo': true, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', cuestionarioId);
  }

  /// Edita una pregunta del catálogo (admin). Solo campos provistos.
  Future<void> updatePregunta({
    required int preguntaId,
    String? texto,
    String? tipoRespuesta,
    bool? obligatoria,
    List<String>? opciones,
    Map<String, dynamic>? riesgo,
    bool? activo,
  }) async {
    final payload = <String, dynamic>{
      'pregunta': ?texto,
      'tipo_respuesta': ?tipoRespuesta,
      'obligatoria': ?obligatoria,
      'opciones': ?opciones,
      'riesgo': ?riesgo,
      'activo': ?activo,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (payload.isEmpty) return;
    await _client.from('preguntas').update(payload).eq('id', preguntaId);
  }

  // ── Evaluación de salud (autoridad: RPC en BD) ─────────────────────────────

  Future<Map<String, dynamic>> guardarRespuestasEvaluacion({
    required int cuestionarioId,
    required Map<int, String> respuestas,
  }) async {
    final payload = [
      for (final entry in respuestas.entries)
        {'pregunta_id': entry.key, 'valor': entry.value},
    ];
    return await _client.rpc(
      'guardar_respuestas_evaluacion',
      params: {
        'p_cuestionario_id': cuestionarioId,
        'p_respuestas': payload,
      },
    ) as Map<String, dynamic>;
  }

  Future<EvaluacionSaludModel?> fetchUltimaEvaluacion() async {
    final pacienteId = await _getPacienteId();
    if (pacienteId == null) return null;
    final res = await _client
        .from('evaluaciones_salud')
        .select()
        .eq('paciente_id', pacienteId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (res == null) return null;
    return EvaluacionSaludModel.fromJson(res);
  }

  // ── Validación de telemedicina (autoridad: RPC en BD) ──────────────────────

  Future<Map<String, dynamic>> registrarValidacionTelemedicina({
    required bool aprobado,
    required String proveedor,
    String? codigoReferencia,
  }) async {
    return await _client.rpc(
      'registrar_validacion_telemedicina',
      params: {
        'p_aprobado': aprobado,
        'p_proveedor': proveedor,
        'p_codigo_referencia': ?codigoReferencia,
      },
    ) as Map<String, dynamic>;
  }

  Future<ValidacionTelemedicinaModel?> fetchMiValidacion() async {
    final pacienteId = await _getPacienteId();
    if (pacienteId == null) return null;
    final res = await _client
        .from('validaciones_telemedicina')
        .select()
        .eq('paciente_id', pacienteId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (res == null) return null;
    return ValidacionTelemedicinaModel.fromJson(res);
  }
}