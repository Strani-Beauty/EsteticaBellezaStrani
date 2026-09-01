import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/app/config/app_routes.dart';
import 'package:esteticaybellezastrani/app/core/di/injection.dart';
import 'package:esteticaybellezastrani/features/auth_users/presentation/cubits/auth_cubit.dart';
import 'package:esteticaybellezastrani/features/auth_users/presentation/widgets/profile_menu_button.dart';
import 'package:esteticaybellezastrani/features/notifications/presentation/cubits/notifications_cubit.dart';
import 'package:esteticaybellezastrani/features/notifications/presentation/widgets/notificaciones_bell.dart';
import '../cubits/specialists_cubit.dart';
import '../../domain/entities/contrato_entity.dart';
import '../../domain/entities/documento_especialista_entity.dart';
import '../../domain/entities/especialista_entity.dart';
import '../../domain/entities/medico_regente_entity.dart';
import '../widgets/disponibilidad_card.dart';
import '../widgets/documentos_section.dart';
import '../widgets/documentos_requeridos.dart';
import '../widgets/expediente_compliance.dart';

/// Panel del especialista — carga perfil, verificación, disponibilidad,
/// documentos y contrato vía [SpecialistsCubit].
class SpecialistHomeScreen extends StatefulWidget {
  const SpecialistHomeScreen({super.key});

  @override
  State<SpecialistHomeScreen> createState() => _SpecialistHomeScreenState();
}

class _SpecialistHomeScreenState extends State<SpecialistHomeScreen> {
  bool _redirectedToOnboarding = false;
  bool _redirectedToDocuments = false;

  @override
  void initState() {
    super.initState();
    final usuarioId = context.read<AuthCubit>().currentProfile?.id;
    if (usuarioId != null) {
      context.read<SpecialistsCubit>().loadDashboard(usuarioId: usuarioId);
      sl<NotificationsCubit>().load(usuarioId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.read<AuthCubit>().currentProfile;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Panel de Especialista — ${profile?.fullName ?? 'Bienvenido'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          const NotificacionesBell(),
          const ProfileMenuButton(iconColor: Colors.white),
          IconButton(
            onPressed: () => context.read<AuthCubit>().signOut(),
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
          ),
        ],
      ),
      body: BlocListener<SpecialistsCubit, SpecialistsState>(
        listener: (context, state) {
          if (state is! SpecialistsLoaded) return;

          // Onboarding obligatorio:
          // 1) Sin perfil de especialista aún → wizard completo.
          // 2) Perfil creado pero sin datos profesionales mínimos (médico
          //    regente + especialidades) → wizard en el paso profesional.
          // 3) Faltan documentos requeridos → pantalla de documentos.
          if (state.especialista == null) {
            if (!_redirectedToOnboarding) {
              _redirectedToOnboarding = true;
              context.go(
                AppRoutes.specialistOnboarding,
                extra: '',
              );
            }
            return;
          }

          final cubit = context.read<SpecialistsCubit>();
          if (!cubit.tieneDatosProfesionales) {
            if (!_redirectedToOnboarding) {
              _redirectedToOnboarding = true;
              context.go(
                AppRoutes.specialistOnboarding,
                extra: state.especialista!.id,
              );
            }
            return;
          }

          // Un especialista rechazado se queda en el panel para leer el motivo
          // y desde ahí corregir/reenviar; el resto sin documentos va a subirlos.
          final rechazado =
              state.especialista!.estadoVerificacion == EstadoVerificacion.rechazado;
          if (!rechazado && !_tieneDocumentosRequeridos(state) && !_redirectedToDocuments) {
            _redirectedToDocuments = true;
            context.push(
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
    return tieneDocumentosRequeridos(state.documentos);
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
          _MiPerfilCard(
            onTap: () => context.push(AppRoutes.specialistProfile),
          ),
          if (especialista != null) ...[
            DisponibilidadCard(
              especialistaId: especialista.id,
              disponibilidad: state.disponibilidad,
              habilitado: especialista.isApproved,
            ),
            const SizedBox(height: 16),
            _ExpedienteCard(
              especialista: especialista,
              documentos: state.documentos,
              medicosRegentes: state.medicosRegentes,
              numeroEspecialidades: state.especialidadIds.length,
              contrato: state.contrato,
            ),
            const SizedBox(height: 16),
            DocumentosSection(
              especialistaId: especialista.id,
              documentos: state.documentos,
              verificado: especialista.isApproved,
            ),
            const SizedBox(height: 16),
            _ContratoCard(
              contrato: state.contrato,
              especialistaId: especialista.id,
            ),
            if (especialista.isApproved && (state.disponibilidad?.isAvailable ?? false)) ...[
              const SizedBox(height: 16),
              _MapaPacientesCard(
                onTap: () => context.push(
                  AppRoutes.specialistPatientMap,
                  extra: especialista.id,
                ),
              ),
              const SizedBox(height: 16),
              _MisCitasCard(
                onTap: () => context.push(
                  AppRoutes.misCitas,
                  extra: especialista.id,
                ),
              ),
              const SizedBox(height: 16),
              _MisLiquidacionesCard(
                onTap: () => context.push(
                  AppRoutes.misLiquidaciones,
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

class _VerificationCard extends StatefulWidget {
  final EspecialistaEntity? especialista;
  final List especialidades;
  final void Function(String licencia) onCreate;

  const _VerificationCard({
    required this.especialista,
    required this.especialidades,
    required this.onCreate,
  });

  @override
  State<_VerificationCard> createState() => _VerificationCardState();
}

class _VerificationCardState extends State<_VerificationCard> {
  final _licenciaCtrl = TextEditingController();

  @override
  void dispose() {
    _licenciaCtrl.dispose();
    super.dispose();
  }

  void _enviar([String? texto]) {
    final licencia = (texto ?? _licenciaCtrl.text).trim();
    if (licencia.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Ingresa el número de licencia para solicitar la verificación.'),
        ),
      );
      return;
    }
    widget.onCreate(licencia);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.especialista;
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
                controller: _licenciaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Número de licencia',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: _enviar,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _enviar,
                icon: const Icon(Icons.verified_user_rounded),
                label: const Text('Solicitar verificación'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              s.isApproved ? Icons.verified_rounded : Icons.hourglass_top_rounded,
              color: s.isApproved ? AppTheme.cBrandGreen : AppTheme.cDeepAccent,
              size: 40,
            ),
            title: Text('Estado: ${_estadoLabel(s.estadoVerificacion)}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (s.numeroLicencia != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('Licencia: ${s.numeroLicencia}'),
                  ),
                if (!s.isApproved && s.observacion != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Motivo: ${s.observacion}',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
              ],
            ),
            trailing: _Badge(s.estadoVerificacion),
          ),
          if (!s.isApproved && s.observacion != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _pedirVerificacion(context),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Corregir y reenviar'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _pedirVerificacion(BuildContext context) {
    context.push(
      AppRoutes.specialistDocuments,
      extra: widget.especialista?.id ?? '',
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

class _ExpedienteCard extends StatelessWidget {
  final EspecialistaEntity especialista;
  final List<DocumentoEspecialistaEntity> documentos;
  final List<MedicoRegenteEntity> medicosRegentes;
  final int numeroEspecialidades;
  final ContratoEntity? contrato;

  const _ExpedienteCard({
    required this.especialista,
    required this.documentos,
    required this.medicosRegentes,
    required this.numeroEspecialidades,
    required this.contrato,
  });

  @override
  Widget build(BuildContext context) {
    final expediente = ExpedienteEspecialista(
      documentos: documentos,
      medicoRegenteId: especialista.medicoRegenteId,
      medicosRegentes: medicosRegentes,
      numeroEspecialidades: numeroEspecialidades,
      contrato: contrato,
    );

    if (especialista.isApproved) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.verified_rounded,
              color: AppTheme.cBrandGreen, size: 32),
          title: const Text('Expediente completo',
              style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Estás verificado y habilitado para operar.'),
        ),
      );
    }

    final pendientes = expediente.pendientes;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tu expediente de verificación',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            for (final item in _checklist(expediente))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      item.$1 ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 18,
                      color: item.$1
                          ? AppTheme.cBrandGreen
                          : AppTheme.cMutedText,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(item.$2,
                          style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Text(
              'Pendiente: ${pendientes.isEmpty ? 'nada' : pendientes.join(', ')}',
              style: const TextStyle(
                  color: AppTheme.cMutedText, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  /// Pares (cumplido, label) del checklist del expediente.
  List<(bool, String)> _checklist(ExpedienteEspecialista e) => [
        (e.documentosAprobados, 'Documentos obligatorios aprobados'),
        (e.medicoRegenteActivo, 'Médico regente activo'),
        (e.tieneEspecialidades, 'Al menos una especialidad'),
        (e.contratoFirmado, 'Contrato firmado'),
      ];
}

class _ContratoCard extends StatelessWidget {
  final ContratoEntity? contrato;
  final String especialistaId;
  const _ContratoCard({required this.contrato, required this.especialistaId});

  @override
  Widget build(BuildContext context) {
    final firmado = contrato != null && contrato!.firmado == true;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
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
              trailing: firmado
                  ? const Icon(Icons.check_circle, color: AppTheme.cBrandGreen)
                  : null,
            ),
            if (!firmado) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => context.push(
                  AppRoutes.specialistContract,
                  extra: especialistaId,
                ),
                icon: const Icon(Icons.draw_rounded),
                label: const Text('Firmar contrato'),
              ),
            ],
          ],
        ),
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

class _MiPerfilCard extends StatelessWidget {
  final VoidCallback onTap;
  const _MiPerfilCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: AppTheme.cDeepAccent,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.account_circle_rounded, color: Colors.white, size: 26),
        ),
        title: const Text(
          'Mi información',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: const Text(
          'Consulta y actualiza tus datos personales, licencia, médico regente y especialidades.',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _MisCitasCard extends StatelessWidget {
  final VoidCallback onTap;
  const _MisCitasCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: AppTheme.cDeepAccent,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.event_available_rounded,
              color: Colors.white, size: 26),
        ),
        title: const Text(
          'Mis citas',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: const Text(
          'Ejecuta el ciclo de tus citas: desplazamiento, tratamiento, insumos y firma.',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _MisLiquidacionesCard extends StatelessWidget {
  final VoidCallback onTap;
  const _MisLiquidacionesCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: AppTheme.cDeepAccent,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.payments_rounded,
              color: Colors.white, size: 26),
        ),
        title: const Text(
          'Mis liquidaciones',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: const Text(
          'Consulta tu historial de cortes semanales y pagos recibidos.',
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