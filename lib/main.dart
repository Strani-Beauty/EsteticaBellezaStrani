import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_stripe_web/flutter_stripe_web.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esteticaybellezastrani/app/config/app_env.dart';
import 'package:esteticaybellezastrani/app/core/di/injection.dart';
import 'package:esteticaybellezastrani/app/app.dart';

/// Bootstrap — carga de entorno, inicialización de Supabase y arranque de la app.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await _bootstrap();
    runApp(const App());
  } catch (e, st) {
    debugPrint('FATAL: $e\n$st');
    runApp(_ErrorApp('$e'));
  }
}

Future<void> _bootstrap() async {
  // 1. Cargar variables de entorno
  await dotenv.load(fileName: '.env').catchError((_) {});

  // 2. Validar credenciales imprescindibles antes de continuar
  AppEnv.validate();

  // 2.5 Configurar Stripe (publishable key) si está presente
  if (AppEnv.stripePublishableKey.isNotEmpty) {
    // Flutter no registra flutter_stripe_web en el plugin registrant porque
    // el parent flutter_stripe apunta a un default_package discontinuado
    // (stripe_web). Registramos WebStripe manualmente.
    StripePlatform.instance = WebStripe.instance;
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
}

/// Widget de fallback visible si la inicialización falla (en vez de pantalla blanca).
class _ErrorApp extends StatelessWidget {
  final String message;
  const _ErrorApp(this.message);

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SelectableText(
                'Error de inicialización:\n\n$message\n\n'
                'Verificá que el archivo .env existe y contiene '
                'SUPABASE_URL y SUPABASE_ANON_KEY.',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
      );
}
