import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/especialidad_admin_entity.dart';
import '../../domain/entities/financiero_entity.dart';
import '../../domain/entities/rol_entity.dart';

/// Datasource de Supabase para Datos Maestros del admin.
/// Solo habla con Supabase y devuelve entidades.
class AdminMasterDataSupabaseDataSource {
  final SupabaseClient _client;

  AdminMasterDataSupabaseDataSource(this._client);

  // ── Roles y Permisos ──────────────────────────────────────

  Future<List<RolEntity>> fetchRoles() async {
    final res = await _client.from('roles').select('''
      id, name, description, code, activo,
      rol_permisos(permiso_id, permisos(codigo, nombre, modulo, descripcion))
    ''').order('name');
    return res.map((json) => _rolFromJson(json)).toList();
  }

  RolEntity _rolFromJson(Map<String, dynamic> json) {
    final permisos = <PermisoEntity>[];
    final rp = json['rol_permisos'];
    if (rp is List) {
      for (final item in rp) {
        if (item is! Map<String, dynamic>) continue;
        final p = item['permisos'];
        if (p is Map<String, dynamic>) {
          permisos.add(PermisoEntity(
            id: (p['id'] as num?)?.toInt() ?? 0,
            codigo: p['codigo']?.toString() ?? '',
            nombre: p['nombre']?.toString() ?? '',
            modulo: p['modulo']?.toString(),
            descripcion: p['descripcion']?.toString(),
          ));
        }
      }
    }
    return RolEntity(
      id: (json['id'] as num?)?.toInt() ?? 0,
      nombre: json['name']?.toString() ?? '',
      descripcion: json['description']?.toString(),
      codigo: json['code']?.toString(),
      activo: json['activo'] != false,
      permisos: permisos,
    );
  }

  Future<List<PermisoEntity>> fetchPermisos() async {
    final res = await _client
        .from('permisos')
        .select()
        .order('modulo')
        .order('nombre');
    return res
        .map((json) => PermisoEntity(
              id: (json['id'] as num?)?.toInt() ?? 0,
              codigo: json['codigo']?.toString() ?? '',
              nombre: json['nombre']?.toString() ?? '',
              modulo: json['modulo']?.toString(),
              descripcion: json['descripcion']?.toString(),
            ))
        .toList();
  }

  Future<RolEntity> guardarRol({
    int? id,
    required String nombre,
    String? descripcion,
    String? codigo,
    bool activo = true,
  }) async {
    final payload = <String, dynamic>{
      'name': nombre,
      'description': descripcion,
      'code': codigo,
      'activo': activo,
    };
    final res = id == null
        ? await _client.from('roles').insert(payload).select().maybeSingle()
        : await _client
            .from('roles')
            .update(payload)
            .eq('id', id)
            .select()
            .maybeSingle();
    if (res == null) throw Exception('No se pudo guardar el rol.');
    return _rolFromJson(Map<String, dynamic>.from(res));
  }

  Future<void> setRolActivo(int id, bool activo) async {
    await _client.from('roles').update({'activo': activo}).eq('id', id);
  }

  Future<void> asignarPermisoRol(int rolId, int permisoId) async {
    final existe = await _client
        .from('rol_permisos')
        .select('id')
        .eq('rol_id', rolId)
        .eq('permiso_id', permisoId)
        .maybeSingle();
    if (existe != null) return;
    await _client.from('rol_permisos').insert({
      'rol_id': rolId,
      'permiso_id': permisoId,
    });
  }

  Future<void> quitarPermisoRol(int rolId, int permisoId) async {
    await _client
        .from('rol_permisos')
        .delete()
        .eq('rol_id', rolId)
        .eq('permiso_id', permisoId);
  }

  // ── Especialidades ────────────────────────────────────────

  Future<List<EspecialidadAdminEntity>> fetchEspecialidadesAdmin() async {
    final res =
        await _client.from('especialidades').select().order('nombre');
    return res
        .map((json) => EspecialidadAdminEntity(
              id: (json['id'] as num?)?.toInt() ?? 0,
              nombre: json['nombre']?.toString() ?? '',
              descripcion: json['descripcion']?.toString(),
              activo: json['activo'] != false,
            ))
        .toList();
  }

  Future<EspecialidadAdminEntity> guardarEspecialidad({
    int? id,
    required String nombre,
    String? descripcion,
    bool activo = true,
  }) async {
    final payload = <String, dynamic>{
      'nombre': nombre,
      'descripcion': descripcion,
      'activo': activo,
    };
    final res = id == null
        ? await _client
            .from('especialidades')
            .insert(payload)
            .select()
            .maybeSingle()
        : await _client
            .from('especialidades')
            .update(payload)
            .eq('id', id)
            .select()
            .maybeSingle();
    if (res == null) throw Exception('No se pudo guardar la especialidad.');
    return EspecialidadAdminEntity(
      id: (res['id'] as num?)?.toInt() ?? 0,
      nombre: res['nombre']?.toString() ?? '',
      descripcion: res['descripcion']?.toString(),
      activo: res['activo'] != false,
    );
  }

  Future<void> setEspecialidadActivo(int id, bool activo) async {
    await _client.from('especialidades').update({'activo': activo}).eq('id', id);
  }

  // ── Comisiones / liquidaciones / pagos ────────────────────

  Future<List<LiquidacionEntity>> fetchLiquidaciones() async {
    final res = await _client.from('liquidaciones_especialistas').select('''
      *,
      especialistas(usuario_id, profiles!especialistas_usuario_id_fkey(full_name))
    ''').order('fecha_inicio', ascending: false);
    return res.map((json) => _liquidationFromJson(json)).toList();
  }

  LiquidacionEntity _liquidationFromJson(Map<String, dynamic> json) {
    final esp = json['especialistas'];
    String? nombre;
    if (esp is Map<String, dynamic>) {
      final profile = esp['profiles'];
      if (profile is Map<String, dynamic>) {
        nombre = profile['full_name']?.toString();
      }
    }
    return LiquidacionEntity(
      id: json['id']?.toString() ?? '',
      especialistaId: json['especialista_id']?.toString() ?? '',
      especialistaNombre: nombre,
      fechaInicio: _parseDate(json['fecha_inicio']),
      fechaFin: _parseDate(json['fecha_fin']),
      montoTotalServicios:
          (json['monto_total_servicios'] as num?)?.toDouble() ?? 0,
      montoComision: (json['monto_comision'] as num?)?.toDouble() ?? 0,
      montoPagar: (json['monto_pagar'] as num?)?.toDouble() ?? 0,
      estado: json['estado']?.toString(),
      fechaPago: _parseDate(json['fecha_pago']),
    );
  }

  Future<List<PagoEspecialistaEntity>> fetchPagosEspecialistas() async {
    final res = await _client.from('pagos_especialistas').select('''
      *,
      especialistas(usuario_id, profiles!especialistas_usuario_id_fkey(full_name))
    ''').order('fecha_pago', ascending: false);
    return res.map((json) {
      final esp = json['especialistas'];
      String? nombre;
      if (esp is Map<String, dynamic>) {
        final profile = esp['profiles'];
        if (profile is Map<String, dynamic>) {
          nombre = profile['full_name']?.toString();
        }
      }
      return PagoEspecialistaEntity(
        id: json['id']?.toString() ?? '',
        liquidacionId: json['liquidacion_id']?.toString() ?? '',
        especialistaId: json['especialista_id']?.toString() ?? '',
        especialistaNombre: nombre,
        fechaPago: _parseDate(json['fecha_pago']),
        montoPagado: (json['monto_pagado'] as num?)?.toDouble() ?? 0,
        metodoPago: json['metodo_pago']?.toString(),
        referenciaPago: json['referencia_pago']?.toString(),
        notas: json['notas']?.toString(),
      );
    }).toList();
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
