import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/fotografia_tratamiento_entity.dart';
import '../repositories/i_treatment_photos_repository.dart';

class SubirFotografiaParams {
  final String tratamientoId;
  final TipoFotografia tipoFotografia;
  final Uint8List bytes;
  final String nombreArchivo;
  final String? descripcion;
  const SubirFotografiaParams({
    required this.tratamientoId,
    required this.tipoFotografia,
    required this.bytes,
    required this.nombreArchivo,
    this.descripcion,
  });
}

/// Sube una fotografía al bucket y registra la fila en la BD.
class SubirFotografia
    extends UseCase<FotografiaTratamientoEntity, SubirFotografiaParams> {
  final ITreatmentPhotosRepository _repository;
  SubirFotografia(this._repository);

  @override
  Future<Either<Failure, FotografiaTratamientoEntity>> call(
      SubirFotografiaParams params) {
    return _repository.subirFotografia(
      tratamientoId: params.tratamientoId,
      tipoFotografia: params.tipoFotografia,
      bytes: params.bytes,
      nombreArchivo: params.nombreArchivo,
      descripcion: params.descripcion,
    );
  }
}