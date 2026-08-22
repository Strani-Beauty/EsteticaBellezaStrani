import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../entities/especialidad_admin_entity.dart';
import '../repositories/i_admin_master_data_repository.dart';

class GetEspecialidadesAdmin extends NoParamsUseCase<List<EspecialidadAdminEntity>> {
  final IAdminMasterDataRepository _repository;
  GetEspecialidadesAdmin(this._repository);
  @override
  Future<Either<Failure, List<EspecialidadAdminEntity>>> call() async {
    try {
      return await _repository.getEspecialidadesAdmin();
    } catch (e) {
      return Left(ServerFailure('No se pudieron cargar las especialidades: $e'));
    }
  }
}

class GuardarEspecialidadParams {
  final int? id;
  final String nombre;
  final String? descripcion;
  final bool activo;
  const GuardarEspecialidadParams({
    this.id,
    required this.nombre,
    this.descripcion,
    this.activo = true,
  });
}

class GuardarEspecialidad
    extends UseCase<EspecialidadAdminEntity, GuardarEspecialidadParams> {
  final IAdminMasterDataRepository _repository;
  GuardarEspecialidad(this._repository);
  @override
  Future<Either<Failure, EspecialidadAdminEntity>> call(
      GuardarEspecialidadParams params) async {
    try {
      return await _repository.guardarEspecialidad(
        id: params.id,
        nombre: params.nombre,
        descripcion: params.descripcion,
        activo: params.activo,
      );
    } catch (e) {
      return Left(ServerFailure('No se pudo guardar la especialidad: $e'));
    }
  }
}

class SetEspecialidadActivoParams {
  final int id;
  final bool activo;
  const SetEspecialidadActivoParams(this.id, this.activo);
}

class SetEspecialidadActivo extends UseCase<void, SetEspecialidadActivoParams> {
  final IAdminMasterDataRepository _repository;
  SetEspecialidadActivo(this._repository);
  @override
  Future<Either<Failure, void>> call(SetEspecialidadActivoParams params) async {
    try {
      return await _repository.setEspecialidadActivo(params.id, params.activo);
    } catch (e) {
      return Left(ServerFailure('No se pudo actualizar la especialidad: $e'));
    }
  }
}
