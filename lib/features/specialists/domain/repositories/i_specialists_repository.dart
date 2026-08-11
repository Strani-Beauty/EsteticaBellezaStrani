import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import '../entities/contrato_entity.dart';
import '../entities/disponibilidad_entity.dart';
import '../entities/documento_especialista_entity.dart';
import '../entities/especialidad_entity.dart';
import '../entities/especialista_entity.dart';
import '../entities/medico_regente_entity.dart';
import '../entities/ubicacion_especialista_entity.dart';

/// Contrato del repositorio de especialistas.
/// La implementación vive en data/repositories/specialists_repository_impl.dart
abstract class ISpecialistsRepository {
  // ── Especialista ─────────────────────────────────────────────
  Future<Either<Failure, EspecialistaEntity?>> getEspecialistaByUsuarioId(String usuarioId);

  Future<Either<Failure, EspecialistaEntity>> getEspecialistaById(String id);

  Future<Either<Failure, EspecialistaEntity>> createEspecialista({
    required String usuarioId,
    String? numeroLicencia,
    String? medicoRegenteId,
  });

  Future<Either<Failure, EspecialistaEntity>> updateEspecialista(
    String id,
    Map<String, dynamic> data,
  );

  Future<Either<Failure, List<EspecialistaEntity>>> getEspecialistas();

  // ── Médicos Regentes ─────────────────────────────────────────
  Future<Either<Failure, List<MedicoRegenteEntity>>> getMedicosRegentes({
    bool soloActivos = true,
  });

  Future<Either<Failure, MedicoRegenteEntity>> createMedicoRegente({
    required String nombre,
    String? numeroLicencia,
    String? telefono,
    String? correo,
  });

  Future<Either<Failure, MedicoRegenteEntity>> aprobarMedicoRegente(String id);

  // ── Especialidades ───────────────────────────────────────────
  Future<Either<Failure, List<EspecialidadEntity>>> getEspecialidades();

  Future<Either<Failure, List<EspecialistaEspecialidadEntity>>>
      getEspecialistaEspecialidades(String especialistaId);

  Future<Either<Failure, List<EspecialistaEspecialidadEntity>>>
      reemplazarEspecialidades(String especialistaId, List<int> especialidadIds);

  // ── Perfil (datos personales del especialista) ───────────────
  Future<Either<Failure, void>> updatePerfilEspecialista({
    required String userId,
    String? fullName,
    String? phone,
    String? address,
    double? latitude,
    double? longitude,
    double? hourlyRate,
    String? avatarUrl,
  });

  // ── Documentos ───────────────────────────────────────────────
  Future<Either<Failure, List<DocumentoEspecialistaEntity>>> getDocumentos(String especialistaId);

  Future<Either<Failure, DocumentoEspecialistaEntity>> registerDocumento({
    required String especialistaId,
    required TipoDocumento tipoDocumento,
    String? nombreArchivo,
    String? urlArchivo,
    int versionDocumento,
  });

  Future<Either<Failure, DocumentoEspecialistaEntity>> subirDocumento({
    required String especialistaId,
    required TipoDocumento tipoDocumento,
    required Uint8List bytes,
    required String nombreArchivo,
    int versionDocumento,
  });

  // ── Disponibilidad ───────────────────────────────────────────
  Future<Either<Failure, DisponibilidadEntity?>> getDisponibilidad(String especialistaId);

  Future<Either<Failure, DisponibilidadEntity>> setDisponibilidad(
    String especialistaId,
    EstadoDisponibilidad estado, {
    DateTime? fechaInicio,
    DateTime? fechaFin,
  });

  Future<Either<Failure, DisponibilidadEntity>> updateDisponibilidad(
    String id,
    EstadoDisponibilidad estado, {
    DateTime? fechaInicio,
    DateTime? fechaFin,
  });

  // ── Contrato ─────────────────────────────────────────────────
  Future<Either<Failure, ContratoEntity?>> getContrato(String especialistaId);

  Future<Either<Failure, ContratoEntity>> firmarContrato(
    String especialistaId, {
    required MetodoFirma metodoFirma,
    String? urlDocumento,
    int versionContrato,
  });

  // ── Ubicación ────────────────────────────────────────────────
  Future<Either<Failure, UbicacionEspecialistaEntity?>> getUbicacion(String especialistaId);

  Future<Either<Failure, UbicacionEspecialistaEntity>> saveUbicacion(
    String especialistaId, {
    required double latitud,
    required double longitud,
    double precisionMetros,
  });
}