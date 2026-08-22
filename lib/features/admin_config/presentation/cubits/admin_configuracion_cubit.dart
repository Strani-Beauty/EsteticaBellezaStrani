import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Los usecases se inyectan por nombre; esta regla no aplica aquí.
// ignore_for_file: prefer_initializing_formals

import '../../domain/entities/config_sistema_entity.dart';
import '../../domain/usecases/get_config_sistema.dart';
import '../../domain/usecases/update_config_sistema.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ESTADOS
// ─────────────────────────────────────────────────────────────────────────────

abstract class AdminConfiguracionState extends Equatable {
  const AdminConfiguracionState();
  @override
  List<Object?> get props => [];
}

class AdminConfiguracionInitial extends AdminConfiguracionState {
  const AdminConfiguracionInitial();
}

class AdminConfiguracionLoading extends AdminConfiguracionState {
  const AdminConfiguracionLoading();
}

class AdminConfiguracionLoaded extends AdminConfiguracionState {
  final List<ConfigSistemaEntity> items;
  const AdminConfiguracionLoaded(this.items);
  @override
  List<Object?> get props => [items];
}

class AdminConfiguracionError extends AdminConfiguracionState {
  final String message;
  const AdminConfiguracionError(this.message);
  @override
  List<Object?> get props => [message];
}

/// Feedback de guardado (consumido por la UI como snackbar).
class AdminConfiguracionSaved extends AdminConfiguracionState {
  final String message;
  const AdminConfiguracionSaved(this.message);
  @override
  List<Object?> get props => [message];
}

// ─────────────────────────────────────────────────────────────────────────────
// CUBIT
// ─────────────────────────────────────────────────────────────────────────────

class AdminConfiguracionCubit extends Cubit<AdminConfiguracionState> {
  final GetConfigSistema _getConfiguracion;
  final UpdateConfigSistema _updateConfiguracion;

  AdminConfiguracionCubit({
    required GetConfigSistema getConfiguracion,
    required UpdateConfigSistema updateConfiguracion,
  })  : _getConfiguracion = getConfiguracion,
        _updateConfiguracion = updateConfiguracion,
        super(const AdminConfiguracionInitial());

  Future<void> load() async {
    emit(const AdminConfiguracionLoading());
    final result = await _getConfiguracion();
    result.fold(
      (f) => emit(AdminConfiguracionError(f.message)),
      (items) => emit(AdminConfiguracionLoaded(items)),
    );
  }

  Future<bool> update(String clave, String valor) async {
    final result = await _updateConfiguracion(
        UpdateConfigSistemaParams(clave: clave, valor: valor));
    var ok = false;
    result.fold(
      (f) => emit(AdminConfiguracionError(f.message)),
      (_) {
        ok = true;
        emit(AdminConfiguracionSaved('Clave "$clave" actualizada.'));
      },
    );
    return ok;
  }

  void clearSaved() {
    if (state is AdminConfiguracionSaved) {
      emit(const AdminConfiguracionInitial());
    }
  }
}
