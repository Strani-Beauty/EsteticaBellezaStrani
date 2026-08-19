import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// Los usecases se inyectan por nombre; esta regla no aplica aquí.
// ignore_for_file: prefer_initializing_formals

import '../../domain/entities/cuestionario_entity.dart';
import '../../domain/usecases/activar_version_cuestionario.dart';
import '../../domain/usecases/crear_nueva_version_cuestionario.dart';
import '../../domain/usecases/get_cuestionario_preguntas.dart';
import '../../domain/usecases/get_cuestionarios.dart';
import '../../domain/usecases/update_pregunta.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ESTADOS
// ─────────────────────────────────────────────────────────────────────────────

abstract class AdminCuestionarioState extends Equatable {
  const AdminCuestionarioState();
  @override
  List<Object?> get props => [];
}

class AdminCuestionarioInitial extends AdminCuestionarioState {
  const AdminCuestionarioInitial();
}

class AdminCuestionarioLoading extends AdminCuestionarioState {
  const AdminCuestionarioLoading();
}

class AdminCuestionarioLoaded extends AdminCuestionarioState {
  final List<CuestionarioEntity> cuestionarios;
  final int? versionSeleccionada;
  final List<PreguntaEntity> preguntas;
  final String? feedback;

  const AdminCuestionarioLoaded({
    this.cuestionarios = const [],
    this.versionSeleccionada,
    this.preguntas = const [],
    this.feedback,
  });

  AdminCuestionarioLoaded copyWith({
    List<CuestionarioEntity>? cuestionarios,
    int? versionSeleccionada,
    List<PreguntaEntity>? preguntas,
    String? feedback,
  }) {
    return AdminCuestionarioLoaded(
      cuestionarios: cuestionarios ?? this.cuestionarios,
      versionSeleccionada: versionSeleccionada ?? this.versionSeleccionada,
      preguntas: preguntas ?? this.preguntas,
      feedback: feedback ?? this.feedback,
    );
  }

  @override
  List<Object?> get props => [
        cuestionarios,
        versionSeleccionada,
        preguntas,
        feedback,
      ];
}

class AdminCuestionarioError extends AdminCuestionarioState {
  final String message;
  const AdminCuestionarioError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─────────────────────────────────────────────────────────────────────────────
// CUBIT
// ─────────────────────────────────────────────────────────────────────────────

class AdminCuestionarioCubit extends Cubit<AdminCuestionarioState> {
  final GetCuestionarios _getCuestionarios;
  final GetCuestionarioPreguntas _getCuestionarioPreguntas;
  final CrearNuevaVersionCuestionario _crearNuevaVersion;
  final ActivarVersionCuestionario _activarVersion;
  final UpdatePregunta _updatePregunta;

  AdminCuestionarioCubit({
    required GetCuestionarios getCuestionarios,
    required GetCuestionarioPreguntas getCuestionarioPreguntas,
    required CrearNuevaVersionCuestionario crearNuevaVersion,
    required ActivarVersionCuestionario activarVersion,
    required UpdatePregunta updatePregunta,
  })  : _getCuestionarios = getCuestionarios,
        _getCuestionarioPreguntas = getCuestionarioPreguntas,
        _crearNuevaVersion = crearNuevaVersion,
        _activarVersion = activarVersion,
        _updatePregunta = updatePregunta,
        super(const AdminCuestionarioInitial());

  Future<void> load() async {
    emit(const AdminCuestionarioLoading());
    final result = await _getCuestionarios(const GetCuestionariosParams());
    result.fold(
      (f) => emit(AdminCuestionarioError(f.message)),
      (cuestionarios) {
        final activa = _buscarActiva(cuestionarios);
        emit(AdminCuestionarioLoaded(
          cuestionarios: cuestionarios,
          versionSeleccionada: activa?.id,
        ));
        if (activa != null) {
          loadPreguntas(activa.id);
        }
      },
    );
  }

  CuestionarioEntity? _buscarActiva(List<CuestionarioEntity> lista) {
    for (final c in lista) {
      if (c.activo) return c;
    }
    return null;
  }

  Future<void> loadPreguntas(int cuestionarioId) async {
    final result = await _getCuestionarioPreguntas(
      GetCuestionarioPreguntasParams(cuestionarioId),
    );
    result.fold(
      (f) => emit(AdminCuestionarioError(f.message)),
      (preguntas) {
        if (state is AdminCuestionarioLoaded) {
          final current = state as AdminCuestionarioLoaded;
          emit(current.copyWith(
            versionSeleccionada: cuestionarioId,
            preguntas: preguntas,
          ));
        }
      },
    );
  }

  Future<void> crearNuevaVersion(int versionActualId) async {
    final result = await _crearNuevaVersion(
      CrearNuevaVersionCuestionarioParams(versionActualId),
    );
    await result.fold(
      (f) async => emit(AdminCuestionarioError(f.message)),
      (nueva) async {
        if (state is AdminCuestionarioLoaded) {
          final current = state as AdminCuestionarioLoaded;
          emit(current.copyWith(
            cuestionarios: [...current.cuestionarios, nueva],
            feedback:
                'Versión ${nueva.version} creada (inactiva). Edítala y actívala cuando esté lista.',
          ));
        }
        await load();
      },
    );
  }

  Future<void> activarVersion(int cuestionarioId) async {
    final result = await _activarVersion(
      ActivarVersionCuestionarioParams(cuestionarioId),
    );
    await result.fold(
      (f) async => emit(AdminCuestionarioError(f.message)),
      (_) async {
        if (state is AdminCuestionarioLoaded) {
          final current = state as AdminCuestionarioLoaded;
          emit(current.copyWith(feedback: 'Versión activada correctamente.'));
        }
        await load();
      },
    );
  }

  Future<void> editarPregunta({
    required int preguntaId,
    String? texto,
    String? tipoRespuesta,
    bool? obligatoria,
    List<String>? opciones,
    Map<String, dynamic>? riesgo,
    bool? activo,
  }) async {
    final result = await _updatePregunta(UpdatePreguntaParams(
      preguntaId: preguntaId,
      texto: texto,
      tipoRespuesta: tipoRespuesta,
      obligatoria: obligatoria,
      opciones: opciones,
      riesgo: riesgo,
      activo: activo,
    ));
    await result.fold(
      (f) async => emit(AdminCuestionarioError(f.message)),
      (_) async {
        if (state is AdminCuestionarioLoaded) {
          final current = state as AdminCuestionarioLoaded;
          emit(current.copyWith(feedback: 'Pregunta actualizada correctamente.'));
        }
        final seleccionada = state is AdminCuestionarioLoaded
            ? (state as AdminCuestionarioLoaded).versionSeleccionada
            : null;
        if (seleccionada != null) {
          await loadPreguntas(seleccionada);
        }
      },
    );
  }
}