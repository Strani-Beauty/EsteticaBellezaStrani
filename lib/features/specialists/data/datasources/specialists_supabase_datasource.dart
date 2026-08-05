import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/contrato_model.dart';
import '../models/disponibilidad_model.dart';
import '../models/documento_especialista_model.dart';
import '../models/especialidad_model.dart';
import '../models/especialista_model.dart';
import '../models/medico_regente_model.dart';
import '../models/ubicacion_especialista_model.dart';
import '../../domain/entities/contrato_entity.dart';
import '../../domain/entities/disponibilidad_entity.dart';
import '../../domain/entities/documento_especialista_entity.dart';

/// Datasource de Supabase para el módulo specialists.
/// Solo habla con Supabase y devuelve Models.
class SpecialistsSupabaseDataSource {
  final SupabaseClient _client;

  SpecialistsSupabaseDataSource(this._client);

  // ── Especialista ─────────────────────────────────────────────

  Future<EspecialistaModel?> fetchEspecialistaByUsuarioId(String usuarioId) async {
    final res = await _client
        .from('especialistas')
        .select()
        .eq('usuario_id', usuarioId)
        .maybeSingle();
    if (res == null) return null;
    return EspecialistaModel.fromJson(res);
  }

  Future<EspecialistaModel> fetchEspecialistaById(String id) async {
    final res = await _client
        .from('especialistas')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (res == null) {
      throw Exception('Especialista $id no encontrado');
    }
    return EspecialistaModel.fromJson(res);
  }

  /// Crea el registro del especialista y solicita verificación.
  Future<EspecialistaModel> createEspecialista({
    required String usuarioId,
    String? numeroLicencia,
    String? medicoRegenteId,
  }) async {
    final now = DateTime.now().toIso8601String();
    final payload = <String, dynamic>{
      'usuario_id': usuarioId,
      'numero_licencia': numeroLicencia,
      'medico_regente_id': medicoRegenteId,
      'estado_verificacion': 'PENDIENTE',
      'fecha_solicitud_verificacion': now,
      'disponible': false,
      'activo': false,
      'created_at': now,
      'updated_at': now,
    };
    final res = await _client
        .from('especialistas')
        .insert(payload)
        .select()
        .maybeSingle();
    if (res == null) {
      throw Exception('No se pudo crear el especialista');
    }
    return EspecialistaModel.fromJson(res);
  }

  Future<EspecialistaModel> updateEspecialista(
    String id,
    Map<String, dynamic> data,
  ) async {
    final patch = Map<String, dynamic>.from(data);
    patch['updated_at'] = DateTime.now().toIso8601String();
    final res = await _client
        .from('especialistas')
        .update(patch)
        .eq('id', id)
        .select()
        .maybeSingle();
    if (res == null) throw Exception('Especialista $id no actualizado');
    return EspecialistaModel.fromJson(res);
  }

  // ── Médicos Regentes ─────────────────────────────────────────

  Future<List<MedicoRegenteModel>> fetchMedicosRegentes() async {
    final res = await _client
        .from('medicos_regentes')
        .select()
        .eq('activo', true)
        .order('nombre');
    return res
        .map((json) => MedicoRegenteModel.fromJson(json))
        .toList();
  }

  // ── Especialidades ───────────────────────────────────────────

  Future<List<EspecialidadModel>> fetchEspecialidades() async {
    final res = await _client
        .from('especialidades')
        .select()
        .eq('activo', true)
        .order('nombre');
    return res.map((json) => EspecialidadModel.fromJson(json)).toList();
  }

  Future<List<EspecialistaEspecialidadModel>> fetchEspecialistaEspecialidades(
    String especialistaId,
  ) async {
    final res = await _client
        .from('especialista_especialidades')
        .select()
        .eq('especialista_id', especialistaId);
    return res
        .map((json) => EspecialistaEspecialidadModel.fromJson(json))
        .toList();
  }

  // ── Documentos ───────────────────────────────────────────────

  Future<List<DocumentoEspecialistaModel>> fetchDocumentos(String especialistaId) async {
    final res = await _client
        .from('documentos_especialista')
        .select()
        .eq('especialista_id', especialistaId)
        .order('created_at');
    return res
        .map((json) => DocumentoEspecialistaModel.fromJson(json))
        .toList();
  }

  Future<DocumentoEspecialistaModel> registerDocumento({
    required String especialistaId,
    required TipoDocumento tipoDocumento,
    String? nombreArchivo,
    String? urlArchivo,
    int versionDocumento = 1,
  }) async {
    final now = DateTime.now().toIso8601String();
    final res = await _client.from('documentos_especialista').insert({
      'especialista_id': especialistaId,
      'tipo_documento': tipoDocumento.toDb,
      'nombre_archivo': nombreArchivo,
      'url_archivo': urlArchivo,
      'estado_revision': 'PENDIENTE',
      'version_documento': versionDocumento,
      'activo': true,
      'created_at': now,
      'updated_at': now,
    }).select().maybeSingle();
    if (res == null) throw Exception('No se pudo registrar el documento');
    return DocumentoEspecialistaModel.fromJson(res);
  }

  // ── Disponibilidad ───────────────────────────────────────────

  Future<DisponibilidadModel?> fetchDisponibilidad(String especialistaId) async {
    final res = await _client
        .from('disponibilidad_especialista')
        .select()
        .eq('especialista_id', especialistaId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (res == null) return null;
    return DisponibilidadModel.fromJson(res);
  }

  Future<DisponibilidadModel> setDisponibilidad(
    String especialistaId,
    EstadoDisponibilidad estado, {
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) async {
    final now = DateTime.now().toIso8601String();
    final res = await _client.from('disponibilidad_especialista').insert({
      'especialista_id': especialistaId,
      'estado': estado.toDb,
      'fecha_inicio': fechaInicio?.toIso8601String(),
      'fecha_fin': fechaFin?.toIso8601String(),
      'created_at': now,
    }).select().maybeSingle();
    if (res == null) throw Exception('No se pudo actualizar disponibilidad');
    return DisponibilidadModel.fromJson(res);
  }

  Future<DisponibilidadModel> updateDisponibilidad(
    String id,
    EstadoDisponibilidad estado, {
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) async {
    final res = await _client.from('disponibilidad_especialista').update({
      'estado': estado.toDb,
      'fecha_inicio': fechaInicio?.toIso8601String(),
      'fecha_fin': fechaFin?.toIso8601String(),
    }).eq('id', id).select().maybeSingle();
    if (res == null) throw Exception('No se pudo actualizar disponibilidad');
    return DisponibilidadModel.fromJson(res);
  }

  // ── Contrato ─────────────────────────────────────────────────

  Future<ContratoModel?> fetchContrato(String especialistaId) async {
    final res = await _client
        .from('contratos')
        .select()
        .eq('especialista_id', especialistaId)
        .order('version_contrato', ascending: false)
        .limit(1)
        .maybeSingle();
    if (res == null) return null;
    return ContratoModel.fromJson(res);
  }

  Future<ContratoModel> firmarContrato(
    String especialistaId, {
    required MetodoFirma metodoFirma,
    String? urlDocumento,
    int versionContrato = 1,
  }) async {
    final now = DateTime.now().toIso8601String();
    final res = await _client.from('contratos').insert({
      'especialista_id': especialistaId,
      'version_contrato': versionContrato,
      'url_documento': urlDocumento,
      'firmado': true,
      'fecha_firma': now,
      'metodo_firma': metodoFirma.toDb,
      'created_at': now,
      'updated_at': now,
    }).select().maybeSingle();
    if (res == null) throw Exception('No se pudo registrar la firma');
    return ContratoModel.fromJson(res);
  }

  // ── Ubicación ────────────────────────────────────────────────

  Future<UbicacionEspecialistaModel?> fetchUbicacion(String especialistaId) async {
    final res = await _client
        .from('ubicaciones_especialista')
        .select()
        .eq('especialista_id', especialistaId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (res == null) return null;
    return UbicacionEspecialistaModel.fromJson(res);
  }

  Future<UbicacionEspecialistaModel> saveUbicacion(
    String especialistaId, {
    required double latitud,
    required double longitud,
    double precisionMetros = 0,
  }) async {
    final now = DateTime.now().toIso8601String();
    final payload = <String, dynamic>{
      'especialista_id': especialistaId,
      'latitud': latitud,
      'longitud': longitud,
      'precision_metros': precisionMetros,
      'fecha_actualizacion': now,
      'created_at': now,
    };
    // La columna geography(Point,4326) espera EWKT: SRID=4326;POINT(lng lat)
    payload['ubicacion'] = 'SRID=4326;POINT($longitud $latitud)';

    final res = await _client
        .from('ubicaciones_especialista')
        .insert(payload)
        .select()
        .maybeSingle();
    if (res == null) throw Exception('No se pudo guardar la ubicación');
    return UbicacionEspecialistaModel.fromJson(res);
  }
}