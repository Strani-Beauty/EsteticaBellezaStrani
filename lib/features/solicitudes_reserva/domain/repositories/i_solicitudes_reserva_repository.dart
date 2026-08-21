import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import '../entities/seguimiento_solicitud_entity.dart';
import '../entities/servicio_seleccionado_entity.dart';
import '../entities/solicitud_reserva_entity.dart';

/// Contrato del flujo de reserva del paciente.
/// La implementación vive en data/repositories/solicitudes_reserva_repository_impl.dart
abstract class ISolicitudesReservaRepository {
  /// Crea la solicitud PENDIENTE_PAGO con uno o varios servicios
  /// (`solicitud_detalles`) y la obligación de pago PARCIAL.
  Future<Either<Failure, SolicitudReservaEntity>> crearSolicitudReserva({
    required String profileId,
    required List<ServicioSeleccionadoEntity> servicios,
    required String direccionId,
    DateTime? fechaProgramada,
    double? radioKm,
    String? observaciones,
    required bool pagoTotal,
  });

  /// Confirma el depósito y publica la solicitud (modo simulado / pruebas).
  /// En producción (enforce_pago_real) esto lo hace el webhook.
  Future<Either<Failure, String>> confirmarPagoDeposito({
    required String solicitudId,
    required String stripePaymentId,
    required String concepto,
    required double monto,
  });

  /// Lista de solicitudes del paciente con detalles, pago y cita asignada.
  Future<Either<Failure, List<SeguimientoSolicitudEntity>>>
      getMisSolicitudes(String profileId);

  /// Dirección principal del paciente (para la zona de prestación).
  Future<Either<Failure, DireccionPrincipalEntity?>>
      getMiDireccionPrincipal(String profileId);

  /// Configuración del flujo (radio y si el pago se confirma por webhook).
  Future<Either<Failure, ConfigReservaEntity>> getConfigReserva();
}
