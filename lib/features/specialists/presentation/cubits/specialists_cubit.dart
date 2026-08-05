import 'dart:typed_data';

import 'package:equatable/equatable.dart';
// Los usecases se inyectan por nombre; esta regla no aplica aquí.
// ignore_for_file: prefer_initializing_formals
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/contrato_entity.dart';
import '../../domain/entities/disponibilidad_entity.dart';
import '../../domain/entities/documento_especialista_entity.dart';
import '../../domain/entities/especialidad_entity.dart';
import '../../domain/entities/especialista_entity.dart';
import '../../domain/entities/medico_regente_entity.dart';
import '../../domain/entities/ubicacion_especialista_entity.dart';
import '../../domain/usecases/create_especialista.dart';
import '../../domain/usecases/get_contrato.dart';
import '../../domain/usecases/get_disponibilidad.dart';
import '../../domain/usecases/get_documentos.dart';
import '../../domain/usecases/get_especialidades.dart';
import '../../domain/usecases/get_medicos_regentes.dart';
import '../../domain/usecases/get_my_specialist.dart';
import '../../domain/usecases/save_ubicacion.dart';
import '../../domain/usecases/set_disponibilidad.dart';

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

  const SpecialistsLoaded({
    this.especialista,
    this.medicosRegentes = const [],
    this.especialidades = const [],
    this.documentos = const [],
    this.disponibilidad,
    this.contrato,
    this.ubicacion,
  });

  SpecialistsLoaded copyWith({
    EspecialistaEntity? especialista,
    List<MedicoRegenteEntity>? medicosRegentes,
    List<EspecialidadEntity>? especialidades,
    List<DocumentoEspecialistaEntity>? documentos,
    DisponibilidadEntity? disponibilidad,
    ContratoEntity? contrato,
    UbicacionEspecialistaEntity? ubicacion,
  }) {
    return SpecialistsLoaded(
      especialista: especialista ?? this.especialista,
      medicosRegentes: medicosRegentes ?? this.medicosRegentes,
      especialidades: especialidades ?? this.especialidades,
      documentos: documentos ?? this.documentos,
      disponibilidad: disponibilidad ?? this.disponibilidad,
      contrato: contrato ?? this.contrato,
      ubicacion: ubicacion ?? this.ubicacion,
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
  Future<void> createSpecialist({
    required String usuarioId,
    String? numeroLicencia,
    String? medicoRegenteId,
  }) async {
    emit(const SpecialistsLoading());
    final result = await _createEspecialista(CreateEspecialistaParams(
      usuarioId: usuarioId,
      numeroLicencia: numeroLicencia,
      medicoRegenteId: medicoRegenteId,
    ));
    result.fold(
      (f) => emit(SpecialistsError(f.message)),
      (s) {
        final current = state;
        if (current is SpecialistsLoaded) {
          emit(current.copyWith(especialista: s));
        } else {
          emit(const SpecialistsLoaded());
        }
      },
    );
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

  EspecialistaEntity? get especialista =>
      state is SpecialistsLoaded ? (state as SpecialistsLoaded).especialista : null;
}