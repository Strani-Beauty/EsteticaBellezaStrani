import '../../domain/entities/entrevista_medica_entity.dart';

/// Modelo de la entrevista médica F2F (`entrevistas_medicas`).
class EntrevistaMedicaModel {
  final String id;
  final String pacienteId;
  final String? pacienteUsuarioId;
  final String? pacienteNombre;
  final String? pacienteEmail;
  final String? evaluacionSaludId;
  final String? medicoId;
  final String? agendadaPor;
  final DateTime fechaProgramada;
  final int duracionMin;
  final String estado;
  final String salaId;
  final String? notasClinicas;
  final String? hallazgos;
  final bool consentimientoTelemedicina;
  final String? firmaConsentimientoUrl;
  final String? grabacionUrl;
  final String? dictamen;
  final String? dictamenObservaciones;
  final String? validacionId;
  final DateTime? iniciadaAt;
  final DateTime? finalizadaAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const EntrevistaMedicaModel({
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

  factory EntrevistaMedicaModel.fromJson(Map<String, dynamic> json) {
    final paciente = json['pacientes'] as Map<String, dynamic>?;
    final perfil = paciente?['profiles'] as Map<String, dynamic>?;
    return EntrevistaMedicaModel(
      id: (json['id'] as String?) ?? '',
      pacienteId: (json['paciente_id'] as String?) ?? '',
      pacienteUsuarioId: (paciente?['usuario_id'] as String?) ??
          (json['paciente_usuario_id'] as String?),
      pacienteNombre:
          (perfil?['full_name'] as String?) ?? (json['paciente_nombre'] as String?),
      pacienteEmail:
          (perfil?['email'] as String?) ?? (json['paciente_email'] as String?),
      evaluacionSaludId: json['evaluacion_salud_id'] as String?,
      medicoId: json['medico_id'] as String?,
      agendadaPor: json['agendada_por'] as String?,
      fechaProgramada: DateTime.tryParse(
              (json['fecha_programada'] as String?) ?? '') ??
          DateTime.now(),
      duracionMin: (json['duracion_min'] as num?)?.toInt() ?? 30,
      estado: (json['estado'] as String?) ?? 'PROGRAMADA',
      salaId: (json['sala_id'] as String?) ?? '',
      notasClinicas: json['notas_clinicas'] as String?,
      hallazgos: json['hallazgos'] as String?,
      consentimientoTelemedicina: json['consentimiento_telemedicina'] == true,
      firmaConsentimientoUrl: json['firma_consentimiento_url'] as String?,
      grabacionUrl: json['grabacion_url'] as String?,
      dictamen: json['dictamen'] as String?,
      dictamenObservaciones: json['dictamen_observaciones'] as String?,
      validacionId: json['validacion_id'] as String?,
      iniciadaAt: json['iniciada_at'] != null
          ? DateTime.tryParse(json['iniciada_at'].toString())
          : null,
      finalizadaAt: json['finalizada_at'] != null
          ? DateTime.tryParse(json['finalizada_at'].toString())
          : null,
      createdAt: DateTime.tryParse((json['created_at'] as String?) ?? '') ??
          DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  EntrevistaMedicaEntity toEntity() => EntrevistaMedicaEntity(
        id: id,
        pacienteId: pacienteId,
        pacienteUsuarioId: pacienteUsuarioId,
        pacienteNombre: pacienteNombre,
        pacienteEmail: pacienteEmail,
        evaluacionSaludId: evaluacionSaludId,
        medicoId: medicoId,
        agendadaPor: agendadaPor,
        fechaProgramada: fechaProgramada,
        duracionMin: duracionMin,
        estado: EstadoEntrevistaX.fromDb(estado),
        salaId: salaId,
        notasClinicas: notasClinicas,
        hallazgos: hallazgos,
        consentimientoTelemedicina: consentimientoTelemedicina,
        firmaConsentimientoUrl: firmaConsentimientoUrl,
        grabacionUrl: grabacionUrl,
        dictamen: DictamenEntrevistaX.fromDb(dictamen),
        dictamenObservaciones: dictamenObservaciones,
        validacionId: validacionId,
        iniciadaAt: iniciadaAt,
        finalizadaAt: finalizadaAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
