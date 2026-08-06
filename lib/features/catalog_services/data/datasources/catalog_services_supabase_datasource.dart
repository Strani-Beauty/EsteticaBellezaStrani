import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/categoria_servicio_model.dart';
import '../models/servicio_model.dart';

/// Datasource de Supabase para el módulo catalog_services.
/// Solo habla con Supabase y devuelve Models.
class CatalogServicesSupabaseDataSource {
  final SupabaseClient _client;

  CatalogServicesSupabaseDataSource(this._client);

  // ── Categorías ─────────────────────────────────────────────

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

  // ── Servicios ──────────────────────────────────────────────

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
}
