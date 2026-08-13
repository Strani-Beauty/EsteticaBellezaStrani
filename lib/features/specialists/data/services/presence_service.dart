import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:esteticaybellezastrani/app/config/app_constants.dart';
import '../../domain/repositories/i_specialists_repository.dart';

/// Servicio de presencia online/offline del especialista (heartbeat en BD).
///
/// Mientras la app del especialista está en foreground, actualiza
/// `especialistas.en_linea` / `ultima_conexion` periódicamente. Al pasar a
/// segundo plano, cerrar la app o cerrar sesión, marca offline. Un cierre
/// forzado sin apagado limpio queda cubierto por el umbral de expiración
/// (`umbralOnlineSegundos`) evaluado en las consultas/RPCs.
class PresenceService {
  final ISpecialistsRepository _repository;

  Timer? _heartbeat;
  String? _especialistaId;
  bool _started = false;

  PresenceService(this._repository);

  /// Arranca la presencia para el usuario autenticado. No-op si el usuario no
  /// es especialista (no tiene fila en `especialistas`).
  Future<void> start(String usuarioId) async {
    if (_started) return;
    _started = true;

    final result = await _repository.getEspecialistaByUsuarioId(usuarioId);
    result.fold(
      (f) {
        debugPrint('⚠️ [Presencia] No se pudo resolver especialista: ${f.message}');
        _started = false;
      },
      (especialista) {
        if (especialista == null) {
          _started = false;
          return;
        }
        _especialistaId = especialista.id;
        markOnline();
      },
    );
  }

  /// Marca online y (re)asegura el heartbeat.
  Future<void> markOnline() async {
    final id = _especialistaId;
    if (id == null) return;
    await _write(id, enLinea: true);
    _heartbeat ??= Timer.periodic(AppConstants.heartbeatPresencia, (_) {
      final current = _especialistaId;
      if (current != null) _write(current, enLinea: true);
    });
  }

  /// Detiene el heartbeat y marca offline.
  Future<void> markOffline() async {
    _heartbeat?.cancel();
    _heartbeat = null;
    final id = _especialistaId;
    if (id == null) return;
    await _write(id, enLinea: false);
  }

  Future<void> _write(String id, {required bool enLinea}) async {
    final res = await _repository.marcarPresencia(id, enLinea: enLinea);
    res.fold(
      (f) => debugPrint(
          '⚠️ [Presencia] ${enLinea ? "online" : "offline"} falló: ${f.message}'),
      (_) {},
    );
  }

  void dispose() {
    _heartbeat?.cancel();
    _heartbeat = null;
  }
}
