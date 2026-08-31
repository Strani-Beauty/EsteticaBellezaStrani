import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/config/app_constants.dart';
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
      estado: EstadoLiquidacion.fromDb(json['estado']?.toString()),
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
        comprobanteUrl: json['comprobante_url']?.toString(),
        notas: json['notas']?.toString(),
      );
    }).toList();
  }

  /// Citas terminadas elegibles para liquidación en un período.
  /// Elegibilidad: cita FINALIZADA + tratamiento COMPLETADO + pago PAGADO/saldo
  /// <=0 + no incluida aún en `liquidacion_detalles` (idempotencia).
  Future<List<CitaFinalizadaAdminEntity>> fetchCitasFinalizadasAdmin({
    required DateTime desde,
    required DateTime hasta,
  }) async {
    final liquidadas = await _client
        .from('liquidacion_detalles')
        .select('cita_id');
    final liquidadasIds =
        (liquidadas.map((j) => j['cita_id']?.toString()).toSet());

    final res = await _client
        .from('citas')
        .select('''
        id, solicitud_id, fecha_finalizacion, especialista_id,
        solicitudes(
          pagos(monto_total, deposito, saldo_pendiente, estado),
          pacientes(profiles(full_name)),
          solicitud_detalles(servicios(nombre))
        ),
        especialistas(usuario_id, profiles!especialistas_usuario_id_fkey(full_name))
      ''')
        .eq('estado', AppConstants.citaFinalizada)
        .gte('fecha_finalizacion', desde.toIso8601String())
        .lte('fecha_finalizacion', hasta.toIso8601String())
        .order('fecha_finalizacion', ascending: false);

    // Filtro servidor: descartamos citas ya liquidadas (idempotencia).
    final candidatas = res.where((j) {
      final citaId = j['id']?.toString();
      return citaId != null && !liquidadasIds.contains(citaId);
    });

    final completadas = await _client
        .from('tratamientos')
        .select('cita_id')
        .eq('estado', AppConstants.tratamientoCompletado);
    final completadasIds =
        (completadas.map((j) => j['cita_id']?.toString()).toSet());

    final out = <CitaFinalizadaAdminEntity>[];
    for (final json in candidatas) {
      final citaId = json['id']?.toString() ?? '';
      if (!completadasIds.contains(citaId)) continue;

      final solicitudes = json['solicitudes'];
      Map<String, dynamic>? pago;
      if (solicitudes is Map<String, dynamic>) {
        final pagos = solicitudes['pagos'];
        if (pagos is List && pagos.isNotEmpty) {
          pago = Map<String, dynamic>.from(pagos.first as Map);
        }
      }
      final saldo = (pago?['saldo_pendiente'] as num?)?.toDouble() ?? 0;
      final estadoPago = pago?['estado']?.toString() ?? '';
      if (estadoPago != 'PAGADO') continue;
      if (saldo > 0) continue;

      final esp = json['especialistas'];
      String? nombre;
      if (esp is Map<String, dynamic>) {
        final profile = esp['profiles'];
        if (profile is Map<String, dynamic>) {
          nombre = profile['full_name']?.toString();
        }
      }

      String? pacienteNombre;
      final servicios = <String>[];
      if (solicitudes is Map<String, dynamic>) {
        final pacientes = solicitudes['pacientes'];
        if (pacientes is Map<String, dynamic>) {
          final profile = pacientes['profiles'];
          if (profile is Map<String, dynamic>) {
            pacienteNombre = profile['full_name']?.toString();
          }
        }
        final detalles = solicitudes['solicitud_detalles'];
        if (detalles is List) {
          for (final d in detalles) {
            if (d is! Map) continue;
            final s = d['servicios'];
            if (s is Map) {
              final nombreServicio = s['nombre']?.toString();
              if (nombreServicio != null && nombreServicio.isNotEmpty) {
                servicios.add(nombreServicio);
              }
            }
          }
        }
      }

      out.add(CitaFinalizadaAdminEntity(
        citaId: citaId,
        solicitudId: json['solicitud_id']?.toString(),
        especialistaId: json['especialista_id']?.toString(),
        especialistaNombre: nombre,
        fechaFinalizacion: _parseDate(json['fecha_finalizacion']),
        montoTotal: (pago?['monto_total'] as num?)?.toDouble() ?? 0,
        deposito: (pago?['deposito'] as num?)?.toDouble() ?? 0,
        saldoPendiente: saldo,
        estadoPago: estadoPago,
        pacienteNombre: pacienteNombre,
        servicios: servicios,
      ));
    }
    return out;
  }

  /// Detalle (líneas) de una liquidación.
  Future<List<DetalleLiquidacionEntity>> fetchLiquidacionDetalles(
      String liquidacionId) async {
    final res = await _client
        .from('liquidacion_detalles')
        .select()
        .eq('liquidacion_id', liquidacionId)
        .order('created_at');
    return res
        .map((json) => DetalleLiquidacionEntity(
              id: json['id']?.toString() ?? '',
              liquidacionId: json['liquidacion_id']?.toString() ?? '',
              citaId: json['cita_id']?.toString() ?? '',
              montoServicio:
                  (json['monto_servicio'] as num?)?.toDouble() ?? 0,
              comisionAplicada:
                  (json['comision_aplicada'] as num?)?.toDouble() ?? 0,
              montoEspecialista:
                  (json['monto_especialista'] as num?)?.toDouble() ?? 0,
            ))
        .toList();
  }

  /// Cambia el estado de una liquidación (RPC admin-only).
  Future<String> cambiarEstadoLiquidacion(
      String liquidacionId, String nuevoEstado) async {
    final res = await _client.rpc(AppConstants.rpcCambiarEstadoLiquidacion,
        params: {
          'p_liquidacion_id': liquidacionId,
          'p_nuevo_estado': nuevoEstado,
        });
    return res?['motivo']?.toString() ?? 'ERROR';
  }

  /// Registra el pago externo a un especialista (RPC admin-only).
  Future<String> registrarPagoEspecialista({
    required String liquidacionId,
    required String metodoPago,
    String? referenciaPago,
    String? comprobanteUrl,
    String? notas,
    double? montoPagado,
  }) async {
    final res = await _client.rpc(AppConstants.rpcRegistrarPagoEspecialista,
        params: {
          'p_liquidacion_id': liquidacionId,
          'p_metodo_pago': metodoPago,
          'p_referencia_pago': referenciaPago,
          'p_comprobante_url': comprobanteUrl,
          'p_notas': notas,
          'p_monto_pagado': montoPagado,
        });
    return res?['motivo']?.toString() ?? 'ERROR';
  }

  /// Sube el comprobante de pago a storage privado y devuelve su path.
  Future<String> subirComprobantePago({
    required String liquidacionId,
    required List<int> bytes,
    required String nombreArchivo,
  }) async {
    final ext =
        nombreArchivo.contains('.') ? nombreArchivo.split('.').last : 'png';
    final path = '$liquidacionId/comprobante_'
        '${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage
        .from(AppConstants.bucketComprobantes)
        .uploadBinary(path, Uint8List.fromList(bytes));
    return path;
  }

  /// Lee el día de inicio de la semana de liquidación (1=Lunes..7=Domingo).
  Future<int> fetchInicioSemanaLiquidacion() async {
    final res = await _client
        .from('configuracion_sistema')
        .select('valor')
        .eq('clave', AppConstants.inicioSemanaLiquidacionClave)
        .maybeSingle();
    final valor = res?['valor']?.toString();
    final parsed = int.tryParse(valor ?? '');
    if (parsed == null || parsed < 1 || parsed > 7) return 1;
    return parsed;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  /// Firma temporalmente (60 min) la URL de un comprobante en storage.
  Future<String?> firmarComprobante(String path) async {
    try {
      final url = await _client.storage
          .from(AppConstants.bucketComprobantes)
          .createSignedUrl(path, 3600);
      return url;
    } catch (_) {
      return null;
    }
  }
}
