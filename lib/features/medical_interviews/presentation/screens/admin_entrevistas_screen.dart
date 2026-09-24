import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:esteticaybellezastrani/app/config/app_routes.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/presentation/widgets/advertencia_expediente_dialog.dart';
import '../../domain/entities/entrevista_medica_entity.dart';
import '../cubits/entrevistas_cubit.dart';

/// Panel admin: agenda de entrevistas médicas F2F (videollamada) con filtro
/// por estado. Desde aquí se agenda, se conduce la entrevista y se emite el
/// dictamen del examen médico total (ePHI/HIPAA).
class AdminEntrevistasScreen extends StatefulWidget {
  const AdminEntrevistasScreen({super.key});

  @override
  State<AdminEntrevistasScreen> createState() => _AdminEntrevistasScreenState();
}

class _AdminEntrevistasScreenState extends State<AdminEntrevistasScreen> {
  bool _cargado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_cargado) {
      _cargado = true;
      context.read<EntrevistasCubit>().load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Entrevistas Médicas')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.cDeepAccent,
        foregroundColor: Colors.white,
        onPressed: () async {
          if (await confirmarAccesoExpediente(context)) {
            if (context.mounted) {
              context.push(AppRoutes.adminAgendarEntrevista);
            }
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Agendar'),
      ),
      body: BlocConsumer<EntrevistasCubit, EntrevistasState>(
        listener: (context, state) {
          if (state is EntrevistasError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppTheme.cError),
            );
          }
        },
        builder: (context, state) {
          if (state is EntrevistasLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is EntrevistasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.cError)),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () =>
                        context.read<EntrevistasCubit>().load(),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          if (state is EntrevistasLoaded) {
            final entrevistas = state.entrevistas;
            if (entrevistas.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No hay entrevistas agendadas.\nUsa "Agendar" para crear la primera.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.cMutedText),
                  ),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () => context.read<EntrevistasCubit>().refrescar(),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                itemCount: entrevistas.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) =>
                    _EntrevistaTile(entrevistas[index]),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _EntrevistaTile extends StatelessWidget {
  final EntrevistaMedicaEntity entrevista;
  const _EntrevistaTile(this.entrevista);

  @override
  Widget build(BuildContext context) {
    final color = _colorEstado(entrevista.estado);
    return Card(
      elevation: 0,
      color: AppTheme.cSurface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        side: const BorderSide(color: Colors.black12),
      ),
      child: ListTile(
        onTap: () async {
          if (await confirmarAccesoExpediente(context)) {
            if (context.mounted) {
              context.push(AppRoutes.adminEntrevistaDetalle,
                  extra: entrevista);
            }
          }
        },
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(Icons.videocam_rounded, color: color),
        ),
        title: Text(
          entrevista.pacienteNombre ?? 'Paciente',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontWeight: FontWeight.w600, color: AppTheme.cDarkText),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_fmtFechaHora(entrevista.fechaProgramada)} · ${entrevista.duracionMin} min',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.cMutedText),
              ),
              if (entrevista.dictamen != null)
                Text('Dictamen: ${entrevista.dictamen!.toDb()}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Text(
                entrevista.estado.toDb().replaceAll('_', ' '),
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700, color: color),
              ),
            ),
            const SizedBox(height: 4),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.cDeepAccent),
          ],
        ),
      ),
    );
  }
}

Color _colorEstado(EstadoEntrevista estado) {
  switch (estado) {
    case EstadoEntrevista.programada:
      return AppTheme.cGoldAccent;
    case EstadoEntrevista.enCurso:
      return AppTheme.cDeepAccent;
    case EstadoEntrevista.completada:
      return AppTheme.cBrandGreen;
    case EstadoEntrevista.cancelada:
    case EstadoEntrevista.noAsistio:
      return AppTheme.cError;
  }
}

String _fmtFechaHora(DateTime dt) {
  final l = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
}
