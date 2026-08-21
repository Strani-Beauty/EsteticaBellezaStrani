import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../../../app/core/usecases/use_case.dart';
import '../entities/servicio_seleccionado_entity.dart';
import '../entities/solicitud_reserva_entity.dart';
import '../repositories/i_solicitudes_reserva_repository.dart';

class CrearSolicitudReservaParams {
  final String profileId;
  final List<ServicioSeleccionadoEntity> servicios;
  final String direccionId;
  final DateTime? fechaProgramada;
  final double? radioKm;
  final String? observaciones;
  final bool pagoTotal;

  const CrearSolicitudReservaParams({
    required this.profileId,
    required this.servicios,
    required this.direccionId,
    this.fechaProgramada,
    this.radioKm,
    this.observaciones,
    this.pagoTotal = false,
  });
}

/// Crea la solicitud de reserva en estado PENDIENTE_PAGO.
class CrearSolicitudReserva
    extends UseCase<SolicitudReservaEntity, CrearSolicitudReservaParams> {
  final ISolicitudesReservaRepository _repository;

  CrearSolicitudReserva(this._repository);

  @override
  Future<Either<Failure, SolicitudReservaEntity>> call(
      CrearSolicitudReservaParams params) async {
    try {
      final result = await _repository.crearSolicitudReserva(
        profileId: params.profileId,
        servicios: params.servicios,
        direccionId: params.direccionId,
        fechaProgramada: params.fechaProgramada,
        radioKm: params.radioKm,
        observaciones: params.observaciones,
        pagoTotal: params.pagoTotal,
      );
      return result;
    } catch (e) {
      return Left(ServerFailure('No se pudo crear la solicitud: $e'));
    }
  }
}
