import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import '../entities/especialidad_admin_entity.dart';
import '../entities/financiero_entity.dart';
import '../entities/rol_entity.dart';

/// Contrato de Datos Maestros del panel admin.
abstract class IAdminMasterDataRepository {
  // ── Roles y Permisos ──────────────────────────────────────
  Future<Either<Failure, List<RolEntity>>> getRoles();
  Future<Either<Failure, List<PermisoEntity>>> getPermisos();
  Future<Either<Failure, RolEntity>> guardarRol({
    int? id,
    required String nombre,
    String? descripcion,
    String? codigo,
    bool activo,
  });
  Future<Either<Failure, void>> setRolActivo(int id, bool activo);
  Future<Either<Failure, void>> asignarPermisoRol(int rolId, int permisoId);
  Future<Either<Failure, void>> quitarPermisoRol(int rolId, int permisoId);

  // ── Especialidades ────────────────────────────────────────
  Future<Either<Failure, List<EspecialidadAdminEntity>>>
      getEspecialidadesAdmin();
  Future<Either<Failure, EspecialidadAdminEntity>> guardarEspecialidad({
    int? id,
    required String nombre,
    String? descripcion,
    bool activo,
  });
  Future<Either<Failure, void>> setEspecialidadActivo(int id, bool activo);

  // ── Comisiones / liquidaciones / pagos ────────────────────
  Future<Either<Failure, List<LiquidacionEntity>>> getLiquidaciones();
  Future<Either<Failure, List<PagoEspecialistaEntity>>> getPagosEspecialistas();
}
