import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../entities/servicio_entity.dart';
import '../repositories/i_catalog_repository.dart';

class GuardarServicioParams {
  final String id; // vacío = crear
  final int? categoriaId;
  final String nombre;
  final String? descripcion;
  final double precioBase;
  final TipoPrecio tipoPrecio;
  final int? duracionEstimada;
  final bool requiereTelemedicina;
  final bool requiereFaceMap;
  final bool requiereFotos;
  final bool requiereConsentimiento;
  final bool activo;

  const GuardarServicioParams({
    this.id = '',
    this.categoriaId,
    required this.nombre,
    this.descripcion,
    required this.precioBase,
    this.tipoPrecio = TipoPrecio.precioFijo,
    this.duracionEstimada,
    this.requiereTelemedicina = false,
    this.requiereFaceMap = false,
    this.requiereFotos = false,
    this.requiereConsentimiento = false,
    this.activo = true,
  });
}

/// Crea o actualiza un servicio del catálogo (solo admin).
class GuardarServicio extends UseCase<ServicioEntity, GuardarServicioParams> {
  final ICatalogRepository _repository;
  GuardarServicio(this._repository);

  @override
  Future<Either<Failure, ServicioEntity>> call(
      GuardarServicioParams params) {
    return _repository.guardarServicio(
      id: params.id,
      categoriaId: params.categoriaId,
      nombre: params.nombre,
      descripcion: params.descripcion,
      precioBase: params.precioBase,
      tipoPrecio: params.tipoPrecio,
      duracionEstimada: params.duracionEstimada,
      requiereTelemedicina: params.requiereTelemedicina,
      requiereFaceMap: params.requiereFaceMap,
      requiereFotos: params.requiereFotos,
      requiereConsentimiento: params.requiereConsentimiento,
      activo: params.activo,
    );
  }
}