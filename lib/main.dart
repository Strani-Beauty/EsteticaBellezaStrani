import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esteticaybellezastrani/app/config/app_env.dart';
import 'package:esteticaybellezastrani/app/core/di/injection.dart';
import 'package:esteticaybellezastrani/app/app.dart';

/// Bootstrap mínimo — toda la lógica migrada a features/
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Cargar variables de entorno
  await dotenv.load(fileName: '.env').catchError((_) {});

  // 2. Inicializar Supabase
  await Supabase.initialize(
    url: AppEnv.supabaseUrl,
    // ignore: deprecated_member_use
    anonKey: AppEnv.supabaseAnonKey,
  );

  // 3. Registrar dependencias (GetIt)
  setupDependencies();

  // 4. Lanzar la app
  runApp(const App());
}
