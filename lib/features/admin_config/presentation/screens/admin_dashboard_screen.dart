import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:esteticaybellezastrani/app/config/app_routes.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/features/auth_users/presentation/cubits/auth_cubit.dart';
import 'package:esteticaybellezastrani/features/auth_users/presentation/widgets/profile_menu_button.dart';
import '../cubits/admin_dashboard_cubit.dart';

/// Panel de administración — dashboard (KPIs + accesos por sección).
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _cargado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_cargado) {
      _cargado = true;
      context.read<AdminDashboardCubit>().load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthCubit>().currentProfile;
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Panel Admin — ${profile?.fullName ?? 'Administrador'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppTheme.cDeepAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          const ProfileMenuButton(iconColor: Colors.white),
          IconButton(
            onPressed: () => context.read<AuthCubit>().signOut(),
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<AdminDashboardCubit>().load();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildKpis(),
            const SizedBox(height: 20),
            const _SectionHeader(title: 'Administrativo'),
            const SizedBox(height: 8),
            _buildAdministrativo(),
            const SizedBox(height: 20),
            const _SectionHeader(title: 'Datos Maestros'),
            const SizedBox(height: 8),
            _buildDatosMaestros(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildKpis() {
    return BlocBuilder<AdminDashboardCubit, AdminDashboardState>(
      builder: (context, state) {
        if (state is AdminDashboardLoading) {
          return const SizedBox(
            height: 96,
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.cDeepAccent),
            ),
          );
        }
        if (state is AdminDashboardError) {
          return _KpiError(message: state.message);
        }
        if (state is! AdminDashboardLoaded) {
          return const SizedBox.shrink();
        }
        final kpis = state.kpis;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Resumen',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _KpiCard(
                  label: 'Solicitudes',
                  value: '${kpis.solicitudesPorEstado.values.fold(0, (a, b) => a + b)}',
                  icon: Icons.request_page_rounded,
                  color: AppTheme.cDeepAccent,
                  detail: kpis.solicitudesPorEstado.entries
                      .map((e) => '${e.key}: ${e.value}')
                      .join(' · '),
                ),
                _KpiCard(
                  label: 'Citas activas',
                  value: '${kpis.citasActivas}',
                  icon: Icons.event_available_rounded,
                  color: AppTheme.cBrandGreen,
                ),
                _KpiCard(
                  label: 'Especialistas pend.',
                  value: '${kpis.especialistasPendientes}',
                  icon: Icons.badge_outlined,
                  color: Colors.orange,
                ),
                _KpiCard(
                  label: 'Médicos pend.',
                  value: '${kpis.medicosPendientes}',
                  icon: Icons.medical_information_outlined,
                  color: Colors.redAccent,
                ),
                _KpiCard(
                  label: 'Ingresos (USD)',
                  value: '\$${kpis.ingresosTotales.toStringAsFixed(2)}',
                  icon: Icons.payments_rounded,
                  color: AppTheme.cDeepAccent,
                ),
                _KpiCard(
                  label: 'Usuarios activos',
                  value: '${kpis.totalUsuarios}',
                  icon: Icons.people_outline_rounded,
                  color: AppTheme.cGoldAccent,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildAdministrativo() {
    return Column(
      children: [
        if (_tiene('admin.usuarios'))
          _NavCard(
            icon: Icons.people_outline_rounded,
            color: AppTheme.cPastelPurple,
            title: 'Usuarios del Sistema',
            subtitle: 'Consultar y activar/desactivar cuentas',
            onTap: () => context.go(AppRoutes.adminUsuarios),
          ),
        if (_tiene('admin.pacientes'))
          _NavCard(
            icon: Icons.badge_outlined,
            color: AppTheme.cPastelBlue.withValues(alpha: 0.4),
            title: 'Gestión de Pacientes',
            subtitle: 'Consultar pacientes y activar/desactivar cuentas',
            onTap: () => context.go(AppRoutes.adminPacientes),
          ),
        if (_tiene('admin.cuestionario'))
          _NavCard(
            icon: Icons.assignment_rounded,
            color: AppTheme.cPastelPink,
            title: 'Cuestionario de Salud',
            subtitle: 'Versiones, activar versión y editar preguntas',
            onTap: () => context.go(AppRoutes.adminCuestionario),
          ),
        if (_tiene('admin.catalogo'))
          _NavCard(
            icon: Icons.storefront_rounded,
            color: AppTheme.cBrandGreen.withValues(alpha: 0.15),
            title: 'Catálogo de Servicios',
            subtitle: 'Categorías, servicios, especialidades y requisitos',
            onTap: () => context.go(AppRoutes.adminCatalog),
          ),
        if (_tiene('admin.licencias'))
          _NavCard(
            icon: Icons.verified_user_outlined,
            color: AppTheme.cGoldAccent.withValues(alpha: 0.2),
            title: 'Verificación de Licencias',
            subtitle: 'Expedientes, documentos y aprobación de especialistas',
            onTap: () => context.go(AppRoutes.adminLicencias),
          ),
        if (_tiene('admin.auditoria'))
          _NavCard(
            icon: Icons.receipt_long_outlined,
            color: AppTheme.cPastelPurple,
            title: 'Auditoría',
            subtitle: 'Registro de operaciones sensibles (quién, qué, cuándo)',
            onTap: () => context.go(AppRoutes.adminAuditoria),
          ),
      ],
    );
  }

  Widget _buildDatosMaestros() {
    return Column(
      children: [
        if (_tiene('admin.roles'))
          _NavCard(
            icon: Icons.admin_panel_settings_outlined,
            color: AppTheme.cPastelBlue.withValues(alpha: 0.4),
            title: 'Roles y Permisos',
            subtitle: 'Catálogo RBAC (roles, permisos y asignación)',
            onTap: () => context.go(AppRoutes.adminRoles),
          ),
        if (_tiene('admin.configuracion'))
          _NavCard(
            icon: Icons.settings_rounded,
            color: AppTheme.cPastelPurple,
            title: 'Configuración del Sistema',
            subtitle: 'Depósito, radio, comisión, adelanto y claves generales',
            onTap: () => context.go(AppRoutes.adminConfiguracion),
          ),
        if (_tiene('admin.comisiones'))
          _NavCard(
            icon: Icons.account_balance_wallet_outlined,
            color: AppTheme.cPastelPink,
            title: 'Comisiones y Liquidaciones',
            subtitle: 'Comisiones, liquidaciones y pagos a especialistas',
            onTap: () => context.go(AppRoutes.adminComisiones),
          ),
        if (_tiene('admin.conciliacion'))
          _NavCard(
            icon: Icons.receipt_long_outlined,
            color: AppTheme.cPastelBlue.withValues(alpha: 0.4),
            title: 'Conciliación de Pagos',
            subtitle: 'Transacciones, refs de Stripe y detalle financiero por cita',
            onTap: () => context.go(AppRoutes.adminConciliacion),
          ),
        if (_tiene('admin.especialidades'))
          _NavCard(
            icon: Icons.category_outlined,
            color: AppTheme.cBrandGreen.withValues(alpha: 0.15),
            title: 'Especialidades',
            subtitle: 'Catálogo de especialidades',
            onTap: () => context.go(AppRoutes.adminEspecialidades),
          ),
        if (_tiene('admin.medicos'))
          _NavCard(
            icon: Icons.medical_information_outlined,
            color: AppTheme.cGoldAccent.withValues(alpha: 0.2),
            title: 'Médicos Regentes',
            subtitle: 'Registro y validación de médicos regentes',
            onTap: () => context.go(AppRoutes.adminMedicosRegentes),
          ),
      ],
    );
  }

  /// El admin (super-rol) ve todo; si la carga de permisos aún no resolvió
  /// (conjunto vacío), se muestran todos los tiles para no romper el panel.
  bool _tiene(String codigo) {
    final state = context.read<AdminDashboardCubit>().state;
    if (state is! AdminDashboardLoaded) return true;
    if (state.permisos.isEmpty) return true;
    return state.permisos.contains(codigo);
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? detail;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.cMutedText)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, height: 1.1)),
          if (detail != null) ...[
            const SizedBox(height: 2),
            Text(detail!,
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.cMutedText)),
          ],
        ],
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppTheme.cSurface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        side: const BorderSide(color: Colors.black12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Icon(icon, color: AppTheme.cDeepAccent),
        ),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: AppTheme.cDarkText)),
        subtitle:
            Text(subtitle, style: const TextStyle(color: AppTheme.cMutedText, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _KpiError extends StatelessWidget {
  final String message;
  const _KpiError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    color: Colors.redAccent, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
