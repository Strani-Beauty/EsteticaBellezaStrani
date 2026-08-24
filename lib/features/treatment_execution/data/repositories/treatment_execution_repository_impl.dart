import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import '../../domain/entities/cita_ejecucion_entity.dart';
import '../../domain/entities/consentimiento_tratamiento_entity.dart';
import '../../domain/entities/producto_aplicado_entity.dart';
import '../../domain/entities/tratamiento_entity.dart';
import '../../domain/repositories/i_treatment_execution_repository.dart';
import '../datasources/treatment_execution_supabase_datasource.dart';

/// Implementación del repositorio de treatment_execution usando Supabase.
class TreatmentExecutionRepositoryImpl
    implements ITreatmentExecutionRepository {
  final TreatmentExecutionSupabaseDataSource _dataSource;

  TreatmentExecutionRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, List<CitaEjecucionEntity>>> getMisCitas(
      String especialistaId) async {
    try {
      final models = await _dataSource.fetchMisCitas(especialistaId);
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<CitaEjecucionEntity>>> getCitasHistorial(
      String especialistaId) async {
    try {
      final models = await _dataSource.fetchCitasHistorial(especialistaId);
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, CitaEjecucionEntity>> getCitaDetalle(
      String citaId) async {
    try {
      final model = await _dataSource.fetchCitaDetalle(citaId);
      return Right(model.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ProductoAplicadoEntity>>> getProductos(
      String tratamientoId) async {
    try {
      final models = await _dataSource.fetchProductos(tratamientoId);
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ConsentimientoTratamientoEntity?>>
      getConsentimiento(String tratamientoId) async {
    try {
      final model = await _dataSource.fetchConsentimiento(tratamientoId);
      return Right(model?.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, CitaEjecucionEntity>> avanzarEstadoCita({
    required String citaId,
    required EstadoCitaEjecucion nuevoEstado,
    String? observaciones,
  }) async {
    try {
      await _dataSource.actualizarEstadoCita(
        citaId: citaId,
        nuevoEstado: nuevoEstado.toDb,
        observaciones: observaciones,
      );
      final model = await _dataSource.fetchCitaDetalle(citaId);
      return Right(model.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, TratamientoEntity>> iniciarTratamiento({
    required String citaId,
    String? evaluacionInicial,
  }) async {
    try {
      final model = await _dataSource.asegurarTratamiento(
        citaId: citaId,
        evaluacionInicial: evaluacionInicial,
      );
      return Right(model.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, TratamientoEntity>> actualizarTratamiento({
    required String tratamientoId,
    String? evaluacionInicial,
    String? observacionesFinales,
    String? recomendacionesPostTratamiento,
  }) async {
    try {
      final model = await _dataSource.actualizarTratamiento(
        tratamientoId: tratamientoId,
        evaluacionInicial: evaluacionInicial,
        observacionesFinales: observacionesFinales,
        recomendacionesPostTratamiento: recomendacionesPostTratamiento,
      );
      return Right(model.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ProductoAplicadoEntity>> agregarProducto({
    required String tratamientoId,
    required String productoNombre,
    String? fabricante,
    String? lote,
    required double cantidadTotal,
    String? unidadMedida,
    DateTime? fechaVencimiento,
    String? observaciones,
  }) async {
    try {
      final model = await _dataSource.insertarProducto(
        tratamientoId: tratamientoId,
        productoNombre: productoNombre,
        fabricante: fabricante,
        lote: lote,
        cantidadTotal: cantidadTotal,
        unidadMedida: unidadMedida,
        fechaVencimiento: fechaVencimiento,
        observaciones: observaciones,
      );
      return Right(model.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> eliminarProducto(String productoId) async {
    try {
      await _dataSource.eliminarProducto(productoId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ConsentimientoTratamientoEntity>>
      registrarConsentimiento({
    required String tratamientoId,
    required String pacienteId,
    required String tipoConsentimiento,
    required String firmaUrl,
  }) async {
    try {
      final model = await _dataSource.insertarConsentimiento(
        tratamientoId: tratamientoId,
        pacienteId: pacienteId,
        tipoConsentimiento: tipoConsentimiento,
        firmaUrl: firmaUrl,
      );
      return Right(model.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> subirFirma({
    required String tratamientoId,
    required Uint8List bytes,
  }) async {
    try {
      final url = await _dataSource.subirFirma(
        tratamientoId: tratamientoId,
        bytes: bytes,
      );
      return Right(url);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> finalizarTratamiento({
    required String citaId,
    required String tratamientoId,
    String? observacionesFinales,
    String? recomendacionesPostTratamiento,
  }) async {
    try {
      await _dataSource.finalizarTratamiento(
        citaId: citaId,
        tratamientoId: tratamientoId,
        observacionesFinales: observacionesFinales,
        recomendacionesPostTratamiento: recomendacionesPostTratamiento,
      );
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, double?>> registrarLlegada({
    required String citaId,
    required double latitud,
    required double longitud,
  }) async {
    try {
      final distancia = await _dataSource.registrarLlegada(
        citaId: citaId,
        latitud: latitud,
        longitud: longitud,
      );
      return Right(distancia);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> cancelarCita({
    required String citaId,
    String? motivo,
  }) async {
    try {
      await _dataSource.cancelarCita(citaId: citaId, motivo: motivo);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}