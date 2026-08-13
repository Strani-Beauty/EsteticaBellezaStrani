import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:esteticaybellezastrani/main.dart' as app;

/// Pruebas end-to-end (E2E) de humo del arranque de la aplicación.
///
/// Requieren un dispositivo/emulador y el archivo `.env` (bundlado como asset):
///
///   `flutter test integration_test/app_test.dart -d DEVICE_ID`
///
/// Para flujos completos (registro de especialista → verificación → mapa) se
/// necesita una BD de prueba separada y credenciales; no se incluyen aquí para
/// no tocar producción.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('smoke: arranque, bienvenida y navegación a login',
      (tester) async {
    await app.main();

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 2));

    // No debe aparecer la pantalla de error de inicialización (.env/Supabase).
    expect(find.textContaining('Error de inicialización'), findsNothing);

    // La ruta pública inicial es la bienvenida.
    expect(find.text('Agendar Cita'), findsOneWidget);
    expect(find.text('Especialistas'), findsOneWidget);

    // Navegación: "Agendar Cita" → login (selección de rol).
    await tester.ensureVisible(find.text('Agendar Cita'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agendar Cita'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Selecciona tu perfil de ingreso:'), findsOneWidget);
  });
}
