import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centraliza el acceso a variables de entorno con validación en tiempo de inicio.
class AppEnv {
  AppEnv._();

  static String get supabaseUrl => _get('SUPABASE_URL', 'https://hhyjremkguvphmjuaazp.supabase.co');
  static String get supabaseAnonKey => _get(
        'SUPABASE_ANON_KEY',
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhoeWpyZW1rZ3V2cGhtanVhYXpwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUyNTQwODIsImV4cCI6MjEwMDgzMDA4Mn0.vVMpT5OlT1aj9kqJIimQ3S1HoKYZ54pGCn8WNUd2sWo',
      );
  static String get stripePublishableKey => _get('STRIPE_PUBLISHABLE_KEY', '');
  static String get mapboxToken => _get('MAPBOX_ACCESS_TOKEN', '');
  static String get googleMapsKey => _get('GOOGLE_MAPS_API_KEY', '');
  static String get qualifyApiUrl => _get('QUALIFY_API_URL', '');

  static String _get(String key, String defaultValue) {
    return dotenv.env[key] ?? defaultValue;
  }
}
