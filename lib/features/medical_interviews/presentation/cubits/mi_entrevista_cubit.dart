import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// Los usecases se inyectan por nombre; esta regla no aplica aquí.
// ignore_for_file: prefer_initializing_formals

import '../../../../app/core/usecases/use_case.dart';
import '../../domain/entities/entrevista_medica_entity.dart';
import '../../domain/usecases/firmar_url_entrevista.dart';
import '../../domain/usecases/get_mi_entrevista.dart';
import '../../domain/usecases/registrar_consentimiento_entrevista.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ESTADOS
// ─────────────────────────────────────────────────────────────────────────────

abstract class MiEntrevistaState extends Equatable {
  const MiEntrevistaState();
  @override
  List<Object?> get props => [];
}

class MiEntrevistaInitial extends MiEntrevistaState {
  const MiEntrevistaInitial();
}

class MiEntrevistaLoading extends MiEntrevistaState {
  const MiEntrevistaLoading();
}

class MiEntrevistaLoaded extends MiEntrevistaState {
  final EntrevistaMedicaEntity? entrevista;
  const MiEntrevistaLoaded(this.entrevista);
  @override
  List<Object?> get props => [entrevista];
}

class MiEntrevistaError extends MiEntrevistaState {
  final String message;
  const MiEntrevistaError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─────────────────────────────────────────────────────────────────────────────
// CUBIT (paciente)
// ─────────────────────────────────────────────────────────────────────────────

class MiEntrevistaCubit extends Cubit<MiEntrevistaState> {
  final GetMiEntrevista _getMiEntrevista;
  final RegistrarConsentimientoEntrevista _registrarConsentimiento;
  final FirmarUrlEntrevista _firmarUrl;

  MiEntrevistaCubit({
    required GetMiEntrevista getMiEntrevista,
    required RegistrarConsentimientoEntrevista registrarConsentimientoEntrevista,
    required FirmarUrlEntrevista firmarUrlEntrevista,
  })  : _getMiEntrevista = getMiEntrevista,
        _registrarConsentimiento = registrarConsentimientoEntrevista,
        _firmarUrl = firmarUrlEntrevista,
        super(const MiEntrevistaInitial());

  Future<void> load() async {
    emit(const MiEntrevistaLoading());
    final result = await _getMiEntrevista(const NoParams());
    result.fold(
      (failure) => emit(MiEntrevistaError(failure.message)),
      (entrevista) => emit(MiEntrevistaLoaded(entrevista)),
    );
  }

  /// Firma y registra el consentimiento; devuelve error o `null`.
  Future<String?> registrarConsentimiento({
    required String entrevistaId,
    required Uint8List firmaBytes,
  }) async {
    final result =
        await _registrarConsentimiento(RegistrarConsentimientoEntrevistaParams(
      entrevistaId: entrevistaId,
      firmaBytes: firmaBytes,
    ));
    if (result.isLeft()) return result.getLeft().toNullable()?.message;
    await load();
    return null;
  }

  Future<String?> firmarUrl(String path) async {
    final result = await _firmarUrl(FirmarUrlEntrevistaParams(path: path));
    return result.fold((f) => null, (url) => url);
  }
}
