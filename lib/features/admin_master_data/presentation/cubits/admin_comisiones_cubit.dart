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
  const AdminComisionesLoaded({
    this.liquidaciones = const [],
    this.pagos = const [],
  });
  @override
  List<Object?> get props => [liquidaciones, pagos];
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

  AdminComisionesCubit({
    required GetLiquidaciones getLiquidaciones,
    required GetPagosEspecialistas getPagos,
  })  : _getLiquidaciones = getLiquidaciones,
        _getPagos = getPagos,
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
}
