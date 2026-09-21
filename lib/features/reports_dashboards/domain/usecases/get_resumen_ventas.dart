import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/ventas_entities.dart';
import '../repositories/i_reports_repository.dart';

class GetResumenVentasParams {
  final DateTime desde;
  final DateTime hasta;
  const GetResumenVentasParams({required this.desde, required this.hasta});
}

/// KPIs financieros del período para el dashboard de ventas (admin).
class GetResumenVentas
    extends UseCase<ResumenVentasEntity, GetResumenVentasParams> {
  final IReportsRepository _repository;
  GetResumenVentas(this._repository);

  @override
  Future<Either<Failure, ResumenVentasEntity>> call(
      GetResumenVentasParams params) {
    return _repository.getResumenVentas(
      desde: params.desde,
      hasta: params.hasta,
    );
  }
}