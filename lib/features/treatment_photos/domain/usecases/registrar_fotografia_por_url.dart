import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/fotografia_tratamiento_entity.dart';
import '../repositories/i_treatment_photos_repository.dart';

class RegistrarFotografiaPorUrlParams {
  final String tratamientoId;
  final TipoFotografia tipoFotografia;
  final String archivoUrl;
  final String? descripcion;
  const RegistrarFotografiaPorUrlParams({
    required this.tratamientoId,
    required this.tipoFotografia,
    required this.archivoUrl,
    this.descripcion,
  });
}

/// Registra una fotografía ya existente en Storage (solo URL).
class RegistrarFotografiaPorUrl
    extends UseCase<FotografiaTratamientoEntity, RegistrarFotografiaPorUrlParams> {
  final ITreatmentPhotosRepository _repository;
  RegistrarFotografiaPorUrl(this._repository);

  @override
  Future<Either<Failure, FotografiaTratamientoEntity>> call(
      RegistrarFotografiaPorUrlParams params) {
    return _repository.registrarPorUrl(
      tratamientoId: params.tratamientoId,
      tipoFotografia: params.tipoFotografia,
      archivoUrl: params.archivoUrl,
      descripcion: params.descripcion,
    );
  }
}