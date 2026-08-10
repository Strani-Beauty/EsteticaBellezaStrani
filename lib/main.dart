import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esteticaybellezastrani/app/config/app_env.dart';
import 'package:esteticaybellezastrani/app/core/di/injection.dart';
import 'package:esteticaybellezastrani/app/app.dart';

/// Bootstrap — carga de entorno, inicialización de Supabase y arranque de la app.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Cargar variables de entorno
  await dotenv.load(fileName: '.env').catchError((_) {});

  // 2. Validar credenciales imprescindibles antes de continuar
  AppEnv.validate();

  // 2.5 Configurar Stripe (publishable key) si está presente
  if (AppEnv.stripePublishableKey.isNotEmpty) {
    Stripe.publishableKey = AppEnv.stripePublishableKey;
  }

  // 3. Inicializar Supabase
  await Supabase.initialize(
    url: AppEnv.supabaseUrl,
    // ignore: deprecated_member_use
    anonKey: AppEnv.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      autoRefreshToken: true,
      detectSessionInUri: true,
    ),
  );

  // 4. Registrar dependencias (GetIt)
  setupDependencies();

  // 5. Lanzar la app
  runApp(const App());
}
