import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// Los usecases se inyectan por nombre; esta regla no aplica aquí.
// ignore_for_file: prefer_initializing_formals
import '../../domain/entities/especialista_mapa_entity.dart';
import '../../domain/entities/solicitud_pendiente_entity.dart';
import '../../domain/usecases/aceptar_solicitud.dart';
import '../../domain/usecases/get_especialistas_aprobados.dart';
import '../../domain/usecases/get_mi_ubicacion.dart';
import '../../domain/usecases/get_solicitudes_pendientes.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ESTADOS
// ─────────────────────────────────────────────────────────────────────────────

abstract class MarketplaceState extends Equatable {
  const MarketplaceState();
  @override
  List<Object?> get props => [];
}

class MarketplaceInitial extends MarketplaceState {
  const MarketplaceInitial();
}

class MarketplaceLoading extends MarketplaceState {
  const MarketplaceLoading();
}

class MarketplaceLoaded extends MarketplaceState {
  final List<SolicitudPendienteEntity> solicitudes;
  final List<EspecialistaMapaEntity> especialistas;
  final double? miLatitud;
  final double? miLongitud;
  final String? aceptandoId;
  final String? feedback;

  const MarketplaceLoaded({
    this.solicitudes = const [],
    this.especialistas = const [],
    this.miLatitud,
    this.miLongitud,
    this.aceptandoId,
    this.feedback,
  });

  MarketplaceLoaded copyWith({
    List<SolicitudPendienteEntity>? solicitudes,
    List<EspecialistaMapaEntity>? especialistas,
    double? miLatitud,
    double? miLongitud,
    String? aceptandoId,
    String? feedback,
  }) {
    return MarketplaceLoaded(
      solicitudes: solicitudes ?? this.solicitudes,
      especialistas: especialistas ?? this.especialistas,
      miLatitud: miLatitud ?? this.miLatitud,
      miLongitud: miLongitud ?? this.miLongitud,
      aceptandoId: aceptandoId,
      feedback: feedback,
    );
  }

  @override
  List<Object?> get props => [
        solicitudes,
        especialistas,
        miLatitud,
        miLongitud,
        aceptandoId,
        feedback,
      ];
}

class MarketplaceError extends MarketplaceState {
  final String message;
  const MarketplaceError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─────────────────────────────────────────────────────────────────────────────
// CUBIT
// ─────────────────────────────────────────────────────────────────────────────

class MarketplaceCubit extends Cubit<MarketplaceState> {
  final GetSolicitudesPendientes _getSolicitudesPendientes;
  final GetEspecialistasAprobados _getEspecialistasAprobados;
  final GetMiUbicacion _getMiUbicacion;
  final AceptarSolicitud _aceptarSolicitud;

  MarketplaceCubit({
    required GetSolicitudesPendientes getSolicitudesPendientes,
    required GetEspecialistasAprobados getEspecialistasAprobados,
    required GetMiUbicacion getMiUbicacion,
    required AceptarSolicitud aceptarSolicitud,
  })  : _getSolicitudesPendientes = getSolicitudesPendientes,
        _getEspecialistasAprobados = getEspecialistasAprobados,
        _getMiUbicacion = getMiUbicacion,
        _aceptarSolicitud = aceptarSolicitud,
        super(const MarketplaceInitial());

  Future<void> load(String especialistaId) async {
    emit(const MarketplaceLoading());

    List<SolicitudPendienteEntity> solicitudes = const [];
    List<EspecialistaMapaEntity> especialistas = const [];
    ({double? latitud, double? longitud})? ubicacion;
    String? error;

    final solRes = await _getSolicitudesPendientes();
    final espRes = await _getEspecialistasAprobados();
    final ubiRes = await _getMiUbicacion(especialistaId);

    solRes.fold((f) => error ??= f.message, (v) => solicitudes = v);
    espRes.fold((f) => error ??= f.message, (v) => especialistas = v);
    ubiRes.fold((f) => error ??= f.message, (v) => ubicacion = v);

    if (error != null) {
      emit(MarketplaceError(error!));
      return;
    }

    emit(MarketplaceLoaded(
      solicitudes: solicitudes,
      especialistas: especialistas,
      miLatitud: ubicacion?.latitud,
      miLongitud: ubicacion?.longitud,
    ));
  }

  Future<void> aceptar({
    required String solicitudId,
    required String especialistaId,
  }) async {
    final current = state;
    if (current is! MarketplaceLoaded) return;

    emit(current.copyWith(aceptandoId: solicitudId));

    final result = await _aceptarSolicitud(AceptarSolicitudParams(
      solicitudId: solicitudId,
      especialistaId: especialistaId,
    ));

    result.fold(
      (f) => emit(MarketplaceError(f.message)),
      (resultado) {
        final base = state is MarketplaceLoaded
            ? state as MarketplaceLoaded
            : current;

        if (resultado.aceptada) {
          emit(base.copyWith(
            solicitudes: base.solicitudes
                .where((s) => s.id != solicitudId)
                .toList(),
            aceptandoId: null,
            feedback: 'Solicitud asignada correctamente. ¡El paciente es tuyo!',
          ));
        } else if (resultado.expirada) {
          emit(base.copyWith(
            solicitudes: base.solicitudes
                .where((s) => s.id != solicitudId)
                .toList(),
            aceptandoId: null,
            feedback: 'Esta solicitud expiró. Ya no está disponible.',
          ));
        } else {
          emit(base.copyWith(
            aceptandoId: null,
            feedback:
                'Este paciente ya fue asignado a otro especialista. Se actualiza el mapa.',
          ));
          _refrescar();
        }
      },
    );
  }

  void clearFeedback() {
    final current = state;
    if (current is MarketplaceLoaded) {
      emit(current.copyWith(feedback: null));
    }
  }

  Future<void> _refrescar() async {
    final res = await _getSolicitudesPendientes();
    res.fold(
      (f) => null,
      (solicitudes) {
        if (state is MarketplaceLoaded) {
          final current = state as MarketplaceLoaded;
          emit(current.copyWith(solicitudes: solicitudes));
        }
      },
    );
  }
}
