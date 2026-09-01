import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import '../entities/auditoria_entity.dart';

/// Filtros opcionales para la consulta de auditoría.
class AuditoriaFiltros {
  final String? entidad;
  final String? accion;
  final DateTime? desde;
  final DateTime? hasta;
  final int? limite;

  const AuditoriaFiltros({
    this.entidad,
    this.accion,
    this.desde,
    this.hasta,
    this.limite,
  });
}

/// Contrato del repositorio de auditoría.
abstract class IAuditoriaRepository {
  /// Consulta registros de auditoría con filtros opcionales.
  Future<Either<Failure, List<AuditoriaEntity>>> getAuditoria(
      AuditoriaFiltros filtros);
}