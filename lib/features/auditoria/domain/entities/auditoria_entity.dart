/// Entidad de dominio: registro de auditoría (`auditoria`).
class AuditoriaEntity {
  final String id;
  final String? usuarioId;
  final String? usuarioNombre;
  final String accion;
  final String entidad;
  final String? entidadId;
  final Map<String, dynamic>? detalle;
  final DateTime fecha;

  const AuditoriaEntity({
    required this.id,
    this.usuarioId,
    this.usuarioNombre,
    required this.accion,
    required this.entidad,
    this.entidadId,
    this.detalle,
    required this.fecha,
  });

  String get accionLabel => _accionLabel(accion);

  static String _accionLabel(String a) => switch (a) {
        'INSERT' => 'Creación',
        'UPDATE' => 'Actualización',
        'DELETE' => 'Eliminación',
        _ => a,
      };
}