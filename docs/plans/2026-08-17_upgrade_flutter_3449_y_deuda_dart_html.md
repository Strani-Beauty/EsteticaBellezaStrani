# Plan: Actualizar Flutter a 3.44.9 + cerrar deuda `dart:html`

| | |
|---|---|
| **Fecha** | 2026-08-17 |
| **Origen** | Evaluación de riesgos de actualizar Flutter: deuda `dart:html` (nuestro cleaner web + `supabase_flutter` 2.5.0) y pins viejos. |
| **Estado** | APROBADO por el usuario (2026-08-17) — objetivo 3.44.9 (patch), fases 1-3 juntas, sin deploy (solo build de verificación). |
| **SDK Flutter** | `C:\Users\Jaime\Desktop\Flutter\flutter` (git, compartido, sin FVM). Commit previo: `058e0af2c2b57e369d905a03ac9748b0ebf543c6`. |

## Contexto
- Actual: **Flutter 3.44.8 / Dart 3.12.2**. Baseline git: `36b9ab5` (main, pusheado).
- Riesgos detectados: nuestro `session_storage_cleaner_web.dart` usaba `dart:html`; `supabase_flutter` pinned 2.5.0 usaba `dart:html` en `local_storage_web.dart` (justo el flujo web PKCE/logout). `flutter_stripe_web`/`flutter_map`/`latlong2` en pins viejos (se mantienen, fuera de alcance salvo conflicto).

## Decisiones (confirmadas)
- Objetivo **3.44.9** (patch de la línea actual, 05-ago-2026).
- **Fases 1-3 juntas**: upgrade Flutter + migrar nuestro cleaner a `package:web` + subir `supabase_flutter` 2.5.0 → 2.16.0 (usa `package:web`; verificado que pinnea `supabase: 2.14.0` = el mismo, storage_client/gotrue/postgrest/realtime **iguales**).
- **Sin deploy** a Firebase Hosting (solo `flutter build web` de verificación + smoke test manual).

## Tareas

### Fase 0 — Preparación y rollback
- [x] Commit SDK previo capturado: `058e0af2c2b57e369d905a03ac9748b0ebf543c6`.
- [x] Tag `pre-flutter-upgrade` en `36b9ab5`.

### Fase 1 — Actualizar Flutter a 3.44.9
- [x] `git fetch --tags` + `git checkout 3.44.9` en el SDK (detached HEAD).
- [x] `flutter --version` → 3.44.9 / Dart 3.12.2 (cache del SDK actualizado).
- [x] `flutter pub get` — sin cambios de lockfile (patch).
- [x] `flutter analyze` sin issues; `flutter test` 80/80.
- [x] `flutter build web` OK (aviso de Wasm por `app_links` 3.5.1, resuelto en Fase 3).

### Fase 2 — Migrar `session_storage_cleaner_web.dart` a `package:web`
- [x] `web: ^1.1.1` añadido como dependencia directa.
- [x] Archivo reescrito con `web.window.localStorage` (`key(i)`/`length`/`removeItem`); sin `dart:html` ni `ignore_for_file`. Mismo comportamiento (borra solo `sb-*-auth-token`, preserva el code verifier).
- [x] `flutter analyze` sin issues; `flutter test` 80/80.

### Fase 3 — `supabase_flutter` 2.5.0 → 2.16.0
- [x] `supabase_flutter: 2.5.0` → `supabase_flutter: ^2.16.0`.
- [x] Resuelto a 2.16.0; `supabase 2.14.0`, `storage_client 2.6.0`, `gotrue 2.26.0`, `postgrest 2.8.0`, `realtime_client 2.11.0` **sin cambios** → `createSignedUrl(path, 3600)` intacto. Nuevos transitivos: `passkeys_platform_interface 2.9.0`, `app_links 7.2.1` (federado → `app_links_web`).
- [x] Incidencia resuelta: registrant web stale apuntaba a `app_links/src/app_links_web.dart` (3.5.1); con app_links 7.x el impl web es federado (`app_links_web`). Solución: `flutter clean` + `pub get` + rebuild → build web OK y **Wasm dry run OK**.
- [x] `flutter analyze` sin issues; `flutter test` 80/80.

### Fase 4 — Verificación integral (sin deploy)
- [x] `flutter analyze` sin issues; `flutter test` 80/80 (post-clean).
- [x] `flutter build web` ✓ Built (Wasm dry run OK).
- [ ] Smoke test manual en browser (pendiente, lo hace el usuario):
  - login/registro email → confirmación PKCE en el mismo browser.
  - logout web → limpia solo el token; enlace pendiente usable.
  - especialista: subir documento (identificación, licencia, diploma/certificación) → PENDIENTE → "Ver" con URL firmada.
  - admin: ver documento (URL firmada), aprobar/rechazar con observación → el especialista ve el motivo y reenvía.
  - vista rápida: mapa (`flutter_map`), firma (`signature`), stripe, avatar.
- [x] Plan persistido (este archivo).
- [ ] Commit + push (pendiente confirmación del usuario).

## Rollback
- Repo: `git checkout pre-flutter-upgrade` y restaurar `pubspec.yaml`+lock desde git.
- SDK: `git -C C:\Users\Jaime\Desktop\Flutter\flutter checkout 058e0af2c2b57e369d905a03ac9748b0ebf543c6` + `flutter --version`.

## Fuera de alcance
- 3.47.0 y futuras (decoupling `material_ui`/`cupertino_ui`, Wasm).
- iOS (SPM/CocoaPods).
- FVM / pin de versión por proyecto.
- Deploy a Firebase Hosting (lo hace el usuario).
- Deuda menor: `flutter_lints ^7`, pins `flutter_stripe_web`/`flutter_map`/`latlong2` (sin conflicto de resolución hoy).

## Checklist
- [x] Fase 0: rollback listo.
- [x] Fase 1: Flutter 3.44.9 + analyze/test/build OK.
- [x] Fase 2: cleaner en `package:web` + analyze/test OK.
- [x] Fase 3: supabase_flutter 2.16.0 + analyze/test OK + build web OK.
- [x] Fase 4 (parcial): analyze/test/build verdes; plan persistido.
- [ ] Smoke test manual en browser.
- [ ] Commit + push.