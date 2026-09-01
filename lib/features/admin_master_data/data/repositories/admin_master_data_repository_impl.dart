import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../domain/entities/especialidad_admin_entity.dart';
import '../../domain/entities/financiero_entity.dart';
import '../../domain/entities/rol_entity.dart';
import '../../domain/repositories/i_admin_master_data_repository.dart';
import '../datasources/admin_master_data_supabase_datasource.dart';

/// Implementación del repositorio de Datos Maestros.
class AdminMasterDataRepositoryImpl implements IAdminMasterDataRepository {
  final AdminMasterDataSupabaseDataSource _dataSource;

  const AdminMasterDataRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, List<RolEntity>>> getRoles() async {
    try {
      return Right(await _dataSource.fetchRoles());
    } catch (e) {
      return Left(ServerFailure('No se pudieron cargar los roles: $e'));
    }
  }

  @override
  Future<Either<Failure, List<PermisoEntity>>> getPermisos() async {
    try {
      return Right(await _dataSource.fetchPermisos());
    } catch (e) {
      return Left(ServerFailure('No se pudieron cargar los permisos: $e'));
    }
  }

  @override
  Future<Either<Failure, RolEntity>> guardarRol({
    int? id,
    required String nombre,
    String? descripcion,
    String? codigo,
    bool activo = true,
  }) async {
    try {
      return Right(await _dataSource.guardarRol(
        id: id,
        nombre: nombre,
        descripcion: descripcion,
        codigo: codigo,
        activo: activo,
      ));
    } catch (e) {
      return Left(ServerFailure('No se pudo guardar el rol: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> setRolActivo(int id, bool activo) async {
    try {
      await _dataSource.setRolActivo(id, activo);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('No se pudo actualizar el rol: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> asignarPermisoRol(
      int rolId, int permisoId) async {
    try {
      await _dataSource.asignarPermisoRol(rolId, permisoId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('No se pudo asignar el permiso: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> quitarPermisoRol(
      int rolId, int permisoId) async {
    try {
      await _dataSource.quitarPermisoRol(rolId, permisoId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('No se pudo quitar el permiso: $e'));
    }
  }

  @override
  Future<Either<Failure, List<EspecialidadAdminEntity>>>
      getEspecialidadesAdmin() async {
    try {
      return Right(await _dataSource.fetchEspecialidadesAdmin());
    } catch (e) {
      return Left(ServerFailure('No se pudieron cargar las especialidades: $e'));
    }
  }

  @override
  Future<Either<Failure, EspecialidadAdminEntity>> guardarEspecialidad({
    int? id,
    required String nombre,
    String? descripcion,
    bool activo = true,
  }) async {
    try {
      return Right(await _dataSource.guardarEspecialidad(
        id: id,
        nombre: nombre,
        descripcion: descripcion,
        activo: activo,
      ));
    } catch (e) {
      return Left(ServerFailure('No se pudo guardar la especialidad: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> setEspecialidadActivo(
      int id, bool activo) async {
    try {
      await _dataSource.setEspecialidadActivo(id, activo);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('No se pudo actualizar la especialidad: $e'));
    }
  }

  @override
  Future<Either<Failure, List<LiquidacionEntity>>> getLiquidaciones() async {
    try {
      return Right(await _dataSource.fetchLiquidaciones());
    } catch (e) {
      return Left(ServerFailure('No se pudieron cargar las liquidaciones: $e'));
    }
  }

  @override
  Future<Either<Failure, List<PagoEspecialistaEntity>>>
      getPagosEspecialistas() async {
    try {
      return Right(await _dataSource.fetchPagosEspecialistas());
    } catch (e) {
      return Left(
          ServerFailure('No se pudieron cargar los pagos a especialistas: $e'));
    }
  }

  @override
  Future<Either<Failure, List<LiquidacionEntity>>> getMisLiquidaciones(
      String especialistaId) async {
    try {
      return Right(await _dataSource.fetchMisLiquidaciones(especialistaId));
    } catch (e) {
      return Left(ServerFailure('No se pudieron cargar tus liquidaciones: $e'));
    }
  }

  @override
  Future<Either<Failure, List<PagoEspecialistaEntity>>>
      getMisPagosEspecialistas(String especialistaId) async {
    try {
      return Right(await _dataSource.fetchMisPagosEspecialistas(especialistaId));
    } catch (e) {
      return Left(ServerFailure('No se pudieron cargar tus pagos: $e'));
    }
  }

  @override
  Future<Either<Failure, List<CitaFinalizadaAdminEntity>>>
      getCitasFinalizadasAdmin({
    required DateTime desde,
    required DateTime hasta,
  }) async {
    try {
      return Right(await _dataSource.fetchCitasFinalizadasAdmin(
        desde: desde,
        hasta: hasta,
      ));
    } catch (e) {
      return Left(
          ServerFailure('No se pudieron cargar las citas terminadas: $e'));
    }
  }

  @override
  Future<Either<Failure, List<DetalleLiquidacionEntity>>>
      getLiquidacionDetalles(String liquidacionId) async {
    try {
      return Right(await _dataSource.fetchLiquidacionDetalles(liquidacionId));
    } catch (e) {
      return Left(ServerFailure('No se pudieron cargar los detalles: $e'));
    }
  }

  @override
  Future<Either<Failure, String>> cambiarEstadoLiquidacion(
      String liquidacionId, String nuevoEstado) async {
    try {
      return Right(await _dataSource.cambiarEstadoLiquidacion(
          liquidacionId, nuevoEstado));
    } catch (e) {
      return Left(ServerFailure('No se pudo cambiar el estado: $e'));
    }
  }

  @override
  Future<Either<Failure, String>> registrarPagoEspecialista({
    required String liquidacionId,
    required String metodoPago,
    String? referenciaPago,
    String? comprobanteUrl,
    String? notas,
    double? montoPagado,
  }) async {
    try {
      return Right(await _dataSource.registrarPagoEspecialista(
        liquidacionId: liquidacionId,
        metodoPago: metodoPago,
        referenciaPago: referenciaPago,
        comprobanteUrl: comprobanteUrl,
        notas: notas,
        montoPagado: montoPagado,
      ));
    } catch (e) {
      return Left(ServerFailure('No se pudo registrar el pago: $e'));
    }
  }

  @override
  Future<Either<Failure, String>> subirComprobantePago({
    required String liquidacionId,
    required List<int> bytes,
    required String nombreArchivo,
  }) async {
    try {
      return Right(await _dataSource.subirComprobantePago(
        liquidacionId: liquidacionId,
        bytes: bytes,
        nombreArchivo: nombreArchivo,
      ));
    } catch (e) {
      return Left(ServerFailure('No se pudo subir el comprobante: $e'));
    }
  }

  @override
  Future<Either<Failure, int>> getInicioSemanaLiquidacion() async {
    try {
      return Right(await _dataSource.fetchInicioSemanaLiquidacion());
    } catch (e) {
      return Left(ServerFailure('No se pudo leer la configuración: $e'));
    }
  }

  @override
  Future<Either<Failure, String?>> firmarComprobante(String path) async {
    try {
      return Right(await _dataSource.firmarComprobante(path));
    } catch (e) {
      return Left(ServerFailure('No se pudo firmar el comprobante: $e'));
    }
  }
}
