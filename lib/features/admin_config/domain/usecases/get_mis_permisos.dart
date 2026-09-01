import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../repositories/i_admin_config_repository.dart';

/// Obtiene los códigos de permiso del usuario logueado (RPC `mis_permisos`).
class GetMisPermisos extends NoParamsUseCase<List<String>> {
  final IAdminConfigRepository _repository;

  GetMisPermisos(this._repository);

  @override
  Future<Either<Failure, List<String>>> call() async {
    try {
      return await _repository.getMisPermisos();
    } catch (e) {
      return Left(ServerFailure('No se pudieron cargar tus permisos: $e'));
    }
  }
}