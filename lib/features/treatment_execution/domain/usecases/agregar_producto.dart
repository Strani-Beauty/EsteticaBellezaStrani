import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/producto_aplicado_entity.dart';
import '../repositories/i_treatment_execution_repository.dart';

class AgregarProductoParams {
  final String tratamientoId;
  final String productoNombre;
  final String? fabricante;
  final String? lote;
  final double cantidadTotal;
  final String? unidadMedida;
  final DateTime? fechaVencimiento;
  final String? observaciones;
  const AgregarProductoParams({
    required this.tratamientoId,
    required this.productoNombre,
    this.fabricante,
    this.lote,
    this.cantidadTotal = 1,
    this.unidadMedida,
    this.fechaVencimiento,
    this.observaciones,
  });
}

/// Agrega un insumo aplicado al tratamiento.
class AgregarProducto
    extends UseCase<ProductoAplicadoEntity, AgregarProductoParams> {
  final ITreatmentExecutionRepository _repository;
  AgregarProducto(this._repository);

  @override
  Future<Either<Failure, ProductoAplicadoEntity>> call(
      AgregarProductoParams params) {
    return _repository.agregarProducto(
      tratamientoId: params.tratamientoId,
      productoNombre: params.productoNombre,
      fabricante: params.fabricante,
      lote: params.lote,
      cantidadTotal: params.cantidadTotal,
      unidadMedida: params.unidadMedida,
      fechaVencimiento: params.fechaVencimiento,
      observaciones: params.observaciones,
    );
  }
}