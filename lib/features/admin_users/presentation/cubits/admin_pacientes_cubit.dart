import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/paciente_admin_entity.dart';
import '../../domain/usecases/get_pacientes.dart';
import '../../domain/usecases/set_usuario_activo.dart';

// ── Estados ────────────────────────────────────────────────────────────────

abstract class AdminPacientesState extends Equatable {
  const AdminPacientesState();

  @override
  List<Object?> get props => [];
}

class AdminPacientesInitial extends AdminPacientesState {
  const AdminPacientesInitial();
}

class AdminPacientesLoading extends AdminPacientesState {
  const AdminPacientesLoading();
}

class AdminPacientesLoaded extends AdminPacientesState {
  final List<PacienteAdminEntity> pacientes;
  const AdminPacientesLoaded(this.pacientes);

  @override
  List<Object?> get props => [pacientes];
}

class AdminPacientesError extends AdminPacientesState {
  final String message;
  const AdminPacientesError(this.message);

  @override
  List<Object?> get props => [message];
}

// ── Cubit ──────────────────────────────────────────────────────────────────

class AdminPacientesCubit extends Cubit<AdminPacientesState> {
  final GetPacientes _getPacientes;
  final SetUsuarioActivo _setUsuarioActivo;

  AdminPacientesCubit(this._getPacientes, this._setUsuarioActivo)
      : super(const AdminPacientesInitial());

  Future<void> loadPacientes() async {
    emit(const AdminPacientesLoading());
    final result = await _getPacientes();
    result.fold(
      (failure) => emit(AdminPacientesError(failure.message)),
      (pacientes) => emit(AdminPacientesLoaded(pacientes)),
    );
  }

  Future<void> setActivo(String userId, bool activo) async {
    final result = await _setUsuarioActivo(userId, activo);
    result.fold(
      (failure) => emit(AdminPacientesError(failure.message)),
      (_) => loadPacientes(),
    );
  }
}