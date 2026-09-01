import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../domain/entities/admin_kpis_entity.dart';
import '../../domain/entities/config_sistema_entity.dart';
import '../../domain/repositories/i_admin_config_repository.dart';
import '../datasources/admin_config_supabase_datasource.dart';

/// Implementación del repositorio de admin_config sobre Supabase.
class AdminConfigRepositoryImpl implements IAdminConfigRepository {
  final AdminConfigSupabaseDataSource _dataSource;

  const AdminConfigRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, AdminKpisEntity>> getKpis() async {
    try {
      return Right(await _dataSource.fetchKpis());
    } catch (e) {
      debugPrint('❌ [getKpis] $e');
      return Left(ServerFailure('No se pudieron cargar los indicadores: $e'));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getMisPermisos() async {
    try {
      return Right(await _dataSource.fetchMisPermisos());
    } catch (e) {
      debugPrint('❌ [getMisPermisos] $e');
      return Left(ServerFailure('No se pudieron cargar tus permisos: $e'));
    }
  }

  @override
  Future<Either<Failure, List<ConfigSistemaEntity>>> getConfiguracion() async {
    try {
      return Right(await _dataSource.fetchConfiguracion());
    } catch (e) {
      debugPrint('❌ [getConfiguracion] $e');
      return Left(ServerFailure('No se pudo cargar la configuración: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateConfiguracion(
      String clave, String valor) async {
    try {
      await _dataSource.updateConfiguracion(clave, valor);
      return const Right(null);
    } catch (e) {
      debugPrint('❌ [updateConfiguracion] $e');
      return Left(ServerFailure('No se pudo guardar la configuración: $e'));
    }
  }
}
