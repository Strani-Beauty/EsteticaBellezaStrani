import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/features/admin_users/domain/entities/paciente_admin_entity.dart';
import 'package:esteticaybellezastrani/features/admin_users/presentation/cubits/admin_pacientes_cubit.dart';
import '../cubits/entrevistas_cubit.dart';

/// Pantalla admin: agendar una entrevista médica F2F por videollamada
/// (selector de paciente + fecha/hora + duración).
class AgendarEntrevistaScreen extends StatefulWidget {
  const AgendarEntrevistaScreen({super.key});

  @override
  State<AgendarEntrevistaScreen> createState() =>
      _AgendarEntrevistaScreenState();
}

class _AgendarEntrevistaScreenState extends State<AgendarEntrevistaScreen> {
  bool _cargado = false;
  String? _pacienteId;
  DateTime? _fecha;
  int _duracion = 30;
  bool _enviando = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_cargado) {
      _cargado = true;
      final state = context.read<AdminPacientesCubit>().state;
      if (state is! AdminPacientesLoaded) {
        context.read<AdminPacientesCubit>().loadPacientes();
      }
    }
  }

  Future<void> _seleccionarFechaHora() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _fecha ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay.fromDateTime(_fecha ?? now.add(const Duration(hours: 2))),
    );
    if (time == null || !mounted) return;

    setState(() {
      _fecha =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _agendar() async {
    if (_pacienteId == null) {
      _snack('Selecciona un paciente.');
      return;
    }
    if (_fecha == null) {
      _snack('Selecciona fecha y hora de la entrevista.');
      return;
    }
    setState(() => _enviando = true);
    final error = await context.read<EntrevistasCubit>().agendar(
          pacienteId: _pacienteId!,
          fechaProgramada: _fecha!,
          duracionMin: _duracion,
        );
    if (!mounted) return;
    setState(() => _enviando = false);
    if (error != null) {
      _snack(error, error: true);
      return;
    }
    Navigator.of(context).pop(true);
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppTheme.cError : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agendar entrevista médica')),
      body: BlocBuilder<AdminPacientesCubit, AdminPacientesState>(
        builder: (context, state) {
          if (state is AdminPacientesLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is AdminPacientesError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.cError)),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => context
                        .read<AdminPacientesCubit>()
                        .loadPacientes(),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          final pacientes =
              state is AdminPacientesLoaded ? state.pacientes : <PacienteAdminEntity>[];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Agenda una entrevista por videollamada donde el médico '
                'evaluará el examen médico total (evaluación médica + entrevista).',
                style: TextStyle(fontSize: 13, color: AppTheme.cMutedText),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: _pacienteId,
                isExpanded: true,
                decoration: AppTheme.fieldDecoration(
                  label: 'Paciente',
                  prefix:
                      const Icon(Icons.person_outline_rounded, size: 20),
                ),
                items: [
                  for (final p in pacientes)
                    DropdownMenuItem(
                      value: p.id,
                      child: Text(
                        p.fullName?.isNotEmpty == true
                            ? '${p.fullName} · ${p.email ?? ''}'
                            : (p.email ?? 'Paciente'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _pacienteId = v),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _seleccionarFechaHora,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: InputDecorator(
                  decoration: AppTheme.fieldDecoration(
                    label: 'Fecha y hora',
                    prefix: const Icon(Icons.event_rounded, size: 20),
                  ),
                  child: Text(
                    _fecha == null
                        ? 'Seleccionar fecha y hora'
                        : _fmtFechaHora(_fecha!),
                    style: TextStyle(
                      color: _fecha == null
                          ? AppTheme.cMutedText
                          : AppTheme.cDarkText,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _duracion,
                decoration: AppTheme.fieldDecoration(
                  label: 'Duración',
                  prefix: const Icon(Icons.timer_outlined, size: 20),
                ),
                items: const [
                  DropdownMenuItem(value: 30, child: Text('30 minutos')),
                  DropdownMenuItem(value: 45, child: Text('45 minutos')),
                  DropdownMenuItem(value: 60, child: Text('60 minutos')),
                ],
                onChanged: (v) => setState(() => _duracion = v ?? 30),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.cDeepAccent),
                onPressed: _enviando ? null : _agendar,
                icon: _enviando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.videocam_rounded),
                label: const Text('Agendar y notificar al paciente'),
              ),
              const SizedBox(height: 12),
              const Text(
                'El paciente recibirá una notificación y un recordatorio antes '
                'de la entrevista.',
                style: TextStyle(fontSize: 11, color: AppTheme.cMutedText),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _fmtFechaHora(DateTime dt) {
  final l = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
}
