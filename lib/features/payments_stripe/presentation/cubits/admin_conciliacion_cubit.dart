// Los usecases se inyectan por nombre.
// ignore_for_file: prefer_initializing_formals

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../admin_master_data/domain/entities/financiero_entity.dart';
import '../../../admin_master_data/domain/usecases/financiero_usecases.dart';
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
  final List<CitaFinalizadaAdminEntity> citasFinalizadas;
  final int inicioSemana;
  final bool cargandoCitas;

  const AdminConciliacionLoaded({
    this.transacciones = const [],
    this.comisiones = const [],
    this.detalle,
    this.generandoLiquidacion = false,
    this.citasFinalizadas = const [],
    this.inicioSemana = 1,
    this.cargandoCitas = false,
  });

  AdminConciliacionLoaded copyWith({
    List<TransaccionEntity>? transacciones,
    List<ComisionEntity>? comisiones,
    DetalleFinancieroCitaEntity? detalle,
    bool? generandoLiquidacion,
    List<CitaFinalizadaAdminEntity>? citasFinalizadas,
    int? inicioSemana,
    bool? cargandoCitas,
  }) {
    return AdminConciliacionLoaded(
      transacciones: transacciones ?? this.transacciones,
      comisiones: comisiones ?? this.comisiones,
      detalle: detalle ?? this.detalle,
      generandoLiquidacion: generandoLiquidacion ?? this.generandoLiquidacion,
      citasFinalizadas: citasFinalizadas ?? this.citasFinalizadas,
      inicioSemana: inicioSemana ?? this.inicioSemana,
      cargandoCitas: cargandoCitas ?? this.cargandoCitas,
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
  final GetCitasFinalizadasAdmin _getCitasFinalizadas;
  final GetInicioSemanaLiquidacion _getInicioSemana;

  AdminConciliacionCubit({
    required GetTransaccionesAdmin getTransacciones,
    required GetComisionesAdmin getComisiones,
    required GetDetalleFinancieroCita getDetalle,
    required GenerarLiquidaciones generarLiquidaciones,
    required GetCitasFinalizadasAdmin getCitasFinalizadas,
    required GetInicioSemanaLiquidacion getInicioSemana,
  })  : _getTransacciones = getTransacciones,
        _getComisiones = getComisiones,
        _getDetalle = getDetalle,
        _generarLiquidaciones = generarLiquidaciones,
        _getCitasFinalizadas = getCitasFinalizadas,
        _getInicioSemana = getInicioSemana,
        super(const AdminConciliacionInitial());

  Future<void> load() async {
    emit(const AdminConciliacionLoading());
    final txEither =
        await _getTransacciones(const GetTransaccionesAdminParams());
    final comEither = await _getComisiones();
    final inicioSemana =
        (await _getInicioSemana()).getOrElse((l) => 1);

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
      inicioSemana: inicioSemana,
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

  /// Carga las citas terminadas (elegibles) del período seleccionado.
  Future<void> cargarCitasPorPeriodo({
    required DateTime desde,
    required DateTime hasta,
  }) async {
    final current = state;
    if (current is! AdminConciliacionLoaded) return;
    emit(current.copyWith(citasFinalizadas: const [], cargandoCitas: true));
    final result = await _getCitasFinalizadas(GetCitasFinalizadasAdminParams(
      desde: desde,
      hasta: hasta,
    ));
    result.fold(
      (l) => emit(current.copyWith(cargandoCitas: false)),
      (citas) => emit(
          current.copyWith(citasFinalizadas: citas, cargandoCitas: false)),
    );
  }

  /// Rango por defecto: última semana completa [lunes..domingo] según
  /// `inicioSemana` (1=Lunes ... 7=Domingo) de la configuración del sistema.
  ({DateTime desde, DateTime hasta}) rangoUltimaSemana(DateTime hoy) {
    final inicio = state is AdminConciliacionLoaded
        ? (state as AdminConciliacionLoaded).inicioSemana
        : 1;
    final inicioReal = (inicio >= 1 && inicio <= 7) ? inicio : 1;
    final iso = hoy.weekday; // 1=Lunes ... 7=Domingo
    final diff = (iso - inicioReal) % 7;
    final lunes = DateTime(hoy.year, hoy.month, hoy.day).subtract(
      Duration(days: diff + 7),
    );
    final domingo = lunes.add(const Duration(days: 6));
    return (desde: lunes, hasta: domingo);
  }
}