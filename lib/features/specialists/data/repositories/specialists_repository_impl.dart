import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:esteticaybellezastrani/app/core/error/failures.dart';
import '../../domain/entities/contrato_entity.dart';
import '../../domain/entities/disponibilidad_entity.dart';
import '../../domain/entities/documento_especialista_entity.dart';
import '../../domain/entities/especialidad_entity.dart';
import '../../domain/entities/especialista_entity.dart';
import '../../domain/entities/medico_regente_entity.dart';
import '../../domain/entities/ubicacion_especialista_entity.dart';
import '../../domain/repositories/i_specialists_repository.dart';
import '../datasources/specialists_supabase_datasource.dart';

/// Implementación del repositorio de especialistas usando Supabase.
class SpecialistsRepositoryImpl implements ISpecialistsRepository {
  final SpecialistsSupabaseDataSource _dataSource;

  SpecialistsRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, EspecialistaEntity?>> getEspecialistaByUsuarioId(
      String usuarioId) async {
    try {
      final model = await _dataSource.fetchEspecialistaByUsuarioId(usuarioId);
      return Right(model?.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, EspecialistaEntity>> getEspecialistaById(String id) async {
    try {
      final model = await _dataSource.fetchEspecialistaById(id);
      return Right(model.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, EspecialistaEntity>> createEspecialista({
    required String usuarioId,
    String? numeroLicencia,
    String? medicoRegenteId,
  }) async {
    try {
      final model = await _dataSource.createEspecialista(
        usuarioId: usuarioId,
        numeroLicencia: numeroLicencia,
        medicoRegenteId: medicoRegenteId,
      );
      return Right(model.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, EspecialistaEntity>> updateEspecialista(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final model = await _dataSource.updateEspecialista(id, data);
      return Right(model.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<EspecialistaEntity>>> getEspecialistas() async {
    try {
      final models = await _dataSource.fetchEspecialistas();
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<MedicoRegenteEntity>>> getMedicosRegentes({
    bool soloActivos = true,
  }) async {
    try {
      final models = await _dataSource.fetchMedicosRegentes(soloActivos: soloActivos);
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, MedicoRegenteEntity>> createMedicoRegente({
    required String nombre,
    String? numeroLicencia,
    String? telefono,
    String? correo,
  }) async {
    try {
      final model = await _dataSource.createMedicoRegente(
        nombre: nombre,
        numeroLicencia: numeroLicencia,
        telefono: telefono,
        correo: correo,
      );
      return Right(model.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, MedicoRegenteEntity>> aprobarMedicoRegente(String id) async {
    try {
      final model = await _dataSource.updateMedicoRegente(id, {
        'estado': 'ACTIVO',
        'activo': true,
      });
      return Right(model.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<EspecialidadEntity>>> getEspecialidades() async {
    try {
      final models = await _dataSource.fetchEspecialidades();
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<EspecialistaEspecialidadEntity>>>
      getEspecialistaEspecialidades(String especialistaId) async {
    try {
      final models =
          await _dataSource.fetchEspecialistaEspecialidades(especialistaId);
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<EspecialistaEspecialidadEntity>>>
      reemplazarEspecialidades(
    String especialistaId,
    List<int> especialidadIds,
  ) async {
    try {
      final models = await _dataSource.reemplazarEspecialidades(
        especialistaId,
        especialidadIds,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updatePerfilEspecialista({
    required String userId,
    String? fullName,
    String? phone,
    String? address,
    double? latitude,
    double? longitude,
    double? hourlyRate,
    String? avatarUrl,
  }) async {
    try {
      await _dataSource.updatePerfilEspecialista(
        userId: userId,
        fullName: fullName,
        phone: phone,
        address: address,
        latitude: latitude,
        longitude: longitude,
        hourlyRate: hourlyRate,
        avatarUrl: avatarUrl,
      );
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<DocumentoEspecialistaEntity>>> getDocumentos(
      String especialistaId) async {
    try {
      final models = await _dataSource.fetchDocumentos(especialistaId);
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, DocumentoEspecialistaEntity>> registerDocumento({
    required String especialistaId,
    required TipoDocumento tipoDocumento,
    String? nombreArchivo,
    String? urlArchivo,
    int versionDocumento = 1,
  }) async {
    try {
      final model = await _dataSource.registerDocumento(
        especialistaId: especialistaId,
        tipoDocumento: tipoDocumento,
        nombreArchivo: nombreArchivo,
        urlArchivo: urlArchivo,
        versionDocumento: versionDocumento,
      );
      return Right(model.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, DocumentoEspecialistaEntity>> subirDocumento({
    required String especialistaId,
    required TipoDocumento tipoDocumento,
    required Uint8List bytes,
    required String nombreArchivo,
    int versionDocumento = 1,
  }) async {
    try {
      final model = await _dataSource.subirDocumento(
        especialistaId: especialistaId,
        tipoDocumento: tipoDocumento,
        bytes: bytes,
        nombreArchivo: nombreArchivo,
        versionDocumento: versionDocumento,
      );
      return Right(model.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, DisponibilidadEntity?>> getDisponibilidad(
      String especialistaId) async {
    try {
      final model = await _dataSource.fetchDisponibilidad(especialistaId);
      return Right(model?.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, DisponibilidadEntity>> setDisponibilidad(
    String especialistaId,
    EstadoDisponibilidad estado, {
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) async {
    try {
      final model = await _dataSource.setDisponibilidad(
        especialistaId,
        estado,
        fechaInicio: fechaInicio,
        fechaFin: fechaFin,
      );
      return Right(model.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, DisponibilidadEntity>> updateDisponibilidad(
    String id,
    EstadoDisponibilidad estado, {
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) async {
    try {
      final model = await _dataSource.updateDisponibilidad(
        id,
        estado,
        fechaInicio: fechaInicio,
        fechaFin: fechaFin,
      );
      return Right(model.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ContratoEntity?>> getContrato(String especialistaId) async {
    try {
      final model = await _dataSource.fetchContrato(especialistaId);
      return Right(model?.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ContratoEntity>> firmarContrato(
    String especialistaId, {
    required MetodoFirma metodoFirma,
    String? urlDocumento,
    int versionContrato = 1,
  }) async {
    try {
      final model = await _dataSource.firmarContrato(
        especialistaId,
        metodoFirma: metodoFirma,
        urlDocumento: urlDocumento,
        versionContrato: versionContrato,
      );
      return Right(model.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UbicacionEspecialistaEntity?>> getUbicacion(
      String especialistaId) async {
    try {
      final model = await _dataSource.fetchUbicacion(especialistaId);
      return Right(model?.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UbicacionEspecialistaEntity>> saveUbicacion(
    String especialistaId, {
    required double latitud,
    required double longitud,
    double precisionMetros = 0,
  }) async {
    try {
      final model = await _dataSource.saveUbicacion(
        especialistaId,
        latitud: latitud,
        longitud: longitud,
        precisionMetros: precisionMetros,
      );
      return Right(model.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}