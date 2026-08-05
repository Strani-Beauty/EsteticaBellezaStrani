import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/fotografia_tratamiento_entity.dart';
import '../repositories/i_treatment_photos_repository.dart';

class GetFotografiasParams {
  final String tratamientoId;
  const GetFotografiasParams(this.tratamientoId);
}

/// Lista las fotografías de un tratamiento.
class GetFotografias
    extends UseCase<List<FotografiaTratamientoEntity>, GetFotografiasParams> {
  final ITreatmentPhotosRepository _repository;
  GetFotografias(this._repository);

  @override
  Future<Either<Failure, List<FotografiaTratamientoEntity>>> call(
      GetFotografiasParams params) {
    return _repository.getFotografias(params.tratamientoId);
  }
}