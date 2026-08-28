import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/config/app_constants.dart';
import '../models/cita_ejecucion_model.dart';
import '../models/consentimiento_model.dart';
import '../models/face_map_especialista_model.dart';
import '../models/producto_aplicado_model.dart';
import '../models/tratamiento_model.dart';

/// Datasource de Supabase para el módulo treatment_execution.
/// Solo habla con Supabase y devuelve Models.
class TreatmentExecutionSupabaseDataSource {
  final SupabaseClient _client;

  TreatmentExecutionSupabaseDataSource(this._client);

  static const String _citaSelect = '''
    *,
    solicitudes(id, servicios(nombre, precio_base, tipo_precio), pacientes(profiles(full_name, phone)), direcciones_paciente(latitud, longitud, direccion, ciudad)),
    tratamientos(*)
  ''';

  String? get _uid => _client.auth.currentUser?.id;

  // ── Lecturas ─────────────────────────────────────────────────

  Future<List<CitaEjecucionModel>> fetchMisCitas(String especialistaId) async {
    final res = await _client
        .from('citas')
        .select(_citaSelect)
        .eq('especialista_id', especialistaId)
        .inFilter('estado', [
          AppConstants.citaProgramada,
          AppConstants.citaEnCamino,
          AppConstants.citaLlego,
          AppConstants.citaEnProceso,
        ])
        .order('fecha_aceptacion', ascending: true);
    return res
        .map((json) => CitaEjecucionModel.fromJson(json))
        .toList();
  }

  Future<CitaEjecucionModel> fetchCitaDetalle(String citaId) async {
    final res = await _client
        .from('citas')
        .select(_citaSelect)
        .eq('id', citaId)
        .maybeSingle();
    if (res == null) throw Exception('Cita $citaId no encontrada');
    return CitaEjecucionModel.fromJson(res);
  }

  /// Todas las citas del especialista (incluye finalizadas, canceladas y no
  /// completadas), para el historial de la lista "Mis citas".
  Future<List<CitaEjecucionModel>> fetchCitasHistorial(
      String especialistaId) async {
    final res = await _client
        .from('citas')
        .select(_citaSelect)
        .eq('especialista_id', especialistaId)
        .order('fecha_aceptacion', ascending: true);
    return res
        .map((json) => CitaEjecucionModel.fromJson(json))
        .toList();
  }

  Future<List<ProductoAplicadoModel>> fetchProductos(
      String tratamientoId) async {
    final res = await _client
        .from('productos_aplicados')
        .select()
        .eq('tratamiento_id', tratamientoId)
        .order('created_at', ascending: false);
    return res
        .map((json) => ProductoAplicadoModel.fromJson(json))
        .toList();
  }

  Future<ConsentimientoModel?> fetchConsentimiento(
      String tratamientoId) async {
    final res = await _client
        .from('consentimientos_tratamiento')
        .select()
        .eq('tratamiento_id', tratamientoId)
        .maybeSingle();
    if (res == null) return null;
    return ConsentimientoModel.fromJson(res);
  }

  // ── Escritura: ciclo de la cita ─────────────────────────────

  /// Actualiza el estado de la cita y registra la transición.
  Future<void> actualizarEstadoCita({
    required String citaId,
    required String nuevoEstado,
    String? observaciones,
  }) async {
    final payload = <String, dynamic>{'estado': nuevoEstado};
    if (nuevoEstado == AppConstants.citaEnProceso) {
      payload['fecha_inicio'] = DateTime.now().toIso8601String();
    } else if (nuevoEstado == AppConstants.citaFinalizada) {
      payload['fecha_finalizacion'] = DateTime.now().toIso8601String();
    }
    await _client.from('citas').update(payload).eq('id', citaId);

    await _insertHistorial(
      citaId: citaId,
      estado: nuevoEstado,
      observaciones: observaciones,
    );
  }

  Future<void> _insertHistorial({
    required String citaId,
    required String estado,
    String? observaciones,
    String? motivo,
  }) async {
    await _client.from('historial_estados').insert({
      'tipo_entidad': 'CITA',
      'entidad_id': citaId,
      'estado': estado,
      'fecha_estado': DateTime.now().toIso8601String(),
      'usuario_id': _uid,
      'observaciones': observaciones,
      'motivo_cancelacion': motivo,
    });
  }

  // ── Tratamiento ──────────────────────────────────────────────

  /// Devuelve el tratamiento existente de la cita o crea uno `PENDIENTE_FIRMA`
  /// (la firma del consentimiento es el primer paso obligatorio antes de
  /// continuar con la ejecución).
  Future<TratamientoModel> asegurarTratamiento({
    required String citaId,
    String? evaluacionInicial,
  }) async {
    final cita = await _client
        .from('citas')
        .select('id, especialista_id, solicitudes(paciente_id)')
        .eq('id', citaId)
        .maybeSingle();
    if (cita == null) throw Exception('Cita $citaId no encontrada');

    final solicitud = cita['solicitudes'];
    final pacienteId = solicitud is Map<String, dynamic>
        ? solicitud['paciente_id']
        : null;
    final especialistaId = cita['especialista_id'] as String?;
    if (especialistaId == null) throw Exception('Especialista no válido');
    if (pacienteId == null) throw Exception('Paciente no válido');

    final existente = await _client
        .from('tratamientos')
        .select()
        .eq('cita_id', citaId)
        .maybeSingle();
    if (existente != null) {
      return TratamientoModel.fromJson(existente);
    }

    final now = DateTime.now().toIso8601String();
    final res = await _client.from('tratamientos').insert({
      'cita_id': citaId,
      'paciente_id': pacienteId,
      'especialista_id': especialistaId,
      'fecha_inicio': now,
      'estado': AppConstants.tratamientoPendienteFirma,
      'evaluacion_inicial': evaluacionInicial,
      'created_at': now,
      'updated_at': now,
    }).select().maybeSingle();
    if (res == null) throw Exception('No se pudo crear el tratamiento');
    return TratamientoModel.fromJson(res);
  }

  Future<TratamientoModel> actualizarTratamiento({
    required String tratamientoId,
    String? evaluacionInicial,
    String? observacionesFinales,
    String? recomendacionesPostTratamiento,
    String? estado,
  }) async {
    final payload = <String, dynamic>{'updated_at': DateTime.now().toIso8601String()};
    if (evaluacionInicial != null) payload['evaluacion_inicial'] = evaluacionInicial;
    if (observacionesFinales != null) payload['observaciones_finales'] = observacionesFinales;
    if (recomendacionesPostTratamiento != null) {
      payload['recomendaciones_post_tratam'] = recomendacionesPostTratamiento;
    }
    if (estado != null) payload['estado'] = estado;

    final res = await _client
        .from('tratamientos')
        .update(payload)
        .eq('id', tratamientoId)
        .select()
        .maybeSingle();
    if (res == null) throw Exception('No se pudo actualizar el tratamiento');
    return TratamientoModel.fromJson(res);
  }

  // ── Productos aplicados ──────────────────────────────────────

  Future<ProductoAplicadoModel> insertarProducto({
    required String tratamientoId,
    required String productoNombre,
    String? fabricante,
    String? lote,
    required double cantidadTotal,
    String? unidadMedida,
    DateTime? fechaVencimiento,
    String? observaciones,
  }) async {
    final res = await _client.from('productos_aplicados').insert({
      'tratamiento_id': tratamientoId,
      'producto_nombre': productoNombre,
      'fabricante': fabricante,
      'lote': lote,
      'cantidad_total': cantidadTotal,
      'unidad_medida': unidadMedida,
      'fecha_vencimiento': fechaVencimiento?.toIso8601String(),
      'observaciones': observaciones,
    }).select().maybeSingle();
    if (res == null) throw Exception('No se pudo registrar el producto');
    return ProductoAplicadoModel.fromJson(res);
  }

  Future<void> eliminarProducto(String productoId) async {
    await _client.from('productos_aplicados').delete().eq('id', productoId);
  }

  // ── Consentimiento / firma ───────────────────────────────────

  Future<ConsentimientoModel> insertarConsentimiento({
    required String tratamientoId,
    required String pacienteId,
    required String tipoConsentimiento,
    required String firmaUrl,
  }) async {
    final now = DateTime.now().toIso8601String();
    final res = await _client.from('consentimientos_tratamiento').insert({
      'tratamiento_id': tratamientoId,
      'paciente_id': pacienteId,
      'tipo_consentimiento': tipoConsentimiento,
      'firma_url': firmaUrl,
      'fecha_firma': now,
    }).select().maybeSingle();
    if (res == null) throw Exception('No se pudo registrar el consentimiento');
    return ConsentimientoModel.fromJson(res);
  }

  /// Sube los bytes de la firma al bucket (privado) y devuelve el PATH del
  /// objeto en storage para guardarlo en `firma_url`. La URL firmada se genera
  /// al leer (createSignedUrl).
  Future<String> subirFirma({
    required String tratamientoId,
    required Uint8List bytes,
  }) async {
    final path =
        '$tratamientoId/firma_${DateTime.now().millisecondsSinceEpoch}.png';
    await _client.storage
        .from(AppConstants.bucketFirmas)
        .uploadBinary(path, bytes);
    return path;
  }

  // ── Finalizar ────────────────────────────────────────────────

  /// Marca el tratamiento COMPLETADO y la cita FINALIZADA (con historial).
  Future<void> finalizarTratamiento({
    required String citaId,
    required String tratamientoId,
    String? observacionesFinales,
    String? recomendacionesPostTratamiento,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _client.from('tratamientos').update({
      'estado': AppConstants.tratamientoCompletado,
      'fecha_finalizacion': now,
      'observaciones_finales': observacionesFinales,
      'recomendaciones_post_tratam': recomendacionesPostTratamiento,
      'updated_at': now,
    }).eq('id', tratamientoId);

    await _client.from('citas').update({
      'estado': AppConstants.citaFinalizada,
      'fecha_finalizacion': now,
    }).eq('id', citaId);

    await _insertHistorial(
      citaId: citaId,
      estado: AppConstants.citaFinalizada,
      observaciones: observacionesFinales,
    );
  }

  /// Indica si la simulación de llegada está habilitada (configuración de
  /// pruebas). Lee la clave `simular_llegada` de `configuracion_sistema`.
  Future<bool> fetchSimularLlegada() async {
    final res = await _client
        .from('configuracion_sistema')
        .select('valor')
        .eq('clave', AppConstants.simularLlegadaClave)
        .maybeSingle();
    final valor = res?['valor'];
    return valor == null || valor.toString().toLowerCase() == 'true';
  }

  /// Cancela la cita y la deja sin valor (estado CANCELADA) vía RPC, que valida
  /// la transición y registra el motivo + usuario en `historial_estados`.
  Future<void> cancelarCita({
    required String citaId,
    String? motivo,
  }) async {
    final res = await _client.rpc('cancelar_cita', params: {
      'p_cita_id': citaId,
      'p_motivo': motivo,
    });
    final ok = res is Map && res['ok'] == true;
    if (!ok) {
      throw Exception(
          'No se pudo cancelar la cita: ${res is Map ? res['motivo'] : 'error'}');
    }
  }

  /// Registra la llegada del especialista al domicilio vía RPC, escribiendo
  /// latitud_llegada/longitud_llegada/distancia_recorrida. Devuelve la
  /// distancia recorrida en metros (o null si no se pudo calcular).
  Future<double?> registrarLlegada({
    required String citaId,
    required double latitud,
    required double longitud,
  }) async {
    final res = await _client.rpc('registrar_llegada_especialista', params: {
      'p_cita_id': citaId,
      'p_latitud': latitud,
      'p_longitud': longitud,
    });
    if (res is Map && res['ok'] == true) {
      final dist = res['distancia_recorrida_m'];
      return dist is num ? dist.toDouble() : null;
    }
    throw Exception(
        'No se pudo registrar la llegada: ${res is Map ? res['motivo'] : 'error'}');
  }

  // ── Face map del especialista ────────────────────────────────

  /// Devuelve el face map vinculado al tratamiento (el guardado por el
  /// especialista) o, si no existe, el mapa pre-tratamiento del paciente
  /// (face_maps con tratamiento_id nulo del mismo paciente y del mismo
  /// servicio). Carga los puntos desde `face_map_puntos`, con el nombre del
  /// producto aplicado embebido. Devuelve `null` si no hay mapa.
  Future<FaceMapEspecialistaModel?> fetchFaceMapPorTratamiento(
      String tratamientoId) async {
    final tratamiento = await _client
        .from('tratamientos')
        .select('id, paciente_id, citas(solicitudes(servicios(id)))')
        .eq('id', tratamientoId)
        .maybeSingle();
    if (tratamiento == null) return null;

    final citasJson = tratamiento['citas'];
    final solicitudesJson = citasJson is Map<String, dynamic>
        ? citasJson['solicitudes']
        : null;
    final serviciosJson = solicitudesJson is Map<String, dynamic>
        ? solicitudesJson['servicios']
        : null;
    final servicioId = serviciosJson is Map<String, dynamic>
        ? serviciosJson['id'] as String?
        : null;

    var mapa = await _client
        .from('face_maps')
        .select()
        .eq('tratamiento_id', tratamientoId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    final pacienteId = tratamiento['paciente_id'] as String?;
    if (mapa == null && pacienteId != null) {
      var query = _client
          .from('face_maps')
          .select()
          .eq('paciente_id', pacienteId)
          .isFilter('tratamiento_id', null);
      if (servicioId != null) {
        query = query.eq('servicio_id', servicioId);
      }
      mapa = await query
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
    }
    if (mapa == null) return null;

    final model = FaceMapEspecialistaModel.fromJson(mapa);
    final puntos = await _client
        .from('face_map_puntos')
        .select('*, productos_aplicados(producto_nombre)')
        .eq('face_map_id', model.id ?? '')
        .order('created_at', ascending: true);
    return FaceMapEspecialistaModel(
      id: model.id,
      tratamientoId: model.tratamientoId,
      pacienteId: model.pacienteId,
      servicioId: model.servicioId,
      tipoMapa: model.tipoMapa,
      imagenBaseUrl: model.imagenBaseUrl,
      observaciones: model.observaciones,
      puntos: puntos.cast<Map<String, dynamic>>().toList(),
    );
  }

  /// Guarda el face map del especialista vinculado al tratamiento: crea o
  /// actualiza la fila en `face_maps` y reemplaza los puntos en
  /// `face_map_puntos` (delete + insert, operación idempotente).
  Future<void> guardarFaceMapPorTratamiento({
    required String tratamientoId,
    required String pacienteId,
    required List<Map<String, dynamic>> puntos,
    String? observaciones,
  }) async {
    final now = DateTime.now().toIso8601String();
    final existente = await _client
        .from('face_maps')
        .select('id')
        .eq('tratamiento_id', tratamientoId)
        .maybeSingle();

    String faceMapId;
    if (existente != null) {
      faceMapId = existente['id'] as String;
      await _client.from('face_maps').update({
        'observaciones': observaciones,
        'updated_at': now,
      }).eq('id', faceMapId);
    } else {
      final res = await _client.from('face_maps').insert({
        'tratamiento_id': tratamientoId,
        'paciente_id': pacienteId,
        'tipo_mapa': 'ROSTRO',
        'imagen_base_url': '',
        'observaciones': observaciones,
        'created_at': now,
        'updated_at': now,
      }).select('id').maybeSingle();
      if (res == null) throw Exception('No se pudo crear el face map');
      faceMapId = res['id'] as String;
    }

    await _client
        .from('face_map_puntos')
        .delete()
        .eq('face_map_id', faceMapId);

    if (puntos.isNotEmpty) {
      final filas = puntos.map((p) {
        final fila = <String, dynamic>{
          'face_map_id': faceMapId,
          'zona_anatomica': p['zona_anatomica'],
          'punto_id': p['punto_id'],
          'vista': p['vista'],
          'coordenada_x': p['coordenada_x'],
          'coordenada_y': p['coordenada_y'],
        };
        final productoId = p['producto_id'];
        if (productoId is String && productoId.isNotEmpty) {
          fila['producto_id'] = productoId;
          final cantidad = p['cantidad'];
          if (cantidad is num && cantidad > 0) {
            fila['cantidad'] = cantidad;
          }
          final unidad = p['unidad_medida'];
          if (unidad is String && unidad.trim().isNotEmpty) {
            fila['unidad_medida'] = unidad;
          }
        }
        final observacion = p['observaciones'];
        if (observacion is String && observacion.trim().isNotEmpty) {
          fila['observaciones'] = observacion;
        }
        return fila;
      }).toList();
      await _client.from('face_map_puntos').insert(filas);
    }
  }
}