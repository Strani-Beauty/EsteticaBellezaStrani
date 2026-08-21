import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../app/core/error/failures.dart';
import '../../domain/entities/seguimiento_solicitud_entity.dart';
import '../../domain/entities/servicio_seleccionado_entity.dart';
import '../../domain/entities/solicitud_reserva_entity.dart';
import '../../domain/repositories/i_solicitudes_reserva_repository.dart';
import '../datasources/solicitudes_reserva_supabase_datasource.dart';

/// Implementación del repositorio de reserva sobre el datasource de Supabase.
class SolicitudesReservaRepositoryImpl implements ISolicitudesReservaRepository {
  final SolicitudesReservaSupabaseDataSource _dataSource;

  const SolicitudesReservaRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, SolicitudReservaEntity>> crearSolicitudReserva({
    required String profileId,
    required List<ServicioSeleccionadoEntity> servicios,
    required String direccionId,
    DateTime? fechaProgramada,
    double? radioKm,
    String? observaciones,
    required bool pagoTotal,
  }) async {
    try {
      final model = await _dataSource.crearSolicitudReserva(
        profileId: profileId,
        servicios: servicios,
        direccionId: direccionId,
        fechaProgramada: fechaProgramada,
        radioKm: radioKm,
        observaciones: observaciones,
        pagoTotal: pagoTotal,
      );
      return Right(model);
    } catch (e) {
      debugPrint('❌ [crearSolicitudReserva] $e');
      return Left(ServerFailure('No se pudo crear la solicitud: $e'));
    }
  }

  @override
  Future<Either<Failure, String>> confirmarPagoDeposito({
    required String solicitudId,
    required String stripePaymentId,
    required String concepto,
    required double monto,
  }) async {
    try {
      final motivo = await _dataSource.confirmarPagoDeposito(
        solicitudId: solicitudId,
        stripePaymentId: stripePaymentId,
        concepto: concepto,
        monto: monto,
      );
      return Right(motivo);
    } catch (e) {
      debugPrint('❌ [confirmarPagoDeposito] $e');
      return Left(PaymentFailure('No se pudo confirmar el pago: $e'));
    }
  }

  @override
  Future<Either<Failure, List<SeguimientoSolicitudEntity>>> getMisSolicitudes(
      String profileId) async {
    try {
      final models = await _dataSource.fetchMisSolicitudes(profileId);
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      debugPrint('❌ [getMisSolicitudes] $e');
      return Left(ServerFailure('No se pudieron cargar tus solicitudes: $e'));
    }
  }

  @override
  Future<Either<Failure, DireccionPrincipalEntity?>>
      getMiDireccionPrincipal(String profileId) async {
    try {
      final entity = await _dataSource.fetchMiDireccionPrincipal(profileId);
      return Right(entity);
    } catch (e) {
      debugPrint('❌ [getMiDireccionPrincipal] $e');
      return Left(ServerFailure('No se pudo cargar tu dirección: $e'));
    }
  }

  @override
  Future<Either<Failure, ConfigReservaEntity>> getConfigReserva() async {
    try {
      final entity = await _dataSource.fetchConfigReserva();
      return Right(entity);
    } catch (e) {
      debugPrint('❌ [getConfigReserva] $e');
      return Left(ServerFailure('No se pudo cargar la configuración: $e'));
    }
  }
}
