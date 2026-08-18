import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// Los usecases se inyectan por nombre; esta regla no aplica aquí.
// ignore_for_file: prefer_initializing_formals

import '../../domain/entities/cuestionario_entity.dart';
import '../../domain/entities/estado_salud_entity.dart';
import '../../domain/entities/evaluacion_salud_entity.dart';
import '../../domain/usecases/consultar_estado_salud.dart';
import '../../domain/usecases/get_cuestionario_activo.dart';
import '../../domain/usecases/get_cuestionario_preguntas.dart';
import '../../domain/usecases/guardar_respuestas_evaluacion.dart';
import '../../domain/usecases/registrar_validacion_telemedicina.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ESTADOS
// ─────────────────────────────────────────────────────────────────────────────

abstract class PatientHealthState extends Equatable {
  const PatientHealthState();
  @override
  List<Object?> get props => [];
}

class PatientHealthInitial extends PatientHealthState {
  const PatientHealthInitial();
}

class PatientHealthLoading extends PatientHealthState {
  const PatientHealthLoading();
}

class PatientHealthLoaded extends PatientHealthState {
  final EstadoSaludEntity? estadoSalud;
  final CuestionarioEntity? cuestionario;
  final List<PreguntaEntity> preguntas;
  final ResultadoEvaluacionRegistrada? ultimoResultado;
  final ValidacionTelemedicinaEntity? validacion;
  final bool enviando;

  const PatientHealthLoaded({
    this.estadoSalud,
    this.cuestionario,
    this.preguntas = const [],
    this.ultimoResultado,
    this.validacion,
    this.enviando = false,
  });

  PatientHealthLoaded copyWith({
    EstadoSaludEntity? estadoSalud,
    CuestionarioEntity? cuestionario,
    List<PreguntaEntity>? preguntas,
    ResultadoEvaluacionRegistrada? ultimoResultado,
    ValidacionTelemedicinaEntity? validacion,
    bool? enviando,
  }) {
    return PatientHealthLoaded(
      estadoSalud: estadoSalud ?? this.estadoSalud,
      cuestionario: cuestionario ?? this.cuestionario,
      preguntas: preguntas ?? this.preguntas,
      ultimoResultado: ultimoResultado ?? this.ultimoResultado,
      validacion: validacion ?? this.validacion,
      enviando: enviando ?? this.enviando,
    );
  }

  @override
  List<Object?> get props => [
        estadoSalud,
        cuestionario,
        preguntas,
        ultimoResultado,
        validacion,
        enviando,
      ];
}

class PatientHealthError extends PatientHealthState {
  final String message;
  const PatientHealthError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─────────────────────────────────────────────────────────────────────────────
// CUBIT
// ─────────────────────────────────────────────────────────────────────────────

class PatientHealthCubit extends Cubit<PatientHealthState> {
  final ConsultarEstadoSalud _consultarEstadoSalud;
  final GetCuestionarioActivo _getCuestionarioActivo;
  final GetCuestionarioPreguntas _getCuestionarioPreguntas;
  final GuardarRespuestasEvaluacion _guardarRespuestasEvaluacion;
  final RegistrarValidacionTelemedicina _registrarValidacionTelemedicina;

  PatientHealthCubit({
    required ConsultarEstadoSalud consultarEstadoSalud,
    required GetCuestionarioActivo getCuestionarioActivo,
    required GetCuestionarioPreguntas getCuestionarioPreguntas,
    required GuardarRespuestasEvaluacion guardarRespuestasEvaluacion,
    required RegistrarValidacionTelemedicina registrarValidacionTelemedicina,
  })  : _consultarEstadoSalud = consultarEstadoSalud,
        _getCuestionarioActivo = getCuestionarioActivo,
        _getCuestionarioPreguntas = getCuestionarioPreguntas,
        _guardarRespuestasEvaluacion = guardarRespuestasEvaluacion,
        _registrarValidacionTelemedicina = registrarValidacionTelemedicina,
        super(const PatientHealthInitial());

  /// Consulta el estado integral de salud del paciente (requisito 13).
  Future<void> loadEstadoSalud() async {
    emit(const PatientHealthLoading());
    final result = await _consultarEstadoSalud();
    result.fold(
      (f) => emit(PatientHealthError(f.message)),
      (estado) {
        if (state is PatientHealthLoaded) {
          final current = state as PatientHealthLoaded;
          emit(current.copyWith(estadoSalud: estado));
        } else {
          emit(PatientHealthLoaded(estadoSalud: estado));
        }
      },
    );
  }

  /// Carga el cuestionario activo y sus preguntas (requisito 6).
  Future<void> loadCuestionario() async {
    final cuestionario = await _getCuestionarioActivo();
    await cuestionario.fold(
      (f) async => emit(PatientHealthError(f.message)),
      (c) async {
        if (c == null) {
          emit(const PatientHealthError('No hay un cuestionario activo configurado.'));
          return;
        }
        final preguntas = await _getCuestionarioPreguntas(
          GetCuestionarioPreguntasParams(c.id),
        );
        preguntas.fold(
          (f) => emit(PatientHealthError(f.message)),
          (p) {
            if (state is PatientHealthLoaded) {
              final current = state as PatientHealthLoaded;
              emit(current.copyWith(cuestionario: c, preguntas: p));
            } else {
              emit(PatientHealthLoaded(cuestionario: c, preguntas: p));
            }
          },
        );
      },
    );
  }

  /// Persiste las respuestas del cuestionario (requisito 7-9).
  Future<ResultadoEvaluacionRegistrada?> enviarRespuestas(
    int cuestionarioId,
    Map<int, String> respuestas,
  ) async {
    final current = state is PatientHealthLoaded
        ? state as PatientHealthLoaded
        : null;
    if (current != null) emit(current.copyWith(enviando: true));

    final result = await _guardarRespuestasEvaluacion(
      GuardarRespuestasEvaluacionParams(
        cuestionarioId: cuestionarioId,
        respuestas: respuestas,
      ),
    );

    return result.fold(
      (f) {
        emit(PatientHealthError(f.message));
        return null;
      },
      (resultado) {
        final base = state is PatientHealthLoaded
            ? state as PatientHealthLoaded
            : current;
        if (base != null) {
          emit(base.copyWith(
            ultimoResultado: resultado,
            enviando: false,
          ));
        }
        return resultado;
      },
    );
  }

  /// Registra la validación de telemedicina (requisitos 10-11).
  Future<ValidacionTelemedicinaEntity?> registrarValidacion({
    required bool aprobado,
    required String proveedor,
  }) async {
    final result = await _registrarValidacionTelemedicina(
      RegistrarValidacionTelemedicinaParams(
        aprobado: aprobado,
        proveedor: proveedor,
      ),
    );

    return result.fold(
      (f) {
        emit(PatientHealthError(f.message));
        return null;
      },
      (validacion) {
        if (state is PatientHealthLoaded) {
          final current = state as PatientHealthLoaded;
          emit(current.copyWith(validacion: validacion, enviando: false));
        }
        return validacion;
      },
    );
  }
}