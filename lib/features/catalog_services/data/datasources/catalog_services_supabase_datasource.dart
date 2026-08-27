import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/config/app_constants.dart';
import '../../domain/entities/servicio_cuestionario_entity.dart';
import '../../domain/entities/servicio_entity.dart';
import '../models/categoria_servicio_model.dart';
import '../models/servicio_model.dart';

/// Datasource de Supabase para el módulo catalog_services.
/// Solo habla con Supabase y devuelve Models.
class CatalogServicesSupabaseDataSource {
  final SupabaseClient _client;

  CatalogServicesSupabaseDataSource(this._client);

  // ── Categorías ─────────────────────────────────────────────

  /// Categorías activas (catálogo público).
  Future<List<CategoriaServicioModel>> fetchCategorias() async {
    final res = await _client
        .from('categorias_servicio')
        .select()
        .eq('activo', true)
        .order('nombre', ascending: true);
    return res
        .map((json) => CategoriaServicioModel.fromJson(json))
        .toList();
  }

  /// Todas las categorías (incl. inactivas) — uso admin.
  Future<List<CategoriaServicioModel>> fetchCategoriasAdmin() async {
    final res = await _client
        .from('categorias_servicio')
        .select()
        .order('nombre', ascending: true);
    return res
        .map((json) => CategoriaServicioModel.fromJson(json))
        .toList();
  }

  /// Crea una categoría (solo admin vía RLS).
  Future<CategoriaServicioModel> insertCategoria({
    required String nombre,
    String? descripcion,
    required bool activo,
  }) async {
    final res = await _client.from('categorias_servicio').insert({
      'nombre': nombre,
      'descripcion': descripcion,
      'activo': activo,
    }).select().maybeSingle();
    if (res == null) {
      throw Exception('No se pudo crear la categoría.');
    }
    return CategoriaServicioModel.fromJson(res);
  }

  /// Actualiza una categoría (solo admin vía RLS).
  Future<CategoriaServicioModel> updateCategoria({
    required int id,
    required String nombre,
    String? descripcion,
    required bool activo,
  }) async {
    final res = await _client.from('categorias_servicio').update({
      'nombre': nombre,
      'descripcion': descripcion,
      'activo': activo,
    }).eq('id', id).select().maybeSingle();
    if (res == null) {
      throw Exception('No se pudo actualizar la categoría.');
    }
    return CategoriaServicioModel.fromJson(res);
  }

  // ── Servicios ──────────────────────────────────────────────

  /// Servicios activos, opcionalmente filtrados por categoría (catálogo público).
  Future<List<ServicioModel>> fetchServicios({int? categoriaId}) async {
    var query = _client
        .from('servicios')
        .select('*, categorias_servicio(id, nombre, descripcion, activo)')
        .eq('activo', true);

    if (categoriaId != null) {
      query = query.eq('categoria_id', categoriaId);
    }

    final res = await query.order('nombre', ascending: true);
    return res.map((json) => ServicioModel.fromJson(json)).toList();
  }

  /// Todos los servicios (incl. inactivos) — uso admin.
  Future<List<ServicioModel>> fetchServiciosAdmin() async {
    final res = await _client
        .from('servicios')
        .select('*, categorias_servicio(id, nombre, descripcion, activo)')
        .order('nombre', ascending: true);
    return res.map((json) => ServicioModel.fromJson(json)).toList();
  }

  /// Crea un servicio (solo admin vía RLS). `id` lo genera la BD.
  Future<ServicioModel> insertServicio({
    int? categoriaId,
    required String nombre,
    String? descripcion,
    required double precioBase,
    required TipoPrecio tipoPrecio,
    int? duracionEstimada,
    bool requiereTelemedicina = false,
    bool requiereFaceMap = false,
    bool requiereFotos = false,
    bool requiereConsentimiento = false,
    bool activo = true,
    String? imagenUrl,
  }) async {
    final res = await _client.from('servicios').insert({
      'categoria_id': categoriaId,
      'nombre': nombre,
      'descripcion': descripcion,
      'precio_base': precioBase,
      'tipo_precio': tipoPrecio.toDb,
      'duracion_estimada': duracionEstimada,
      'requiere_telemedicina': requiereTelemedicina,
      'requiere_face_map': requiereFaceMap,
      'requiere_fotos': requiereFotos,
      'requiere_consentimiento': requiereConsentimiento,
      'activo': activo,
      'imagen_url': (imagenUrl == null || imagenUrl.isEmpty) ? null : imagenUrl,
    }).select().maybeSingle();
    if (res == null) {
      throw Exception('No se pudo crear el servicio.');
    }
    return ServicioModel.fromJson(res);
  }

  /// Actualiza un servicio (solo admin vía RLS).
  Future<ServicioModel> updateServicio({
    required String id,
    int? categoriaId,
    required String nombre,
    String? descripcion,
    required double precioBase,
    required TipoPrecio tipoPrecio,
    int? duracionEstimada,
    bool requiereTelemedicina = false,
    bool requiereFaceMap = false,
    bool requiereFotos = false,
    bool requiereConsentimiento = false,
    bool activo = true,
    String? imagenUrl,
  }) async {
    final res = await _client.from('servicios').update({
      'categoria_id': categoriaId,
      'nombre': nombre,
      'descripcion': descripcion,
      'precio_base': precioBase,
      'tipo_precio': tipoPrecio.toDb,
      'duracion_estimada': duracionEstimada,
      'requiere_telemedicina': requiereTelemedicina,
      'requiere_face_map': requiereFaceMap,
      'requiere_fotos': requiereFotos,
      'requiere_consentimiento': requiereConsentimiento,
      'activo': activo,
      'imagen_url': (imagenUrl == null || imagenUrl.isEmpty) ? null : imagenUrl,
    }).eq('id', id).select().maybeSingle();
    if (res == null) {
      throw Exception('No se pudo actualizar el servicio.');
    }
    return ServicioModel.fromJson(res);
  }

  /// Elimina un servicio del catálogo vía RPC seguro (solo admin).
  /// Lanza [Exception] con 'REFERENCIADO' si el servicio tiene historial
  /// en solicitudes (no se puede eliminar; debe desactivarse).
  Future<void> eliminarServicio(String id) async {
    final res = await _client.rpc(
      'eliminar_servicio',
      params: {'p_servicio_id': id},
    );
    final ok = res is Map<String, dynamic> ? res['ok'] == true : false;
    if (!ok) {
      final motivo = res is Map<String, dynamic> ? res['motivo'] : null;
      throw Exception(motivo == 'REFERENCIADO'
          ? 'No se puede eliminar: el servicio tiene solicitudes/historial. Desactívelo en su lugar.'
          : 'No se pudo eliminar el servicio.');
    }
  }

  // ── Imagen del servicio (storage) ─────────────────────────

  /// Sube la imagen de un servicio al bucket público `imagenes-servicios`
  /// (path `<servicioId>/imagen_<ts>.<ext>`), actualiza `servicios.imagen_url`
  /// con la URL pública y la devuelve. Solo admin vía storage policy.
  Future<String> subirImagenServicio({
    required String servicioId,
    required Uint8List bytes,
    required String nombreArchivo,
  }) async {
    final ext = nombreArchivo.contains('.')
        ? nombreArchivo.substring(nombreArchivo.lastIndexOf('.'))
        : '.jpg';
    final path =
        '$servicioId/imagen_${DateTime.now().millisecondsSinceEpoch}$ext';
    await _client.storage
        .from(AppConstants.bucketImagenesServicios)
        .uploadBinary(path, bytes);
    final publicUrl = _client.storage
        .from(AppConstants.bucketImagenesServicios)
        .getPublicUrl(path);
    final url = publicUrl;
    final res = await _client
        .from('servicios')
        .update({'imagen_url': url}).eq('id', servicioId).select('imagen_url')
        .maybeSingle();
    if (res == null) {
      throw Exception('No se pudo guardar la imagen del servicio.');
    }
    return url;
  }

  // ── Relaciones (servicio_especialidades / servicio_cuestionarios) ────────

  /// Requisitos configurados de un servicio (especialidades + cuestionarios).
  Future<ServicioRequisitosEntity> fetchRequisitosServicio(
      String servicioId) async {
    final espRes = await _client
        .from('servicio_especialidades')
        .select('especialidad_id')
        .eq('servicio_id', servicioId);
    final cuestRes = await _client
        .from('servicio_cuestionarios')
        .select('cuestionario_id, obligatorio, orden, cuestionarios(nombre)')
        .eq('servicio_id', servicioId)
        .order('orden', ascending: true);
    return ServicioRequisitosEntity(
      especialidadIds: [
        for (final r in espRes) (r['especialidad_id'] as num?)?.toInt() ?? 0,
      ],
      cuestionarios: [
        for (final r in cuestRes)
          ServicioCuestionarioEntity(
            cuestionarioId: (r['cuestionario_id'] as num?)?.toInt() ?? 0,
            nombre:
                (r['cuestionarios'] as Map<String, dynamic>?)?['nombre']
                    as String?,
            obligatorio: r['obligatorio'] as bool? ?? false,
            orden: (r['orden'] as num?)?.toInt() ?? 0,
          ),
      ],
    );
  }

  /// Reemplaza las especialidades de un servicio vía RPC atómico (solo admin).
  Future<void> reemplazarEspecialidadesServicio(
    String servicioId,
    List<int> especialidadIds,
  ) async {
    await _client.rpc(
      'reemplazar_servicio_especialidades',
      params: {
        'p_servicio_id': servicioId,
        'p_ids': especialidadIds,
      },
    );
  }

  /// Reemplaza los cuestionarios de un servicio vía RPC atómico (solo admin).
  Future<void> reemplazarCuestionariosServicio(
    String servicioId,
    List<ServicioCuestionarioEntity> items,
  ) async {
    await _client.rpc(
      'reemplazar_servicio_cuestionarios',
      params: {
        'p_servicio_id': servicioId,
        'p_items': [
          for (final c in items)
            {
              'cuestionario_id': c.cuestionarioId,
              'obligatorio': c.obligatorio,
              'orden': c.orden,
            },
        ],
      },
    );
  }
}
