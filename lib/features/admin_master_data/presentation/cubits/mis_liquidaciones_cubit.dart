// ignore_for_file: prefer_initializing_formals

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/financiero_entity.dart';
import '../../domain/usecases/financiero_usecases.dart';

abstract class MisLiquidacionesState extends Equatable {
  const MisLiquidacionesState();
  @override
  List<Object?> get props => [];
}

class MisLiquidacionesInitial extends MisLiquidacionesState {
  const MisLiquidacionesInitial();
}

class MisLiquidacionesLoading extends MisLiquidacionesState {
  const MisLiquidacionesLoading();
}

class MisLiquidacionesLoaded extends MisLiquidacionesState {
  final List<LiquidacionEntity> liquidaciones;
  final List<PagoEspecialistaEntity> pagos;
  const MisLiquidacionesLoaded({
    this.liquidaciones = const [],
    this.pagos = const [],
  });

  MisLiquidacionesLoaded copyWith({
    List<LiquidacionEntity>? liquidaciones,
    List<PagoEspecialistaEntity>? pagos,
  }) {
    return MisLiquidacionesLoaded(
      liquidaciones: liquidaciones ?? this.liquidaciones,
      pagos: pagos ?? this.pagos,
    );
  }

  @override
  List<Object?> get props => [liquidaciones, pagos];
}

class MisLiquidacionesError extends MisLiquidacionesState {
  final String message;
  const MisLiquidacionesError(this.message);
  @override
  List<Object?> get props => [message];
}

class MisLiquidacionesCubit extends Cubit<MisLiquidacionesState> {
  final GetMisLiquidaciones _getLiquidaciones;
  final GetMisPagosEspecialistas _getPagos;
  final FirmarComprobante _firmarComprobante;

  MisLiquidacionesCubit({
    required GetMisLiquidaciones getLiquidaciones,
    required GetMisPagosEspecialistas getPagos,
    required FirmarComprobante firmarComprobante,
  })  : _getLiquidaciones = getLiquidaciones,
        _getPagos = getPagos,
        _firmarComprobante = firmarComprobante,
        super(const MisLiquidacionesInitial());

  Future<void> load(String especialistaId) async {
    emit(const MisLiquidacionesLoading());
    List<LiquidacionEntity>? liquidaciones;
    List<PagoEspecialistaEntity>? pagos;
    String? error;
    final r1 = await _getLiquidaciones(GetMisLiquidacionesParams(especialistaId));
    final r2 = await _getPagos(GetMisPagosEspecialistasParams(especialistaId));
    r1.fold((f) => error ??= f.message, (v) => liquidaciones = v);
    r2.fold((f) => error ??= f.message, (v) => pagos = v);
    if (error != null) {
      emit(MisLiquidacionesError(error!));
      return;
    }
    emit(MisLiquidacionesLoaded(
      liquidaciones: liquidaciones ?? const [],
      pagos: pagos ?? const [],
    ));
  }

  /// Firma el comprobante de un pago para poder visualizarlo.
  Future<String?> firmarComprobante(String path) async {
    final result = await _firmarComprobante(FirmarComprobanteParams(path: path));
    return result.fold((l) => null, (url) => url);
  }
}