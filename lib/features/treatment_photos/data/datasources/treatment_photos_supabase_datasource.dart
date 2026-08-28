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
    final fotografias = res
        .map((json) => FotografiaTratamientoModel.fromJson(json))
        .toList();
    return Future.wait(
        fotografias.map((foto) => _withSignedUrl(foto)).toList());
  }

  /// Devuelve el modelo con `archivoUrl` apuntando a una URL firmada cuando la
  /// fila guarda un path de storage privado (no una URL http externa).
  Future<FotografiaTratamientoModel> _withSignedUrl(
      FotografiaTratamientoModel foto) async {
    final path = foto.archivoUrl;
    if (path.isEmpty || path.startsWith('http')) return foto;
    final url = await _signedUrl(path);
    return foto.copyWith(archivoUrl: url);
  }

  Future<String> _signedUrl(String path) async {
    try {
      // uploadBinary puede devolver el path con el prefijo del bucket
      // (`fotografias-tratamiento/<tratamiento>/<archivo>`); createSignedUrl
      // espera el path RELATIVO al bucket, así que se normaliza.
      final clean = path.startsWith('${AppConstants.bucketFotografias}/')
          ? path.substring(AppConstants.bucketFotografias.length + 1)
          : path;
      final res = await _client.storage
          .from(AppConstants.bucketFotografias)
          .createSignedUrl(clean, 3600);
      return res;
    } catch (_) {
      return path;
    }
  }

  // ── Escritura ───────────────────────────────────────────────

  /// Sube los bytes de la imagen al bucket (privado) y guarda el PATH del
  /// objeto en `archivo_url` (la URL firmada se genera al leer).
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

    // uploadBinary devuelve el path con el prefijo del bucket
    // (`fotografias-tratamiento/<tratamiento>/<archivo>`); se guarda el path
    // RELATIVO al bucket para createSignedUrl (mismo formato que el resto).
    final storedPath =
        uploadResult.startsWith('${AppConstants.bucketFotografias}/')
            ? uploadResult.substring(AppConstants.bucketFotografias.length + 1)
            : uploadResult;

    final now = DateTime.now().toIso8601String();
    final payload = <String, dynamic>{
      'tratamiento_id': tratamientoId,
      'tipo_fotografia': tipoFotografia.toDb,
      'archivo_url': storedPath,
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
    // La fila guarda el path de storage; se devuelve la URL firmada para que
    // la tarjeta del grid la muestre inmediatamente (mismo criterio que fetch).
    return _withSignedUrl(FotografiaTratamientoModel.fromJson(res));
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