import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:esteticaybellezastrani/app/config/app_routes.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/app/core/di/injection.dart';
import 'package:esteticaybellezastrani/features/auth_users/data/datasources/auth_supabase_datasource.dart';
import 'package:esteticaybellezastrani/features/auth_users/data/services/fcm_token_service.dart';
import 'package:esteticaybellezastrani/features/auth_users/presentation/cubits/auth_cubit.dart';

/// Punto de entrada de la aplicación.
/// Provee AuthCubit globalmente (inyectado vía GetIt) y conecta GoRouter.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthCubit>(
      create: (_) => sl<AuthCubit>()..checkCurrentSession(),
      child: const _SessionLifecycleGate(),
    );
  }
}

/// Limpia la sesión local cuando la app/web se cierra o queda en segundo plano
/// durante mucho tiempo, para no dejar un "usuario activo" en caché.
class _SessionLifecycleGate extends StatefulWidget {
  const _SessionLifecycleGate();

  @override
  State<_SessionLifecycleGate> createState() => _SessionLifecycleGateState();
}

class _SessionLifecycleGateState extends State<_SessionLifecycleGate>
    with WidgetsBindingObserver {
  StreamSubscription<sb.AuthState>? _recoverySub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenRecoveryLink();
    sl<FcmTokenService>().init();
  }

  /// Detecta el deep link de recovery de Supabase (email "¿Olvidaste tu
  /// contraseña?") y navega al formulario de nueva contraseña.
  /// NOTA: el estado de sesión NO se deriva de este stream (regla AGENTS);
  /// aquí solo se usa para detectar el evento `passwordRecovery` y navegar.
  void _listenRecoveryLink() {
    _recoverySub =
        sl<AuthSupabaseDataSource>().authStateChanges.listen((authState) {
      if (authState.event == sb.AuthChangeEvent.passwordRecovery) {
        if (!mounted) return;
        context.go(AppRoutes.resetPassword);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recoverySub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      context.read<AuthCubit>().clearLocalSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          sl<FcmTokenService>().registerCurrentDevice(state.profile.id);
        }
      },
      child: MaterialApp.router(
        title: 'Estética y Belleza Strani',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: appRouter,
      ),
    );
  }
}
