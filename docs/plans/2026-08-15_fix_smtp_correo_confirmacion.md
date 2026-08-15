# Plan: Corregir envío de correo de confirmación (SMTP + UX de error)

| | |
|---|---|
| **Fecha** | 2026-08-15 |
| **Origen** | Error reportado por el usuario al registrar: `{"code":"unexpected_failure","message":"Error sending confirmation email"}`. |
| **Estado** | APROBADO por el usuario (2026-08-15). |
| **Proyecto Supabase** | `hhyjremkguvphmjuaazp` (bellezastrani@gmail.com). |

## Diagnóstico

El error lo devuelve **GoTrue** (Auth de Supabase) cuando falla el envío del correo de
confirmación por SMTP. **No es un bug del código Flutter**; el flujo de la app es
correcto (`login_screen.dart:446` → `AuthCubit.signUp` → `auth_repository_impl.dart:46`
→ `_client.auth.signUp()` en `auth_supabase_datasource.dart:37`). El repo envuelve la
`AuthException` en `AuthFailure(e.message, code: e.code)` y el cubit emite `AuthError`
→ SnackBar en español/inglés crudo.

Causa raíz: configuración SMTP (Gmail) en el dashboard. Causas típicas:
- App Password revocado/caducado (Google lo revoca al cambiar contraseña o desactivar 2FA).
- Gmail bloqueando el login SMTP (intentos fallidos / "less secure apps").
- Puerto/encriptación incorrecta (465 SSL vs 587 STARTTLS).
- Sender no coincide con el usuario SMTP.

## Fase 1 — Diagnóstico en dashboard (manual)

1. Authentication → **Logs → Auth**: revisar el signup fallido y copiar el error SMTP real.
2. Authentication → **Email / SMTP Settings**: verificar host `smtp.gmail.com`, puerto, usuario y sender.

## Fase 2 — Corregir SMTP en el dashboard (manual)

3. Regenerar **App Password** en Google si fue revocado.
4. Reintroducir credenciales en Custom SMTP (465 SSL o 587 STARTTLS).
5. Probar signup real; confirmar que llega el correo y activa la cuenta.

## Fase 3 — Mejora de la app (código)

6. Mapear en `auth_repository_impl.dart` (`signUp`) el `code == 'unexpected_failure'`
   con mensaje de envío de correo → `AuthFailure` con mensaje amigable en español.
7. Mensaje cubre el botón "Reenviar correo" (`login_screen.dart:542`) y la alternativa
   Authentication → Logs / Emails del dashboard.
8. `flutter analyze` + `flutter test`.

## Checklist

- [x] Plan persistido en `docs/plans/` (este archivo).
- [x] Dashboard: error SMTP real identificado (Logs → Auth) = `535 "5.7.8 Username and Password not accepted"` (BadCredentials). Credenciales SMTP inválidas en el dashboard.
- [ ] Dashboard: regenerar App Password en Google y reconfigurarlo en Supabase (host `smtp.gmail.com`, puerto 465+SSL, usuario/sender `bellezastrani@gmail.com`). *(pendiente, manual)*
- [x] App: mensaje amigable para `unexpected_failure` en `auth_repository_impl.dart`
      (helper `_authFailureFrom`, aplicado a `signUp` y `resendConfirmationEmail`).
- [x] `flutter analyze` sin issues (73.5s) y `flutter test` 80/80 en verde.
- [ ] Signup real re-probado (correo entregado + cuenta confirmable). *(pendiente, manual)*
