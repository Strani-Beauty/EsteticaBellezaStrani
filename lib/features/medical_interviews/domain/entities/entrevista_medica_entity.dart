import 'package:equatable/equatable.dart';

/// Estado de la entrevista médica F2F (alineado a `entrevistas_medicas.estado`).
enum EstadoEntrevista { programada, enCurso, completada, cancelada, noAsistio }

extension EstadoEntrevistaX on EstadoEntrevista {
  String toDb() {
    switch (this) {
      case EstadoEntrevista.programada:
        return 'PROGRAMADA';
      case EstadoEntrevista.enCurso:
        return 'EN_CURSO';
      case EstadoEntrevista.completada:
        return 'COMPLETADA';
      case EstadoEntrevista.cancelada:
        return 'CANCELADA';
      case EstadoEntrevista.noAsistio:
        return 'NO_ASISTIO';
    }
  }

  static EstadoEntrevista fromDb(String? value) {
    switch ((value ?? '').toUpperCase()) {
      case 'EN_CURSO':
        return EstadoEntrevista.enCurso;
      case 'COMPLETADA':
        return EstadoEntrevista.completada;
      case 'CANCELADA':
        return EstadoEntrevista.cancelada;
      case 'NO_ASISTIO':
        return EstadoEntrevista.noAsistio;
      case 'PROGRAMADA':
      default:
        return EstadoEntrevista.programada;
    }
  }
}

/// Dictamen del examen médico total (alineado a `entrevistas_medicas.dictamen`).
enum DictamenEntrevista { apto, noApto, requiereRevision }

extension DictamenEntrevistaX on DictamenEntrevista {
  String toDb() {
    switch (this) {
      case DictamenEntrevista.apto:
        return 'APTO';
      case DictamenEntrevista.noApto:
        return 'NO_APTO';
      case DictamenEntrevista.requiereRevision:
        return 'REQUIERE_REVISION';
    }
  }

  static DictamenEntrevista? fromDb(String? value) {
    switch ((value ?? '').toUpperCase()) {
      case 'APTO':
        return DictamenEntrevista.apto;
      case 'NO_APTO':
        return DictamenEntrevista.noApto;
      case 'REQUIERE_REVISION':
        return DictamenEntrevista.requiereRevision;
      default:
        return null;
    }
  }
}

/// Entrevista médica F2F por videollamada (ePHI).
class EntrevistaMedicaEntity extends Equatable {
  final String id; // uuid
  final String pacienteId; // FK pacientes.id
  final String? pacienteUsuarioId; // FK profiles.id (join)
  final String? pacienteNombre; // join profiles.full_name
  final String? pacienteEmail; // join profiles.email
  final String? evaluacionSaludId;
  final String? medicoId;
  final String? agendadaPor;
  final DateTime fechaProgramada;
  final int duracionMin;
  final EstadoEntrevista estado;
  final String salaId;
  final String? notasClinicas;
  final String? hallazgos;
  final bool consentimientoTelemedicina;
  final String? firmaConsentimientoUrl;
  final String? grabacionUrl;
  final DictamenEntrevista? dictamen;
  final String? dictamenObservaciones;
  final String? validacionId;
  final DateTime? iniciadaAt;
  final DateTime? finalizadaAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const EntrevistaMedicaEntity({
    required this.id,
    required this.pacienteId,
    this.pacienteUsuarioId,
    this.pacienteNombre,
    this.pacienteEmail,
    this.evaluacionSaludId,
    this.medicoId,
    this.agendadaPor,
    required this.fechaProgramada,
    this.duracionMin = 30,
    required this.estado,
    required this.salaId,
    this.notasClinicas,
    this.hallazgos,
    this.consentimientoTelemedicina = false,
    this.firmaConsentimientoUrl,
    this.grabacionUrl,
    this.dictamen,
    this.dictamenObservaciones,
    this.validacionId,
    this.iniciadaAt,
    this.finalizadaAt,
    required this.createdAt,
    this.updatedAt,
  });

  bool get emitida => dictamen != null;
  bool get activa =>
      estado == EstadoEntrevista.programada || estado == EstadoEntrevista.enCurso;
  bool get cerrada =>
      estado == EstadoEntrevista.completada ||
      estado == EstadoEntrevista.cancelada ||
      estado == EstadoEntrevista.noAsistio;

  @override
  List<Object?> get props => [id, pacienteId, estado, dictamen, fechaProgramada];
}
