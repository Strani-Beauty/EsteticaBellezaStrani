import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/ventas_entities.dart';
import '../repositories/i_reports_repository.dart';

class GetSerieVentasParams {
  final DateTime desde;
  final DateTime hasta;
  final String agrupacion;
  const GetSerieVentasParams({
    required this.desde,
    required this.hasta,
    this.agrupacion = 'day',
  });
}

/// Serie temporal (día/semana/mes) para el dashboard (admin).
class GetSerieVentas
    extends UseCase<List<PuntoSerieVentasEntity>, GetSerieVentasParams> {
  final IReportsRepository _repository;
  GetSerieVentas(this._repository);

  @override
  Future<Either<Failure, List<PuntoSerieVentasEntity>>> call(
      GetSerieVentasParams params) {
    return _repository.getSerieVentas(
      desde: params.desde,
      hasta: params.hasta,
      agrupacion: params.agrupacion,
    );
  }
}