import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centraliza el acceso a variables de entorno con validación en tiempo de inicio.
class AppEnv {
  AppEnv._();

  static String get supabaseUrl => _require('SUPABASE_URL');
  static String get supabaseAnonKey => _require('SUPABASE_ANON_KEY');
  static String get stripePublishableKey => _get('STRIPE_PUBLISHABLE_KEY', '');
  static String get mapboxToken => _get('MAPBOX_ACCESS_TOKEN', '');
  static String get googleMapsKey => _get('GOOGLE_MAPS_API_KEY', '');
  static String get qualifyApiUrl => _get('QUALIFY_API_URL', '');

  static String _require(String key) {
    final val = dotenv.env[key];
    if (val == null || val.isEmpty) {
      throw Exception('[AppEnv] Variable de entorno requerida no encontrada: $key');
    }
    return val;
  }

  static String _get(String key, String defaultValue) {
    return dotenv.env[key] ?? defaultValue;
  }
}
