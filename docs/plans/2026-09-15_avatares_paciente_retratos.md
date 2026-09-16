# Plan — Avatares de paciente: retratos realistas en lugar de presets DiceBear

Fecha: 2026-09-15
Estado: COMPLETADO. Sin commit.

## Objetivo

Reemplazar los 8 presets DiceBear del selector de avatar de paciente por los 8
retratos fotográficos de `assets/icons/Avatares/` (8 carpetas con `screen.png`
1024x1024 PNG ~1 MB cada una, generados con IA). DiceBear se conserva **solo como
fallback por defecto** (paciente sin avatar → `adventurer` con seed = user id).

Decisiones confirmadas (m0392):
- Reemplazar presets DiceBear por los 8 retratos.
- Redimensionar a ~256 px y comprimir antes de empaquetar (los PNG de 1 MB se
  usan a 38-96 px; no inflar el bundle ~8 MB).

## Hallazgos (contexto)

- `AvatarView` (`lib/features/auth_users/presentation/widgets/avatar_view.dart:39-65`)
  resuelve `profiles.avatar_url` en orden: preset `avatar_N` → SVG DiceBear
  runtime; path de storage / URL legacy → URL firmada (`GenerarUrlFirmadaAvatar`);
  null + paciente → DiceBear `adventurer` seed=`profile.id`; null + admin/especialista
  → ícono de rol.
- `AvatarPreset` (`avatar_preset.dart`): `key` (avatar_1..8, se persiste en
  `profiles.avatar_url`), `label`, `style` (DiceBear), `seed`, `color`. Presets
  son const, determinísticos, offline (SVG), sin storage.
- `AvatarSelector` (`avatar_selector.dart`): usado en `complete_profile_screen.dart:601`
  y `profile_screen.dart:155`. Muestra "Subir foto" + fila de 8 tiles (`_PresetTile`
  con `dicebearSvgFor(preset.key)` en círculo 38px).
- Bucket `avatars` es **privado** (migración `20260817000100_avatars_storage_privado.sql`),
  policies por dueño (`foldername(name)[1] = auth.uid()`) + SELECT admin. Foto
  subida = path `<userId>/<ts>.<ext>`, lectura con URL firmada.
- Las claves `avatar_1..8` ya guardadas en BD siguen siendo válidas si se conserva
  el mismo `key` → **sin migración de BD**.

## Cambios

### 1. Imágenes optimizadas
- Redimensionar los 8 `screen.png` a **256x256** y guardar como **JPEG (~q85)** en
  `assets/images/avatares/avatar_1.jpg`..`avatar_8.jpg` (PowerShell + System.Drawing).
- Los originales de `assets/icons/Avatares` NO se commitean (sin trackear, ~8 MB).
- **pubspec.yaml**: además de `assets/images/`, se declara explícitamente
  `assets/images/avatares/`. El bundler de esta versión de Flutter **no recursa**
  en subcarpetas de un asset declarado por directorio: sin esta línea los JPG no
  se copiaban al bundle y el motor web daba 404 en
  `/assets/assets/images/avatares/avatar_N.jpg`.

### 2. `lib/features/auth_users/presentation/widgets/avatar_preset.dart`
- `AvatarPreset` + campo `final String? assetPath;`.
- Los 8 presets pasan a `assetPath` del retrato (mismos `key` avatar_1..8),
  `label` descriptivo, `style`/`seed`/`color` conservados (compatibilidad).
- Se conservan `presetFor`, `isPresetKey`, `dicebearSvg`, `_styleFor`,
  `dicebearSvgFor`, `presetColorFor`.

### 3. `lib/features/auth_users/presentation/widgets/avatar_view.dart`
- En `build`: si `preset != null && preset.assetPath != null` → círculo con
  `Image.asset(preset.assetPath!, fit: BoxFit.cover)`; si no → DiceBear como hoy.
- Orden de resolución intacto (URL firmada, default, ícono).

### 4. `lib/features/auth_users/presentation/widgets/avatar_selector.dart`
- `_PresetTile`: si `preset.assetPath != null` → `Image.asset` en el círculo 38px;
  si no → `SvgPicture.string` (como hoy).

### Sin cambios
- BD/RLS/storage, `supabase_service`, cubits, rutas.
- **pubspec.yaml**: se añade `assets/images/avatares/` (fix del bundler que no
  recursa en subcarpetas; ver arriba).

## Verificación

- [x] `flutter analyze` limpio.
- [x] `flutter test` (366 tests; no hay tests de avatar).
- [ ] Manual en `flutter run -d chrome`: profile/complete-profile → editar avatar →
      8 retratos visibles; seleccionar persiste `avatar_N`; vista previa y perfil
      muestran el retrato; paciente sin avatar → DiceBear default (adventurer).
- [ ] Peso del bundle: 8 JPEG ~256px (unos pocos KB c/u) en vez de ~8 MB.

## Notas

- Sin commit (regla del proyecto: preguntar antes de commitear).
- `assets/icons/` incluye además `Gemini_Generated_Image_*.jfif` y un .zip; se
  dejan sin trackear (no se usan en el código).