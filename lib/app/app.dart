import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esteticaybellezastrani/app/config/app_routes.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/features/auth_users/data/datasources/auth_supabase_datasource.dart';
import 'package:esteticaybellezastrani/features/auth_users/data/repositories/auth_repository_impl.dart';
import 'package:esteticaybellezastrani/features/auth_users/presentation/cubits/auth_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Punto de entrada de la aplicación.
/// Provee AuthCubit globalmente y conecta GoRouter.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthCubit>(
      create: (_) {
        // Crear dependencias manualmente (en Fase 3 se migra a GetIt)
        final supabase = Supabase.instance.client;
        final dataSource = AuthSupabaseDataSource(supabase);
        final repository = AuthRepositoryImpl(dataSource);
        return AuthCubit(repository)..checkCurrentSession();
      },
      child: Builder(
        builder: (context) => MaterialApp.router(
          title: 'Estética y Belleza Strani',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          routerConfig: appRouter,
        ),
      ),
    );
  }
}
