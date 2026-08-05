import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import '../entities/fotografia_tratamiento_entity.dart';

/// Contrato del repositorio de fotografías de tratamiento.
/// La implementación vive en data/repositories/treatment_photos_repository_impl.dart
abstract class ITreatmentPhotosRepository {
  Future<Either<Failure, List<FotografiaTratamientoEntity>>>
      getFotografias(String tratamientoId);

  Future<Either<Failure, FotografiaTratamientoEntity>> subirFotografia({
    required String tratamientoId,
    required TipoFotografia tipoFotografia,
    required Uint8List bytes,
    required String nombreArchivo,
    String? descripcion,
  });

  Future<Either<Failure, FotografiaTratamientoEntity>> registrarPorUrl({
    required String tratamientoId,
    required TipoFotografia tipoFotografia,
    required String archivoUrl,
    String? descripcion,
  });

  Future<Either<Failure, void>> eliminarFotografia(
    String id, {
    String? pathEnStorage,
  });
}