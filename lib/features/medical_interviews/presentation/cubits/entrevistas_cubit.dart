import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// Los usecases se inyectan por nombre; esta regla no aplica aquí.
// ignore_for_file: prefer_initializing_formals

import '../../domain/entities/entrevista_medica_entity.dart';
import '../../domain/usecases/agendar_entrevista.dart';
import '../../domain/usecases/emitir_dictamen_entrevista.dart';
import '../../domain/usecases/firmar_url_entrevista.dart';
import '../../domain/usecases/get_entrevistas.dart';
import '../../domain/usecases/guardar_grabacion_entrevista.dart';
import '../../domain/usecases/guardar_notas_entrevista.dart';
import '../../domain/usecases/iniciar_entrevista.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ESTADOS
// ─────────────────────────────────────────────────────────────────────────────

abstract class EntrevistasState extends Equatable {
  const EntrevistasState();
  @override
  List<Object?> get props => [];
}

class EntrevistasInitial extends EntrevistasState {
  const EntrevistasInitial();
}

class EntrevistasLoading extends EntrevistasState {
  const EntrevistasLoading();
}

class EntrevistasLoaded extends EntrevistasState {
  final List<EntrevistaMedicaEntity> entrevistas;
  const EntrevistasLoaded(this.entrevistas);
  @override
  List<Object?> get props => [entrevistas];
}

class EntrevistasError extends EntrevistasState {
  final String message;
  const EntrevistasError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─────────────────────────────────────────────────────────────────────────────
// CUBIT (agenda + acciones admin)
// ─────────────────────────────────────────────────────────────────────────────

class EntrevistasCubit extends Cubit<EntrevistasState> {
  final GetEntrevistas _getEntrevistas;
  final AgendarEntrevista _agendarEntrevista;
  final IniciarEntrevista _iniciarEntrevista;
  final EmitirDictamenEntrevista _emitirDictamen;
  final GuardarNotasEntrevista _guardarNotas;
  final GuardarGrabacionEntrevista _guardarGrabacion;
  final FirmarUrlEntrevista _firmarUrl;

  EntrevistasCubit({
    required GetEntrevistas getEntrevistas,
    required AgendarEntrevista agendarEntrevista,
    required IniciarEntrevista iniciarEntrevista,
    required EmitirDictamenEntrevista emitirDictamenEntrevista,
    required GuardarNotasEntrevista guardarNotasEntrevista,
    required GuardarGrabacionEntrevista guardarGrabacionEntrevista,
    required FirmarUrlEntrevista firmarUrlEntrevista,
  })  : _getEntrevistas = getEntrevistas,
        _agendarEntrevista = agendarEntrevista,
        _iniciarEntrevista = iniciarEntrevista,
        _emitirDictamen = emitirDictamenEntrevista,
        _guardarNotas = guardarNotasEntrevista,
        _guardarGrabacion = guardarGrabacionEntrevista,
        _firmarUrl = firmarUrlEntrevista,
        super(const EntrevistasInitial());

  String? _estadoFiltro;

  List<EntrevistaMedicaEntity> get entrevistas =>
      state is EntrevistasLoaded ? (state as EntrevistasLoaded).entrevistas : const [];

  EntrevistaMedicaEntity? porId(String id) {
    for (final e in entrevistas) {
      if (e.id == id) return e;
    }
    return null;
  }

  Future<void> load({String? estado}) async {
    _estadoFiltro = estado;
    emit(const EntrevistasLoading());
    final result = await _getEntrevistas(GetEntrevistasParams(estado: estado));
    result.fold(
      (failure) => emit(EntrevistasError(failure.message)),
      (lista) => emit(EntrevistasLoaded(lista)),
    );
  }

  Future<void> refrescar() => load(estado: _estadoFiltro);

  /// Crea una entrevista; devuelve el mensaje de error o `null` si ok.
  Future<String?> agendar({
    required String pacienteId,
    required DateTime fechaProgramada,
    int duracionMin = 30,
    String? evaluacionSaludId,
  }) async {
    final result = await _agendarEntrevista(AgendarEntrevistaParams(
      pacienteId: pacienteId,
      fechaProgramada: fechaProgramada,
      duracionMin: duracionMin,
      evaluacionSaludId: evaluacionSaludId,
    ));
    if (result.isLeft()) return result.getLeft().toNullable()?.message;
    await refrescar();
    return null;
  }

  Future<String?> iniciar(String entrevistaId) async {
    final result = await _iniciarEntrevista(
      IniciarEntrevistaParams(entrevistaId: entrevistaId),
    );
    if (result.isLeft()) return result.getLeft().toNullable()?.message;
    await refrescar();
    return null;
  }

  Future<String?> emitirDictamen({
    required String entrevistaId,
    required bool aprobado,
    required String observaciones,
    String? hallazgos,
  }) async {
    final result = await _emitirDictamen(EmitirDictamenEntrevistaParams(
      entrevistaId: entrevistaId,
      aprobado: aprobado,
      observaciones: observaciones,
      hallazgos: hallazgos,
    ));
    if (result.isLeft()) return result.getLeft().toNullable()?.message;
    await refrescar();
    return null;
  }

  Future<String?> guardarNotas({
    required String entrevistaId,
    required String notasClinicas,
    String? hallazgos,
  }) async {
    final result = await _guardarNotas(GuardarNotasEntrevistaParams(
      entrevistaId: entrevistaId,
      notasClinicas: notasClinicas,
      hallazgos: hallazgos,
    ));
    if (result.isLeft()) return result.getLeft().toNullable()?.message;
    await refrescar();
    return null;
  }

  Future<String?> adjuntarGrabacion({
    required String entrevistaId,
    required Uint8List bytes,
    String extension = 'webm',
  }) async {
    final result = await _guardarGrabacion(GuardarGrabacionEntrevistaParams(
      entrevistaId: entrevistaId,
      bytes: bytes,
      extension: extension,
    ));
    if (result.isLeft()) return result.getLeft().toNullable()?.message;
    await refrescar();
    return null;
  }

  /// Genera una URL firmada (3600 s) para un objeto del bucket de entrevistas.
  Future<String?> firmarUrl(String path) async {
    final result = await _firmarUrl(FirmarUrlEntrevistaParams(path: path));
    return result.fold((f) => null, (url) => url);
  }
}
