import 'dart:typed_data';

import 'package:equatable/equatable.dart';
// Los usecases se inyectan por nombre; esta regla no aplica aquí.
// ignore_for_file: prefer_initializing_formals
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esteticaybellezastrani/app/core/usecases/use_case.dart';
import '../../domain/entities/contrato_entity.dart';
import '../../domain/entities/disponibilidad_entity.dart';
import '../../domain/entities/documento_especialista_entity.dart';
import '../../domain/entities/especialidad_entity.dart';
import '../../domain/entities/especialista_entity.dart';
import '../../domain/entities/medico_regente_entity.dart';
import '../../domain/entities/ubicacion_especialista_entity.dart';
import '../../domain/usecases/create_especialista.dart';
import '../../domain/usecases/get_all_especialistas.dart';
import '../../domain/usecases/get_contrato.dart';
import '../../domain/usecases/get_disponibilidad.dart';
import '../../domain/usecases/get_documentos.dart';
import '../../domain/usecases/get_especialidades.dart';
import '../../domain/usecases/get_medicos_regentes.dart';
import '../../domain/usecases/get_my_specialist.dart';
import '../../domain/usecases/save_ubicacion.dart';
import '../../domain/usecases/set_disponibilidad.dart';
import '../../domain/usecases/update_especialista.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ESTADOS
// ─────────────────────────────────────────────────────────────────────────────

abstract class SpecialistsState extends Equatable {
  const SpecialistsState();
  @override
  List<Object?> get props => [];
}

class SpecialistsInitial extends SpecialistsState {
  const SpecialistsInitial();
}

class SpecialistsLoading extends SpecialistsState {
  const SpecialistsLoading();
}

class SpecialistsLoaded extends SpecialistsState {
  final EspecialistaEntity? especialista;
  final List<MedicoRegenteEntity> medicosRegentes;
  final List<EspecialidadEntity> especialidades;
  final List<DocumentoEspecialistaEntity> documentos;
  final DisponibilidadEntity? disponibilidad;
  final ContratoEntity? contrato;
  final UbicacionEspecialistaEntity? ubicacion;
  final List<EspecialistaEntity> especialistas;

  const SpecialistsLoaded({
    this.especialista,
    this.medicosRegentes = const [],
    this.especialidades = const [],
    this.documentos = const [],
    this.disponibilidad,
    this.contrato,
    this.ubicacion,
    this.especialistas = const [],
  });

  SpecialistsLoaded copyWith({
    EspecialistaEntity? especialista,
    List<MedicoRegenteEntity>? medicosRegentes,
    List<EspecialidadEntity>? especialidades,
    List<DocumentoEspecialistaEntity>? documentos,
    DisponibilidadEntity? disponibilidad,
    ContratoEntity? contrato,
    UbicacionEspecialistaEntity? ubicacion,
    List<EspecialistaEntity>? especialistas,
  }) {
    return SpecialistsLoaded(
      especialista: especialista ?? this.especialista,
      medicosRegentes: medicosRegentes ?? this.medicosRegentes,
      especialidades: especialidades ?? this.especialidades,
      documentos: documentos ?? this.documentos,
      disponibilidad: disponibilidad ?? this.disponibilidad,
      contrato: contrato ?? this.contrato,
      ubicacion: ubicacion ?? this.ubicacion,
      especialistas: especialistas ?? this.especialistas,
    );
  }

  @override
  List<Object?> get props => [
        especialista,
        medicosRegentes,
        especialidades,
        documentos,
        disponibilidad,
        contrato,
        ubicacion,
        especialistas,
      ];
}

class SpecialistsError extends SpecialistsState {
  final String message;
  const SpecialistsError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─────────────────────────────────────────────────────────────────────────────
// CUBIT
// ─────────────────────────────────────────────────────────────────────────────

class SpecialistsCubit extends Cubit<SpecialistsState> {
  final GetMySpecialist _getMySpecialist;
  final CreateEspecialista _createEspecialista;
  final GetMedicosRegentes _getMedicosRegentes;
  final GetEspecialidades _getEspecialidades;
  final GetDisponibilidad _getDisponibilidad;
  final GetDocumentos _getDocumentos;
  final RegisterDocumento _registerDocumento;
  final SubirDocumento _subirDocumento;
  final SetDisponibilidad _setDisponibilidad;
  final GetContrato _getContrato;
  final FirmarContrato _firmarContrato;
  final SaveUbicacion _saveUbicacion;
  final UpdateEspecialista _updateEspecialista;
  final GetAllEspecialistas _getAllEspecialistas;

  SpecialistsCubit({
    required GetMySpecialist getMySpecialist,
    required CreateEspecialista createEspecialista,
    required GetMedicosRegentes getMedicosRegentes,
    required GetEspecialidades getEspecialidades,
    required GetDisponibilidad getDisponibilidad,
    required GetDocumentos getDocumentos,
    required RegisterDocumento registerDocumento,
    required SubirDocumento subirDocumento,
    required SetDisponibilidad setDisponibilidad,
    required GetContrato getContrato,
    required FirmarContrato firmarContrato,
    required SaveUbicacion saveUbicacion,
    required UpdateEspecialista updateEspecialista,
    required GetAllEspecialistas getAllEspecialistas,
  })  : _getMySpecialist = getMySpecialist,
        _createEspecialista = createEspecialista,
        _getMedicosRegentes = getMedicosRegentes,
        _getEspecialidades = getEspecialidades,
        _getDisponibilidad = getDisponibilidad,
        _getDocumentos = getDocumentos,
        _registerDocumento = registerDocumento,
        _subirDocumento = subirDocumento,
        _setDisponibilidad = setDisponibilidad,
        _getContrato = getContrato,
        _firmarContrato = firmarContrato,
        _saveUbicacion = saveUbicacion,
        _updateEspecialista = updateEspecialista,
        _getAllEspecialistas = getAllEspecialistas,
        super(const SpecialistsInitial());

  /// Carga el tablero completo del especialista.
  Future<void> loadDashboard({required String usuarioId}) async {
    emit(const SpecialistsLoading());

    final specialistResult = await _getMySpecialist(GetMySpecialistParams(usuarioId));
    EspecialistaEntity? especialista;
    var failure = false;

    specialistResult.fold(
      (f) { failure = true; },
      (s) => especialista = s,
    );

    final medicos = await _getMedicosRegentes();
    final especialidades = await _getEspecialidades();

    List<DocumentoEspecialistaEntity> documentos = [];
    DisponibilidadEntity? disponibilidad;
    ContratoEntity? contrato;
    final esp = especialista;
    if (esp != null) {
      final docs = await _getDocumentos(GetDocumentosParams(esp.id));
      docs.fold((_) {}, (d) => documentos = d);
      final disp = await _getDisponibilidad(GetDisponibilidadParams(esp.id));
      disp.fold((_) {}, (d) => disponibilidad = d);
      final con = await _getContrato(GetContratoParams(esp.id));
      con.fold((_) {}, (c) => contrato = c);
    }

    if (failure) {
      emit(const SpecialistsError('No se pudo cargar el perfil de especialista.'));
      return;
    }

    List<MedicoRegenteEntity> medicosList = [];
    medicos.fold((_) {}, (m) => medicosList = m);
    List<EspecialidadEntity> especialidadesList = [];
    especialidades.fold((_) {}, (e) => especialidadesList = e);

    emit(SpecialistsLoaded(
      especialista: especialista,
      medicosRegentes: medicosList,
      especialidades: especialidadesList,
      documentos: documentos,
      disponibilidad: disponibilidad,
      contrato: contrato,
    ));
  }

  /// Crea el registro de especialista (solicitud de verificación).
  /// Conserva el especialista recién creado en el estado (evita que la UI
  /// vuelva a mostrar el formulario de licencia) y, si la inserción falla por
  /// unicidad de `usuario_id` (el registro ya existe en BD), recupera el
  /// especialista existente en vez de quedarse bloqueado en un error.
  Future<void> createSpecialist({
    required String usuarioId,
    String? numeroLicencia,
    String? medicoRegenteId,
  }) async {
    final prior = state is SpecialistsLoaded ? state as SpecialistsLoaded : null;
    emit(const SpecialistsLoading());

    final result = await _createEspecialista(CreateEspecialistaParams(
      usuarioId: usuarioId,
      numeroLicencia: numeroLicencia,
      medicoRegenteId: medicoRegenteId,
    ));

    result.fold(
      (f) {
        if (_esUnicidadViolada(f.message)) {
          loadDashboard(usuarioId: usuarioId);
        } else {
          emit(SpecialistsError(f.message));
        }
      },
      (s) => emit((prior ?? const SpecialistsLoaded()).copyWith(especialista: s)),
    );
  }

  bool _esUnicidadViolada(String message) {
    final m = message.toLowerCase();
    return m.contains('23505') ||
        m.contains('duplicate key') ||
        m.contains('unique constraint') ||
        m.contains('unicidad');
  }

  /// Alterna la disponibilidad del especialista.
  Future<void> toggleDisponibilidad({required String especialistaId}) async {
    final current = state;
    if (current is! SpecialistsLoaded) return;

    final next = current.disponibilidad?.isAvailable == true
        ? EstadoDisponibilidad.noDisponible
        : EstadoDisponibilidad.disponible;

    final result = await _setDisponibilidad(SetDisponibilidadParams(
      especialistaId: especialistaId,
      estado: next,
    ));
    result.fold(
      (f) => emit(SpecialistsError(f.message)),
      (d) => emit(current.copyWith(disponibilidad: d)),
    );
  }

  /// Registra un documento para revisión.
  Future<void> registerDocument({
    required String especialistaId,
    required TipoDocumento tipoDocumento,
    String? nombreArchivo,
    String? urlArchivo,
  }) async {
    final current = state;
    if (current is! SpecialistsLoaded) return;

    final result = await _registerDocumento(RegisterDocumentoParams(
      especialistaId: especialistaId,
      tipoDocumento: tipoDocumento,
      nombreArchivo: nombreArchivo,
      urlArchivo: urlArchivo,
    ));
    result.fold(
      (f) => emit(SpecialistsError(f.message)),
      (doc) => emit(current.copyWith(documentos: [...current.documentos, doc])),
    );
  }

  /// Sube los bytes del documento al bucket y lo registra para revisión.
  Future<void> uploadDocument({
    required String especialistaId,
    required TipoDocumento tipoDocumento,
    required Uint8List bytes,
    required String nombreArchivo,
  }) async {
    final current = state;
    if (current is! SpecialistsLoaded) return;

    final result = await _subirDocumento(SubirDocumentoParams(
      especialistaId: especialistaId,
      tipoDocumento: tipoDocumento,
      bytes: bytes,
      nombreArchivo: nombreArchivo,
    ));
    result.fold(
      (f) => emit(SpecialistsError(f.message)),
      (doc) => emit(current.copyWith(documentos: [...current.documentos, doc])),
    );
  }

  /// Registra la firma del contrato.
  Future<void> signContract({
    required String especialistaId,
    required MetodoFirma metodoFirma,
    String? urlDocumento,
  }) async {
    final current = state;
    if (current is! SpecialistsLoaded) return;

    final result = await _firmarContrato(FirmarContratoParams(
      especialistaId: especialistaId,
      metodoFirma: metodoFirma,
      urlDocumento: urlDocumento,
    ));
    result.fold(
      (f) => emit(SpecialistsError(f.message)),
      (c) => emit(current.copyWith(contrato: c)),
    );
  }

  /// Guarda la ubicación del especialista.
  Future<void> saveLocation({
    required String especialistaId,
    required double latitud,
    required double longitud,
    double precisionMetros = 0,
  }) async {
    final current = state;
    if (current is! SpecialistsLoaded) return;

    final result = await _saveUbicacion(SaveUbicacionParams(
      especialistaId: especialistaId,
      latitud: latitud,
      longitud: longitud,
      precisionMetros: precisionMetros,
    ));
    result.fold(
      (f) => emit(SpecialistsError(f.message)),
      (u) => emit(current.copyWith(ubicacion: u)),
    );
  }

  /// Lista todos los especialistas (panel de administración).
  Future<void> loadAllEspecialistas() async {
    emit(const SpecialistsLoading());
    final result = await _getAllEspecialistas(const NoParams());
    result.fold(
      (f) => emit(SpecialistsError(f.message)),
      (especialistas) => emit(SpecialistsLoaded(especialistas: especialistas)),
    );
  }

  /// Cambia el estado de verificación de la licencia de un especialista
  /// (aprobado/rechazado/bloqueado) desde el panel de administración.
  Future<void> updateVerificacion({
    required String especialistaId,
    required EstadoVerificacion estado,
    required String aprobadoPor,
  }) async {
    final current = state;
    if (current is! SpecialistsLoaded) return;

    final now = DateTime.now();
    final result = await _updateEspecialista(UpdateEspecialistaParams(
      id: especialistaId,
      estadoVerificacion: estado.toDb,
      activo: estado == EstadoVerificacion.aprobado,
      fechaVerificacion: now,
      fechaAprobacion: estado == EstadoVerificacion.aprobado ? now : null,
      aprobadoPor: aprobadoPor,
    ));
    result.fold(
      (f) => emit(SpecialistsError(f.message)),
      (actualizado) => emit(current.copyWith(
        especialistas: [
          for (final e in current.especialistas)
            if (e.id == actualizado.id)
              actualizado.copyWith(
                nombreUsuario: e.nombreUsuario,
                emailUsuario: e.emailUsuario,
              )
            else
              e,
        ],
      )),
    );
  }

  EspecialistaEntity? get especialista =>
      state is SpecialistsLoaded ? (state as SpecialistsLoaded).especialista : null;
}