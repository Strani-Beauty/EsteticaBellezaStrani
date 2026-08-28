// Los usecases se inyectan por nombre.
// ignore_for_file: prefer_initializing_formals

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../domain/entities/comision_entity.dart';
import '../../domain/entities/detalle_financiero_entity.dart';
import '../../domain/entities/transaccion_entity.dart';
import '../../domain/usecases/generar_liquidaciones.dart';
import '../../domain/usecases/get_comisiones_admin.dart';
import '../../domain/usecases/get_detalle_financiero_cita.dart';
import '../../domain/usecases/get_transacciones_admin.dart';

abstract class AdminConciliacionState {
  const AdminConciliacionState();
}

class AdminConciliacionInitial extends AdminConciliacionState {
  const AdminConciliacionInitial();
}

class AdminConciliacionLoading extends AdminConciliacionState {
  const AdminConciliacionLoading();
}

class AdminConciliacionLoaded extends AdminConciliacionState {
  final List<TransaccionEntity> transacciones;
  final List<ComisionEntity> comisiones;
  final DetalleFinancieroCitaEntity? detalle;
  final bool generandoLiquidacion;

  const AdminConciliacionLoaded({
    this.transacciones = const [],
    this.comisiones = const [],
    this.detalle,
    this.generandoLiquidacion = false,
  });

  AdminConciliacionLoaded copyWith({
    List<TransaccionEntity>? transacciones,
    List<ComisionEntity>? comisiones,
    DetalleFinancieroCitaEntity? detalle,
    bool? generandoLiquidacion,
  }) {
    return AdminConciliacionLoaded(
      transacciones: transacciones ?? this.transacciones,
      comisiones: comisiones ?? this.comisiones,
      detalle: detalle ?? this.detalle,
      generandoLiquidacion: generandoLiquidacion ?? this.generandoLiquidacion,
    );
  }
}

class AdminConciliacionError extends AdminConciliacionState {
  final String message;
  const AdminConciliacionError(this.message);
}

/// Cubit de la vista admin de conciliación de pagos/transacciones con Stripe.
class AdminConciliacionCubit extends Cubit<AdminConciliacionState> {
  final GetTransaccionesAdmin _getTransacciones;
  final GetComisionesAdmin _getComisiones;
  final GetDetalleFinancieroCita _getDetalle;
  final GenerarLiquidaciones _generarLiquidaciones;

  AdminConciliacionCubit({
    required GetTransaccionesAdmin getTransacciones,
    required GetComisionesAdmin getComisiones,
    required GetDetalleFinancieroCita getDetalle,
    required GenerarLiquidaciones generarLiquidaciones,
  })  : _getTransacciones = getTransacciones,
        _getComisiones = getComisiones,
        _getDetalle = getDetalle,
        _generarLiquidaciones = generarLiquidaciones,
        super(const AdminConciliacionInitial());

  Future<void> load() async {
    emit(const AdminConciliacionLoading());
    final results = await Future.wait([
      _getTransacciones(const GetTransaccionesAdminParams()),
      _getComisiones(),
    ]);
    final txEither = results[0] as Either<Failure, List<TransaccionEntity>>;
    final comEither =
        results[1] as Either<Failure, List<ComisionEntity>>;

    final tx = txEither.getOrElse((l) => <TransaccionEntity>[]);
    final com = comEither.getOrElse((l) => <ComisionEntity>[]);

    if (state is AdminConciliacionError &&
        txEither.isLeft() &&
        comEither.isLeft()) {
      emit(AdminConciliacionError(
          txEither.fold((l) => l.message, (_) => '')));
      return;
    }
    emit(AdminConciliacionLoaded(
      transacciones: tx,
      comisiones: com,
    ));
  }

  Future<void> consultarDetalle(String citaId) async {
    final current = state;
    if (current is! AdminConciliacionLoaded) return;
    emit(current.copyWith(detalle: null));
    final result =
        await _getDetalle(GetDetalleFinancieroCitaParams(citaId: citaId));
    result.fold(
      (l) => emit(AdminConciliacionError(l.message)),
      (detalle) => emit(current.copyWith(detalle: detalle)),
    );
  }

  Future<String?> generarLiquidaciones({
    required DateTime fechaInicio,
    required DateTime fechaFin,
  }) async {
    final current = state;
    if (current is! AdminConciliacionLoaded) return null;
    emit(current.copyWith(generandoLiquidacion: true));
    final result = await _generarLiquidaciones(GenerarLiquidacionesParams(
      fechaInicio: fechaInicio,
      fechaFin: fechaFin,
    ));
    final resp = result.getOrElse(
        (l) => GenerarLiquidacionesEntity(ok: false, motivo: l.message));
    emit(current.copyWith(generandoLiquidacion: false));
    return resp.ok
        ? 'Liquidación generada: ${resp.especialistas} especialista(s), '
            '${resp.citas} cita(s), \$${resp.montoPagar.toStringAsFixed(2)} a pagar.'
        : resp.motivo;
  }
}