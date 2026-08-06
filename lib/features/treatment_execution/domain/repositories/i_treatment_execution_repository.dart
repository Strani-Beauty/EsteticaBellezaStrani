import 'package:fpdart/fpdart.dart';
import 'dart:typed_data';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import '../entities/cita_ejecucion_entity.dart';
import '../entities/consentimiento_tratamiento_entity.dart';
import '../entities/producto_aplicado_entity.dart';
import '../entities/tratamiento_entity.dart';

/// Contrato del módulo treatment_execution.
/// Se usa fpdart [Either] para errores tipados.
/// La implementación vive en data/repositories/treatment_execution_repository_impl.dart
abstract class ITreatmentExecutionRepository {
  /// Citas asignadas al especialista que aún no terminan su ciclo.
  Future<Either<Failure, List<CitaEjecucionEntity>>> getMisCitas(
    String especialistaId,
  );

  /// Detalle de una cita (con paciente, servicio y tratamiento asociado).
  Future<Either<Failure, CitaEjecucionEntity>> getCitaDetalle(String citaId);

  /// Insumos aplicados al tratamiento.
  Future<Either<Failure, List<ProductoAplicadoEntity>>> getProductos(
    String tratamientoId,
  );

  /// Consentimiento firmado del tratamiento (o null).
  Future<Either<Failure, ConsentimientoTratamientoEntity?>>
      getConsentimiento(String tratamientoId);

  /// Avanza el estado de la cita y registra la transición en historial_estados.
  Future<Either<Failure, CitaEjecucionEntity>> avanzarEstadoCita({
    required String citaId,
    required EstadoCitaEjecucion nuevoEstado,
    String? observaciones,
  });

  /// Crea el tratamiento `INICIADO` vinculado a la cita (si no existe).
  Future<Either<Failure, TratamientoEntity>> iniciarTratamiento({
    required String citaId,
    String? evaluacionInicial,
  });

  /// Actualiza datos del tratamiento (evaluación/recomendaciones/estado).
  Future<Either<Failure, TratamientoEntity>> actualizarTratamiento({
    required String tratamientoId,
    String? evaluacionInicial,
    String? observacionesFinales,
    String? recomendacionesPostTratamiento,
  });

  /// Agrega un producto aplicado al tratamiento.
  Future<Either<Failure, ProductoAplicadoEntity>> agregarProducto({
    required String tratamientoId,
    required String productoNombre,
    String? fabricante,
    String? lote,
    required double cantidadTotal,
    String? unidadMedida,
    DateTime? fechaVencimiento,
    String? observaciones,
  });

  /// Elimina un producto aplicado.
  Future<Either<Failure, void>> eliminarProducto(String productoId);

  /// Registra el consentimiento firmado por el paciente (PNG subido a storage).
  Future<Either<Failure, ConsentimientoTratamientoEntity>> registrarConsentimiento({
    required String tratamientoId,
    required String pacienteId,
    required String tipoConsentimiento,
    required String firmaUrl,
  });

  /// Sube los bytes de la firma al bucket y devuelve la URL pública.
  Future<Either<Failure, String>> subirFirma({
    required String tratamientoId,
    required Uint8List bytes,
  });

  /// Completa el tratamiento y finaliza la cita.
  Future<Either<Failure, void>> finalizarTratamiento({
    required String citaId,
    required String tratamientoId,
    String? observacionesFinales,
    String? recomendacionesPostTratamiento,
  });
}
