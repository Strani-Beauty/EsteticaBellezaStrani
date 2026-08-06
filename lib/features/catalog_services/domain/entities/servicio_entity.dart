import 'package:equatable/equatable.dart';
import 'categoria_servicio_entity.dart';

/// Tipo de precio de un servicio (columna `tipo_precio`, enum `tipo_precio_enum`).
enum TipoPrecio {
  precioFijo,
  porUnidad,
  porJeringa,
  porSesion,
  porPlan;

  static const Map<TipoPrecio, String> _db = {
    TipoPrecio.precioFijo: 'PRECIO_FIJO',
    TipoPrecio.porUnidad: 'POR_UNIDAD',
    TipoPrecio.porJeringa: 'POR_JERINGA',
    TipoPrecio.porSesion: 'POR_SESION',
    TipoPrecio.porPlan: 'POR_PLAN',
  };

  String get toDb => _db[this]!;

  static TipoPrecio? fromDb(String? value) {
    for (final entry in _db.entries) {
      if (entry.value == value?.toUpperCase()) return entry.key;
    }
    return null;
  }
}

/// Entidad de dominio: `servicios`.
/// Servicio del catálogo con sus flags de prerrequisitos.
class ServicioEntity extends Equatable {
  final String id; // uuid PK
  final int? categoriaId; // FK categorias_servicio.id
  final String nombre;
  final String? descripcion;
  final double precioBase;
  final TipoPrecio tipoPrecio;
  final int? duracionEstimada; // minutos
  final bool requiereTelemedicina;
  final bool requiereFaceMap;
  final bool requiereFotos;
  final bool requiereConsentimiento;
  final bool activo;
  final CategoriaServicioEntity? categoria; // join embebido

  const ServicioEntity({
    required this.id,
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
    this.categoria,
  });

  String? get nombreCategoria => categoria?.nombre;

  @override
  List<Object?> get props => [id, categoriaId, nombre, precioBase, tipoPrecio];
}
