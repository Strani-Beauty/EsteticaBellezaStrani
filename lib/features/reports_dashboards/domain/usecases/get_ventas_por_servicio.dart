import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/ventas_entities.dart';
import '../repositories/i_reports_repository.dart';

class GetVentasPorServicioParams {
  final DateTime desde;
  final DateTime hasta;
  const GetVentasPorServicioParams({
    required this.desde,
    required this.hasta,
  });
}

/// Ventas agregadas por servicio para el dashboard (admin).
class GetVentasPorServicio
    extends UseCase<List<VentaPorServicioEntity>, GetVentasPorServicioParams> {
  final IReportsRepository _repository;
  GetVentasPorServicio(this._repository);

  @override
  Future<Either<Failure, List<VentaPorServicioEntity>>> call(
      GetVentasPorServicioParams params) {
    return _repository.getVentasPorServicio(
      desde: params.desde,
      hasta: params.hasta,
    );
  }
}