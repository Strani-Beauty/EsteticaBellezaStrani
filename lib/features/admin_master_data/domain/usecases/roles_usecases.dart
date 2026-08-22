import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../entities/rol_entity.dart';
import '../repositories/i_admin_master_data_repository.dart';

class GetRoles extends NoParamsUseCase<List<RolEntity>> {
  final IAdminMasterDataRepository _repository;
  GetRoles(this._repository);
  @override
  Future<Either<Failure, List<RolEntity>>> call() async {
    try {
      return await _repository.getRoles();
    } catch (e) {
      return Left(ServerFailure('No se pudieron cargar los roles: $e'));
    }
  }
}

class GetPermisos extends NoParamsUseCase<List<PermisoEntity>> {
  final IAdminMasterDataRepository _repository;
  GetPermisos(this._repository);
  @override
  Future<Either<Failure, List<PermisoEntity>>> call() async {
    try {
      return await _repository.getPermisos();
    } catch (e) {
      return Left(ServerFailure('No se pudieron cargar los permisos: $e'));
    }
  }
}

class GuardarRolParams {
  final int? id;
  final String nombre;
  final String? descripcion;
  final String? codigo;
  final bool activo;
  const GuardarRolParams({
    this.id,
    required this.nombre,
    this.descripcion,
    this.codigo,
    this.activo = true,
  });
}

class GuardarRol extends UseCase<RolEntity, GuardarRolParams> {
  final IAdminMasterDataRepository _repository;
  GuardarRol(this._repository);
  @override
  Future<Either<Failure, RolEntity>> call(GuardarRolParams params) async {
    try {
      return await _repository.guardarRol(
        id: params.id,
        nombre: params.nombre,
        descripcion: params.descripcion,
        codigo: params.codigo,
        activo: params.activo,
      );
    } catch (e) {
      return Left(ServerFailure('No se pudo guardar el rol: $e'));
    }
  }
}

class SetRolActivoParams {
  final int id;
  final bool activo;
  const SetRolActivoParams(this.id, this.activo);
}

class SetRolActivo extends UseCase<void, SetRolActivoParams> {
  final IAdminMasterDataRepository _repository;
  SetRolActivo(this._repository);
  @override
  Future<Either<Failure, void>> call(SetRolActivoParams params) async {
    try {
      return await _repository.setRolActivo(params.id, params.activo);
    } catch (e) {
      return Left(ServerFailure('No se pudo actualizar el rol: $e'));
    }
  }
}

class AsignarPermisoRolParams {
  final int rolId;
  final int permisoId;
  const AsignarPermisoRolParams(this.rolId, this.permisoId);
}

class AsignarPermisoRol extends UseCase<void, AsignarPermisoRolParams> {
  final IAdminMasterDataRepository _repository;
  AsignarPermisoRol(this._repository);
  @override
  Future<Either<Failure, void>> call(AsignarPermisoRolParams params) async {
    try {
      return await _repository.asignarPermisoRol(params.rolId, params.permisoId);
    } catch (e) {
      return Left(ServerFailure('No se pudo asignar el permiso: $e'));
    }
  }
}

class QuitarPermisoRolParams {
  final int rolId;
  final int permisoId;
  const QuitarPermisoRolParams(this.rolId, this.permisoId);
}

class QuitarPermisoRol extends UseCase<void, QuitarPermisoRolParams> {
  final IAdminMasterDataRepository _repository;
  QuitarPermisoRol(this._repository);
  @override
  Future<Either<Failure, void>> call(QuitarPermisoRolParams params) async {
    try {
      return await _repository.quitarPermisoRol(params.rolId, params.permisoId);
    } catch (e) {
      return Left(ServerFailure('No se pudo quitar el permiso: $e'));
    }
  }
}
