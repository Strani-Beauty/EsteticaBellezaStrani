import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import '../entities/ventas_entities.dart';

/// Contrato del repositorio de reportes del dashboard de ventas (admin).
abstract class IReportsRepository {
  /// KPIs financieros del período (montos recibidos/pagados, comisión, etc.).
  Future<Either<Failure, ResumenVentasEntity>> getResumenVentas({
    required DateTime desde,
    required DateTime hasta,
  });

  /// Ventas agregadas por servicio en el período.
  Future<Either<Failure, List<VentaPorServicioEntity>>> getVentasPorServicio({
    required DateTime desde,
    required DateTime hasta,
  });

  /// Ventas agregadas por especialista en el período.
  Future<Either<Failure, List<VentaPorEspecialistaEntity>>>
      getVentasPorEspecialista({
    required DateTime desde,
    required DateTime hasta,
  });

  /// Serie temporal (día/semana/mes) de montos y citas del período.
  Future<Either<Failure, List<PuntoSerieVentasEntity>>> getSerieVentas({
    required DateTime desde,
    required DateTime hasta,
    String agrupacion = 'day',
  });
}