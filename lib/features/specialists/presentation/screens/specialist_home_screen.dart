import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/app/config/app_routes.dart';
import 'package:esteticaybellezastrani/features/auth_users/presentation/cubits/auth_cubit.dart';
import '../cubits/specialists_cubit.dart';
import '../../domain/entities/contrato_entity.dart';
import '../../domain/entities/documento_especialista_entity.dart';
import '../../domain/entities/especialista_entity.dart';
import '../widgets/disponibilidad_card.dart';
import '../widgets/documentos_section.dart';

/// Panel del especialista — carga perfil, verificación, disponibilidad,
/// documentos y contrato vía [SpecialistsCubit].
class SpecialistHomeScreen extends StatefulWidget {
  const SpecialistHomeScreen({super.key});

  @override
  State<SpecialistHomeScreen> createState() => _SpecialistHomeScreenState();
}

class _SpecialistHomeScreenState extends State<SpecialistHomeScreen> {
  bool _redirectedToDocuments = false;

  @override
  void initState() {
    super.initState();
    final usuarioId = context.read<AuthCubit>().currentProfile?.id;
    if (usuarioId != null) {
      context.read<SpecialistsCubit>().loadDashboard(usuarioId: usuarioId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.read<AuthCubit>().currentProfile;
    return Scaffold(
      appBar: AppBar(
        title: Text('Panel de Especialista — ${profile?.fullName ?? 'Bienvenido'}'),
        actions: [
          IconButton(
            onPressed: () => context.read<AuthCubit>().signOut(),
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
          ),
        ],
      ),
      body: BlocListener<SpecialistsCubit, SpecialistsState>(
        listener: (context, state) {
          // Onboarding obligatorio: si el especialista existe pero aún no ha
          // subido los documentos requeridos, se le lleva a esa pantalla.
          if (state is SpecialistsLoaded &&
              state.especialista != null &&
              !_tieneDocumentosRequeridos(state) &&
              !_redirectedToDocuments) {
            _redirectedToDocuments = true;
            context.go(
              AppRoutes.specialistDocuments,
              extra: state.especialista!.id,
            );
          }
        },
        child: BlocBuilder<SpecialistsCubit, SpecialistsState>(
          builder: (context, state) {
            if (state is SpecialistsLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is SpecialistsError) {
              return _ErrorView(message: state.message);
            }
            if (state is! SpecialistsLoaded) {
              return const SizedBox.shrink();
            }
            return _buildDashboard(context, state);
          },
        ),
      ),
    );
  }

  bool _tieneDocumentosRequeridos(SpecialistsLoaded state) {
    const requeridos = [TipoDocumento.identificacion, TipoDocumento.licencia];
    return requeridos.every((t) =>
        state.documentos.any((d) => d.tipoDocumento == t && d.activo));
  }

  Widget _buildDashboard(BuildContext context, SpecialistsLoaded state) {
    final especialista = state.especialista;

    return RefreshIndicator(
      onRefresh: () async {
        final usuarioId = context.read<AuthCubit>().currentProfile?.id;
        if (usuarioId != null) {
          await context.read<SpecialistsCubit>().loadDashboard(usuarioId: usuarioId);
        }
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Perfil de Especialista',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _VerificationCard(
            especialista: especialista,
            especialidades: state.especialidades,
            onCreate: (licencia) {
              final usuarioId = context.read<AuthCubit>().currentProfile?.id;
              if (usuarioId != null) {
                context
                    .read<SpecialistsCubit>()
                    .createSpecialist(usuarioId: usuarioId, numeroLicencia: licencia);
              }
            },
          ),
          const SizedBox(height: 16),
          if (especialista != null) ...[
            DisponibilidadCard(
              especialistaId: especialista.id,
              disponibilidad: state.disponibilidad,
            ),
            const SizedBox(height: 16),
            DocumentosSection(
              especialistaId: especialista.id,
              documentos: state.documentos,
            ),
            const SizedBox(height: 16),
            _ContratoCard(contrato: state.contrato),
            if (especialista.isApproved && (state.disponibilidad?.isAvailable ?? false)) ...[
              const SizedBox(height: 16),
              _MapaPacientesCard(
                onTap: () => context.push(
                  AppRoutes.specialistPatientMap,
                  extra: especialista.id,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ── Estados de verificación ─────────────────────────────────────

class _VerificationCard extends StatelessWidget {
  final EspecialistaEntity? especialista;
  final List especialidades;
  final void Function(String licencia) onCreate;

  const _VerificationCard({
    required this.especialista,
    required this.especialidades,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final s = especialista;
    if (s == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Aún no tienes perfil de especialista',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text(
                'Registra tu licencia para solicitar la verificación y comenzar a ofrecer servicios.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: TextEditingController(),
                decoration: const InputDecoration(
                  labelText: 'Número de licencia',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: onCreate,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => onCreate(''),
                icon: const Icon(Icons.verified_user_rounded),
                label: const Text('Solicitar verificación'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: ListTile(
        leading: Icon(
          s.isApproved ? Icons.verified_rounded : Icons.hourglass_top_rounded,
          color: s.isApproved ? AppTheme.cBrandGreen : AppTheme.cDeepAccent,
          size: 40,
        ),
        title: Text('Estado: ${_estadoLabel(s.estadoVerificacion)}'),
        subtitle: s.numeroLicencia == null
            ? null
            : Text('Licencia: ${s.numeroLicencia}'),
        trailing: _Badge(s.estadoVerificacion),
      ),
    );
  }

  String _estadoLabel(EstadoVerificacion e) => switch (e) {
        EstadoVerificacion.aprobado => 'Verificado',
        EstadoVerificacion.enRevision => 'En revisión',
        EstadoVerificacion.rechazado => 'Rechazado',
        EstadoVerificacion.bloqueado => 'Bloqueado',
        EstadoVerificacion.pendiente => 'Pendiente',
      };
}

class _Badge extends StatelessWidget {
  final EstadoVerificacion estado;
  const _Badge(this.estado);

  @override
  Widget build(BuildContext context) {
    final Color color = switch (estado) {
      EstadoVerificacion.aprobado => AppTheme.cBrandGreen,
      EstadoVerificacion.rechazado ||
      EstadoVerificacion.bloqueado =>
        Colors.redAccent,
      EstadoVerificacion.enRevision => Colors.orange,
      EstadoVerificacion.pendiente => AppTheme.cDeepAccent,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Text(estado.toDb, style: TextStyle(color: color, fontSize: 11)),
    );
  }
}

class _ContratoCard extends StatelessWidget {
  final ContratoEntity? contrato;
  const _ContratoCard({required this.contrato});

  @override
  Widget build(BuildContext context) {
    final firmado = contrato != null && contrato!.firmado == true;
    return Card(
      child: ListTile(
        leading: Icon(
          firmado ? Icons.task_alt : Icons.assignment_outlined,
          color: firmado ? AppTheme.cBrandGreen : AppTheme.cMutedText,
        ),
        title: Text(firmado ? 'Contrato firmado' : 'Contrato pendiente'),
        subtitle: Text(
          firmado
              ? 'Versión ${contrato!.versionContrato}'
              : 'Aún no has firmado tu contrato.',
        ),
        trailing: firmado ? const Icon(Icons.check_circle, color: AppTheme.cBrandGreen) : null,
      ),
    );
  }
}

class _MapaPacientesCard extends StatelessWidget {
  final VoidCallback onTap;
  const _MapaPacientesCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: AppTheme.cBrandGreen,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.map_rounded, color: Colors.white, size: 26),
        ),
        title: const Text(
          'Buscar Pacientes en Mapa',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: const Text(
          'Visualiza pacientes que buscan especialista y asigna por cercanía (primer aviso gana).',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}