import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Los usecases se inyectan por nombre; esta regla no aplica aquí.
// ignore_for_file: prefer_initializing_formals

import '../../domain/entities/seguimiento_solicitud_entity.dart';
import '../../domain/usecases/get_mis_solicitudes.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ESTADOS
// ─────────────────────────────────────────────────────────────────────────────

abstract class MisSolicitudesState extends Equatable {
  const MisSolicitudesState();
  @override
  List<Object?> get props => [];
}

class MisSolicitudesInitial extends MisSolicitudesState {
  const MisSolicitudesInitial();
}

class MisSolicitudesLoading extends MisSolicitudesState {
  const MisSolicitudesLoading();
}

class MisSolicitudesLoaded extends MisSolicitudesState {
  final List<SeguimientoSolicitudEntity> solicitudes;
  const MisSolicitudesLoaded(this.solicitudes);
  @override
  List<Object?> get props => [solicitudes];
}

class MisSolicitudesError extends MisSolicitudesState {
  final String message;
  const MisSolicitudesError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─────────────────────────────────────────────────────────────────────────────
// CUBIT
// ─────────────────────────────────────────────────────────────────────────────

class MisSolicitudesCubit extends Cubit<MisSolicitudesState> {
  final GetMisSolicitudes _getMisSolicitudes;

  MisSolicitudesCubit({required GetMisSolicitudes getMisSolicitudes})
      : _getMisSolicitudes = getMisSolicitudes,
        super(const MisSolicitudesInitial());

  Future<void> load(String profileId) async {
    emit(const MisSolicitudesLoading());
    final result = await _getMisSolicitudes(profileId);
    result.fold(
      (f) => emit(MisSolicitudesError(f.message)),
      (solicitudes) => emit(MisSolicitudesLoaded(solicitudes)),
    );
  }
}
