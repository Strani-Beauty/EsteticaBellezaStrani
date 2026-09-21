import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/ventas_entities.dart';
import '../repositories/i_reports_repository.dart';

class GetVentasPorEspecialistaParams {
  final DateTime desde;
  final DateTime hasta;
  const GetVentasPorEspecialistaParams({
    required this.desde,
    required this.hasta,
  });
}

/// Ventas agregadas por especialista para el dashboard (admin).
class GetVentasPorEspecialista extends UseCase<
    List<VentaPorEspecialistaEntity>, GetVentasPorEspecialistaParams> {
  final IReportsRepository _repository;
  GetVentasPorEspecialista(this._repository);

  @override
  Future<Either<Failure, List<VentaPorEspecialistaEntity>>> call(
      GetVentasPorEspecialistaParams params) {
    return _repository.getVentasPorEspecialista(
      desde: params.desde,
      hasta: params.hasta,
    );
  }
}