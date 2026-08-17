# Plan: Fix confirmación de correo (PKCE) cuando hay sesión previa / browser con actividad

| | |
|---|---|
| **Fecha** | 2026-08-17 |
| **Origen** | Bug reportado: confirmar el correo fallaba cuando ya había una sesión abierta en el mismo browser; desde una ventana aparte funcionó. |
| **Estado** | APROBADO por el usuario (2026-08-17) — estrategia A (parche mínimo). |
| **Proyecto Supabase** | `hhyjremkguvphmjuaazp` (bellezastrani@gmail.com). |

## Diagnóstico (causa raíz confirmada en código)

Con `AuthFlowType.pkce` + `detectSessionInUri: true` (`main.dart:44-48`), el link de
confirmación trae un `code` de un solo uso que se intercambia durante
`Supabase.initialize` (`exchangeCodeForSession`). Ese intercambio requiere el *code
verifier* que quedó guardado en el browser al registrarse
(`supabase.auth.token-code-verifier`).

La app lo borra en cada cierre de pestaña web:

- `app.dart:85` → `clearLocalSession()` en `AppLifecycleState.detached` →
  `signOut(scope: SignOutScope.local)` → gotrue 2.26 elimina la clave del verifier
  (`gotrue_client.dart:986-989`, `_signOut`).
- Si además ya hay una sesión (p.ej. login con contraseña, que nunca crea verifier),
  el link no tiene verifier que usar.

Al faltar el verifier, `exchangeCodeForSession` lanza
`AuthException('Code verifier could not be found in local storage.')` que supabase_flutter
loguea en silencio (`supabase_auth.dart:217-220`) → el usuario no ve nada. En ventana
limpia donde se registra y confirma al hilo, el verifier está intacto y funciona.

Este bug también rompía el flujo de **recovery de contraseña** (usa el mismo verifier).

## Cambios (parche mínimo)

1. **`lib/app/core/session_storage_cleaner*.dart`** (nuevo, import condicional):
   - En web elimina SOLO el token de sesión de `window.localStorage`
     (`sb-<project>-auth-token`), preservando el code verifier de PKCE
     (`flutter.supabase.auth.token-code-verifier`). Stub no-op fuera de web.

2. **`lib/app/app.dart`** — cerrar pestaña sin dejar "usuario activo" en caché
   PERO sin romper enlaces pendientes:
   - `AppLifecycleState.detached`: en web (`kIsWeb`) → limpiar solo el token de
     sesión (verifier intacto); en mobile → `clearLocalSession()` (comportamiento
     previo de gotrue, incluye el verifier).
   - Antes el `signOut(scope: local)` de gotrue borraba sesión Y verifier, de ahí
     que la confirmación fallara al volver al mismo browser.

3. **`lib/main.dart`** — surfear fallo silencioso del enlace:
   - Tras `Supabase.initialize`, si la URL inicial es callback de auth
     (`code` / `error` / `error_description` / `error_code` en `Uri.base`) y
     `currentUser == null`, preparar aviso amigable:
     *"El enlace no se pudo usar (expiró, ya fue usado o fue enviado desde otro
     navegador). Iniciá sesión o solicitá un correo nuevo."*
   - Pasar el aviso a `App` para mostrarlo como SnackBar tras el primer frame.
   - Solo `Uri.base` (cross-platform), sin `dart:html` → sin imports condicionales.

4. **Verificación**: `flutter analyze`, `flutter test` (placeholder) y prueba manual
   del flujo registro → confirmar en el mismo browser con sesión previa.

## Fuera de alcance (fase 2 sugerida)

Confirmar desde otro browser/dispositivo sigue fallando por diseño de PKCE (verifier
atado al browser de registro). Requiere estrategia `token_hash`/`verifyOtp` + editar
plantillas de email en el Dashboard. En mobile, `clearLocalSession()` al matar la app
sigue borrando el verifier (afecta deep links de recovery dentro de la app); la
confirmación de correo en mobile ocurre en el web app (Site URL), así que no aplica ahí.

## Checklist

- [x] Plan persistido en `docs/plans/` (este archivo).
- [x] `session_storage_cleaner*.dart`: borra solo el token de sesión web, preserva el verifier.
- [x] `app.dart`: `detached` → web limpia solo token de sesión; mobile `clearLocalSession()`.
- [x] `main.dart`: detección de callback de auth + aviso amigable.
- [x] `App`: SnackBar con el aviso tras el primer frame.
- [x] `flutter analyze` sin issues (107.5s).
- [x] `flutter test` en verde (80/80).
- [ ] Prueba manual: registrar → cerrar pestaña → abrir link de confirmación en el
      mismo browser (con sesión previa) → se confirma la cuenta. *(pendiente, manual)*