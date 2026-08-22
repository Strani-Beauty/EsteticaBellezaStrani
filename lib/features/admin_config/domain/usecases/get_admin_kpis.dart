import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../entities/admin_kpis_entity.dart';
import '../repositories/i_admin_config_repository.dart';

/// Obtiene los KPIs del dashboard.
class GetAdminKpis extends NoParamsUseCase<AdminKpisEntity> {
  final IAdminConfigRepository _repository;

  GetAdminKpis(this._repository);

  @override
  Future<Either<Failure, AdminKpisEntity>> call() async {
    try {
      return await _repository.getKpis();
    } catch (e) {
      return Left(ServerFailure('No se pudieron cargar los indicadores: $e'));
    }
  }
}
