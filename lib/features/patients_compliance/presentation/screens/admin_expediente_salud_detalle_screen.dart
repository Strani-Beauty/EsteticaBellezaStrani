import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart';

import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/features/admin_users/domain/entities/paciente_admin_entity.dart';
import 'package:esteticaybellezastrani/features/auth_users/presentation/cubits/auth_cubit.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/domain/entities/expediente_salud_entity.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/domain/entities/evaluacion_salud_entity.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/presentation/cubits/expediente_salud_cubit.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/presentation/widgets/expediente_pdf.dart';

/// Detalle del expediente de salud (ePHI) de un paciente: perfil, clínicos,
/// histórico de evaluaciones con respuestas, validación médica y exportación
/// a PDF (imprimir / descargar). Solo accesible por administradores.
class ExpedienteSaludDetalleScreen extends StatefulWidget {
  final PacienteAdminEntity paciente;
  const ExpedienteSaludDetalleScreen({super.key, required this.paciente});

  @override
  State<ExpedienteSaludDetalleScreen> createState() =>
      _ExpedienteSaludDetalleScreenState();
}

class _ExpedienteSaludDetalleScreenState
    extends State<ExpedienteSaludDetalleScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ExpedienteSaludCubit>().cargarExpediente(widget.paciente.usuarioId);
    context.read<ExpedienteSaludCubit>().auditar('EXPEDIENTE_SALUD_VISTO');
  }

  Future<void> _exportar(ExpedienteSaludEntity expediente,
      {required bool imprimir}) async {
    final adminNombre = context.read<AuthCubit>().currentProfile?.fullName;
    final bytes = await generarExpedientePdf(expediente, adminNombre: adminNombre);
    if (!mounted) return;
    if (imprimir) {
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } else {
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'expediente_salud_${expediente.paciente.profileId}.pdf',
      );
    }
    if (mounted) {
      context.read<ExpedienteSaludCubit>().auditar('EXPEDIENTE_SALUD_PDF');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expediente de Salud')),
      body: BlocBuilder<ExpedienteSaludCubit, ExpedienteSaludState>(
        builder: (context, state) {
          if (state is ExpedienteSaludLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is ExpedienteSaludError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 48, color: AppTheme.cError),
                  const SizedBox(height: 12),
                  Text(state.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.cError)),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => context
                        .read<ExpedienteSaludCubit>()
                        .cargarExpediente(widget.paciente.usuarioId),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          if (state is ExpedienteSaludLoaded) {
            return _buildContenido(context, state.expediente);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildContenido(BuildContext context, ExpedienteSaludEntity exp) {
    final paciente = exp.paciente;
    return RefreshIndicator(
      onRefresh: () =>
          context.read<ExpedienteSaludCubit>().cargarExpediente(exp.paciente.profileId),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _cardAcciones(exp),
          const SizedBox(height: 12),
          _seccion(
            'Datos del paciente',
            [
              _fila('Nombre', exp.fullName ?? '—'),
              _fila('Correo', exp.email ?? '—'),
              _fila('Teléfono', exp.phone ?? '—'),
              _fila(
                'Fecha de nacimiento',
                paciente.fechaNacimiento == null
                    ? '—'
                    : _fmtFecha(paciente.fechaNacimiento!),
              ),
              _fila('Edad', paciente.edad == null ? '—' : '${paciente.edad} años'),
              _fila('Género', paciente.genero ?? '—'),
              _fila('Activo', paciente.activo ? 'Sí' : 'No'),
            ],
          ),
          const SizedBox(height: 12),
          _seccion(
            'Datos clínicos',
            [
              _fila('Grupo sanguíneo', paciente.grupoSanguineo ?? '—'),
              _fila('Alergias', paciente.alergias ?? '—'),
              _fila('Antecedentes', paciente.antecedentes ?? '—'),
            ],
          ),
          const SizedBox(height: 12),
          _seccion('Evaluaciones de salud', [
            if (exp.evaluaciones.isEmpty)
              const Text('Sin evaluaciones registradas.',
                  style: TextStyle(color: AppTheme.cMutedText))
            else
              for (var i = 0; i < exp.evaluaciones.length; i++)
                _cardEvaluacion(exp.evaluaciones[i], i + 1),
          ]),
          const SizedBox(height: 12),
          _seccion('Validación médica', _bloqueValidacion(exp)),
          const SizedBox(height: 16),
          const Text(
            'Información de salud protegida (HIPAA). El acceso y la exportación quedan registrados en la auditoría.',
            style: TextStyle(fontSize: 11, color: AppTheme.cMutedText),
          ),
        ],
      ),
    );
  }

  Widget _cardAcciones(ExpedienteSaludEntity exp) {
    return Card(
      elevation: 0,
      color: AppTheme.cSurface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: const BorderSide(color: Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exp.fullName ?? widget.paciente.fullName ?? 'Paciente',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.cDarkText),
            ),
            if (exp.email != null) ...[
              const SizedBox(height: 2),
              Text(exp.email!,
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.cMutedText)),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.cDeepAccent),
                    onPressed: () => _exportar(exp, imprimir: true),
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: const Text('Imprimir'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.cDeepAccent,
                      side: const BorderSide(color: AppTheme.cDeepAccent),
                    ),
                    onPressed: () => _exportar(exp, imprimir: false),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Descargar PDF'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _seccion(String titulo, List<Widget> contenido) {
    return Card(
      elevation: 0,
      color: AppTheme.cSurface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: const BorderSide(color: Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.cDeepAccent)),
            const SizedBox(height: 10),
            ...contenido,
          ],
        ),
      ),
    );
  }

  Widget _fila(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.cMutedText)),
          ),
          Expanded(
            child: Text(valor,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.cDarkText)),
          ),
        ],
      ),
    );
  }

  Widget _cardEvaluacion(EvaluacionExpedienteEntity item, int indice) {
    final ev = item.evaluacion;
    final resultado = ev.resultado;
    final colorResultado = resultado == null
        ? AppTheme.cMutedText
        : (resultado.toDb() == 'APTO'
            ? AppTheme.cBrandGreen
            : resultado.toDb() == 'NO_APTO'
                ? AppTheme.cError
                : AppTheme.cGoldAccent);
    final nombreCuestionario =
        item.cuestionarioNombre ?? 'Cuestionario #${ev.cuestionarioId}';
    final version = item.version ?? ev.versionCuestionario;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cWhite,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('$indice. $nombreCuestionario  ·  v$version',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colorResultado.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Text(
                  resultado == null ? 'SIN RESULTADO' : resultado.toDb(),
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: colorResultado),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text('Fecha: ${_fmtFecha(ev.fechaEvaluacion)} · Estado: ${ev.estado}',
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.cMutedText)),
          if (ev.riesgos.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Riesgos: ${ev.riesgos.map((r) => '${r.etiqueta}${r.critico ? ' (crítico)' : ''}').join(' · ')}',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.cError),
            ),
          ],
          const SizedBox(height: 8),
          if (item.respuestas.isEmpty)
            const Text('Sin respuestas registradas.',
                style: TextStyle(
                    fontSize: 11, color: AppTheme.cMutedText))
          else
            for (final r in item.respuestas)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        r.preguntaTexto ?? 'Pregunta #${r.preguntaId}',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.cDarkText),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      r.valorLegible,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  List<Widget> _bloqueValidacion(ExpedienteSaludEntity exp) {
    final v = exp.validacion;
    if (v == null) {
      return const [
        Text('Sin validación médica registrada.',
            style: TextStyle(color: AppTheme.cMutedText)),
      ];
    }
    final estadoColor = v.estado == 'APROBADA'
        ? AppTheme.cBrandGreen
        : v.estado == 'RECHAZADA'
            ? AppTheme.cError
            : AppTheme.cGoldAccent;
    return [
      _fila('Proveedor', v.proveedor.isEmpty ? '—' : v.proveedor),
      _fila('Estado', v.estado),
      _fila('Código de referencia', v.codigoReferencia ?? '—'),
      _fila('Fecha de validación',
          v.fechaValidacion == null ? '—' : _fmtFecha(v.fechaValidacion!)),
      _fila('Fecha de vencimiento',
          v.fechaVencimiento == null ? '—' : _fmtFecha(v.fechaVencimiento!)),
      if (v.observaciones != null && v.observaciones!.isNotEmpty)
        _fila('Observaciones', v.observaciones!),
      const SizedBox(height: 4),
      Text(
        v.vigente
            ? 'Vigente'
            : v.vencida
                ? 'Vencida'
                : 'No vigente',
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, color: estadoColor),
      ),
    ];
  }

  String _fmtFecha(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}