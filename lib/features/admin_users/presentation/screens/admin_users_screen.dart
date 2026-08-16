import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esteticaybellezastrani/app/config/app_constants.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/features/admin_users/domain/entities/usuario_admin_entity.dart';
import 'package:esteticaybellezastrani/features/admin_users/presentation/cubits/admin_users_cubit.dart';
import 'package:esteticaybellezastrani/features/auth_users/presentation/cubits/auth_cubit.dart';

/// Panel admin: consulta y gestión (activar/desactivar) de usuarios.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      context.read<AdminUsersCubit>().loadUsuarios();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios del Sistema'),
      ),
      body: BlocConsumer<AdminUsersCubit, AdminUsersState>(
        listener: (context, state) {
          if (state is AdminUsersError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.cError,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is AdminUsersLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is AdminUsersError) {
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
                        context.read<AdminUsersCubit>().loadUsuarios(),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          if (state is AdminUsersLoaded) {
            final usuarios = state.usuarios;
            if (usuarios.isEmpty) {
              return const Center(child: Text('No hay usuarios registrados.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: usuarios.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) =>
                  _UserTile(usuarios[index]),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final UsuarioAdminEntity user;
  const _UserTile(this.user);

  bool get _esAdmin => user.role == AppConstants.rolAdministrador;

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthCubit>().currentProfile?.id;
    final esAuto = currentUserId == user.id;

    // No se puede desactivar a otro admin ni a uno mismo.
    final canToggle = !_esAdmin && !esAuto;

    return Card(
      elevation: 0,
      color: AppTheme.cSurface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        side: const BorderSide(color: Colors.black12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _esAdmin
              ? AppTheme.cPastelPurple
              : AppTheme.cPastelBlue,
          child: Icon(
            _esAdmin
                ? Icons.admin_panel_settings_rounded
                : Icons.person_outline_rounded,
            color: AppTheme.cDeepAccent,
          ),
        ),
        title: Text(
          user.fullName == null || user.fullName!.isEmpty
              ? user.email
              : '${user.fullName} (${user.email})',
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
                '${user.role}${esAuto ? ' · tú' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  color: _esAdmin ? AppTheme.cDeepAccent : AppTheme.cMutedText,
                  fontWeight: _esAdmin ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              if (user.phone != null && user.phone!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.phone_outlined,
                          size: 12, color: AppTheme.cMutedText),
                      const SizedBox(width: 4),
                      Text(
                        user.phone!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.cMutedText,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        trailing: canToggle
            ? Switch(
                value: user.activo,
                onChanged: (value) => context
                    .read<AdminUsersCubit>()
                    .setActivo(user.id, value),
              )
            : null,
      ),
    );
  }
}