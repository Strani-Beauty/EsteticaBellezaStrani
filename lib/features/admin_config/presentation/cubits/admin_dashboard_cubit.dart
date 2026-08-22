import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Los usecases se inyectan por nombre; esta regla no aplica aquí.
// ignore_for_file: prefer_initializing_formals

import '../../domain/entities/admin_kpis_entity.dart';
import '../../domain/usecases/get_admin_kpis.dart';

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
  const AdminDashboardLoaded(this.kpis);
  @override
  List<Object?> get props => [kpis];
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

  AdminDashboardCubit({required GetAdminKpis getKpis})
      : _getKpis = getKpis,
        super(const AdminDashboardInitial());

  Future<void> load() async {
    emit(const AdminDashboardLoading());
    final result = await _getKpis();
    result.fold(
      (f) => emit(AdminDashboardError(f.message)),
      (kpis) => emit(AdminDashboardLoaded(kpis)),
    );
  }
}
