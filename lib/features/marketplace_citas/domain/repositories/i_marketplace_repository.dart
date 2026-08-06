import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import '../entities/especialista_mapa_entity.dart';
import '../entities/resultado_aceptacion_entity.dart';
import '../entities/solicitud_pendiente_entity.dart';

/// Contrato del marketplace de citas (mapa de pacientes).
/// Se usa fpdart [Either] para errores tipados.
/// La implementación vive en data/repositories/marketplace_repository_impl.dart
abstract class IMarketplaceRepository {
  /// Solicitudes pendientes de asignación (`PUBLICADA` / `BUSCANDO_ESPECIALISTA`).
  Future<Either<Failure, List<SolicitudPendienteEntity>>>
      getSolicitudesPendientes();

  /// Especialistas aprobados con su última ubicación registrada.
  Future<Either<Failure, List<EspecialistaMapaEntity>>>
      getEspecialistasAprobados();

  /// Última ubicación registrada del especialista actual.
  Future<Either<Failure, ({double? latitud, double? longitud})>>
      getMiUbicacion(String especialistaId);

  /// Acepta una solicitud de forma atómica ("primer aviso gana") vía RPC.
  Future<Either<Failure, ResultadoAceptacionEntity>> aceptarSolicitud({
    required String solicitudId,
    required String especialistaId,
  });
}