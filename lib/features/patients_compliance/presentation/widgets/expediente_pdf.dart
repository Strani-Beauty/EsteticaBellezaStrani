import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/entities/expediente_salud_entity.dart';
import '../../domain/entities/evaluacion_salud_entity.dart';

/// Construye el PDF del expediente de salud (ePHI) de un paciente.
///
/// Formato Letter, tipografía Helvetica (base de package:pdf, sin assets).
/// El documento es únicamente para uso del administrador (HIPAA: el ePHI se
/// entrega/exporta solo a petición justificada del paciente).
Future<Uint8List> generarExpedientePdf(
  ExpedienteSaludEntity expediente, {
  String? adminNombre,
}) async {
  final pdf = pw.Document();
  final fechaEmision = DateTime.now();
  final paciente = expediente.paciente;

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(36),
      theme: pw.ThemeData.withFont(base: pw.Font.helvetica()),
      header: (context) => pw.Container(
        alignment: pw.Alignment.centerLeft,
        padding: const pw.EdgeInsets.only(bottom: 8),
        decoration: pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: PdfColors.purple900)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'MERAKI spa onsite',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.purple900,
              ),
            ),
            pw.Text(
              'Expediente de Salud (ePHI)',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            ),
          ],
        ),
      ),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        padding: const pw.EdgeInsets.only(top: 8),
        child: pw.Text(
          'Confidencial — Información de salud protegida (HIPAA). Página ${context.pageNumber} de ${context.pagesCount}.',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ),
      build: (context) => [
        pw.Text(
          'Expediente de Salud — ${_fechaLarga(fechaEmision)}',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Emitido a petición del paciente. Documento interno de uso administrativo.',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 14),
        _seccion('Datos del paciente', [
          _fila('Nombre completo', expediente.fullName ?? '—'),
          _fila('Correo electrónico', expediente.email ?? '—'),
          _fila('Teléfono', expediente.phone ?? '—'),
          _fila(
            'Fecha de nacimiento',
            paciente.fechaNacimiento == null
                ? '—'
                : _fechaCorta(paciente.fechaNacimiento!),
          ),
          _fila('Edad', paciente.edad == null ? '—' : '${paciente.edad} años'),
          _fila('Género', paciente.genero ?? '—'),
          _fila('Activo', paciente.activo ? 'Sí' : 'No'),
        ]),
        pw.SizedBox(height: 12),
        _seccion('Datos clínicos', [
          _fila('Grupo sanguíneo', paciente.grupoSanguineo ?? '—'),
          _fila('Alergias', paciente.alergias ?? '—'),
          _fila('Antecedentes', paciente.antecedentes ?? '—'),
        ]),
        pw.SizedBox(height: 12),
        _seccion('Evaluaciones de salud', [
          if (expediente.evaluaciones.isEmpty)
            pw.Text(
              'Sin evaluaciones registradas.',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            )
          else
            for (var i = 0; i < expediente.evaluaciones.length; i++)
              _bloqueEvaluacion(expediente.evaluaciones[i], i + 1),
        ]),
        pw.SizedBox(height: 12),
        _seccion('Validación médica', _bloqueValidacion(expediente)),
        pw.SizedBox(height: 18),
        pw.Divider(color: PdfColors.grey400),
        pw.SizedBox(height: 8),
        pw.Text(
          'Generado por ${adminNombre?.trim().isNotEmpty == true ? adminNombre : 'Administrador'} · ${_fechaHora(fechaEmision)}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      ],
    ),
  );

  return pdf.save();
}

// ── Helpers de secciones ─────────────────────────────────────────────────────

pw.Widget _seccion(String titulo, List<pw.Widget> contenido) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: PdfColors.grey100,
      border: pw.Border.all(color: PdfColors.grey300),
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          titulo,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.purple900,
          ),
        ),
        pw.SizedBox(height: 6),
        ...contenido,
      ],
    ),
  );
}

pw.Widget _fila(String label, String valor) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 150,
          child: pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            valor,
            style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}

pw.Widget _bloqueEvaluacion(EvaluacionExpedienteEntity item, int indice) {
  final ev = item.evaluacion;
  final resultado = ev.resultado;
  final colorResultado = switch (resultado) {
    null => PdfColors.grey700,
    _ => ev.resultado!.toDb() == 'APTO'
        ? PdfColors.green800
        : ev.resultado!.toDb() == 'NO_APTO'
            ? PdfColors.red800
            : PdfColors.orange800,
  };
  final nombreCuestionario =
      item.cuestionarioNombre ?? 'Cuestionario #${ev.cuestionarioId}';
  final version = item.version ?? ev.versionCuestionario;

  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 8),
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      border: pw.Border.all(color: PdfColors.grey300),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              '$indice. $nombreCuestionario  ·  v$version',
              style: const pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                resultado == null ? 'SIN RESULTADO' : ev.resultado!.toDb(),
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: colorResultado,
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'Fecha: ${_fechaHora(ev.fechaEvaluacion)} · Estado: ${ev.estado}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        if (ev.riesgos.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            'Riesgos: ${ev.riesgos.map((r) => '${r.etiqueta}${r.critico ? ' (crítico)' : ''}').join(' · ')}',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.red800,
            ),
          ),
        ],
        pw.SizedBox(height: 6),
        if (item.respuestas.isEmpty)
          pw.Text(
            'Sin respuestas registradas.',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          )
        else
          for (final r in item.respuestas)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      r.preguntaTexto ?? 'Pregunta #${r.preguntaId}',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.SizedBox(
                    width: 140,
                    child: pw.Text(
                      r.valorLegible,
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: 9,
fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ],
    ),
  );
}

List<pw.Widget> _bloqueValidacion(ExpedienteSaludEntity expediente) {
  final v = expediente.validacion;
  if (v == null) {
    return [
      pw.Text(
        'Sin validación médica registrada.',
        style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
      ),
    ];
  }
  final estadoColor = v.estado == 'APROBADA'
      ? PdfColors.green800
      : v.estado == 'RECHAZADA'
          ? PdfColors.red800
          : PdfColors.orange800;
  return [
    _fila('Proveedor', v.proveedor.isEmpty ? '—' : v.proveedor),
    _fila('Estado', v.estado),
    _fila('Código de referencia', v.codigoReferencia ?? '—'),
    _fila(
      'Fecha de validación',
      v.fechaValidacion == null ? '—' : _fechaCorta(v.fechaValidacion!),
    ),
    _fila(
      'Fecha de vencimiento',
      v.fechaVencimiento == null ? '—' : _fechaCorta(v.fechaVencimiento!),
    ),
    if (v.observaciones != null && v.observaciones!.isNotEmpty)
      _fila('Observaciones', v.observaciones!),
    pw.SizedBox(height: 2),
    pw.Text(
      v.vigente
          ? 'Vigente'
          : v.vencida
              ? 'Vencida'
              : 'No vigente',
      style: pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: estadoColor,
      ),
    ),
  ];
}

// ── Helpers de fecha ─────────────────────────────────────────────────────────

String _fechaCorta(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

String _fechaLarga(DateTime dt) =>
    '${_fechaCorta(dt)} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

String _fechaHora(DateTime dt) => _fechaLarga(dt);