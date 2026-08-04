import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centraliza el acceso a variables de entorno con validación en tiempo de inicio.
class AppEnv {
  AppEnv._();

  static String get supabaseUrl => _get('SUPABASE_URL', '');
  static String get supabaseAnonKey => _get('SUPABASE_ANON_KEY', '');
  static String get stripePublishableKey => _get('STRIPE_PUBLISHABLE_KEY', '');
  static String get mapboxToken => _get('MAPBOX_ACCESS_TOKEN', '');
  static String get googleMapsKey => _get('GOOGLE_MAPS_API_KEY', '');
  static String get qualifyApiUrl => _get('QUALIFY_API_URL', '');

  /// Valida que existan las variables imprescindibles de Supabase.
  /// Debe llamarse tras cargar el .env en main(). Lanza StateError si faltan.
  static void validate() {
    if (supabaseUrl.isEmpty) {
      throw StateError('Falta SUPABASE_URL. Copia .env.example a .env y configúralo.');
    }
    if (supabaseAnonKey.isEmpty) {
      throw StateError('Falta SUPABASE_ANON_KEY. Copia .env.example a .env y configúralo.');
    }
  }

  static String _get(String key, String defaultValue) {
    return dotenv.env[key] ?? defaultValue;
  }
}
