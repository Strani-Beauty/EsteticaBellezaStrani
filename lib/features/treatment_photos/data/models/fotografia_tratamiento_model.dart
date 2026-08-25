import '../../domain/entities/fotografia_tratamiento_entity.dart';

class FotografiaTratamientoModel {
  final String id;
  final String tratamientoId;
  final TipoFotografia tipoFotografia;
  final String archivoUrl;
  final DateTime fechaCaptura;
  final String? descripcion;
  final DateTime createdAt;
  final String? tipoFoto;

  const FotografiaTratamientoModel({
    required this.id,
    required this.tratamientoId,
    required this.tipoFotografia,
    required this.archivoUrl,
    required this.fechaCaptura,
    this.descripcion,
    required this.createdAt,
    this.tipoFoto,
  });

  factory FotografiaTratamientoModel.fromJson(Map<String, dynamic> json) {
    return FotografiaTratamientoModel(
      id: json['id'] as String,
      tratamientoId: json['tratamiento_id'] as String,
      tipoFotografia: TipoFotografia.fromDb(json['tipo_fotografia'] as String?) ??
          TipoFotografia.otro,
      archivoUrl: json['archivo_url'] as String? ?? '',
      fechaCaptura: _parseDate(json['fecha_captura']) ?? DateTime.now(),
      descripcion: json['descripcion'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      tipoFoto: json['tipo_foto'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tratamiento_id': tratamientoId,
      'tipo_fotografia': tipoFotografia.toDb,
      'archivo_url': archivoUrl,
      'fecha_captura': fechaCaptura.toIso8601String(),
      'descripcion': descripcion,
      'tipo_foto': tipoFoto,
    };
  }

  FotografiaTratamientoModel copyWith({String? archivoUrl}) {
    return FotografiaTratamientoModel(
      id: id,
      tratamientoId: tratamientoId,
      tipoFotografia: tipoFotografia,
      archivoUrl: archivoUrl ?? this.archivoUrl,
      fechaCaptura: fechaCaptura,
      descripcion: descripcion,
      createdAt: createdAt,
      tipoFoto: tipoFoto,
    );
  }

  FotografiaTratamientoEntity toEntity() {
    return FotografiaTratamientoEntity(
      id: id,
      tratamientoId: tratamientoId,
      tipoFotografia: tipoFotografia,
      archivoUrl: archivoUrl,
      fechaCaptura: fechaCaptura,
      descripcion: descripcion,
      createdAt: createdAt,
      tipoFoto: tipoFoto,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}