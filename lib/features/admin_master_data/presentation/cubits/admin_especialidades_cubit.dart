import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Los usecases se inyectan por nombre; esta regla no aplica aquí.
// ignore_for_file: prefer_initializing_formals

import '../../domain/entities/especialidad_admin_entity.dart';
import '../../domain/usecases/especialidades_usecases.dart';

abstract class AdminEspecialidadesState extends Equatable {
  const AdminEspecialidadesState();
  @override
  List<Object?> get props => [];
}

class AdminEspecialidadesInitial extends AdminEspecialidadesState {
  const AdminEspecialidadesInitial();
}

class AdminEspecialidadesLoading extends AdminEspecialidadesState {
  const AdminEspecialidadesLoading();
}

class AdminEspecialidadesLoaded extends AdminEspecialidadesState {
  final List<EspecialidadAdminEntity> items;
  const AdminEspecialidadesLoaded(this.items);
  @override
  List<Object?> get props => [items];
}

class AdminEspecialidadesError extends AdminEspecialidadesState {
  final String message;
  const AdminEspecialidadesError(this.message);
  @override
  List<Object?> get props => [message];
}

class AdminEspecialidadesCubit extends Cubit<AdminEspecialidadesState> {
  final GetEspecialidadesAdmin _getEspecialidades;
  final GuardarEspecialidad _guardarEspecialidad;
  final SetEspecialidadActivo _setActivo;

  AdminEspecialidadesCubit({
    required GetEspecialidadesAdmin getEspecialidades,
    required GuardarEspecialidad guardarEspecialidad,
    required SetEspecialidadActivo setActivo,
  })  : _getEspecialidades = getEspecialidades,
        _guardarEspecialidad = guardarEspecialidad,
        _setActivo = setActivo,
        super(const AdminEspecialidadesInitial());

  Future<void> load() async {
    emit(const AdminEspecialidadesLoading());
    final result = await _getEspecialidades();
    result.fold(
      (f) => emit(AdminEspecialidadesError(f.message)),
      (items) => emit(AdminEspecialidadesLoaded(items)),
    );
  }

  Future<bool> guardar({
    int? id,
    required String nombre,
    String? descripcion,
    bool activo = true,
  }) async {
    final result = await _guardarEspecialidad(GuardarEspecialidadParams(
      id: id,
      nombre: nombre,
      descripcion: descripcion,
      activo: activo,
    ));
    var ok = false;
    result.fold((f) => emit(AdminEspecialidadesError(f.message)), (_) => ok = true);
    if (ok) await load();
    return ok;
  }

  Future<bool> setActivo(int id, bool activo) async {
    final result = await _setActivo(SetEspecialidadActivoParams(id, activo));
    var ok = false;
    result.fold((f) => emit(AdminEspecialidadesError(f.message)), (_) => ok = true);
    if (ok) await load();
    return ok;
  }
}
