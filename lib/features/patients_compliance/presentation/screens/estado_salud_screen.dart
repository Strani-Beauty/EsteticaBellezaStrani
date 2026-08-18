import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/app/core/di/injection.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/domain/entities/estado_salud_entity.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/presentation/cubits/patient_health_cubit.dart';

/// Consulta el estado integral de salud del paciente (requisito 13):
/// cuota inicial, cuestionario, resultado de evaluación, validación de
/// telemedicina con su vencimiento y siguiente paso sugerido.
class EstadoSaludScreen extends StatelessWidget {
  const EstadoSaludScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PatientHealthCubit>.value(
      value: sl<PatientHealthCubit>(),
      child: const _EstadoSaludView(),
    );
  }
}

class _EstadoSaludView extends StatefulWidget {
  const _EstadoSaludView();

  @override
  State<_EstadoSaludView> createState() => _EstadoSaludViewState();
}

class _EstadoSaludViewState extends State<_EstadoSaludView> {
  @override
  void initState() {
    super.initState();
    sl<PatientHealthCubit>().loadEstadoSalud();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estado de Salud'),
        centerTitle: true,
      ),
      body: BlocBuilder<PatientHealthCubit, PatientHealthState>(
        builder: (context, state) {
          if (state is PatientHealthLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.cDeepAccent),
            );
          }
          if (state is PatientHealthError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.cError, size: 44),
                    const SizedBox(height: 12),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.cMutedText),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cDeepAccent),
                      onPressed: () => context.read<PatientHealthCubit>().loadEstadoSalud(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (state is PatientHealthLoaded && state.estadoSalud != null) {
            return _buildContenido(context, state.estadoSalud!);
          }
          return const Center(
            child: Text('Sin información disponible.', style: TextStyle(color: AppTheme.cMutedText)),
          );
        },
      ),
    );
  }

  Widget _buildContenido(BuildContext context, EstadoSaludEntity estado) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _banner(estado),
          const SizedBox(height: 20),

          const Text(
            'Tu expediente de salud',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.cDarkText),
          ),
          const SizedBox(height: 12),

          _fila(
            icon: Icons.payment_rounded,
            titulo: 'Cuota inicial',
            ok: estado.paymentCompleted,
            detalle: estado.paymentCompleted ? 'Pagada' : 'Pendiente de pago',
          ),
          _fila(
            icon: Icons.assignment_rounded,
            titulo: 'Cuestionario de salud',
            ok: estado.cuestionarioCompletado,
            detalle: estado.cuestionarioCompletado ? 'Completado' : 'Pendiente',
          ),
          _fila(
            icon: Icons.medical_information_rounded,
            titulo: 'Resultado de evaluación',
            ok: estado.evaluacionResultado == 'APTO',
            detalle: _resultadoLabel(estado.evaluacionResultado),
          ),
          _fila(
            icon: Icons.videocam_rounded,
            titulo: 'Validación médica',
            ok: estado.habilitado,
            detalle: _validacionLabel(estado),
          ),
          if (estado.fechaVencimiento != null)
            _fila(
              icon: Icons.event_available_rounded,
              titulo: 'Vencimiento de validación',
              ok: !estado.validacionVencida,
              detalle: _fmtFecha(estado.fechaVencimiento),
            ),

          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.cPastelPurple,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.cDeepAccent.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline_rounded, color: AppTheme.cDeepAccent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    estado.siguientePaso,
                    style: const TextStyle(fontSize: 13, color: AppTheme.cDarkText, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _banner(EstadoSaludEntity estado) {
    final habilitado = estado.habilitado;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (habilitado ? AppTheme.cBrandGreen : Colors.orange).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: (habilitado ? AppTheme.cBrandGreen : Colors.orange).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            habilitado ? Icons.verified_user_rounded : Icons.info_outline_rounded,
            color: habilitado ? AppTheme.cBrandGreen : Colors.orange,
            size: 34,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habilitado ? 'Habilitado para solicitar servicios' : 'Cuenta incompleta',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: habilitado ? AppTheme.cBrandGreen : Colors.orange,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  habilitado
                      ? 'Tu validación médica está vigente (${estado.proveedor}).'
                      : 'Completa los pasos pendientes para habilitar tus reservas.',
                  style: const TextStyle(fontSize: 12, color: AppTheme.cDarkText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fila({
    required IconData icon,
    required String titulo,
    required bool ok,
    required String detalle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.cPastelBlue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.cDeepAccent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.cDarkText),
                ),
                Text(
                  detalle,
                  style: const TextStyle(fontSize: 12, color: AppTheme.cMutedText),
                ),
              ],
            ),
          ),
          Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: ok ? AppTheme.cSuccess : AppTheme.cError, size: 22),
        ],
      ),
    );
  }

  String _fmtFecha(DateTime? d) => d == null
      ? '—'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _resultadoLabel(String resultado) {
    switch (resultado) {
      case 'APTO':
        return 'Apto';
      case 'REQUIERE_REVISION':
        return 'Requiere revisión';
      case 'NO_APTO':
        return 'No apto';
      default:
        return 'Pendiente';
    }
  }

  String _validacionLabel(EstadoSaludEntity estado) {
    switch (estado.validacionEstado) {
      case 'APROBADA':
        return estado.validacionVencida ? 'Vencida' : 'Aprobada (${estado.proveedor})';
      case 'RECHAZADA':
        return 'Rechazada';
      case 'VENCIDA':
        return 'Vencida';
      default:
        return 'Pendiente';
    }
  }
}