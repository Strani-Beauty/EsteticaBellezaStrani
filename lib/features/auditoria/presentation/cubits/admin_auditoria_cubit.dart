import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Los usecases se inyectan por nombre; esta regla no aplica aquí.
// ignore_for_file: prefer_initializing_formals

import '../../domain/entities/auditoria_entity.dart';
import '../../domain/repositories/i_auditoria_repository.dart';
import '../../domain/usecases/get_auditoria.dart';

// ── Estados ────────────────────────────────────────────────────────────────

abstract class AdminAuditoriaState extends Equatable {
  const AdminAuditoriaState();

  @override
  List<Object?> get props => [];
}

class AdminAuditoriaInitial extends AdminAuditoriaState {
  const AdminAuditoriaInitial();
}

class AdminAuditoriaLoading extends AdminAuditoriaState {
  const AdminAuditoriaLoading();
}

class AdminAuditoriaLoaded extends AdminAuditoriaState {
  final List<AuditoriaEntity> registros;
  final AuditoriaFiltros filtros;
  const AdminAuditoriaLoaded(this.registros, this.filtros);

  @override
  List<Object?> get props => [registros, filtros];
}

class AdminAuditoriaError extends AdminAuditoriaState {
  final String message;
  const AdminAuditoriaError(this.message);

  @override
  List<Object?> get props => [message];
}

// ── Cubit ──────────────────────────────────────────────────────────────────

class AdminAuditoriaCubit extends Cubit<AdminAuditoriaState> {
  final GetAuditoria _getAuditoria;

  AdminAuditoriaCubit({required GetAuditoria getAuditoria})
      : _getAuditoria = getAuditoria,
        super(const AdminAuditoriaInitial());

  Future<void> load([AuditoriaFiltros? filtros]) async {
    emit(const AdminAuditoriaLoading());
    final result = await _getAuditoria(filtros ?? const AuditoriaFiltros());
    result.fold(
      (failure) => emit(AdminAuditoriaError(failure.message)),
      (registros) => emit(AdminAuditoriaLoaded(
        registros,
        filtros ?? const AuditoriaFiltros(),
      )),
    );
  }
}