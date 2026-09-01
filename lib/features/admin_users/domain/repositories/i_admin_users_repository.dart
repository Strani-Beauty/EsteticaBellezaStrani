import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/admin_users/domain/entities/paciente_admin_entity.dart';
import 'package:esteticaybellezastrani/features/admin_users/domain/entities/usuario_admin_entity.dart';

/// Contrato del repositorio de administración de usuarios.
abstract class IAdminUsersRepository {
  /// Lista todos los usuarios del sistema (requiere rol Administrador).
  Future<Either<Failure, List<UsuarioAdminEntity>>> getUsuarios();

  /// Lista los pacientes del sistema con su perfil (requiere rol Administrador).
  Future<Either<Failure, List<PacienteAdminEntity>>> getPacientes();

  /// Activa o desactiva la cuenta de un usuario.
  Future<Either<Failure, void>> setUsuarioActivo(String userId, bool activo);
}