import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/features/admin_users/data/datasources/admin_users_supabase_datasource.dart';
import 'package:esteticaybellezastrani/features/admin_users/domain/entities/paciente_admin_entity.dart';
import 'package:esteticaybellezastrani/features/admin_users/domain/entities/usuario_admin_entity.dart';
import 'package:esteticaybellezastrani/features/admin_users/domain/repositories/i_admin_users_repository.dart';

/// Implementación del repositorio de administración de usuarios.
class AdminUsersRepositoryImpl implements IAdminUsersRepository {
  final AdminUsersSupabaseDataSource _dataSource;

  AdminUsersRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, List<UsuarioAdminEntity>>> getUsuarios() async {
    try {
      final models = await _dataSource.fetchUsuarios();
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<PacienteAdminEntity>>> getPacientes() async {
    try {
      final models = await _dataSource.fetchPacientesAdmin();
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> setUsuarioActivo(String userId, bool activo) async {
    try {
      await _dataSource.setActivo(userId, activo);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}