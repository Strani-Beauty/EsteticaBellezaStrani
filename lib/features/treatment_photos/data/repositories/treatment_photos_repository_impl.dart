import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import '../../domain/entities/fotografia_tratamiento_entity.dart';
import '../../domain/repositories/i_treatment_photos_repository.dart';
import '../datasources/treatment_photos_supabase_datasource.dart';

/// Implementación del repositorio de fotografías de tratamiento usando Supabase.
class TreatmentPhotosRepositoryImpl implements ITreatmentPhotosRepository {
  final TreatmentPhotosSupabaseDataSource _dataSource;

  TreatmentPhotosRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, List<FotografiaTratamientoEntity>>> getFotografias(
      String tratamientoId) async {
    try {
      final models = await _dataSource.fetchFotografias(tratamientoId);
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, FotografiaTratamientoEntity>> subirFotografia({
    required String tratamientoId,
    required TipoFotografia tipoFotografia,
    required Uint8List bytes,
    required String nombreArchivo,
    String? descripcion,
  }) async {
    try {
      final model = await _dataSource.subirFotografia(
        tratamientoId: tratamientoId,
        tipoFotografia: tipoFotografia,
        bytes: bytes,
        nombreArchivo: nombreArchivo,
        descripcion: descripcion,
      );
      return Right(model.toEntity());
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, FotografiaTratamientoEntity>> registrarPorUrl({
    required String tratamientoId,
    required TipoFotografia tipoFotografia,
    required String archivoUrl,
    String? descripcion,
  }) async {
    try {
      final model = await _dataSource.registrarPorUrl(
        tratamientoId: tratamientoId,
        tipoFotografia: tipoFotografia,
        archivoUrl: archivoUrl,
        descripcion: descripcion,
      );
      return Right(model.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> eliminarFotografia(
    String id, {
    String? pathEnStorage,
  }) async {
    try {
      await _dataSource.eliminarFotografia(id, pathEnStorage: pathEnStorage);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}