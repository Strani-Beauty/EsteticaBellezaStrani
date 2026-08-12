import 'package:equatable/equatable.dart';

/// Resultado de la aceptación de una solicitud (RPC `aceptar_solicitud`).
class ResultadoAceptacionEntity extends Equatable {
  final bool aceptada;
  final String? citaId;
  final String? motivo; // OK | ASIGNADA | EXPIRADA | NO_ENCONTRADA

  const ResultadoAceptacionEntity({
    required this.aceptada,
    this.citaId,
    this.motivo,
  });

  bool get yaAsignada => !aceptada && motivo == 'ASIGNADA';
  bool get expirada => !aceptada && motivo == 'EXPIRADA';
  bool get noAprobado => !aceptada && motivo == 'NO_APROBADO';

  @override
  List<Object?> get props => [aceptada, citaId, motivo];
}
