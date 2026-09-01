import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../entities/auditoria_entity.dart';
import '../repositories/i_auditoria_repository.dart';

/// Obtiene registros de auditoría con filtros opcionales.
class GetAuditoria extends UseCase<List<AuditoriaEntity>, AuditoriaFiltros> {
  final IAuditoriaRepository _repository;

  GetAuditoria(this._repository);

  @override
  Future<Either<Failure, List<AuditoriaEntity>>> call(
      AuditoriaFiltros params) async {
    try {
      return await _repository.getAuditoria(params);
    } catch (e) {
      return Left(ServerFailure('No se pudo cargar la auditoría: $e'));
    }
  }
}