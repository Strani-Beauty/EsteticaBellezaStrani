// ignore_for_file: prefer_initializing_formals

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import '../../domain/entities/ventas_entities.dart';
import '../../domain/usecases/get_resumen_ventas.dart';
import '../../domain/usecases/get_serie_ventas.dart';
import '../../domain/usecases/get_ventas_por_especialista.dart';
import '../../domain/usecases/get_ventas_por_servicio.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ESTADOS
// ─────────────────────────────────────────────────────────────────────────────

abstract class ReportsState extends Equatable {
  const ReportsState();

  @override
  List<Object?> get props => [];
}

class ReportsInitial extends ReportsState {
  const ReportsInitial();
}

class ReportsLoading extends ReportsState {
  const ReportsLoading();
}

class ReportsLoaded extends ReportsState {
  final ResumenVentasEntity resumen;
  final List<VentaPorServicioEntity> porServicio;
  final List<VentaPorEspecialistaEntity> porEspecialista;
  final List<PuntoSerieVentasEntity> serie;
  final DateTime desde;
  final DateTime hasta;
  final String agrupacion;

  const ReportsLoaded({
    this.resumen = const ResumenVentasEntity(),
    this.porServicio = const [],
    this.porEspecialista = const [],
    this.serie = const [],
    required this.desde,
    required this.hasta,
    this.agrupacion = 'day',
  });

  ReportsLoaded copyWith({
    ResumenVentasEntity? resumen,
    List<VentaPorServicioEntity>? porServicio,
    List<VentaPorEspecialistaEntity>? porEspecialista,
    List<PuntoSerieVentasEntity>? serie,
    String? agrupacion,
  }) {
    return ReportsLoaded(
      resumen: resumen ?? this.resumen,
      porServicio: porServicio ?? this.porServicio,
      porEspecialista: porEspecialista ?? this.porEspecialista,
      serie: serie ?? this.serie,
      desde: desde,
      hasta: hasta,
      agrupacion: agrupacion ?? this.agrupacion,
    );
  }

  @override
  List<Object?> get props =>
      [resumen, porServicio, porEspecialista, serie, desde, hasta, agrupacion];
}

class ReportsError extends ReportsState {
  final String message;
  const ReportsError(this.message);

  @override
  List<Object?> get props => [message];
}

// ─────────────────────────────────────────────────────────────────────────────
// CUBIT
// ─────────────────────────────────────────────────────────────────────────────

class ReportsDashboardCubit extends Cubit<ReportsState> {
  final GetResumenVentas _getResumen;
  final GetVentasPorServicio _getPorServicio;
  final GetVentasPorEspecialista _getPorEspecialista;
  final GetSerieVentas _getSerie;

  ReportsDashboardCubit({
    required GetResumenVentas getResumen,
    required GetVentasPorServicio getPorServicio,
    required GetVentasPorEspecialista getPorEspecialista,
    required GetSerieVentas getSerie,
  })  : _getResumen = getResumen,
        _getPorServicio = getPorServicio,
        _getPorEspecialista = getPorEspecialista,
        _getSerie = getSerie,
        super(const ReportsInitial());

  @override
  void emit(ReportsState state) {
    if (isClosed) return;
    super.emit(state);
  }

  /// Carga el dashboard para el período indicado (default: último mes).
  Future<void> load({DateTime? desde, DateTime? hasta}) async {
    final now = DateTime.now();
    final desdeFinal =
        desde ?? DateTime(now.year, now.month - 1, now.day, now.hour);
    final hastaFinal = hasta ?? now;

    final previous = state;
    final agrupacion =
        previous is ReportsLoaded ? previous.agrupacion : 'day';

    emit(const ReportsLoading());

    final resumen = await _getResumen(
        GetResumenVentasParams(desde: desdeFinal, hasta: hastaFinal));
    final porServicio = await _getPorServicio(
        GetVentasPorServicioParams(desde: desdeFinal, hasta: hastaFinal));
    final porEspecialista = await _getPorEspecialista(
        GetVentasPorEspecialistaParams(desde: desdeFinal, hasta: hastaFinal));
    final serie = await _getSerie(GetSerieVentasParams(
        desde: desdeFinal, hasta: hastaFinal, agrupacion: agrupacion));

    final errores = <Failure>[
      if (resumen.isLeft()) resumen.getLeft().toNullable() ?? const ServerFailure(''),
      if (porServicio.isLeft()) porServicio.getLeft().toNullable() ?? const ServerFailure(''),
      if (porEspecialista.isLeft()) porEspecialista.getLeft().toNullable() ?? const ServerFailure(''),
      if (serie.isLeft()) serie.getLeft().toNullable() ?? const ServerFailure(''),
    ];

    if (errores.isNotEmpty) {
      emit(ReportsError(errores.first.message));
      return;
    }

    emit(ReportsLoaded(
      resumen: resumen.getRight().toNullable() ?? const ResumenVentasEntity(),
      porServicio: porServicio.getRight().toNullable() ?? const [],
      porEspecialista: porEspecialista.getRight().toNullable() ?? const [],
      serie: serie.getRight().toNullable() ?? const [],
      desde: desdeFinal,
      hasta: hastaFinal,
      agrupacion: agrupacion,
    ));
  }

  /// Cambia la agrupación de la serie (day/week/month) y recarga la serie.
  Future<void> cambiarAgrupacion(String agrupacion) async {
    final current = state;
    if (current is! ReportsLoaded || current.agrupacion == agrupacion) return;

    emit(current.copyWith(agrupacion: agrupacion));

    final serie = await _getSerie(GetSerieVentasParams(
      desde: current.desde,
      hasta: current.hasta,
      agrupacion: agrupacion,
    ));

    final value = serie.getRight().toNullable();
    if (value == null) return;
    if (state is! ReportsLoaded) return;
    emit((state as ReportsLoaded).copyWith(serie: value));
  }
}