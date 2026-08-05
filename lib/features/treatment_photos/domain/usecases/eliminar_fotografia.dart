import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../repositories/i_treatment_photos_repository.dart';

class EliminarFotografiaParams {
  final String id;
  final String? pathEnStorage;
  const EliminarFotografiaParams(this.id, {this.pathEnStorage});
}

/// Elimina una fotografía (fila y objeto del bucket si aplica).
class EliminarFotografia extends UseCase<void, EliminarFotografiaParams> {
  final ITreatmentPhotosRepository _repository;
  EliminarFotografia(this._repository);

  @override
  Future<Either<Failure, void>> call(EliminarFotografiaParams params) {
    return _repository.eliminarFotografia(
      params.id,
      pathEnStorage: params.pathEnStorage,
    );
  }
}