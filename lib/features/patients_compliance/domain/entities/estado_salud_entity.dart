import 'package:equatable/equatable.dart';

/// Estado integral del flujo de salud del paciente.
/// Es la fuente para la pantalla de consulta de estado (requisito 13) y el gate
/// de acceso a servicios (RN-020).
class EstadoSaludEntity extends Equatable {
  final bool paymentCompleted;
  final bool cuestionarioCompletado;
  final String evaluacionResultado; // 'APTO' | 'REQUIERE_REVISION' | 'NO_APTO' | 'PENDIENTE'
  final String validacionEstado; // 'APROBADA' | 'RECHAZADA' | 'VENCIDA' | 'PENDIENTE'
  final String proveedor;
  final DateTime? fechaVencimiento;

  const EstadoSaludEntity({
    required this.paymentCompleted,
    required this.cuestionarioCompletado,
    required this.evaluacionResultado,
    required this.validacionEstado,
    required this.proveedor,
    this.fechaVencimiento,
  });

  /// Habilitado para solicitar servicios con requisito médico (RN-020):
  /// validación de telemedicina APROBADA y no vencida.
  bool get habilitado =>
      validacionEstado == 'APROBADA' &&
      (fechaVencimiento == null || fechaVencimiento!.isAfter(DateTime.now()));

  bool get validacionVencida =>
      validacionEstado == 'APROBADA' &&
      fechaVencimiento != null &&
      !fechaVencimiento!.isAfter(DateTime.now());

  /// Siguiente acción sugerida para el paciente.
  String get siguientePaso {
    if (!paymentCompleted) {
      return 'Completa la cuota inicial para habilitar tu cuenta.';
    }
    if (!cuestionarioCompletado) {
      return 'Responde el cuestionario de salud.';
    }
    if (validacionEstado == 'RECHAZADA') {
      return 'Tu evaluación médica fue rechazada. Contacta a soporte para una nueva evaluación.';
    }
    if (validacionVencida) {
      return 'Tu validación médica venció. Realiza una nueva evaluación para renovarla.';
    }
    if (habilitado) {
      return 'Estás habilitado para solicitar servicios.';
    }
    return 'Completa los pasos pendientes para habilitar tu cuenta.';
  }

  @override
  List<Object?> get props =>
      [paymentCompleted, cuestionarioCompletado, evaluacionResultado, validacionEstado, fechaVencimiento];
}