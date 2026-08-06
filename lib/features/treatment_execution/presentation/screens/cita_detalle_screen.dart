import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import '../../domain/entities/cita_ejecucion_entity.dart';
import '../../domain/entities/consentimiento_tratamiento_entity.dart';
import '../../domain/entities/producto_aplicado_entity.dart';
import '../../domain/entities/tratamiento_entity.dart';
import '../cubits/treatment_execution_cubit.dart';
import '../widgets/estado_chip.dart';
import '../widgets/producto_card.dart';
import 'firma_consentimiento_screen.dart';

/// Ejecución de una cita: ciclo de estados, tratamiento, insumos y firma.
class CitaDetalleScreen extends StatefulWidget {
  final String citaId;
  const CitaDetalleScreen({super.key, required this.citaId});

  @override
  State<CitaDetalleScreen> createState() => _CitaDetalleScreenState();
}

class _CitaDetalleScreenState extends State<CitaDetalleScreen> {
  @override
  void initState() {
    super.initState();
    context.read<TreatmentExecutionCubit>().loadDetalle(citaId: widget.citaId);
  }

  void _mensaje(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TreatmentExecutionCubit>();
    return Scaffold(
      appBar: AppBar(title: const Text('Ejecutar cita')),
      body: BlocConsumer<TreatmentExecutionCubit, TreatmentExecutionState>(
        listenWhen: (prev, curr) =>
            curr is TreatmentExecutionError ||
            (prev is TreatmentExecutionLoaded &&
                curr is TreatmentExecutionLoaded &&
                prev.trabajando &&
                !curr.trabajando &&
                curr.cita?.estado == EstadoCitaEjecucion.finalizada),
        listener: (context, state) {
          if (state is TreatmentExecutionError) _mensaje(state.message);
          if (state is TreatmentExecutionLoaded &&
              state.cita?.estado == EstadoCitaEjecucion.finalizada) {
            Navigator.of(context).pop();
          }
        },
        builder: (context, state) {
          if (state is TreatmentExecutionLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is TreatmentExecutionError) {
            return Center(child: Text(state.message));
          }
          if (state is! TreatmentExecutionLoaded || state.cita == null) {
            return const SizedBox.shrink();
          }
          final cita = state.cita!;
          final tratamiento = cita.tratamiento;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _InfoHeader(cita: cita),
              const SizedBox(height: 16),
              if (cita.estado == EstadoCitaEjecucion.programada)
                _AccionButton(
                  icon: Icons.directions_walk_rounded,
                  label: 'Comenzar desplazamiento',
                  onPressed: () => cubit.avanzar(
                    citaId: cita.id,
                    nuevoEstado: EstadoCitaEjecucion.enCamino,
                  ),
                ),
              if (cita.estado == EstadoCitaEjecucion.enCamino)
                _AccionButton(
                  icon: Icons.pin_drop_rounded,
                  label: 'Llegué al domicilio',
                  onPressed: () => cubit.avanzar(
                    citaId: cita.id,
                    nuevoEstado: EstadoCitaEjecucion.llego,
                  ),
                ),
              if (cita.estado == EstadoCitaEjecucion.llego)
                _AccionButton(
                  icon: Icons.play_circle_outline_rounded,
                  label: 'Iniciar servicio',
                  onPressed: () async {
                    await cubit.avanzar(
                      citaId: cita.id,
                      nuevoEstado: EstadoCitaEjecucion.enProceso,
                    );
                    if (mounted) {
                      await cubit.iniciarTratamiento(citaId: cita.id);
                    }
                  },
                ),
              if (cita.estado == EstadoCitaEjecucion.enProceso) ...[
                if (tratamiento != null) ...[
                  _EvaluacionCard(
                    tratamientoId: tratamiento.id,
                    evaluacion: tratamiento.evaluacionInicial,
                  ),
                  const SizedBox(height: 16),
                  _ProductosSection(
                    tratamientoId: tratamiento.id,
                    productos: state.productos,
                    trabajando: state.trabajando,
                  ),
                  const SizedBox(height: 16),
                  _FirmaSection(
                    tratamiento: tratamiento,
                    consentimiento: state.consentimiento,
                  ),
                  const SizedBox(height: 16),
                  _AccionButton(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Finalizar tratamiento',
                    color: AppTheme.cBrandGreen,
                    onPressed: () => _dialogoFinalizar(cubit, cita, tratamiento.id),
                  ),
                ],
              ],
              if (cita.estado == EstadoCitaEjecucion.finalizada)
                const _EstadoFinal(icon: Icons.task_alt, texto: 'Cita finalizada'),
              if (cita.estado == EstadoCitaEjecucion.cancelada ||
                  cita.estado == EstadoCitaEjecucion.noCompletada)
                const _EstadoFinal(
                    icon: Icons.cancel_outlined, texto: 'Cita sin ejecutar'),
            ],
          );
        },
      ),
    );
  }

  Future<void> _dialogoFinalizar(
    TreatmentExecutionCubit cubit,
    CitaEjecucionEntity cita,
    String tratamientoId,
  ) async {
    final observaciones = TextEditingController();
    final recomendaciones = TextEditingController();
    final guardar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalizar tratamiento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: observaciones,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Observaciones finales',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: recomendaciones,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Recomendaciones post tratamiento',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
    if (guardar == true && mounted) {
      await cubit.finalizar(
        citaId: cita.id,
        tratamientoId: tratamientoId,
        observacionesFinales:
            observaciones.text.isEmpty ? null : observaciones.text,
        recomendacionesPostTratamiento: recomendaciones.text.isEmpty
            ? null
            : recomendaciones.text,
      );
    }
  }
}

// ── Header con datos de paciente/servicio ─────────────────────────

class _InfoHeader extends StatelessWidget {
  final CitaEjecucionEntity cita;
  const _InfoHeader({required this.cita});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Paciente',
                      style: TextStyle(color: AppTheme.cMutedText, fontSize: 12)),
                ),
                EstadoChip(estado: cita.estado),
              ],
            ),
            const SizedBox(height: 4),
            Text(cita.pacienteNombre,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            if (cita.pacienteTelefono != null)
              Text('Tel: ${cita.pacienteTelefono}',
                  style: const TextStyle(color: AppTheme.cMutedText)),
            const Divider(height: 24),
            _fila('Servicio', cita.servicioNombre),
            _fila('Precio base', '\$${cita.precioBase.toStringAsFixed(2)}'),
            if (cita.direccion != null)
              _fila('Dirección',
                  '${cita.direccion}${cita.ciudad != null ? ', ${cita.ciudad}' : ''}'),
            if (cita.fechaAceptacion != null)
              _fila('Aceptada',
                  '${cita.fechaAceptacion!.day}/${cita.fechaAceptacion!.month}/${cita.fechaAceptacion!.year}'),
          ],
        ),
      ),
    );
  }

  Widget _fila(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: Text(k,
                  style: const TextStyle(
                      color: AppTheme.cMutedText, fontSize: 12)),
            ),
            Expanded(
              child: Text(v, style: const TextStyle(fontSize: 14)),
            ),
          ],
        ),
      );
}

// ── Evaluación inicial ────────────────────────────────────────────

class _EvaluacionCard extends StatefulWidget {
  final String tratamientoId;
  final String? evaluacion;
  const _EvaluacionCard({required this.tratamientoId, this.evaluacion});

  @override
  State<_EvaluacionCard> createState() => _EvaluacionCardState();
}

class _EvaluacionCardState extends State<_EvaluacionCard> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.evaluacion ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Evaluación inicial',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Anamnesis, área a tratar, notas de la sesión…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: () {
                  context.read<TreatmentExecutionCubit>().guardarEvaluacion(
                    tratamientoId: widget.tratamientoId,
                    evaluacionInicial:
                        _controller.text.trim().isEmpty ? null : _controller.text.trim(),
                  );
                },
                child: const Text('Guardar evaluación'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Insumos aplicados ─────────────────────────────────────────────

class _ProductosSection extends StatelessWidget {
  final String tratamientoId;
  final List<ProductoAplicadoEntity> productos;
  final bool trabajando;
  const _ProductosSection({
    required this.tratamientoId,
    required this.productos,
    required this.trabajando,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Insumos aplicados',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (productos.isEmpty)
              const Text('Sin insumos registrados',
                  style: TextStyle(color: AppTheme.cMutedText)),
            ...productos.map((p) => ProductoCard(
                  producto: p,
                  onDelete: trabajando
                      ? null
                      : () => context
                          .read<TreatmentExecutionCubit>()
                          .eliminarProducto(p.id),
                )),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: () =>
                    _dialogoProducto(context, tratamientoId),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 18),
                    SizedBox(width: 6),
                    Text('Agregar insumo'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _dialogoProducto(BuildContext context, String tratamientoId) async {
    final nombre = TextEditingController();
    final fabricante = TextEditingController();
    final lote = TextEditingController();
    final cantidad = TextEditingController(text: '1');
    final unidad = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar insumo'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombre,
                decoration: const InputDecoration(
                    labelText: 'Producto *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: fabricante,
                decoration: const InputDecoration(
                    labelText: 'Fabricante', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lote,
                decoration: const InputDecoration(
                    labelText: 'Lote', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: cantidad,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Cantidad *', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: unidad,
                      decoration: const InputDecoration(
                          labelText: 'Unidad', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final n = nombre.text.trim();
              if (n.isEmpty) return;
              context.read<TreatmentExecutionCubit>().agregarProducto(
                    tratamientoId: tratamientoId,
                    productoNombre: n,
                    fabricante: fabricante.text.trim().isEmpty
                        ? null
                        : fabricante.text.trim(),
                    lote: lote.text.trim().isEmpty ? null : lote.text.trim(),
                    cantidadTotal:
                        double.tryParse(cantidad.text.trim()) ?? 1,
                    unidadMedida:
                        unidad.text.trim().isEmpty ? null : unidad.text.trim(),
                  );
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

// ── Firma / consentimiento ────────────────────────────────────────

class _FirmaSection extends StatelessWidget {
  final TratamientoEntity tratamiento;
  final ConsentimientoTratamientoEntity? consentimiento;
  const _FirmaSection({required this.tratamiento, this.consentimiento});

  @override
  Widget build(BuildContext context) {
    final firmado = consentimiento?.firmado == true;
    return Card(
      child: ListTile(
        leading: Icon(
          firmado ? Icons.verified_rounded : Icons.edit_document,
          color: firmado ? AppTheme.cBrandGreen : AppTheme.cDeepAccent,
          size: 32,
        ),
        title: Text(firmado ? 'Consentimiento firmado' : 'Consentimiento pendiente'),
        subtitle: Text(
          firmado
              ? 'Firmado el ${_fecha(consentimiento!.fechaFirma)}'
              : 'Solicita la firma del paciente para continuar.',
        ),
        trailing: firmado
            ? null
            : FilledButton.tonal(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => FirmaConsentimientoScreen(
                      tratamientoId: tratamiento.id,
                      pacienteId: tratamiento.pacienteId,
                      tipoConsentimiento: 'TRATAMIENTO_ESTETICO',
                    ),
                  ));
                },
                child: const Text('Firmar'),
              ),
      ),
    );
  }

  String _fecha(DateTime? d) =>
      d == null ? '—' : '${d.day}/${d.month}/${d.year}';
}

// ── Botones y estados ─────────────────────────────────────────────

class _AccionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color color;
  const _AccionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color = AppTheme.cDeepAccent,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

class _EstadoFinal extends StatelessWidget {
  final IconData icon;
  final String texto;
  const _EstadoFinal({required this.icon, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 64, color: AppTheme.cBrandGreen),
        const SizedBox(height: 8),
        Text(texto, style: const TextStyle(fontSize: 16)),
      ],
    );
  }
}