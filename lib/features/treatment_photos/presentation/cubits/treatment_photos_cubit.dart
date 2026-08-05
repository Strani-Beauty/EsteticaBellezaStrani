import 'dart:typed_data';

import 'package:equatable/equatable.dart';
// Los usecases se inyectan por nombre; esta regla no aplica aquí.
// ignore_for_file: prefer_initializing_formals
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/fotografia_tratamiento_entity.dart';
import '../../domain/usecases/eliminar_fotografia.dart';
import '../../domain/usecases/get_fotografias.dart';
import '../../domain/usecases/registrar_fotografia_por_url.dart';
import '../../domain/usecases/subir_fotografia.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ESTADOS
// ─────────────────────────────────────────────────────────────────────────────

abstract class TreatmentPhotosState extends Equatable {
  const TreatmentPhotosState();
  @override
  List<Object?> get props => [];
}

class TreatmentPhotosInitial extends TreatmentPhotosState {
  const TreatmentPhotosInitial();
}

class TreatmentPhotosLoading extends TreatmentPhotosState {
  const TreatmentPhotosLoading();
}

class TreatmentPhotosLoaded extends TreatmentPhotosState {
  final List<FotografiaTratamientoEntity> fotografias;
  final bool uploading;
  const TreatmentPhotosLoaded({
    this.fotografias = const [],
    this.uploading = false,
  });

  TreatmentPhotosLoaded copyWith({
    List<FotografiaTratamientoEntity>? fotografias,
    bool? uploading,
  }) {
    return TreatmentPhotosLoaded(
      fotografias: fotografias ?? this.fotografias,
      uploading: uploading ?? this.uploading,
    );
  }

  @override
  List<Object?> get props => [fotografias, uploading];
}

class TreatmentPhotosError extends TreatmentPhotosState {
  final String message;
  const TreatmentPhotosError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─────────────────────────────────────────────────────────────────────────────
// CUBIT
// ─────────────────────────────────────────────────────────────────────────────

class TreatmentPhotosCubit extends Cubit<TreatmentPhotosState> {
  final GetFotografias _getFotografias;
  final SubirFotografia _subirFotografia;
  final RegistrarFotografiaPorUrl _registrarFotografiaPorUrl;
  final EliminarFotografia _eliminarFotografia;

  TreatmentPhotosCubit({
    required GetFotografias getFotografias,
    required SubirFotografia subirFotografia,
    required RegistrarFotografiaPorUrl registrarFotografiaPorUrl,
    required EliminarFotografia eliminarFotografia,
  })  : _getFotografias = getFotografias,
        _subirFotografia = subirFotografia,
        _registrarFotografiaPorUrl = registrarFotografiaPorUrl,
        _eliminarFotografia = eliminarFotografia,
        super(const TreatmentPhotosInitial());

  Future<void> loadFotografias(String tratamientoId) async {
    emit(const TreatmentPhotosLoading());
    final result = await _getFotografias(GetFotografiasParams(tratamientoId));
    result.fold(
      (f) => emit(TreatmentPhotosError(f.message)),
      (fotos) => emit(TreatmentPhotosLoaded(fotografias: fotos)),
    );
  }

  Future<void> subirFotografia({
    required String tratamientoId,
    required TipoFotografia tipoFotografia,
    required Uint8List bytes,
    required String nombreArchivo,
    String? descripcion,
  }) async {
    final current = state;
    if (current is TreatmentPhotosLoaded) {
      emit(current.copyWith(uploading: true));
    }

    final result = await _subirFotografia(SubirFotografiaParams(
      tratamientoId: tratamientoId,
      tipoFotografia: tipoFotografia,
      bytes: bytes,
      nombreArchivo: nombreArchivo,
      descripcion: descripcion,
    ));

    result.fold((f) => emit(TreatmentPhotosError(f.message)), (foto) {
      final base = state is TreatmentPhotosLoaded
          ? state as TreatmentPhotosLoaded
          : const TreatmentPhotosLoaded();
      emit(base.copyWith(
        fotografias: [foto, ...base.fotografias],
        uploading: false,
      ));
    });
  }

  Future<void> registrarPorUrl({
    required String tratamientoId,
    required TipoFotografia tipoFotografia,
    required String archivoUrl,
    String? descripcion,
  }) async {
    final result = await _registrarFotografiaPorUrl(
        RegistrarFotografiaPorUrlParams(
      tratamientoId: tratamientoId,
      tipoFotografia: tipoFotografia,
      archivoUrl: archivoUrl,
      descripcion: descripcion,
    ));
    result.fold(
      (f) => emit(TreatmentPhotosError(f.message)),
      (foto) {
        final base = state is TreatmentPhotosLoaded
            ? state as TreatmentPhotosLoaded
            : const TreatmentPhotosLoaded();
        emit(base.copyWith(fotografias: [foto, ...base.fotografias]));
      },
    );
  }

  Future<void> eliminarFotografia(String id, {String? pathEnStorage}) async {
    final result =
        await _eliminarFotografia(EliminarFotografiaParams(id, pathEnStorage: pathEnStorage));
    result.fold((f) => emit(TreatmentPhotosError(f.message)), (_) {
      final base = state is TreatmentPhotosLoaded
          ? state as TreatmentPhotosLoaded
          : const TreatmentPhotosLoaded();
      emit(base.copyWith(
        fotografias: base.fotografias.where((f) => f.id != id).toList(),
      ));
    });
  }
}