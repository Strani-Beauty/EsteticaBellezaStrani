import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/admin_users/domain/entities/usuario_admin_entity.dart';
import 'package:esteticaybellezastrani/features/admin_users/domain/repositories/i_admin_users_repository.dart';

/// Obtiene la lista de usuarios del sistema (panel admin).
class GetUsuarios {
  final IAdminUsersRepository _repository;

  GetUsuarios(this._repository);

  Future<Either<Failure, List<UsuarioAdminEntity>>> call() {
    return _repository.getUsuarios();
  }
}