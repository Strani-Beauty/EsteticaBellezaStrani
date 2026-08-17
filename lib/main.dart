import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_stripe_web/flutter_stripe_web.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esteticaybellezastrani/app/config/app_env.dart';
import 'package:esteticaybellezastrani/app/core/di/injection.dart';
import 'package:esteticaybellezastrani/app/app.dart';

/// Bootstrap — carga de entorno, inicialización de Supabase y arranque de la app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final startupNotice = await _bootstrap();
    runApp(App(startupNotice: startupNotice));
  } catch (e, st) {
    debugPrint('FATAL: $e\n$st');
    runApp(_ErrorApp('$e'));
  }
}

Future<String?> _bootstrap() async {
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

  // 5. Surfear un enlace de auth (confirmación/recovery) que falló en silencio
  //    durante el intercambio PKCE de `Supabase.initialize`.
  return _authCallbackNotice();
}

/// Devuelve un aviso amigable si la URL inicial es un callback de Supabase Auth
/// (PKCE `code` o redirect con error) que no pudo completarse. `null` si no
/// aplica o si la sesión se estableció correctamente.
String? _authCallbackNotice() {
  final uri = Uri.base;
  final isAuthCallback = uri.queryParameters.containsKey('code') ||
      uri.queryParameters.containsKey('error') ||
      uri.queryParameters.containsKey('error_code') ||
      uri.queryParameters.containsKey('error_description');
  if (!isAuthCallback) return null;

  final errorDescription =
      uri.queryParameters['error_description'] ?? uri.queryParameters['error'];
  if (errorDescription != null && errorDescription.trim().isNotEmpty) {
    return 'No se pudo completar el enlace: $errorDescription';
  }

  // Con `code` presente y sin sesión tras initialize, el intercambio PKCE falló
  // (verifier ausente, expirado o ya usado).
  if (Supabase.instance.client.auth.currentUser == null) {
    return 'El enlace de confirmación no se pudo usar (expiró, ya fue usado '
        'o fue enviado desde otro navegador). Iniciá sesión o solicitá un '
        'correo nuevo.';
  }
  return null;
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
