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
bool tieneDocumentosRequeridos(List<DocumentoEspecialistaEntity> documentos) {
  return requisitosDocumentos.every(
    (r) => documentos.any((d) => d.activo && r.loCumple(d)),
  );
}