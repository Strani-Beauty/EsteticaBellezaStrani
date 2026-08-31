import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Los usecases se inyectan por nombre; esta regla no aplica aquí.
// ignore_for_file: prefer_initializing_formals

import '../../domain/entities/financiero_entity.dart';
import '../../domain/usecases/financiero_usecases.dart';

abstract class AdminComisionesState extends Equatable {
  const AdminComisionesState();
  @override
  List<Object?> get props => [];
}

class AdminComisionesInitial extends AdminComisionesState {
  const AdminComisionesInitial();
}

class AdminComisionesLoading extends AdminComisionesState {
  const AdminComisionesLoading();
}

class AdminComisionesLoaded extends AdminComisionesState {
  final List<LiquidacionEntity> liquidaciones;
  final List<PagoEspecialistaEntity> pagos;
  final Map<String, List<DetalleLiquidacionEntity>> detallesPorLiquidacion;
  final bool trabajando;
  const AdminComisionesLoaded({
    this.liquidaciones = const [],
    this.pagos = const [],
    this.detallesPorLiquidacion = const {},
    this.trabajando = false,
  });

  AdminComisionesLoaded copyWith({
    List<LiquidacionEntity>? liquidaciones,
    List<PagoEspecialistaEntity>? pagos,
    Map<String, List<DetalleLiquidacionEntity>>? detallesPorLiquidacion,
    bool? trabajando,
  }) {
    return AdminComisionesLoaded(
      liquidaciones: liquidaciones ?? this.liquidaciones,
      pagos: pagos ?? this.pagos,
      detallesPorLiquidacion:
          detallesPorLiquidacion ?? this.detallesPorLiquidacion,
      trabajando: trabajando ?? this.trabajando,
    );
  }

  @override
  List<Object?> get props =>
      [liquidaciones, pagos, detallesPorLiquidacion, trabajando];
}

class AdminComisionesError extends AdminComisionesState {
  final String message;
  const AdminComisionesError(this.message);
  @override
  List<Object?> get props => [message];
}

class AdminComisionesCubit extends Cubit<AdminComisionesState> {
  final GetLiquidaciones _getLiquidaciones;
  final GetPagosEspecialistas _getPagos;
  final GetLiquidacionDetalles _getDetalles;
  final CambiarEstadoLiquidacion _cambiarEstado;
  final RegistrarPagoEspecialista _registrarPago;
  final SubirComprobantePago _subirComprobante;

  AdminComisionesCubit({
    required GetLiquidaciones getLiquidaciones,
    required GetPagosEspecialistas getPagos,
    required GetLiquidacionDetalles getDetalles,
    required CambiarEstadoLiquidacion cambiarEstado,
    required RegistrarPagoEspecialista registrarPago,
    required SubirComprobantePago subirComprobante,
  })  : _getLiquidaciones = getLiquidaciones,
        _getPagos = getPagos,
        _getDetalles = getDetalles,
        _cambiarEstado = cambiarEstado,
        _registrarPago = registrarPago,
        _subirComprobante = subirComprobante,
        super(const AdminComisionesInitial());

  Future<void> load() async {
    emit(const AdminComisionesLoading());
    List<LiquidacionEntity>? liquidaciones;
    List<PagoEspecialistaEntity>? pagos;
    String? error;
    final r1 = await _getLiquidaciones();
    final r2 = await _getPagos();
    r1.fold((f) => error ??= f.message, (v) => liquidaciones = v);
    r2.fold((f) => error ??= f.message, (v) => pagos = v);
    if (error != null) {
      emit(AdminComisionesError(error!));
      return;
    }
    emit(AdminComisionesLoaded(
      liquidaciones: liquidaciones ?? const [],
      pagos: pagos ?? const [],
    ));
  }

  /// Carga el detalle (líneas) de una liquidación.
  Future<void> cargarDetalles(String liquidacionId) async {
    final current = state;
    if (current is! AdminComisionesLoaded) return;
    final result =
        await _getDetalles(GetLiquidacionDetallesParams(liquidacionId));
    result.fold(
      (l) => emit(AdminComisionesError(l.message)),
      (detalles) {
        final map = Map<String, List<DetalleLiquidacionEntity>>.from(
            current.detallesPorLiquidacion);
        map[liquidacionId] = detalles;
        emit(current.copyWith(detallesPorLiquidacion: map));
      },
    );
  }

  /// Cambia el estado de una liquidación (EN_REVISION/APROBADA/ANULADA).
  Future<String?> cambiarEstado(String liquidacionId, String nuevoEstado) async {
    final current = state;
    if (current is! AdminComisionesLoaded) return null;
    emit(current.copyWith(trabajando: true));
    final result = await _cambiarEstado(CambiarEstadoLiquidacionParams(
      liquidacionId: liquidacionId,
      nuevoEstado: nuevoEstado,
    ));
    final motivo = result.getOrElse((l) => l.message);
    emit(current.copyWith(trabajando: false));
    await load();
    return motivo;
  }

  /// Registra el pago externo (RPC admin) y recarga.
  Future<String?> registrarPago({
    required String liquidacionId,
    required String metodoPago,
    String? referenciaPago,
    List<int>? comprobanteBytes,
    String? comprobanteNombre,
    String? notas,
    double? montoPagado,
  }) async {
    final current = state;
    if (current is! AdminComisionesLoaded) return null;
    emit(current.copyWith(trabajando: true));
    try {
      String? comprobanteUrl;
      if (comprobanteBytes != null && comprobanteNombre != null) {
        final subida = await _subirComprobante(SubirComprobantePagoParams(
          liquidacionId: liquidacionId,
          bytes: comprobanteBytes,
          nombreArchivo: comprobanteNombre,
        ));
        final path = subida.fold((l) => null, (path) => path);
        if (path == null) {
          emit(current.copyWith(trabajando: false));
          return subida.fold((l) => l.message, (_) => 'No se pudo subir el comprobante.');
        }
        comprobanteUrl = path;
      }
      final result = await _registrarPago(RegistrarPagoEspecialistaParams(
        liquidacionId: liquidacionId,
        metodoPago: metodoPago,
        referenciaPago: referenciaPago,
        comprobanteUrl: comprobanteUrl,
        notas: notas,
        montoPagado: montoPagado,
      ));
      final motivo = result.getOrElse((l) => l.message);
      emit(current.copyWith(trabajando: false));
      await load();
      return motivo;
    } catch (e) {
      emit(current.copyWith(trabajando: false));
      return 'Error: $e';
    }
  }
}