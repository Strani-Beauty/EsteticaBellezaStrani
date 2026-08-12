import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../../../firebase_options.dart';
import '../../domain/repositories/i_auth_repository.dart';

/// Servicio defensivo de registro de devices/token FCM (item 11).
/// Solo actúa si Firebase está configurado en la plataforma actual:
///   - Android/iOS: requiere google-services.json / GoogleService-Info.plist.
///   - Web: requiere `firebase_options.dart` o inicialización con opciones.
/// Si Firebase no está disponible (p. ej. todavía sin configurar), degrada
/// con un log sin romper la sesión ni la navegación.
class FcmTokenService {
  final IAuthRepository _authRepository;

  FcmTokenService(this._authRepository);

  bool _firebaseReady = false;
  FirebaseMessaging? _messaging;

  /// Intenta activar Firebase Messaging una sola vez.
  Future<void> init() async {
    if (_firebaseReady) return;
    try {
      // Si no hay config de Firebase (web/desktop), lanza y degradamos.
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _messaging = FirebaseMessaging.instance;
      _firebaseReady = true;
      debugPrint('📱 [FCM] Firebase Messaging listo.');
    } catch (e) {
      _firebaseReady = false;
      debugPrint('⚠️ [FCM] Firebase no configurado, se omite: $e');
    }
  }

  /// Registra el token del dispositivo actualmente autenticado y se suscribe
  /// al refresco de token. No-op si Firebase no está disponible o no hay sesión.
  Future<void> registerCurrentDevice(String profileId) async {
    if (!_firebaseReady || _messaging == null) return;

    try {
      final permission = await _messaging!.requestPermission();
      if (permission.authorizationStatus != AuthorizationStatus.authorized) {
        debugPrint('⚠️ [FCM] Permiso de notificaciones no autorizado '
            '(${permission.authorizationStatus.name}).');
        return;
      }

      final token = await _messaging!.getToken();
      debugPrint('📱 [FCM] Token obtenido: $token');
      if (token == null || token.isEmpty) return;

      await _authRepository.registerFcmToken(
        profileId: profileId,
        fcmToken: token,
        plataforma: _plataforma(),
      );
      debugPrint('✅ [FCM] Token registrado para perfil $profileId');

      _messaging!.onTokenRefresh.listen((nuevoToken) {
        _authRepository.registerFcmToken(
          profileId: profileId,
          fcmToken: nuevoToken,
          plataforma: _plataforma(),
        );
      });
    } catch (e) {
      debugPrint('⚠️ [FCM] Error al registrar token: $e');
    }
  }

  String? _plataforma() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return null;
    }
  }
}