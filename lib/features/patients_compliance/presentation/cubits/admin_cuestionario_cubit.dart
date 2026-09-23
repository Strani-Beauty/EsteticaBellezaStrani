import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// Los usecases se inyectan por nombre; esta regla no aplica aquí.
// ignore_for_file: prefer_initializing_formals

import '../../../../app/core/usecases/use_case.dart';
import '../../domain/entities/cuestionario_entity.dart';
import '../../domain/usecases/actualizar_orden_pregunta.dart';
import '../../domain/usecases/activar_version_cuestionario.dart';
import '../../domain/usecases/asociar_pregunta.dart';
import '../../domain/usecases/crear_nueva_version_cuestionario.dart';
import '../../domain/usecases/crear_pregunta.dart';
import '../../domain/usecases/desactivar_pregunta.dart';
import '../../domain/usecases/eliminar_cuestionario.dart';
import '../../domain/usecases/get_cuestionario_preguntas.dart';
import '../../domain/usecases/get_cuestionarios.dart';
import '../../domain/usecases/get_preguntas_catalogo.dart';
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
  final List<PreguntaEntity> catalogo;
  final String? feedback;

  const AdminCuestionarioLoaded({
    this.cuestionarios = const [],
    this.versionSeleccionada,
    this.preguntas = const [],
    this.catalogo = const [],
    this.feedback,
  });

  AdminCuestionarioLoaded copyWith({
    List<CuestionarioEntity>? cuestionarios,
    int? versionSeleccionada,
    List<PreguntaEntity>? preguntas,
    List<PreguntaEntity>? catalogo,
    String? feedback,
  }) {
    return AdminCuestionarioLoaded(
      cuestionarios: cuestionarios ?? this.cuestionarios,
      versionSeleccionada: versionSeleccionada ?? this.versionSeleccionada,
      preguntas: preguntas ?? this.preguntas,
      catalogo: catalogo ?? this.catalogo,
      feedback: feedback ?? this.feedback,
    );
  }

  @override
  List<Object?> get props => [
        cuestionarios,
        versionSeleccionada,
        preguntas,
        catalogo,
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
  final GetPreguntasCatalogo _getPreguntasCatalogo;
  final AsociarPregunta _asociarPregunta;
  final DesactivarPregunta _desactivarPregunta;
  final ActualizarOrdenPregunta _actualizarOrdenPregunta;
  final CrearNuevaVersionCuestionario _crearNuevaVersion;
  final ActivarVersionCuestionario _activarVersion;
  final UpdatePregunta _updatePregunta;
  final CrearPregunta _crearPregunta;
  final EliminarCuestionario _eliminarCuestionario;

  AdminCuestionarioCubit({
    required GetCuestionarios getCuestionarios,
    required GetCuestionarioPreguntas getCuestionarioPreguntas,
    required GetPreguntasCatalogo getPreguntasCatalogo,
    required AsociarPregunta asociarPregunta,
    required DesactivarPregunta desactivarPregunta,
    required ActualizarOrdenPregunta actualizarOrdenPregunta,
    required CrearNuevaVersionCuestionario crearNuevaVersion,
    required ActivarVersionCuestionario activarVersion,
    required UpdatePregunta updatePregunta,
    required CrearPregunta crearPregunta,
    required EliminarCuestionario eliminarCuestionario,
  })  : _getCuestionarios = getCuestionarios,
        _getCuestionarioPreguntas = getCuestionarioPreguntas,
        _getPreguntasCatalogo = getPreguntasCatalogo,
        _asociarPregunta = asociarPregunta,
        _desactivarPregunta = desactivarPregunta,
        _actualizarOrdenPregunta = actualizarOrdenPregunta,
        _crearNuevaVersion = crearNuevaVersion,
        _activarVersion = activarVersion,
        _updatePregunta = updatePregunta,
        _crearPregunta = crearPregunta,
        _eliminarCuestionario = eliminarCuestionario,
        super(const AdminCuestionarioInitial());

  Future<void> load() async {
    emit(const AdminCuestionarioLoading());
    final result = await _getCuestionarios(const GetCuestionariosParams());
    await result.fold(
      (f) async => emit(AdminCuestionarioError(f.message)),
      (cuestionarios) async {
        final activa = _buscarActiva(cuestionarios);
        emit(AdminCuestionarioLoaded(
          cuestionarios: cuestionarios,
          versionSeleccionada: activa?.id,
        ));
        await _cargarCatalogo();
        if (activa != null) {
          await loadPreguntas(activa.id);
        }
      },
    );
  }

  Future<void> _cargarCatalogo() async {
    final result = await _getPreguntasCatalogo(const NoParams());
    await result.fold(
      (f) async => emit(AdminCuestionarioError(f.message)),
      (catalogo) async {
        if (state is AdminCuestionarioLoaded) {
          emit((state as AdminCuestionarioLoaded).copyWith(catalogo: catalogo));
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
      GetCuestionarioPreguntasParams(cuestionarioId, soloActivas: false),
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

  Future<void> eliminarCuestionario(int cuestionarioId) async {
    final result = await _eliminarCuestionario(
      EliminarCuestionarioParams(cuestionarioId),
    );
    await result.fold(
      (f) async => emit(AdminCuestionarioError(f.message)),
      (_) async {
        if (state is AdminCuestionarioLoaded) {
          emit((state as AdminCuestionarioLoaded)
              .copyWith(feedback: 'Cuestionario eliminado.'));
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

  Future<void> crearPregunta({
    required String texto,
    required TipoRespuestaPregunta tipo,
    bool obligatoria = false,
    List<String>? opciones,
    Map<String, dynamic>? riesgo,
    bool activo = true,
    int? cuestionarioId,
  }) async {
    final result = await _crearPregunta(CrearPreguntaParams(
      texto: texto,
      tipo: tipo,
      obligatoria: obligatoria,
      opciones: opciones,
      riesgo: riesgo,
      activo: activo,
    ));
    await result.fold(
      (f) async => emit(AdminCuestionarioError(f.message)),
      (nuevoId) async {
        if (cuestionarioId != null) {
          final asociar = await _asociarPregunta(AsociarPreguntaParams(
            cuestionarioId: cuestionarioId,
            preguntaId: nuevoId,
          ));
          final ok = asociar.fold(
            (f) {
              emit(AdminCuestionarioError(f.message));
              return false;
            },
            (_) => true,
          );
          if (!ok) return;
        }
        if (state is AdminCuestionarioLoaded) {
          emit((state as AdminCuestionarioLoaded).copyWith(
            feedback: cuestionarioId != null
                ? 'Pregunta creada y asociada a la versión.'
                : 'Pregunta creada en el catálogo.',
          ));
        }
        await _cargarCatalogo();
        if (cuestionarioId != null) {
          await loadPreguntas(cuestionarioId);
        }
      },
    );
  }

  Future<void> asociarPregunta({
    required int cuestionarioId,
    required int preguntaId,
  }) async {
    final result = await _asociarPregunta(AsociarPreguntaParams(
      cuestionarioId: cuestionarioId,
      preguntaId: preguntaId,
    ));
    await result.fold(
      (f) async => emit(AdminCuestionarioError(f.message)),
      (_) async {
        if (state is AdminCuestionarioLoaded) {
          emit((state as AdminCuestionarioLoaded)
              .copyWith(feedback: 'Pregunta asociada a la versión.'));
        }
        await _cargarCatalogo();
        await loadPreguntas(cuestionarioId);
      },
    );
  }

  Future<void> desactivarPregunta({
    required int cuestionarioId,
    required int preguntaId,
    required bool activo,
  }) async {
    final result = await _desactivarPregunta(DesactivarPreguntaParams(
      cuestionarioId: cuestionarioId,
      preguntaId: preguntaId,
      activo: activo,
    ));
    await result.fold(
      (f) async => emit(AdminCuestionarioError(f.message)),
      (_) async {
        if (state is AdminCuestionarioLoaded) {
          emit((state as AdminCuestionarioLoaded).copyWith(
            feedback: activo
                ? 'Pregunta reactivada en la versión.'
                : 'Pregunta desactivada en la versión.',
          ));
        }
        await loadPreguntas(cuestionarioId);
      },
    );
  }

  Future<void> moverPregunta({
    required int cuestionarioId,
    required int preguntaId,
    required int delta,
  }) async {
    if (state is! AdminCuestionarioLoaded) return;
    final current = state as AdminCuestionarioLoaded;
    final lista = List.of(current.preguntas);
    final index = lista.indexWhere((p) => p.id == preguntaId);
    if (index < 0) return;
    final target = index + delta;
    if (target < 0 || target >= lista.length) return;

    final a = lista[index];
    final b = lista[target];
    final res1 = await _actualizarOrdenPregunta(ActualizarOrdenPreguntaParams(
      cuestionarioId: cuestionarioId,
      preguntaId: a.id,
      orden: b.orden,
    ));
    if (res1.isLeft()) {
      emit(AdminCuestionarioError(
          res1.getLeft().toNullable()?.message ?? 'No se pudo reordenar la pregunta.'));
      return;
    }
    final res2 = await _actualizarOrdenPregunta(ActualizarOrdenPreguntaParams(
      cuestionarioId: cuestionarioId,
      preguntaId: b.id,
      orden: a.orden,
    ));
    if (res2.isLeft()) {
      emit(AdminCuestionarioError(
          res2.getLeft().toNullable()?.message ?? 'No se pudo reordenar la pregunta.'));
      return;
    }
    await loadPreguntas(cuestionarioId);
  }
}