import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../repositories/i_marketplace_repository.dart';

/// Última ubicación registrada del especialista actual.
class GetMiUbicacion
    extends UseCase<({double? latitud, double? longitud}), String> {
  final IMarketplaceRepository _repository;
  GetMiUbicacion(this._repository);

  @override
  Future<Either<Failure, ({double? latitud, double? longitud})>> call(
      String especialistaId) {
    return _repository.getMiUbicacion(especialistaId);
  }
}
