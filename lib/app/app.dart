import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:esteticaybellezastrani/app/config/app_routes.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/app/core/di/injection.dart';
import 'package:esteticaybellezastrani/app/core/session_storage_cleaner.dart';
import 'package:esteticaybellezastrani/app/core/web_unload_cleaner.dart';
import 'package:esteticaybellezastrani/features/auth_users/data/datasources/auth_supabase_datasource.dart';
import 'package:esteticaybellezastrani/features/auth_users/data/services/fcm_token_service.dart';
import 'package:esteticaybellezastrani/features/auth_users/presentation/cubits/auth_cubit.dart';
import 'package:esteticaybellezastrani/features/specialists/data/services/presence_service.dart';

/// Punto de entrada de la aplicación.
/// Provee AuthCubit globalmente (inyectado vía GetIt) y conecta GoRouter.
class App extends StatelessWidget {
  const App({super.key, this.startupNotice});

  /// Aviso de arranque (p.ej. un enlace de auth que no pudo completarse).
  final String? startupNotice;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthCubit>(
      create: (_) => sl<AuthCubit>()..checkCurrentSession(),
      child: _SessionLifecycleGate(startupNotice: startupNotice),
    );
  }
}

/// Limpia la sesión local cuando la app/web se cierra o queda en segundo plano
/// durante mucho tiempo, para no dejar un "usuario activo" en caché.
class _SessionLifecycleGate extends StatefulWidget {
  const _SessionLifecycleGate({this.startupNotice});

  final String? startupNotice;

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
    _showStartupNotice();
    if (kIsWeb) {
      registerWebUnloadCleaner(_handleWebUnload);
    }
  }

  /// Al cerrar/refrescar la pestaña (eventos nativos `pagehide`/`beforeunload`)
  /// se elimina la sesión persistida de forma síncrona. `AppLifecycleState
  /// .detached` no llega de forma fiable en Flutter Web, por eso se usan
  /// listeners del navegador; el handler `detached` se mantiene como fallback.
  void _handleWebUnload() {
    clearPersistedSessionSynchronous();
  }

  /// Muestra el aviso de arranque (enlace de auth fallido) tras el primer frame.
  void _showStartupNotice() {
    final notice = widget.startupNotice;
    if (notice == null || notice.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(notice),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
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
    if (kIsWeb) {
      unregisterWebUnloadCleaner(_handleWebUnload);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final presence = sl<PresenceService>();
    switch (state) {
      case AppLifecycleState.resumed:
        presence.markOnline();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        presence.markOffline();
        break;
      case AppLifecycleState.detached:
        presence.markOffline();
        // Cerrar la pestaña (web) no debe dejar un "usuario activo" en caché
        // (siempre quedaba logueado al volver al login), pero tampoco debe
        // borrar el code verifier de PKCE: un link de confirmación/recovery
        // pendiente en ese browser necesita el verifier intacto. En web se
        // elimina solo el token de sesión; en mobile se conserva el signOut
        // local previo de gotrue.
        if (kIsWeb) {
          clearPersistedSessionKeepingPkceVerifier();
        } else {
          context.read<AuthCubit>().clearLocalSession();
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          sl<FcmTokenService>().registerCurrentDevice(state.profile.id);
          if (state.profile.isSpecialist) {
            sl<PresenceService>().start(state.profile.id);
          }
        } else if (state is AuthUnauthenticated) {
          sl<PresenceService>().markOffline();
          // GoRouter solo re-evalúa el redirect ante una navegación; sin este
          // `go` explícito el usuario se quedaba en la pantalla tras signOut.
          appRouter.go(AppRoutes.welcome);
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
