import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../repositories/i_catalog_repository.dart';

class SubirImagenServicioParams {
  final String servicioId;
  final Uint8List bytes;
  final String nombreArchivo;

  const SubirImagenServicioParams({
    required this.servicioId,
    required this.bytes,
    required this.nombreArchivo,
  });
}

/// Sube la imagen de un servicio al bucket público y guarda la URL en
/// `servicios.imagen_url`. Devuelve la URL pública (solo admin).
class SubirImagenServicio
    extends UseCase<String, SubirImagenServicioParams> {
  final ICatalogRepository _repository;
  SubirImagenServicio(this._repository);

  @override
  Future<Either<Failure, String>> call(SubirImagenServicioParams params) {
    return _repository.subirImagenServicio(
      servicioId: params.servicioId,
      bytes: params.bytes,
      nombreArchivo: params.nombreArchivo,
    );
  }
}