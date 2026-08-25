import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
// Los usecases se inyectan por nombre; esta regla no aplica aquí.
// ignore_for_file: prefer_initializing_formals
import '../../../../app/config/app_constants.dart';
import '../../../treatment_photos/domain/entities/fotografia_tratamiento_entity.dart';
import '../../../treatment_photos/domain/usecases/get_fotografias.dart';
import '../../domain/entities/cita_ejecucion_entity.dart';
import '../../domain/entities/consentimiento_tratamiento_entity.dart';
import '../../domain/entities/face_map_especialista_entity.dart';
import '../../domain/entities/producto_aplicado_entity.dart';
import '../../domain/usecases/agregar_producto.dart';
import '../../domain/usecases/avanzar_estado_cita.dart';
import '../../domain/usecases/eliminar_producto.dart';
import '../../domain/usecases/finalizar_tratamiento.dart';
import '../../domain/usecases/actualizar_tratamiento.dart';
import '../../domain/usecases/get_cita_detalle.dart';
import '../../domain/usecases/get_citas_historial.dart';
import '../../domain/usecases/get_consentimiento.dart';
import '../../domain/usecases/get_face_map_por_tratamiento.dart';
import '../../domain/usecases/guardar_face_map_por_tratamiento.dart';
import '../../domain/usecases/get_mis_citas.dart';
import '../../domain/usecases/get_productos.dart';
import '../../domain/usecases/iniciar_tratamiento.dart';
import '../../domain/usecases/registrar_consentimiento.dart';
import '../../domain/usecases/cancelar_cita.dart';
import '../../domain/usecases/registrar_llegada.dart';
import '../../domain/usecases/subir_firma.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ESTADOS
// ─────────────────────────────────────────────────────────────────────────────

abstract class TreatmentExecutionState {
  const TreatmentExecutionState();
}

class TreatmentExecutionInitial extends TreatmentExecutionState {
  const TreatmentExecutionInitial();
}

class TreatmentExecutionLoading extends TreatmentExecutionState {
  const TreatmentExecutionLoading();
}

class TreatmentExecutionLoaded extends TreatmentExecutionState {
  final List<CitaEjecucionEntity> citas;
  final List<CitaEjecucionEntity> citasHistorial;
  final CitaEjecucionEntity? cita;
  final List<ProductoAplicadoEntity> productos;
  final ConsentimientoTratamientoEntity? consentimiento;
  final List<FotografiaTratamientoEntity> fotografias;
  final FaceMapEspecialistaEntity? faceMap;
  final bool trabajando;

  const TreatmentExecutionLoaded({
    this.citas = const [],
    this.citasHistorial = const [],
    this.cita,
    this.productos = const [],
    this.consentimiento,
    this.fotografias = const [],
    this.faceMap,
    this.trabajando = false,
  });

  TreatmentExecutionLoaded copyWith({
    List<CitaEjecucionEntity>? citas,
    List<CitaEjecucionEntity>? citasHistorial,
    CitaEjecucionEntity? cita,
    List<ProductoAplicadoEntity>? productos,
    ConsentimientoTratamientoEntity? consentimiento,
    List<FotografiaTratamientoEntity>? fotografias,
    FaceMapEspecialistaEntity? faceMap,
    bool? trabajando,
  }) {
    return TreatmentExecutionLoaded(
      citas: citas ?? this.citas,
      citasHistorial: citasHistorial ?? this.citasHistorial,
      cita: cita ?? this.cita,
      productos: productos ?? this.productos,
      consentimiento: consentimiento ?? this.consentimiento,
      fotografias: fotografias ?? this.fotografias,
      faceMap: faceMap ?? this.faceMap,
      trabajando: trabajando ?? this.trabajando,
    );
  }
}

class TreatmentExecutionError extends TreatmentExecutionState {
  final String message;
  const TreatmentExecutionError(this.message);
}

// ─────────────────────────────────────────────────────────────────────────────
// CUBIT
// ─────────────────────────────────────────────────────────────────────────────

class TreatmentExecutionCubit extends Cubit<TreatmentExecutionState> {
  final GetMisCitas _getMisCitas;
  final GetCitaDetalle _getCitaDetalle;
  final GetProductos _getProductos;
  final GetConsentimiento _getConsentimiento;
  final AvanzarEstadoCita _avanzarEstadoCita;
  final IniciarTratamiento _iniciarTratamiento;
  final ActualizarTratamiento _actualizarTratamiento;
  final AgregarProducto _agregarProducto;
  final EliminarProducto _eliminarProducto;
  final RegistrarConsentimiento _registrarConsentimiento;
  final SubirFirma _subirFirma;
  final FinalizarTratamiento _finalizarTratamiento;
  final GetCitasHistorial _getCitasHistorial;
  final RegistrarLlegada _registrarLlegada;
  final CancelarCita _cancelarCita;
  final GetFotografias _getFotografias;
  final GetFaceMapPorTratamiento _getFaceMapPorTratamiento;
  final GuardarFaceMapPorTratamiento _guardarFaceMapPorTratamiento;

  TreatmentExecutionCubit({
    required GetMisCitas getMisCitas,
    required GetCitaDetalle getCitaDetalle,
    required GetProductos getProductos,
    required GetConsentimiento getConsentimiento,
    required AvanzarEstadoCita avanzarEstadoCita,
    required IniciarTratamiento iniciarTratamiento,
    required ActualizarTratamiento actualizarTratamiento,
    required AgregarProducto agregarProducto,
    required EliminarProducto eliminarProducto,
    required RegistrarConsentimiento registrarConsentimiento,
    required SubirFirma subirFirma,
    required FinalizarTratamiento finalizarTratamiento,
    required GetCitasHistorial getCitasHistorial,
    required RegistrarLlegada registrarLlegada,
    required CancelarCita cancelarCita,
    required GetFotografias getFotografias,
    required GetFaceMapPorTratamiento getFaceMapPorTratamiento,
    required GuardarFaceMapPorTratamiento guardarFaceMapPorTratamiento,
  })  : _getMisCitas = getMisCitas,
        _getCitaDetalle = getCitaDetalle,
        _getProductos = getProductos,
        _getConsentimiento = getConsentimiento,
        _avanzarEstadoCita = avanzarEstadoCita,
        _iniciarTratamiento = iniciarTratamiento,
        _actualizarTratamiento = actualizarTratamiento,
        _agregarProducto = agregarProducto,
        _eliminarProducto = eliminarProducto,
        _registrarConsentimiento = registrarConsentimiento,
        _subirFirma = subirFirma,
        _finalizarTratamiento = finalizarTratamiento,
        _getCitasHistorial = getCitasHistorial,
        _registrarLlegada = registrarLlegada,
        _cancelarCita = cancelarCita,
        _getFotografias = getFotografias,
        _getFaceMapPorTratamiento = getFaceMapPorTratamiento,
        _guardarFaceMapPorTratamiento = guardarFaceMapPorTratamiento,
        super(const TreatmentExecutionInitial());

  TreatmentExecutionLoaded? get _loaded =>
      state is TreatmentExecutionLoaded ? state as TreatmentExecutionLoaded : null;

  /// Carga las citas pendientes del especialista (preservando el historial).
  Future<void> loadCitas({required String especialistaId}) async {
    if (_loaded == null) emit(const TreatmentExecutionLoading());
    final result = await _getMisCitas(GetMisCitasParams(especialistaId));
    result.fold(
      (f) => emit(TreatmentExecutionError(f.message)),
      (citas) => emit(TreatmentExecutionLoaded(
        citas: citas,
        citasHistorial: _loaded?.citasHistorial ?? const [],
      )),
    );
  }

  /// Carga todas las citas del especialista (incl. finalizadas y canceladas),
  /// preservando la lista de citas activas.
  Future<void> loadCitasHistorial({required String especialistaId}) async {
    if (_loaded == null) emit(const TreatmentExecutionLoading());
    final result =
        await _getCitasHistorial(GetCitasHistorialParams(especialistaId));
    result.fold(
      (f) => emit(TreatmentExecutionError(f.message)),
      (citas) => emit(TreatmentExecutionLoaded(
        citas: _loaded?.citas ?? const [],
        citasHistorial: citas,
      )),
    );
  }

  /// Carga el detalle de una cita (con productos y consentimiento).
  Future<void> loadDetalle({required String citaId}) async {
    final current = _loaded;
    emit(current?.copyWith(trabajando: true) ??
        const TreatmentExecutionLoading());

    final citaResult = await _getCitaDetalle(GetCitaDetalleParams(citaId));
    CitaEjecucionEntity? cita;
    String? error;
    citaResult.fold((f) => error = f.message, (c) => cita = c);

    List<ProductoAplicadoEntity> productos = [];
    ConsentimientoTratamientoEntity? consentimiento;
    List<FotografiaTratamientoEntity> fotografias = [];
    if (cita?.tratamiento != null) {
      final p = await _getProductos(cita!.tratamiento!.id);
      p.fold((_) {}, (v) => productos = v);
      final c = await _getConsentimiento(cita!.tratamiento!.id);
      c.fold((_) {}, (v) => consentimiento = v);
      final f = await _getFotografias(GetFotografiasParams(cita!.tratamiento!.id));
      f.fold((_) {}, (v) => fotografias = v);
    }

    if (error != null) {
      emit(TreatmentExecutionError(error!));
      return;
    }

    emit(TreatmentExecutionLoaded(
      citas: current?.citas ?? const [],
      citasHistorial: current?.citasHistorial ?? const [],
      cita: cita,
      productos: productos,
      consentimiento: consentimiento,
      fotografias: fotografias,
    ));
  }

  /// Avanza el estado de la cita (PROGRAMADA → EN_CAMINO → LLEGO → EN_PROCESO).
  Future<void> avanzar({
    required String citaId,
    required EstadoCitaEjecucion nuevoEstado,
  }) async {
    final current = _loaded;
    if (current == null) return;
    emit(current.copyWith(trabajando: true));
    final result = await _avanzarEstadoCita(
        AvanzarEstadoCitaParams(citaId: citaId, nuevoEstado: nuevoEstado));
    result.fold(
      (f) => emit(current.copyWith(trabajando: false)),
      (cita) => emit(current.copyWith(cita: cita, trabajando: false)),
    );
  }

  /// Crea o recupera el tratamiento de la cita (lo inicia).
  Future<void> iniciarTratamiento({
    required String citaId,
    String? evaluacionInicial,
  }) async {
    final current = _loaded;
    if (current == null) return;
    emit(current.copyWith(trabajando: true));
    final result = await _iniciarTratamiento(IniciarTratamientoParams(
      citaId: citaId,
      evaluacionInicial: evaluacionInicial,
    ));
    result.fold(
      (f) => emit(TreatmentExecutionError(f.message)),
      (tratamiento) async {
        final detalle = await _getCitaDetalle(GetCitaDetalleParams(citaId));
        CitaEjecucionEntity? cita;
        detalle.fold((f) => emit(TreatmentExecutionError(f.message)),
            (c) => cita = c);
        if (cita != null) {
          emit(current.copyWith(cita: cita, trabajando: false));
        }
      },
    );
  }

  /// Guarda la evaluación inicial del tratamiento.
  Future<void> guardarEvaluacion({
    required String tratamientoId,
    String? evaluacionInicial,
  }) async {
    final current = _loaded;
    if (current == null) return;
    final result = await _actualizarTratamiento(
        ActualizarTratamientoParams(
      tratamientoId: tratamientoId,
      evaluacionInicial: evaluacionInicial,
    ));
    result.fold(
      (f) => emit(TreatmentExecutionError(f.message)),
      (trat) => emit(current.copyWith(
        cita: current.cita?.copyWith(tratamiento: trat),
      )),
    );
  }

  /// Registra un producto aplicado al tratamiento.
  Future<void> agregarProducto({
    required String tratamientoId,
    required String productoNombre,
    String? fabricante,
    String? lote,
    required double cantidadTotal,
    String? unidadMedida,
    DateTime? fechaVencimiento,
    String? observaciones,
  }) async {
    final current = _loaded;
    if (current == null) return;
    final result = await _agregarProducto(AgregarProductoParams(
      tratamientoId: tratamientoId,
      productoNombre: productoNombre,
      fabricante: fabricante,
      lote: lote,
      cantidadTotal: cantidadTotal,
      unidadMedida: unidadMedida,
      fechaVencimiento: fechaVencimiento,
      observaciones: observaciones,
    ));
    result.fold(
      (f) => emit(TreatmentExecutionError(f.message)),
      (p) => emit(current.copyWith(productos: [...current.productos, p])),
    );
  }

  /// Elimina un producto del tratamiento.
  Future<void> eliminarProducto(String productoId) async {
    final current = _loaded;
    if (current == null) return;
    final result = await _eliminarProducto(EliminarProductoParams(productoId));
    result.fold(
      (f) => emit(TreatmentExecutionError(f.message)),
      (_) => emit(current.copyWith(
          productos: [
            for (final p in current.productos)
              if (p.id != productoId) p
          ])),
    );
  }

  /// Sube la firma y registra el consentimiento del tratamiento.
  Future<void> firmarConsulta({
    required String tratamientoId,
    required String pacienteId,
    required String tipoConsentimiento,
    required Uint8List bytesFirma,
  }) async {
    final current = _loaded;
    if (current == null) return;
    emit(current.copyWith(trabajando: true));

    final subida = await _subirFirma(SubirFirmaParams(
      tratamientoId: tratamientoId,
      bytes: bytesFirma,
    ));
    String? url;
    subida.fold((f) => emit(TreatmentExecutionError(f.message)), (u) => url = u);

    if (url == null) {
      emit(current.copyWith(trabajando: false));
      return;
    }

    final result = await _registrarConsentimiento(
      RegistrarConsentimientoParams(
        tratamientoId: tratamientoId,
        pacienteId: pacienteId,
        tipoConsentimiento: tipoConsentimiento,
        firmaUrl: url!,
      ),
    );
    result.fold(
      (f) => emit(TreatmentExecutionError(f.message)),
      (c) async {
        // La firma era el primer paso obligatorio: el tratamiento pasa a EN_PROCESO.
        final upd = await _actualizarTratamiento(ActualizarTratamientoParams(
          tratamientoId: tratamientoId,
          estado: AppConstants.tratamientoEnProceso,
        ));
        upd.fold(
          (f) => emit(current.copyWith(consentimiento: c, trabajando: false)),
          (trat) => emit(current.copyWith(
            consentimiento: c,
            cita: current.cita?.copyWith(tratamiento: trat),
            trabajando: false,
          )),
        );
      },
    );
  }

  /// Finaliza el tratamiento y la cita.
  Future<void> finalizar({
    required String citaId,
    required String tratamientoId,
    String? observacionesFinales,
    String? recomendacionesPostTratamiento,
  }) async {
    final current = _loaded;
    if (current == null) return;
    emit(current.copyWith(trabajando: true));
    final result = await _finalizarTratamiento(FinalizarTratamientoParams(
      citaId: citaId,
      tratamientoId: tratamientoId,
      observacionesFinales: observacionesFinales,
      recomendacionesPostTratamiento: recomendacionesPostTratamiento,
    ));
    result.fold(
      (f) => emit(TreatmentExecutionError(f.message)),
      (_) => emit(current.copyWith(trabajando: false)),
    );
  }

  /// Registra la llegada del especialista (GPS) y devuelve la distancia en metros.
  Future<double?> registrarLlegada({
    required String citaId,
    required double latitud,
    required double longitud,
  }) async {
    final current = _loaded;
    if (current == null) return null;
    emit(current.copyWith(trabajando: true));
    final result = await _registrarLlegada(RegistrarLlegadaParams(
      citaId: citaId,
      latitud: latitud,
      longitud: longitud,
    ));
    double? distancia;
    result.fold(
      (f) => emit(TreatmentExecutionError(f.message)),
      (d) => distancia = d,
    );
    emit(current.copyWith(trabajando: false));
    return distancia;
  }

  /// Cancela la cita registrando el motivo.
  Future<void> cancelar({required String citaId, String? motivo}) async {
    final current = _loaded;
    if (current == null) return;
    emit(current.copyWith(trabajando: true));
    final result = await _cancelarCita(CancelarCitaParams(
      citaId: citaId,
      motivo: motivo,
    ));
    result.fold(
      (f) => emit(TreatmentExecutionError(f.message)),
      (_) => emit(current.copyWith(trabajando: false)),
    );
  }

  /// Carga el face map del tratamiento (o el pre-tratamiento del paciente).
  Future<void> loadFaceMap({required String tratamientoId}) async {
    final current = _loaded;
    if (current == null) return;
    emit(current.copyWith(trabajando: true));
    final result = await _getFaceMapPorTratamiento(tratamientoId);
    result.fold(
      (f) => emit(TreatmentExecutionError(f.message)),
      (faceMap) => emit(current.copyWith(faceMap: faceMap, trabajando: false)),
    );
  }

  /// Guarda (upsert) el face map del tratamiento y sus puntos.
  Future<void> guardarFaceMap({
    required String tratamientoId,
    required String pacienteId,
    required List<Map<String, dynamic>> puntos,
    String? observaciones,
  }) async {
    final current = _loaded;
    if (current == null) return;
    emit(current.copyWith(trabajando: true));
    final result = await _guardarFaceMapPorTratamiento(
      GuardarFaceMapPorTratamientoParams(
        tratamientoId: tratamientoId,
        pacienteId: pacienteId,
        puntos: puntos,
        observaciones: observaciones,
      ),
    );
    result.fold(
      (f) => emit(TreatmentExecutionError(f.message)),
      (_) async {
        final reload = await _getFaceMapPorTratamiento(tratamientoId);
        reload.fold(
          (f) => emit(current.copyWith(trabajando: false)),
          (faceMap) => emit(
            current.copyWith(faceMap: faceMap, trabajando: false),
          ),
        );
      },
    );
  }
}