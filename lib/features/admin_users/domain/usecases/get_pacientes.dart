import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/admin_users/domain/entities/paciente_admin_entity.dart';
import 'package:esteticaybellezastrani/features/admin_users/domain/repositories/i_admin_users_repository.dart';

/// Obtiene la lista de pacientes del sistema (panel admin).
class GetPacientes {
  final IAdminUsersRepository _repository;

  GetPacientes(this._repository);

  Future<Either<Failure, List<PacienteAdminEntity>>> call() {
    return _repository.getPacientes();
  }
}