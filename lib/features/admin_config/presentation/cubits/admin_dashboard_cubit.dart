import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Los usecases se inyectan por nombre; esta regla no aplica aquí.
// ignore_for_file: prefer_initializing_formals

import '../../domain/entities/admin_kpis_entity.dart';
import '../../domain/usecases/get_admin_kpis.dart';
import '../../domain/usecases/get_mis_permisos.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ESTADOS
// ─────────────────────────────────────────────────────────────────────────────

abstract class AdminDashboardState extends Equatable {
  const AdminDashboardState();
  @override
  List<Object?> get props => [];
}

class AdminDashboardInitial extends AdminDashboardState {
  const AdminDashboardInitial();
}

class AdminDashboardLoading extends AdminDashboardState {
  const AdminDashboardLoading();
}

class AdminDashboardLoaded extends AdminDashboardState {
  final AdminKpisEntity kpis;
  final Set<String> permisos;
  const AdminDashboardLoaded(this.kpis, this.permisos);
  @override
  List<Object?> get props => [kpis, permisos];
}

class AdminDashboardError extends AdminDashboardState {
  final String message;
  const AdminDashboardError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─────────────────────────────────────────────────────────────────────────────
// CUBIT
// ─────────────────────────────────────────────────────────────────────────────

class AdminDashboardCubit extends Cubit<AdminDashboardState> {
  final GetAdminKpis _getKpis;
  final GetMisPermisos _getMisPermisos;

  AdminDashboardCubit({
    required GetAdminKpis getKpis,
    required GetMisPermisos getMisPermisos,
  })  : _getKpis = getKpis,
        _getMisPermisos = getMisPermisos,
        super(const AdminDashboardInitial());

  Future<void> load() async {
    emit(const AdminDashboardLoading());
    String? error;
    AdminKpisEntity? kpis;
    List<String>? permisos;

    final r1 = await _getKpis();
    r1.fold((f) => error ??= f.message, (v) => kpis = v);

    final r2 = await _getMisPermisos();
    r2.fold((f) => error ??= f.message, (v) => permisos = v);

    if (error != null) {
      emit(AdminDashboardError(error!));
      return;
    }
    emit(AdminDashboardLoaded(kpis!, (permisos ?? const []).toSet()));
  }
}
