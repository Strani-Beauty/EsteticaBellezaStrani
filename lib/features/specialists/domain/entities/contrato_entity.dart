import 'package:equatable/equatable.dart';

/// Método de firma del contrato (columna `metodo_firma`).
enum MetodoFirma {
  touch,
  digital;

  static const Map<MetodoFirma, String> _db = {
    MetodoFirma.touch: 'TOUCH',
    MetodoFirma.digital: 'DIGITAL',
  };

  String get toDb => _db[this]!;

  static MetodoFirma? fromDb(String? value) {
    for (final entry in _db.entries) {
      if (entry.value == value?.toUpperCase()) return entry.key;
    }
    return null;
  }
}

/// Entidad de dominio: `contratos`.
class ContratoEntity extends Equatable {
  final String id;               // uuid PK
  final String especialistaId;   // FK especialistas.id
  final int versionContrato;
  final String? urlDocumento;
  final bool firmado;
  final DateTime? fechaFirma;
  final MetodoFirma? metodoFirma;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ContratoEntity({
    required this.id,
    required this.especialistaId,
    required this.versionContrato,
    this.urlDocumento,
    required this.firmado,
    this.fechaFirma,
    this.metodoFirma,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isSigned => firmado;

  ContratoEntity copyWith({
    String? urlDocumento,
    bool? firmado,
    DateTime? fechaFirma,
    MetodoFirma? metodoFirma,
    DateTime? updatedAt,
  }) {
    return ContratoEntity(
      id: id,
      especialistaId: especialistaId,
      versionContrato: versionContrato,
      urlDocumento: urlDocumento ?? this.urlDocumento,
      firmado: firmado ?? this.firmado,
      fechaFirma: fechaFirma ?? this.fechaFirma,
      metodoFirma: metodoFirma ?? this.metodoFirma,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, especialistaId, versionContrato, firmado];
}