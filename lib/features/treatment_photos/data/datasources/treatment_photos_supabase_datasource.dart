import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/config/app_constants.dart';
import '../models/fotografia_tratamiento_model.dart';
import '../../domain/entities/fotografia_tratamiento_entity.dart';

/// Datasource de Supabase para el módulo treatment_photos.
/// Sube la imagen al bucket `fotografias-tratamiento` y registra la fila
/// en la tabla `fotografias_tratamiento`.
class TreatmentPhotosSupabaseDataSource {
  final SupabaseClient _client;

  TreatmentPhotosSupabaseDataSource(this._client);

  // ── Lectura ─────────────────────────────────────────────────

  Future<List<FotografiaTratamientoModel>> fetchFotografias(
      String tratamientoId) async {
    final res = await _client
        .from('fotografias_tratamiento')
        .select()
        .eq('tratamiento_id', tratamientoId)
        .order('fecha_captura', ascending: false);
    return res
        .map((json) => FotografiaTratamientoModel.fromJson(json))
        .toList();
  }

  // ── Escritura ───────────────────────────────────────────────

  /// Sube los bytes de la imagen al bucket y registra la fila en la BD.
  /// Devuelve la URL pública del objeto ya guardado.
  Future<FotografiaTratamientoModel> subirFotografia({
    required String tratamientoId,
    required TipoFotografia tipoFotografia,
    required Uint8List bytes,
    required String nombreArchivo,
    String? descripcion,
  }) async {
    final ext = _extension(nombreArchivo);
    final path = '$tratamientoId/${DateTime.now().millisecondsSinceEpoch}_$ext';

    final uploadResult = await _client.storage
        .from(AppConstants.bucketFotografias)
        .uploadBinary(path, bytes);
    final publicUrl = _client.storage
        .from(AppConstants.bucketFotografias)
        .getPublicUrl(uploadResult);

    final now = DateTime.now().toIso8601String();
    final payload = <String, dynamic>{
      'tratamiento_id': tratamientoId,
      'tipo_fotografia': tipoFotografia.toDb,
      'archivo_url': publicUrl,
      'fecha_captura': now,
      'descripcion': descripcion,
      'created_at': now,
      'tipo_foto': tipoFotografia.toDb.toLowerCase(),
    };

    final res = await _client
        .from('fotografias_tratamiento')
        .insert(payload)
        .select()
        .maybeSingle();
    if (res == null) {
      throw Exception('No se pudo registrar la fotografía');
    }
    return FotografiaTratamientoModel.fromJson(res);
  }

  /// Registra una fotografía cuyo archivo ya existe en Storage (solo URL).
  Future<FotografiaTratamientoModel> registrarPorUrl({
    required String tratamientoId,
    required TipoFotografia tipoFotografia,
    required String archivoUrl,
    String? descripcion,
  }) async {
    final now = DateTime.now().toIso8601String();
    final payload = <String, dynamic>{
      'tratamiento_id': tratamientoId,
      'tipo_fotografia': tipoFotografia.toDb,
      'archivo_url': archivoUrl,
      'fecha_captura': now,
      'descripcion': descripcion,
      'created_at': now,
      'tipo_foto': tipoFotografia.toDb.toLowerCase(),
    };

    final res = await _client
        .from('fotografias_tratamiento')
        .insert(payload)
        .select()
        .maybeSingle();
    if (res == null) {
      throw Exception('No se pudo registrar la fotografía');
    }
    return FotografiaTratamientoModel.fromJson(res);
  }

  // ── Eliminación ─────────────────────────────────────────────

  /// Elimina la fila de la BD y, si [pathEnStorage] es distinto de null,
  /// también el objeto del bucket.
  Future<void> eliminarFotografia(
    String id, {
    String? pathEnStorage,
  }) async {
    await _client.from('fotografias_tratamiento').delete().eq('id', id);

    if (pathEnStorage != null && pathEnStorage.isNotEmpty) {
      try {
        await _client.storage
            .from(AppConstants.bucketFotografias)
            .remove([pathEnStorage]);
      } catch (_) {
        // El objeto pudo no existir; la fila ya fue eliminada.
      }
    }
  }

  String _extension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot == -1 || dot == fileName.length - 1) return 'img';
    return fileName.substring(dot + 1);
  }
}