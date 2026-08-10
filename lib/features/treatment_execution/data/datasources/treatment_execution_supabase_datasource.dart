import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/config/app_constants.dart';
import '../models/cita_ejecucion_model.dart';
import '../models/consentimiento_model.dart';
import '../models/producto_aplicado_model.dart';
import '../models/tratamiento_model.dart';

/// Datasource de Supabase para el módulo treatment_execution.
/// Solo habla con Supabase y devuelve Models.
class TreatmentExecutionSupabaseDataSource {
  final SupabaseClient _client;

  TreatmentExecutionSupabaseDataSource(this._client);

  static const String _citaSelect = '''
    *,
    solicitudes(id, servicios(nombre, precio_base), pacientes(profiles(full_name, phone)), direcciones_paciente(latitud, longitud, direccion, ciudad)),
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

  /// Devuelve el tratamiento existente de la cita o crea uno `INICIADO`.
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
      'estado': AppConstants.tratamientoIniciado,
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

  /// Sube los bytes de la firma al bucket y devuelve la URL pública.
  Future<String> subirFirma({
    required String tratamientoId,
    required Uint8List bytes,
  }) async {
    final path =
        '$tratamientoId/firma_${DateTime.now().millisecondsSinceEpoch}.png';
    final upload = await _client.storage
        .from(AppConstants.bucketFirmas)
        .uploadBinary(path, bytes);
    return _client.storage
        .from(AppConstants.bucketFirmas)
        .getPublicUrl(upload);
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

  /// Cancela la cita y la deja sin valor (estado CANCELADA).
  Future<void> cancelarCita({
    required String citaId,
    String? motivo,
  }) async {
    await _client.from('citas').update({
      'estado': AppConstants.citaCancelada,
      'observaciones': motivo,
    }).eq('id', citaId);
    await _insertHistorial(
      citaId: citaId,
      estado: AppConstants.citaCancelada,
      observaciones: motivo,
      motivo: motivo,
    );
  }
}