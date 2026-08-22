import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Los usecases se inyectan por nombre; esta regla no aplica aquí.
// ignore_for_file: prefer_initializing_formals

import '../../domain/entities/rol_entity.dart';
import '../../domain/usecases/roles_usecases.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ESTADOS
// ─────────────────────────────────────────────────────────────────────────────

abstract class AdminRolesState extends Equatable {
  const AdminRolesState();
  @override
  List<Object?> get props => [];
}

class AdminRolesInitial extends AdminRolesState {
  const AdminRolesInitial();
}

class AdminRolesLoading extends AdminRolesState {
  const AdminRolesLoading();
}

class AdminRolesLoaded extends AdminRolesState {
  final List<RolEntity> roles;
  final List<PermisoEntity> permisos;
  const AdminRolesLoaded({this.roles = const [], this.permisos = const []});
  @override
  List<Object?> get props => [roles, permisos];
}

class AdminRolesError extends AdminRolesState {
  final String message;
  const AdminRolesError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─────────────────────────────────────────────────────────────────────────────
// CUBIT
// ─────────────────────────────────────────────────────────────────────────────

class AdminRolesCubit extends Cubit<AdminRolesState> {
  final GetRoles _getRoles;
  final GetPermisos _getPermisos;
  final GuardarRol _guardarRol;
  final SetRolActivo _setRolActivo;
  final AsignarPermisoRol _asignarPermiso;
  final QuitarPermisoRol _quitarPermiso;

  AdminRolesCubit({
    required GetRoles getRoles,
    required GetPermisos getPermisos,
    required GuardarRol guardarRol,
    required SetRolActivo setRolActivo,
    required AsignarPermisoRol asignarPermiso,
    required QuitarPermisoRol quitarPermiso,
  })  : _getRoles = getRoles,
        _getPermisos = getPermisos,
        _guardarRol = guardarRol,
        _setRolActivo = setRolActivo,
        _asignarPermiso = asignarPermiso,
        _quitarPermiso = quitarPermiso,
        super(const AdminRolesInitial());

  Future<void> load() async {
    emit(const AdminRolesLoading());
    List<RolEntity>? roles;
    List<PermisoEntity>? permisos;
    String? error;
    final r1 = await _getRoles();
    final r2 = await _getPermisos();
    r1.fold((f) => error ??= f.message, (v) => roles = v);
    r2.fold((f) => error ??= f.message, (v) => permisos = v);
    if (error != null) {
      emit(AdminRolesError(error!));
      return;
    }
    emit(AdminRolesLoaded(
        roles: roles ?? const [], permisos: permisos ?? const []));
  }

  Future<bool> guardarRol({
    int? id,
    required String nombre,
    String? descripcion,
    String? codigo,
    bool activo = true,
  }) async {
    final result = await _guardarRol(GuardarRolParams(
      id: id,
      nombre: nombre,
      descripcion: descripcion,
      codigo: codigo,
      activo: activo,
    ));
    var ok = false;
    result.fold((f) => emit(AdminRolesError(f.message)), (_) => ok = true);
    if (ok) await load();
    return ok;
  }

  Future<bool> setActivo(int id, bool activo) async {
    final result = await _setRolActivo(SetRolActivoParams(id, activo));
    var ok = false;
    result.fold((f) => emit(AdminRolesError(f.message)), (_) => ok = true);
    if (ok) await load();
    return ok;
  }

  Future<bool> asignarPermiso(int rolId, int permisoId) async {
    final result = await _asignarPermiso(AsignarPermisoRolParams(rolId, permisoId));
    var ok = false;
    result.fold((f) => emit(AdminRolesError(f.message)), (_) => ok = true);
    if (ok) await load();
    return ok;
  }

  Future<bool> quitarPermiso(int rolId, int permisoId) async {
    final result = await _quitarPermiso(QuitarPermisoRolParams(rolId, permisoId));
    var ok = false;
    result.fold((f) => emit(AdminRolesError(f.message)), (_) => ok = true);
    if (ok) await load();
    return ok;
  }
}
