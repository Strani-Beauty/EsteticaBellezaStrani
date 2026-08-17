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
import '../../domain/usecases/aprobar_medico_regente.dart';
import '../../domain/usecases/asignar_especialidades.dart';
import '../../domain/usecases/create_especialista.dart';
import '../../domain/usecases/create_medico_regente.dart';
import '../../domain/usecases/get_all_especialistas.dart';
import '../../domain/usecases/get_contrato.dart';
import '../../domain/usecases/get_disponibilidad.dart';
import '../../domain/usecases/get_documentos.dart';
import '../../domain/usecases/get_especialidades.dart';
import '../../domain/usecases/get_medicos_regentes.dart';
import '../../domain/usecases/get_my_specialist.dart';
import '../../domain/usecases/revisar_documento.dart';
import '../../domain/usecases/save_ubicacion.dart';
import '../../domain/usecases/set_disponibilidad.dart';
import '../../domain/usecases/solicitar_verificacion.dart';
import '../../domain/usecases/update_especialista.dart';
import '../../domain/usecases/update_perfil_especialista.dart';

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
  final List<int> especialidadIds;
  final Map<String, List<DocumentoEspecialistaEntity>> documentosPorEspecialista;

  const SpecialistsLoaded({
    this.especialista,
    this.medicosRegentes = const [],
    this.especialidades = const [],
    this.documentos = const [],
    this.disponibilidad,
    this.contrato,
    this.ubicacion,
    this.especialistas = const [],
    this.especialidadIds = const [],
    this.documentosPorEspecialista = const {},
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
    List<int>? especialidadIds,
    Map<String, List<DocumentoEspecialistaEntity>>? documentosPorEspecialista,
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
      especialidadIds: especialidadIds ?? this.especialidadIds,
      documentosPorEspecialista:
          documentosPorEspecialista ?? this.documentosPorEspecialista,
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
        especialidadIds,
        documentosPorEspecialista,
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
  final UpsertDisponibilidad _upsertDisponibilidad;
  final GetContrato _getContrato;
  final FirmarContrato _firmarContrato;
  final SubirFirmaContrato _subirFirmaContrato;
  final SaveUbicacion _saveUbicacion;
  final UpdateEspecialista _updateEspecialista;
  final GetAllEspecialistas _getAllEspecialistas;
  final AsignarEspecialidades _asignarEspecialidades;
  final CreateMedicoRegente _createMedicoRegente;
  final AprobarMedicoRegente _aprobarMedicoRegente;
  final UpdatePerfilEspecialista _updatePerfilEspecialista;
  final GetEspecialistaEspecialidades _getEspecialidadesDelEspecialista;
  final SolicitarVerificacion _solicitarVerificacion;
  final RevisarDocumento _revisarDocumento;
  final GenerarUrlFirmadaDocumento _generarUrlFirmadaDocumento;

  SpecialistsCubit({
    required GetMySpecialist getMySpecialist,
    required CreateEspecialista createEspecialista,
    required GetMedicosRegentes getMedicosRegentes,
    required GetEspecialidades getEspecialidades,
    required GetDisponibilidad getDisponibilidad,
    required GetDocumentos getDocumentos,
    required RegisterDocumento registerDocumento,
    required SubirDocumento subirDocumento,
    required UpsertDisponibilidad upsertDisponibilidad,
    required GetContrato getContrato,
    required FirmarContrato firmarContrato,
    required SubirFirmaContrato subirFirmaContrato,
    required SaveUbicacion saveUbicacion,
    required UpdateEspecialista updateEspecialista,
    required GetAllEspecialistas getAllEspecialistas,
    required AsignarEspecialidades asignarEspecialidades,
    required CreateMedicoRegente createMedicoRegente,
    required AprobarMedicoRegente aprobarMedicoRegente,
    required UpdatePerfilEspecialista updatePerfilEspecialista,
    required GetEspecialistaEspecialidades getEspecialidadesDelEspecialista,
    required SolicitarVerificacion solicitarVerificacion,
    required RevisarDocumento revisarDocumento,
    required GenerarUrlFirmadaDocumento generarUrlFirmadaDocumento,
  })  : _getMySpecialist = getMySpecialist,
        _createEspecialista = createEspecialista,
        _getMedicosRegentes = getMedicosRegentes,
        _getEspecialidades = getEspecialidades,
        _getDisponibilidad = getDisponibilidad,
        _getDocumentos = getDocumentos,
        _registerDocumento = registerDocumento,
        _subirDocumento = subirDocumento,
        _upsertDisponibilidad = upsertDisponibilidad,
        _getContrato = getContrato,
        _firmarContrato = firmarContrato,
        _subirFirmaContrato = subirFirmaContrato,
        _saveUbicacion = saveUbicacion,
        _updateEspecialista = updateEspecialista,
        _getAllEspecialistas = getAllEspecialistas,
        _asignarEspecialidades = asignarEspecialidades,
        _createMedicoRegente = createMedicoRegente,
        _aprobarMedicoRegente = aprobarMedicoRegente,
        _updatePerfilEspecialista = updatePerfilEspecialista,
        _getEspecialidadesDelEspecialista = getEspecialidadesDelEspecialista,
        _solicitarVerificacion = solicitarVerificacion,
        _revisarDocumento = revisarDocumento,
        _generarUrlFirmadaDocumento = generarUrlFirmadaDocumento,
        super(const SpecialistsInitial());

  /// Guarda contra el caso de emitir tras `close()`: si una operación async
  /// (p.ej. `loadDashboard`) termina cuando el cubit ya se cerró (navegación),
  /// se descarta el estado en vez de lanzar "Cannot emit new states after
  /// calling close".
  @override
  void emit(SpecialistsState state) {
    if (isClosed) return;
    super.emit(state);
  }

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

    final medicos = await _getMedicosRegentes(const GetMedicosRegentesParams());
    final especialidades = await _getEspecialidades();

    List<DocumentoEspecialistaEntity> documentos = [];
    DisponibilidadEntity? disponibilidad;
    ContratoEntity? contrato;
    List<int> especialidadIds = [];
    final esp = especialista;
    if (esp != null) {
      final docs = await _getDocumentos(GetDocumentosParams(esp.id));
      docs.fold((_) {}, (d) => documentos = d);
      final disp = await _getDisponibilidad(GetDisponibilidadParams(esp.id));
      disp.fold((_) {}, (d) => disponibilidad = d);
      final con = await _getContrato(GetContratoParams(esp.id));
      con.fold((_) {}, (c) => contrato = c);
      final rel = await _getEspecialidadesDelEspecialista(
        GetEspecialistaEspecialidadesParams(esp.id),
      );
      rel.fold((_) {}, (r) => especialidadIds = r.map((e) => e.especialidadId).toList());
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
      especialidadIds: especialidadIds,
      documentosPorEspecialista: {
        if (esp != null) esp.id: documentos,
      },
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

  /// Guarda los datos personales del especialista (columnas de `profiles`).
  Future<void> guardarDatosPersonales({
    required String userId,
    String? fullName,
    String? phone,
    String? address,
    double? latitude,
    double? longitude,
    double? hourlyRate,
  }) async {
    final current = state is SpecialistsLoaded ? state as SpecialistsLoaded : null;
    emit(const SpecialistsLoading());

    final result = await _updatePerfilEspecialista(UpdatePerfilEspecialistaParams(
      userId: userId,
      fullName: fullName,
      phone: phone,
      address: address,
      latitude: latitude,
      longitude: longitude,
      hourlyRate: hourlyRate,
    ));
    result.fold(
      (f) => emit(SpecialistsError(f.message)),
      (_) => emit((current ?? const SpecialistsLoaded())),
    );
  }

  /// Reemplaza las especialidades que ofrece el especialista.
  Future<void> guardarEspecialidades({
    required String especialistaId,
    required List<int> especialidadIds,
  }) async {
    final current = state;
    if (current is! SpecialistsLoaded) return;

    final result = await _asignarEspecialidades(AsignarEspecialidadesParams(
      especialistaId: especialistaId,
      especialidadIds: especialidadIds,
    ));
    result.fold(
      (f) => emit(SpecialistsError(f.message)),
      (_) => emit(current.copyWith(especialidadIds: especialidadIds)),
    );
  }

  /// Actualiza licencia y/o médico regente de un especialista ya existente.
  Future<void> actualizarDatosProfesionales({
    required String especialistaId,
    String? numeroLicencia,
    String? medicoRegenteId,
  }) async {
    final current = state;
    if (current is! SpecialistsLoaded) return;

    final result = await _updateEspecialista(UpdateEspecialistaParams(
      id: especialistaId,
      numeroLicencia: numeroLicencia,
      medicoRegenteId: medicoRegenteId,
    ));
    result.fold(
      (f) => emit(SpecialistsError(f.message)),
      (actualizado) => emit(current.copyWith(especialista: actualizado)),
    );
  }

  /// Registra un médico regente (queda PENDIENTE de validación).
  Future<void> createMedicoRegente({
    required String nombre,
    String? numeroLicencia,
    String? telefono,
    String? correo,
  }) async {
    final current = state;
    if (current is! SpecialistsLoaded) return;

    final result = await _createMedicoRegente(CreateMedicoRegenteParams(
      nombre: nombre,
      numeroLicencia: numeroLicencia,
      telefono: telefono,
      correo: correo,
    ));
    result.fold(
      (f) => emit(SpecialistsError(f.message)),
      (medico) {
        // Se agrega a la lista (PENDIENTE) para que el especialista lo vea.
        emit(current.copyWith(
          medicosRegentes: [...current.medicosRegentes, medico],
        ));
      },
    );
  }

  /// Valida un médico regente (PENDIENTE -> ACTIVO) desde el panel de admin.
  Future<void> aprobarMedicoRegente(String id) async {
    final current = state;
    if (current is! SpecialistsLoaded) return;

    final result = await _aprobarMedicoRegente(AprobarMedicoRegenteParams(id));
    result.fold(
      (f) => emit(SpecialistsError(f.message)),
      (medico) => emit(current.copyWith(
        medicosRegentes: [
          for (final m in current.medicosRegentes)
            if (m.id == medico.id) medico else m,
        ],
      )),
    );
  }

  /// Carga todos los médicos regentes (incluye PENDIENTES) — uso administrativo.
  Future<void> loadMedicosRegentesAdmin() async {
    final current = state;
    if (current is! SpecialistsLoaded) return;

    final result = await _getMedicosRegentes(
      const GetMedicosRegentesParams(soloActivos: false),
    );
    result.fold(
      (f) => emit(SpecialistsError(f.message)),
      (medicos) => emit(current.copyWith(medicosRegentes: medicos)),
    );
  }

  /// Alterna la disponibilidad del especialista (upsert + sincroniza
  /// `especialistas.disponible`).
  Future<void> toggleDisponibilidad({required String especialistaId}) async {
    final current = state;
    if (current is! SpecialistsLoaded) return;

    final next = current.disponibilidad?.isAvailable == true
        ? EstadoDisponibilidad.noDisponible
        : EstadoDisponibilidad.disponible;
    final disponible = next == EstadoDisponibilidad.disponible;

    final result = await _upsertDisponibilidad(SetDisponibilidadParams(
      especialistaId: especialistaId,
      estado: next,
    ));

    result.fold(
      (f) => emit(SpecialistsError(f.message)),
      (d) async {
        final base = state is SpecialistsLoaded
            ? state as SpecialistsLoaded
            : current;
        // Sincroniza el flag `disponible` del especialista.
        final espRes = await _updateEspecialista(UpdateEspecialistaParams(
          id: especialistaId,
          disponible: disponible,
        ));
        espRes.fold(
          (f) => emit(base.copyWith(disponibilidad: d)),
          (esp) => emit(base.copyWith(disponibilidad: d, especialista: esp)),
        );
      },
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

  /// Genera una URL firmada para abrir un documento privado.
  /// Devuelve null si falla (emite `SpecialistsError` para el SnackBar).
  Future<String?> generarUrlFirmadaDocumento(String path) async {
    final result = await _generarUrlFirmadaDocumento(
      GenerarUrlFirmadaDocumentoParams(path),
    );
    return result.fold(
      (f) {
        emit(SpecialistsError(f.message));
        return null;
      },
      (url) => url,
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

  /// Sube la firma manuscrita del contrato y registra el contrato como firmado
  /// (metodo_firma=TOUCH, url_documento=imagen subida).
  Future<void> firmarContratoConFirma({
    required String especialistaId,
    required Uint8List bytesFirma,
  }) async {
    final current = state;
    if (current is! SpecialistsLoaded) return;

    final urlRes = await _subirFirmaContrato(SubirFirmaContratoParams(
      especialistaId: especialistaId,
      bytes: bytesFirma,
    ));

    urlRes.fold(
      (f) => emit(SpecialistsError(f.message)),
      (url) async {
        final firmaRes = await _firmarContrato(FirmarContratoParams(
          especialistaId: especialistaId,
          metodoFirma: MetodoFirma.touch,
          urlDocumento: url,
        ));
        firmaRes.fold(
          (f) => emit(SpecialistsError(f.message)),
          (c) {
            final base = state is SpecialistsLoaded
                ? state as SpecialistsLoaded
                : current;
            emit(base.copyWith(contrato: c));
          },
        );
      },
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

  /// Lista todos los especialistas (panel de administración), sus documentos
  /// y los médicos regentes (incluyendo los pendientes de validación).
  Future<void> loadAllEspecialistas() async {
    emit(const SpecialistsLoading());
    final result = await _getAllEspecialistas(const NoParams());
    final medicos = await _getMedicosRegentes(
      const GetMedicosRegentesParams(soloActivos: false),
    );
    List<MedicoRegenteEntity> medicosList = [];
    medicos.fold((_) {}, (m) => medicosList = m);

    final List<EspecialistaEntity> especialistas = [];
    var failure = '';
    result.fold((f) => failure = f.message, (e) => especialistas.addAll(e));

    final docsMap = <String, List<DocumentoEspecialistaEntity>>{};
    for (final esp in especialistas) {
      final docs = await _getDocumentos(GetDocumentosParams(esp.id));
      docs.fold((_) {}, (d) => docsMap[esp.id] = d);
    }

    if (failure.isNotEmpty) {
      emit(SpecialistsError(failure));
      return;
    }

    emit(SpecialistsLoaded(
      especialistas: especialistas,
      medicosRegentes: medicosList,
      documentosPorEspecialista: docsMap,
    ));
  }

  /// Cambia el estado de verificación de la licencia de un especialista
  /// (aprobado/rechazado/bloqueado) desde el panel de administración.
  /// `observacion` es el motivo visible para el especialista (rechazo/bloqueo);
  /// al aprobar se limpia la observación previa.
  Future<void> updateVerificacion({
    required String especialistaId,
    required EstadoVerificacion estado,
    required String aprobadoPor,
    String? observacion,
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
      observacion: observacion,
      limpiarObservacion: estado == EstadoVerificacion.aprobado,
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

  /// Marca la solicitud como EN_REVISION (especialista ya tiene datos
  /// profesionales y documentos requeridos completos).
  Future<void> solicitarVerificacion({required String especialistaId}) async {
    final current = state;
    if (current is! SpecialistsLoaded) return;

    final result = await _solicitarVerificacion(
      SolicitarVerificacionParams(especialistaId),
    );
    result.fold(
      (f) => emit(SpecialistsError(f.message)),
      (actualizado) => emit(current.copyWith(especialista: actualizado)),
    );
  }

  /// Aprueba o rechaza un documento del especialista (panel de administración).
  Future<void> revisarDocumento({
    required String documentoId,
    required EstadoRevisionDocumento estado,
    String? observacion,
    required String revisadoPor,
  }) async {
    final current = state;
    if (current is! SpecialistsLoaded) return;

    final result = await _revisarDocumento(RevisarDocumentoParams(
      documentoId: documentoId,
      estado: estado,
      observacion: observacion,
      revisadoPor: revisadoPor,
    ));
    result.fold(
      (f) => emit(SpecialistsError(f.message)),
      (doc) {
        final docs = [
          for (final d in current.documentos) if (d.id == doc.id) doc else d,
        ];
        final docsPorEsp = Map<String, List<DocumentoEspecialistaEntity>>.from(
          current.documentosPorEspecialista,
        );
        final listaEsp = docsPorEsp[doc.especialistaId];
        if (listaEsp != null) {
          docsPorEsp[doc.especialistaId] = [
            for (final d in listaEsp) if (d.id == doc.id) doc else d,
          ];
        }
        emit(current.copyWith(
          documentos: docs,
          documentosPorEspecialista: docsPorEsp,
        ));
      },
    );
  }

  EspecialistaEntity? get especialista =>
      state is SpecialistsLoaded ? (state as SpecialistsLoaded).especialista : null;

  /// IDs de especialidades ya asociadas al especialista (para preselección).
  List<int> get especialidadIds =>
      state is SpecialistsLoaded
          ? (state as SpecialistsLoaded).especialidadIds
          : const [];

  /// true cuando el especialista ya tiene asociado un médico regente activo
  /// y al menos una especialidad (datos profesionales mínimos).
  bool get tieneDatosProfesionales {
    final s = state;
    if (s is! SpecialistsLoaded || s.especialista == null) return false;
    return s.especialista!.medicoRegenteId != null && s.especialidadIds.isNotEmpty;
  }
}