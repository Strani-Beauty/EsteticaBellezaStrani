import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../app/config/app_constants.dart';
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

  /// Pasa la solicitud de verificación a EN_REVISION cuando el especialista
  /// completa sus datos profesionales y documentos requeridos.
  Future<EspecialistaModel> marcarEnRevision(String especialistaId) async {
    final now = DateTime.now().toIso8601String();
    final res = await _client
        .from('especialistas')
        .update({
          'estado_verificacion': 'EN_REVISION',
          'fecha_solicitud_verificacion': now,
          'updated_at': now,
        })
        .eq('id', especialistaId)
        .select()
        .maybeSingle();
    if (res == null) {
      throw Exception('Especialista $especialistaId no encontrado');
    }
    return EspecialistaModel.fromJson(res);
  }

  /// Lista todos los especialistas (uso administrativo).
  /// Incluye nombre/email del perfil vía join a `profiles` (usuario_id).
  Future<List<EspecialistaModel>> fetchEspecialistas() async {
    final res = await _client
        .from('especialistas')
        .select('*, profiles (full_name, email)')
        .order('created_at');
    return res.map((json) => EspecialistaModel.fromJson(json)).toList();
  }

  // ── Médicos Regentes ─────────────────────────────────────────

  Future<List<MedicoRegenteModel>> fetchMedicosRegentes({
    bool soloActivos = true,
  }) async {
    var query = _client.from('medicos_regentes').select();
    if (soloActivos) {
      query = query.eq('activo', true);
    }
    final res = await query.order('nombre');
    return res
        .map((json) => MedicoRegenteModel.fromJson(json))
        .toList();
  }

  /// Registra un médico regente. Queda en estado PENDIENTE (activo=false)
  /// hasta que un administrador lo valide (ver [updateMedicoRegente]).
  Future<MedicoRegenteModel> createMedicoRegente({
    required String nombre,
    String? numeroLicencia,
    String? telefono,
    String? correo,
  }) async {
    final now = DateTime.now().toIso8601String();
    final res = await _client.from('medicos_regentes').insert({
      'nombre': nombre,
      'numero_licencia': numeroLicencia,
      'telefono': telefono,
      'correo': correo,
      'estado': 'PENDIENTE',
      'activo': false,
      'created_at': now,
      'updated_at': now,
    }).select().maybeSingle();
    if (res == null) throw Exception('No se pudo registrar el médico regente');
    return MedicoRegenteModel.fromJson(res);
  }

  Future<MedicoRegenteModel> updateMedicoRegente(
    String id,
    Map<String, dynamic> data,
  ) async {
    final patch = Map<String, dynamic>.from(data);
    patch['updated_at'] = DateTime.now().toIso8601String();
    final res = await _client
        .from('medicos_regentes')
        .update(patch)
        .eq('id', id)
        .select()
        .maybeSingle();
    if (res == null) throw Exception('Médico regente $id no actualizado');
    return MedicoRegenteModel.fromJson(res);
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

  /// Reemplaza el conjunto de especialidades del especialista
  /// (borra las actuales e inserta la nueva selección).
  Future<List<EspecialistaEspecialidadModel>> reemplazarEspecialidades(
    String especialistaId,
    List<int> especialidadIds,
  ) async {
    await _client
        .from('especialista_especialidades')
        .delete()
        .eq('especialista_id', especialistaId);

    if (especialidadIds.isEmpty) return [];

    final now = DateTime.now().toIso8601String();
    final payload = especialidadIds.map((id) => {
          'especialista_id': especialistaId,
          'especialidad_id': id,
          'created_at': now,
        }).toList();
    final res = await _client
        .from('especialista_especialidades')
        .insert(payload)
        .select();
    return res
        .map((json) => EspecialistaEspecialidadModel.fromJson(json))
        .toList();
  }

  // ── Perfil (datos personales del especialista) ───────────────
  // Actualiza SOLO columnas de `profiles` relevantes al especialista,
  // sin tocar role/pacientes (a diferencia de updateProfileData de SupabaseService).

  Future<void> updatePerfilEspecialista({
    required String userId,
    String? fullName,
    String? phone,
    String? address,
    double? latitude,
    double? longitude,
    double? hourlyRate,
    String? avatarUrl,
  }) async {
    final patch = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (fullName != null) patch['full_name'] = fullName;
    if (phone != null) patch['phone'] = phone;
    if (address != null) patch['address'] = address;
    if (latitude != null) patch['latitude'] = latitude;
    if (longitude != null) patch['longitude'] = longitude;
    if (hourlyRate != null) patch['hourly_rate'] = hourlyRate;
    if (avatarUrl != null) patch['avatar_url'] = avatarUrl;
    await _client.from('profiles').update(patch).eq('id', userId);
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

  /// Sube los bytes del documento al bucket y registra la fila en la BD.
  /// El bucket es privado: `url_archivo` guarda el path de storage (lo que
  /// requiere `createSignedUrl` para leerse).
  Future<DocumentoEspecialistaModel> subirDocumento({
    required String especialistaId,
    required TipoDocumento tipoDocumento,
    required Uint8List bytes,
    required String nombreArchivo,
    int versionDocumento = 1,
  }) async {
    final ext = _extension(nombreArchivo);
    final path = '$especialistaId/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _client.storage
        .from(AppConstants.bucketDocumentos)
        .uploadBinary(path, bytes);

    // Re-subida de un tipo: versiona según la última versión existente.
    final version = versionDocumento == 1
        ? await _siguienteVersionDocumento(especialistaId, tipoDocumento)
        : versionDocumento;

    return registerDocumento(
      especialistaId: especialistaId,
      tipoDocumento: tipoDocumento,
      nombreArchivo: nombreArchivo,
      urlArchivo: path,
      versionDocumento: version,
    );
  }

  /// Devuelve `MAX(version_documento) + 1` para el tipo, o 1 si no hay filas.
  Future<int> _siguienteVersionDocumento(
    String especialistaId,
    TipoDocumento tipoDocumento,
  ) async {
    final res = await _client
        .from('documentos_especialista')
        .select('version_documento')
        .eq('especialista_id', especialistaId)
        .eq('tipo_documento', tipoDocumento.toDb)
        .order('version_documento', ascending: false)
        .limit(1)
        .maybeSingle();
    if (res == null) return 1;
    return ((res['version_documento'] as num?)?.toInt() ?? 0) + 1;
  }

  /// Genera una URL firmada de expiración corta para leer un documento privado.
  Future<String> crearUrlFirmada(String path) async {
    return _client.storage
        .from(AppConstants.bucketDocumentos)
        .createSignedUrl(path, 3600);
  }

  /// Aprueba o rechaza un documento (uso administrativo). Al rechazar deja
  /// `activo=false` para que el especialista vuelva a subirlo con la
  /// observación visible como feedback.
  Future<DocumentoEspecialistaModel> revisarDocumento({
    required String documentoId,
    required EstadoRevisionDocumento estado,
    String? observacion,
    required String revisadoPor,
  }) async {
    final now = DateTime.now().toIso8601String();
    final res = await _client
        .from('documentos_especialista')
        .update({
          'estado_revision': estado.toDb,
          'observacion_revision': observacion,
          'revisado_por': revisadoPor,
          'fecha_revision': now,
          'activo': estado == EstadoRevisionDocumento.aprobado,
          'updated_at': now,
        })
        .eq('id', documentoId)
        .select()
        .maybeSingle();
    if (res == null) throw Exception('Documento $documentoId no encontrado');
    return DocumentoEspecialistaModel.fromJson(res);
  }

  // ── Presencia (online/offline) ───────────────────────────────

  /// Marca el estado de presencia del especialista. Update ligero sin tocar
  /// `updated_at` (el heartbeat escribe con frecuencia).
  Future<void> marcarPresencia(
    String especialistaId, {
    required bool enLinea,
  }) async {
    await _client.from('especialistas').update({
      'en_linea': enLinea,
      'ultima_conexion': DateTime.now().toIso8601String(),
    }).eq('id', especialistaId);
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
      // `fecha_inicio` es NOT NULL (default now()): nunca enviar null.
      'fecha_inicio': (fechaInicio ?? DateTime.now()).toIso8601String(),
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
      // `fecha_inicio` es NOT NULL (default now()): nunca enviar null.
      'fecha_inicio': (fechaInicio ?? DateTime.now()).toIso8601String(),
      'fecha_fin': fechaFin?.toIso8601String(),
    }).eq('id', id).select().maybeSingle();
    if (res == null) throw Exception('No se pudo actualizar disponibilidad');
    return DisponibilidadModel.fromJson(res);
  }

  /// Upsert lógico de disponibilidad: inserta si no existe, actualiza si existe.
  /// Mantiene una única fila vigente por especialista.
  Future<DisponibilidadModel> upsertDisponibilidad(
    String especialistaId,
    EstadoDisponibilidad estado, {
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) async {
    final existente = await fetchDisponibilidad(especialistaId);
    if (existente == null) {
      return setDisponibilidad(especialistaId, estado,
          fechaInicio: fechaInicio, fechaFin: fechaFin);
    }
    return updateDisponibilidad(existente.id, estado,
        fechaInicio: fechaInicio, fechaFin: fechaFin);
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

  /// Sube la imagen de la firma manuscrita del contrato al bucket `contratos`
  /// y devuelve la URL pública.
  Future<String> subirFirmaContrato({
    required String especialistaId,
    required Uint8List bytes,
  }) async {
    final path =
        '$especialistaId/firma_${DateTime.now().millisecondsSinceEpoch}.png';
    final upload = await _client.storage
        .from(AppConstants.bucketContratos)
        .uploadBinary(path, bytes);
    return _client.storage
        .from(AppConstants.bucketContratos)
        .getPublicUrl(upload);
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

  String _extension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot == -1 || dot == fileName.length - 1) return 'pdf';
    return fileName.substring(dot + 1);
  }
}