# Cierre de sesión al salir/cerrar página web (incluye F5)

Fecha: 2026-09-03 · Estado: APROBADO por el usuario (m0056/m0086/m0088)

## Problema

En Flutter Web, al cerrar la pestaña/ventana no siempre se limpia la sesión de
Supabase: al reingresar la app cae en el usuario que quedó abierto (intermitente,
"en ocasiones"). La sesión se persiste en `window.localStorage` bajo la clave
`sb-hhyjremkguvphmjuaazp-auth-token` (supabase_flutter 2.5.0, default
`SharedPreferencesLocalStorage`).

## Causa raíz

La limpieza solo se dispara vía `AppLifecycleState.detached` en
`_SessionLifecycleGateState.didChangeAppLifecycleState` (lib/app/app.dart:106).
Ese evento de Flutter Web **no se entrega de forma fiable** al cerrar la
pestaña/ventana (a veces sí, a veces no). El limpiador ya apunta a la clave
correcta; falla el disparo, no la lógica.

## Solución

Registrar listeners nativos del navegador (`pagehide` + fallback `beforeunload`)
vía `package:web` que invocan la limpieza de forma **síncrona** (cuerpo síncrono:
se completa antes del teardown del navegador). Se conserva el handler `detached`
como fallback.

Decisiones tomadas (confirmadas con el usuario):
- `pagehide`/`beforeunload` también limpian al refrescar (F5) — aceptado: "Limpiar
  también en F5".
- Se preserva el code verifier PKCE (claves `flutter.`): un link de
  confirmación/recovery pendiente en ese browser sigue funcionando.
- No se usa `preventDefault`: no aparece el diálogo "abandonar sitio".
- Mobile/desktop sin cambios (`AuthCubit.clearLocalSession` en detached).

## Cambios

- [x] `lib/app/core/session_storage_cleaner_web.dart`: extraer el loop de
      localStorage a `void clearPersistedSessionSynchronous()` (síncrono);
      `clearPersistedSessionKeepingPkceVerifier()` lo invoca.
- [x] `lib/app/core/session_storage_cleaner.dart` y `_stub.dart`: exponer
      `clearPersistedSessionSynchronous()` (stub: no-op).
- [x] Nuevos `lib/app/core/web_unload_cleaner*.dart` (web/stub/wrapper, patrón
      conditional-import): `registerWebUnloadCleaner(fn)` / `unregisterWebUnloadCleaner(fn)`
      registran/remueven `pagehide` + `beforeunload` en `web.window`.
- [x] `lib/app/app.dart` `_SessionLifecycleGateState`: en initState si `kIsWeb`
      `registerWebUnloadCleaner(_handleWebUnload)`; `_handleWebUnload` →
      `clearPersistedSessionSynchronous()`. En dispose, desregistrar.

## Verificación

- [x] `flutter analyze` — No issues found
- [x] `flutter test` — 366 tests passed
- [x] `flutter build web` — Built build\web
- [x] Commit + push (mensaje en español)