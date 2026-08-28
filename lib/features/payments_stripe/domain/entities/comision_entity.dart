/// Comisión de la plataforma por cita completada (`comisiones`).
class ComisionEntity {
  final String id;
  final String citaId;
  final double porcentaje;
  final double montoComision;
  final double montoEspecialista;

  const ComisionEntity({
    required this.id,
    required this.citaId,
    required this.porcentaje,
    required this.montoComision,
    required this.montoEspecialista,
  });
}