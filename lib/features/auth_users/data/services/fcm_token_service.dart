import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../../../firebase_options.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../../domain/usecases/register_fcm_token.dart';

/// Servicio defensivo de registro de devices/token FCM (item 11).
/// Solo actúa si Firebase está configurado en la plataforma actual:
///   - Android/iOS: requiere google-services.json / GoogleService-Info.plist.
///   - Web: requiere `firebase_options.dart` o inicialización con opciones.
/// Si Firebase no está disponible (p. ej. todavía sin configurar), degrada
/// con un log sin romper la sesión ni la navegación.
class FcmTokenService {
  final RegisterFcmToken _registerFcmToken;
  final IAuthRepository _authRepository;

  FcmTokenService(this._registerFcmToken, this._authRepository);

  bool _firebaseReady = false;
  bool _tokenRefreshSubscribed = false;
  FirebaseMessaging? _messaging;
  String? _currentProfileId;

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

  /// Registra el token del dispositivo actualmente autenticado. No-op si
  /// Firebase no está disponible o no hay sesión.
  Future<void> registerCurrentDevice(String profileId) async {
    if (!_firebaseReady || _messaging == null) return;

    _currentProfileId = profileId;
    _subscribirTokenRefresh();

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

      await _registerFcmToken(
        profileId: profileId,
        fcmToken: token,
        plataforma: _plataforma(),
        modeloDispositivo: await _modeloDispositivo(),
      );
      debugPrint('✅ [FCM] Token registrado para perfil $profileId');
    } catch (e) {
      debugPrint('⚠️ [FCM] Error al registrar token: $e');
    }
  }

  /// Suscribe una única vez al refresco de token FCM (evita acumular
  /// listeners en cada `registerCurrentDevice`). El callback re-registra el
  /// nuevo token para el perfil actualmente autenticado.
  void _subscribirTokenRefresh() {
    if (_tokenRefreshSubscribed || _messaging == null) return;
    _tokenRefreshSubscribed = true;
    _messaging!.onTokenRefresh.listen((nuevoToken) async {
      final profileId = _currentProfileId;
      if (profileId == null || nuevoToken.isEmpty) return;
      debugPrint('📱 [FCM] Token refrescado: $nuevoToken');
      await _registerFcmToken(
        profileId: profileId,
        fcmToken: nuevoToken,
        plataforma: _plataforma(),
        modeloDispositivo: await _modeloDispositivo(),
      );
    });
  }

  /// Desactiva el token del dispositivo actual (logout). No-op si Firebase
  /// no está disponible; nunca rompe el cierre de sesión (fire-and-forget).
  Future<void> deactivateCurrentDevice() async {
    if (!_firebaseReady || _messaging == null) return;

    try {
      final token = await _messaging!.getToken();
      if (token == null || token.isEmpty) return;
      await _authRepository.deactivateFcmToken(token);
      debugPrint('✅ [FCM] Token desactivado: $token');
    } catch (e) {
      debugPrint('⚠️ [FCM] Error al desactivar token: $e');
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

  /// Modelo legible del dispositivo actual (brand + model). Degrada a null si
  /// no puede leerse (p. ej. escritorio sin device_info_plus soportado).
  Future<String?> _modeloDispositivo() async {
    try {
      final plugin = DeviceInfoPlugin();
      if (kIsWeb) {
        final info = await plugin.webBrowserInfo;
        return 'web/${_labelNavegador(info.browserName)}';
      }
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final info = await plugin.androidInfo;
          final brand = info.brand.trim();
          final model = info.model.trim();
          if (brand.isNotEmpty && model.isNotEmpty) return '$brand $model';
          if (model.isNotEmpty) return model;
          if (brand.isNotEmpty) return brand;
          return 'Android';
        case TargetPlatform.iOS:
          final info = await plugin.iosInfo;
          final model = info.model.trim();
          final machine = info.utsname.machine.trim();
          return 'iOS ${model.isNotEmpty ? model : machine}';
        default:
          return null;
      }
    } catch (e) {
      debugPrint('⚠️ [FCM] No se pudo leer el modelo del dispositivo: $e');
      return null;
    }
  }

  String _labelNavegador(BrowserName name) {
    switch (name) {
      case BrowserName.chrome:
        return 'Chrome';
      case BrowserName.safari:
        return 'Safari';
      case BrowserName.firefox:
        return 'Firefox';
      case BrowserName.edge:
        return 'Edge';
      case BrowserName.opera:
        return 'Opera';
      case BrowserName.samsungInternet:
        return 'Samsung Internet';
      default:
        return 'Web';
    }
  }
}