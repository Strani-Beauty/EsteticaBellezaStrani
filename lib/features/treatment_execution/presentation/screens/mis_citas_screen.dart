import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/app/config/app_routes.dart';
import '../../domain/entities/cita_ejecucion_entity.dart';
import '../cubits/treatment_execution_cubit.dart';
import '../widgets/estado_chip.dart';

/// Citas asignadas al especialista: pestañas Activas (pendientes/próximas) e
/// Historial (finalizadas, canceladas y no completadas).
class MisCitasScreen extends StatefulWidget {
  final String especialistaId;
  const MisCitasScreen({super.key, required this.especialistaId});

  @override
  State<MisCitasScreen> createState() => _MisCitasScreenState();
}

class _MisCitasScreenState extends State<MisCitasScreen> {
  @override
  void initState() {
    super.initState();
    final cubit = context.read<TreatmentExecutionCubit>();
    cubit.loadCitas(especialistaId: widget.especialistaId);
    cubit.loadCitasHistorial(especialistaId: widget.especialistaId);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mis citas'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Activas'),
              Tab(text: 'Historial'),
            ],
          ),
        ),
        body: BlocBuilder<TreatmentExecutionCubit, TreatmentExecutionState>(
          builder: (context, state) {
            if (state is TreatmentExecutionLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is TreatmentExecutionError) {
              return Center(child: Text(state.message));
            }
            if (state is! TreatmentExecutionLoaded) {
              return const SizedBox.shrink();
            }

            final activas = state.citas;
            final historial = state.citasHistorial
                .where((c) => !c.estado.esPendienteDeEjecucion)
                .toList();

            return TabBarView(
              children: [
                RefreshIndicator(
                  onRefresh: () => context
                      .read<TreatmentExecutionCubit>()
                      .loadCitas(especialistaId: widget.especialistaId),
                  child: activas.isEmpty
                      ? const _Empty(
                          icon: Icons.event_busy,
                          texto: 'No tienes citas pendientes por ejecutar',
                        )
                      : _ListaCitas(citas: activas),
                ),
                RefreshIndicator(
                  onRefresh: () => context
                      .read<TreatmentExecutionCubit>()
                      .loadCitasHistorial(
                          especialistaId: widget.especialistaId),
                  child: historial.isEmpty
                      ? const _Empty(
                          icon: Icons.history,
                          texto: 'Aún no tienes citas en el historial',
                        )
                      : _ListaCitas(citas: historial),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ListaCitas extends StatelessWidget {
  final List<CitaEjecucionEntity> citas;
  const _ListaCitas({required this.citas});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: citas.length,
      itemBuilder: (context, i) => _CitaCard(cita: citas[i]),
    );
  }
}

class _CitaCard extends StatelessWidget {
  final CitaEjecucionEntity cita;
  const _CitaCard({required this.cita});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: AppTheme.cDeepAccent,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.event_available_rounded,
              color: Colors.white, size: 22),
        ),
        title: Text(cita.pacienteNombre,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          cita.servicioNombre + (cita.ciudad != null ? ' · ${cita.ciudad}' : ''),
        ),
        trailing: EstadoChip(estado: cita.estado),
        onTap: () => context.push(
          AppRoutes.misCitasDetalleDe(cita.id),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String texto;
  const _Empty({required this.icon, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppTheme.cMutedText),
          const SizedBox(height: 12),
          Text(texto),
        ],
      ),
    );
  }
}