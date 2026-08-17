/// Adelanto calculado para un servicio del catálogo.
/// `porcentaje` es el % configurado (`configuracion_sistema.adelanto_porcentaje`)
/// y `monto` el resultado de aplicar ese porcentaje al precio del servicio.
class AdelantoServicioEntity {
  final double porcentaje;
  final double monto;

  const AdelantoServicioEntity({
    required this.porcentaje,
    required this.monto,
  });
}
