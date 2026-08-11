import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/usuario_admin_entity.dart';
import '../../domain/usecases/get_usuarios.dart';
import '../../domain/usecases/set_usuario_activo.dart';

// ── Estados ────────────────────────────────────────────────────────────────

abstract class AdminUsersState extends Equatable {
  const AdminUsersState();

  @override
  List<Object?> get props => [];
}

class AdminUsersInitial extends AdminUsersState {
  const AdminUsersInitial();
}

class AdminUsersLoading extends AdminUsersState {
  const AdminUsersLoading();
}

class AdminUsersLoaded extends AdminUsersState {
  final List<UsuarioAdminEntity> usuarios;
  const AdminUsersLoaded(this.usuarios);

  @override
  List<Object?> get props => [usuarios];
}

class AdminUsersError extends AdminUsersState {
  final String message;
  const AdminUsersError(this.message);

  @override
  List<Object?> get props => [message];
}

// ── Cubit ──────────────────────────────────────────────────────────────────

class AdminUsersCubit extends Cubit<AdminUsersState> {
  final GetUsuarios _getUsuarios;
  final SetUsuarioActivo _setUsuarioActivo;

  AdminUsersCubit(this._getUsuarios, this._setUsuarioActivo)
      : super(const AdminUsersInitial());

  Future<void> loadUsuarios() async {
    emit(const AdminUsersLoading());
    final result = await _getUsuarios();
    result.fold(
      (failure) => emit(AdminUsersError(failure.message)),
      (usuarios) => emit(AdminUsersLoaded(usuarios)),
    );
  }

  Future<void> setActivo(String userId, bool activo) async {
    final result = await _setUsuarioActivo(userId, activo);
    result.fold(
      (failure) => emit(AdminUsersError(failure.message)),
      (_) => loadUsuarios(),
    );
  }
}