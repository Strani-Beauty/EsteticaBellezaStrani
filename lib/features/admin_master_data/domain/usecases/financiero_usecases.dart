import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../entities/financiero_entity.dart';
import '../repositories/i_admin_master_data_repository.dart';

class GetLiquidaciones extends NoParamsUseCase<List<LiquidacionEntity>> {
  final IAdminMasterDataRepository _repository;
  GetLiquidaciones(this._repository);
  @override
  Future<Either<Failure, List<LiquidacionEntity>>> call() async {
    try {
      return await _repository.getLiquidaciones();
    } catch (e) {
      return Left(ServerFailure('No se pudieron cargar las liquidaciones: $e'));
    }
  }
}

class GetPagosEspecialistas
    extends NoParamsUseCase<List<PagoEspecialistaEntity>> {
  final IAdminMasterDataRepository _repository;
  GetPagosEspecialistas(this._repository);
  @override
  Future<Either<Failure, List<PagoEspecialistaEntity>>> call() async {
    try {
      return await _repository.getPagosEspecialistas();
    } catch (e) {
      return Left(
          ServerFailure('No se pudieron cargar los pagos a especialistas: $e'));
    }
  }
}
