import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// Los usecases se inyectan por nombre; esta regla no aplica aquí.
// ignore_for_file: prefer_initializing_formals

import '../../domain/entities/expediente_salud_entity.dart';
import '../../domain/usecases/get_expediente_salud.dart';
import '../../domain/usecases/registrar_auditoria_expediente.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ESTADOS
// ─────────────────────────────────────────────────────────────────────────────

abstract class ExpedienteSaludState extends Equatable {
  const ExpedienteSaludState();
  @override
  List<Object?> get props => [];
}

class ExpedienteSaludInitial extends ExpedienteSaludState {
  const ExpedienteSaludInitial();
}

class ExpedienteSaludLoading extends ExpedienteSaludState {
  const ExpedienteSaludLoading();
}

class ExpedienteSaludLoaded extends ExpedienteSaludState {
  final ExpedienteSaludEntity expediente;
  const ExpedienteSaludLoaded(this.expediente);
  @override
  List<Object?> get props => [expediente];
}

class ExpedienteSaludError extends ExpedienteSaludState {
  final String message;
  const ExpedienteSaludError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─────────────────────────────────────────────────────────────────────────────
// CUBIT
// ─────────────────────────────────────────────────────────────────────────────

class ExpedienteSaludCubit extends Cubit<ExpedienteSaludState> {
  final GetExpedienteSalud _getExpedienteSalud;
  final RegistrarAuditoriaExpediente _registrarAuditoriaExpediente;

  ExpedienteSaludCubit({
    required GetExpedienteSalud getExpedienteSalud,
    required RegistrarAuditoriaExpediente registrarAuditoriaExpediente,
  })  : _getExpedienteSalud = getExpedienteSalud,
        _registrarAuditoriaExpediente = registrarAuditoriaExpediente,
        super(const ExpedienteSaludInitial());

  /// Carga el expediente de salud completo de un paciente por `usuarioId`.
  Future<void> cargarExpediente(String usuarioId) async {
    emit(const ExpedienteSaludLoading());
    final result = await _getExpedienteSalud(
      GetExpedienteSaludParams(usuarioId: usuarioId),
    );
    result.fold(
      (failure) => emit(ExpedienteSaludError(failure.message)),
      (expediente) => expediente == null
          ? emit(const ExpedienteSaludError(
              'No se encontró el expediente de salud del paciente.'))
          : emit(ExpedienteSaludLoaded(expediente)),
    );
  }

  /// Registra en auditoría el acceso/exportación (fire-and-forget, no bloquea UI).
  Future<void> auditar(String accion) async {
    final current = state;
    if (current is! ExpedienteSaludLoaded) return;
    await _registrarAuditoriaExpediente(
      RegistrarAuditoriaExpedienteParams(
        pacienteId: current.expediente.paciente.id,
        accion: accion,
      ),
    );
  }
}