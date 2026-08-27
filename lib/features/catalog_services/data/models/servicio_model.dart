import '../../domain/entities/categoria_servicio_entity.dart';
import '../../domain/entities/servicio_entity.dart';
import 'categoria_servicio_model.dart';

class ServicioModel {
  final String id;
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
  final String? imagenUrl;
  final CategoriaServicioEntity? categoria;

  const ServicioModel({
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
    this.imagenUrl,
    this.categoria,
  });

  factory ServicioModel.fromJson(Map<String, dynamic> json) {
    final categoriaRaw = json['categorias_servicio'];
    CategoriaServicioEntity? categoria;
    if (categoriaRaw is Map<String, dynamic>) {
      categoria = CategoriaServicioModel.fromJson(categoriaRaw).toEntity();
    }

    return ServicioModel(
      id: json['id'] as String? ?? '',
      categoriaId: (json['categoria_id'] as num?)?.toInt(),
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String?,
      precioBase: (json['precio_base'] as num?)?.toDouble() ?? 0,
      tipoPrecio:
          TipoPrecio.fromDb(json['tipo_precio'] as String?) ??
              TipoPrecio.precioFijo,
      duracionEstimada: (json['duracion_estimada'] as num?)?.toInt(),
      requiereTelemedicina: json['requiere_telemedicina'] as bool? ?? false,
      requiereFaceMap: json['requiere_face_map'] as bool? ?? false,
      requiereFotos: json['requiere_fotos'] as bool? ?? false,
      requiereConsentimiento:
          json['requiere_consentimiento'] as bool? ?? false,
      activo: json['activo'] as bool? ?? true,
      imagenUrl: json['imagen_url'] as String?,
      categoria: categoria,
    );
  }

  ServicioEntity toEntity() {
    return ServicioEntity(
      id: id,
      categoriaId: categoriaId,
      nombre: nombre,
      descripcion: descripcion,
      precioBase: precioBase,
      tipoPrecio: tipoPrecio,
      duracionEstimada: duracionEstimada,
      requiereTelemedicina: requiereTelemedicina,
      requiereFaceMap: requiereFaceMap,
      requiereFotos: requiereFotos,
      requiereConsentimiento: requiereConsentimiento,
      activo: activo,
      imagenUrl: imagenUrl,
      categoria: categoria,
    );
  }
}
