import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../../domain/entities/comision_entity.dart';
import '../../domain/repositories/i_payments_repository.dart';

/// Lista las comisiones de la plataforma registradas por cita.
class GetComisionesAdmin extends NoParamsUseCase<List<ComisionEntity>> {
  final IPaymentsRepository _repository;

  GetComisionesAdmin(this._repository);

  @override
  Future<Either<Failure, List<ComisionEntity>>> call() async {
    try {
      final comisiones = await _repository.getComisionesAdmin();
      return Right(comisiones);
    } catch (e) {
      return Left(ServerFailure('No se pudieron cargar las comisiones: $e'));
    }
  }
}