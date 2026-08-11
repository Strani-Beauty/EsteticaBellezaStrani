import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/admin_users/domain/repositories/i_admin_users_repository.dart';

/// Activa o desactiva la cuenta de un usuario.
class SetUsuarioActivo {
  final IAdminUsersRepository _repository;

  SetUsuarioActivo(this._repository);

  Future<Either<Failure, void>> call(String userId, bool activo) {
    return _repository.setUsuarioActivo(userId, activo);
  }
}