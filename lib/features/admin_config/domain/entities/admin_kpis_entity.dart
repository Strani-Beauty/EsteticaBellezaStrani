import 'package:equatable/equatable.dart';

/// Resumen de KPIs del dashboard admin (`admin_resumen_kpis`).
class AdminKpisEntity extends Equatable {
  final Map<String, int> solicitudesPorEstado;
  final int citasActivas;
  final int especialistasPendientes;
  final int medicosPendientes;
  final double ingresosTotales;
  final int totalUsuarios;

  const AdminKpisEntity({
    this.solicitudesPorEstado = const {},
    this.citasActivas = 0,
    this.especialistasPendientes = 0,
    this.medicosPendientes = 0,
    this.ingresosTotales = 0,
    this.totalUsuarios = 0,
  });

  factory AdminKpisEntity.fromJson(Map<String, dynamic> json) {
    final solicitudes = <String, int>{};
    final raw = json['solicitudes_por_estado'];
    if (raw is Map) {
      raw.forEach((k, v) {
        solicitudes[k.toString()] = (v as num?)?.toInt() ?? 0;
      });
    }
    return AdminKpisEntity(
      solicitudesPorEstado: solicitudes,
      citasActivas: (json['citas_activas'] as num?)?.toInt() ?? 0,
      especialistasPendientes:
          (json['especialistas_pendientes'] as num?)?.toInt() ?? 0,
      medicosPendientes: (json['medicos_pendientes'] as num?)?.toInt() ?? 0,
      ingresosTotales: (json['ingresos_totales'] as num?)?.toDouble() ?? 0,
      totalUsuarios: (json['total_usuarios'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [
        solicitudesPorEstado,
        citasActivas,
        especialistasPendientes,
        medicosPendientes,
        ingresosTotales,
        totalUsuarios,
      ];
}
