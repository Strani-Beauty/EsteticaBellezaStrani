import '../../domain/entities/documento_especialista_entity.dart';

/// Requisito de documento de compliance: un tipo principal y, opcionalmente,
/// tipos alternativos que lo cumplen (p.ej. formación = diploma o certificación).
class RequisitoDocumento {
  final TipoDocumento tipo;
  final String label;
  final String descripcion;
  final Set<TipoDocumento> alternativas;

  const RequisitoDocumento({
    required this.tipo,
    required this.label,
    required this.descripcion,
    this.alternativas = const {},
  });

  bool loCumple(DocumentoEspecialistaEntity d) =>
      d.tipoDocumento == tipo || alternativas.contains(d.tipoDocumento);
}

/// Requisitos obligatorios de compliance del especialista. La formación
/// profesional se cumple con `diploma` o `certificacion` (uno solo).
const List<RequisitoDocumento> requisitosDocumentos = [
  RequisitoDocumento(
    tipo: TipoDocumento.identificacion,
    label: 'Identificación oficial (Cédula o pasaporte)',
    descripcion: 'Documento que acredita tu identidad.',
  ),
  RequisitoDocumento(
    tipo: TipoDocumento.licencia,
    label: 'Licencia profesional',
    descripcion: 'Licencia o matrícula profesional vigente.',
  ),
  RequisitoDocumento(
    tipo: TipoDocumento.diploma,
    label: 'Formación profesional',
    descripcion: 'Diploma o certificación de tus estudios.',
    alternativas: {TipoDocumento.certificacion},
  ),
];

/// Tipos que el especialista puede adjuntar para satisfacer un requisito.
List<TipoDocumento> tiposDeRequisito(RequisitoDocumento r) =>
    [r.tipo, ...r.alternativas];

/// True si todos los requisitos tienen un documento activo que los cumple.
/// (Un documento rechazado queda `activo=false`, por lo que cuenta como
/// pendiente de volver a subir.)
bool tieneDocumentosRequeridos(List<DocumentoEspecialistaEntity> documentos) {
  return requisitosDocumentos.every(
    (r) => documentos.any((d) => d.activo && r.loCumple(d)),
  );
}

/// True si todos los requisitos tienen un documento APROBADO que los cumple.
/// (Criterio del expediente: para habilitar al especialista cada requisito
/// debe estar aprobado por el administrador.)
bool tieneDocumentosAprobadosRequeridos(
  List<DocumentoEspecialistaEntity> documentos,
) {
  return requisitosDocumentos.every(
    (r) => documentos.any(
      (d) =>
          d.estadoRevision == EstadoRevisionDocumento.aprobado &&
          r.loCumple(d),
    ),
  );
}

/// Tipos de documento que el especialista puede subir: los que no tienen un
/// documento APROBADO (primera carga o re-subida de un rechazado) ni un
/// documento ACTIVO pendiente de revisión (el trigger bloquea apilar
/// PENDIENTES del mismo tipo). Los tipos ya aprobados quedan fuera (se
/// conservan y no se pueden re-subir).
Set<TipoDocumento> tiposSubiblesDocumentos(
  List<DocumentoEspecialistaEntity> documentos,
) {
  final noSubibles = documentos
      .where((d) =>
          d.estadoRevision == EstadoRevisionDocumento.aprobado ||
          (d.activo && d.estadoRevision == EstadoRevisionDocumento.pendiente))
      .map((d) => d.tipoDocumento)
      .toSet();
  return TipoDocumento.values.where((t) => !noSubibles.contains(t)).toSet();
}

/// Devuelve un documento por tipo: el de mayor versión (el vigente). Evita
/// listar versiones antiguas (rechazadas/inactivas) en la sección del home:
/// tras re-subir, solo aparece la PENDIENTE, no la anterior RECHAZADA.
List<DocumentoEspecialistaEntity> documentosVigentes(
  List<DocumentoEspecialistaEntity> documentos,
) {
  final porTipo = <TipoDocumento, DocumentoEspecialistaEntity>{};
  for (final d in documentos) {
    final prev = porTipo[d.tipoDocumento];
    if (prev == null || d.versionDocumento > prev.versionDocumento) {
      porTipo[d.tipoDocumento] = d;
    }
  }
  final lista = porTipo.values.toList()
    ..sort((a, b) => a.tipoDocumento.index.compareTo(b.tipoDocumento.index));
  return lista;
}