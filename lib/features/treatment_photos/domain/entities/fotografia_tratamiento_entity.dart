import 'package:equatable/equatable.dart';

/// Tipo de fotografía del tratamiento (columna `tipo_fotografia`).
enum TipoFotografia {
  pre,
  post,
  otro;

  static const Map<TipoFotografia, String> _db = {
    TipoFotografia.pre: 'PRE',
    TipoFotografia.post: 'POST',
    TipoFotografia.otro: 'OTRO',
  };

  String get toDb => _db[this]!;

  static TipoFotografia? fromDb(String? value) {
    for (final entry in _db.entries) {
      if (entry.value == value?.toUpperCase()) return entry.key;
    }
    return null;
  }
}

/// Entidad de dominio: `fotografias_tratamiento`.
/// Evidencia fotográfica (PRE/POST/OTRO) de un tratamiento.
class FotografiaTratamientoEntity extends Equatable {
  final String id;               // uuid PK
  final String tratamientoId;    // FK tratamientos.id
  final TipoFotografia tipoFotografia;
  final String archivoUrl;       // URL pública del objeto en Storage
  final DateTime fechaCaptura;
  final String? descripcion;
  final DateTime createdAt;
  final String? tipoFoto;        // columna libre `tipo_foto` (text)

  const FotografiaTratamientoEntity({
    required this.id,
    required this.tratamientoId,
    required this.tipoFotografia,
    required this.archivoUrl,
    required this.fechaCaptura,
    this.descripcion,
    required this.createdAt,
    this.tipoFoto,
  });

  bool get esPre => tipoFotografia == TipoFotografia.pre;
  bool get esPost => tipoFotografia == TipoFotografia.post;

  @override
  List<Object?> get props => [id, tratamientoId, tipoFotografia, archivoUrl];
}