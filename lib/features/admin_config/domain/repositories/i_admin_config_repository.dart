import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import '../entities/admin_kpis_entity.dart';
import '../entities/config_sistema_entity.dart';

/// Contrato del módulo admin_config (panel de administración).
abstract class IAdminConfigRepository {
  /// KPIs del home del dashboard (RPC `admin_resumen_kpis`).
  Future<Either<Failure, AdminKpisEntity>> getKpis();

  /// Lista de claves de `configuracion_sistema`.
  Future<Either<Failure, List<ConfigSistemaEntity>>> getConfiguracion();

  /// Actualiza el valor de una clave de configuración.
  Future<Either<Failure, void>> updateConfiguracion(
      String clave, String valor);
}
