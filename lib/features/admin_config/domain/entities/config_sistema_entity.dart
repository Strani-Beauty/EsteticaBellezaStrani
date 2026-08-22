import 'package:equatable/equatable.dart';

/// Clave de configuración del sistema (`configuracion_sistema`).
class ConfigSistemaEntity extends Equatable {
  final String id;
  final String clave;
  final String valor;
  final String tipoDato;
  final String? descripcion;
  final bool activo;

  const ConfigSistemaEntity({
    required this.id,
    required this.clave,
    required this.valor,
    required this.tipoDato,
    this.descripcion,
    this.activo = true,
  });

  @override
  List<Object?> get props => [id, clave, valor, tipoDato];
}
