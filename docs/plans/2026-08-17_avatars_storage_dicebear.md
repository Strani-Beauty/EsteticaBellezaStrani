# Plan: Avatares de paciente — fix de círculo + DiceBear local

Fecha: 2026-08-17
Estado: aprobado por usuario, en implementación

## Contexto / bug

- En el ingreso de datos del paciente (`complete_profile_screen`) la subida de foto
  muestra "subida correctamente", pero el círculo de vista previa no la muestra.
- Causa raíz: el bucket `avatars` es **privado** (creado a mano, no está en
  migraciones). `AvatarSelector._upload` guarda en `avatar_url` una URL pública
  (`getPublicUrl`), pero `Image.network` la pide sin auth y recibe 400.
- Evidencia: GET anónimo a `storage/v1/object/public/<bucket>/x.png` → 400 para
  todos los buckets; `GET /storage/v1/bucket` autenticado → `[]`.

## Decisiones del usuario

- Vista del bug: ingreso de datos del paciente (preview del selector).
- Estrategia bucket: **privado + URLs firmadas** (`createSignedUrl`).
- Generador por defecto: **DiceBear local** (`dicebear_core` + `dicebear_styles`).

## Tareas

### A. Migración `supabase/migrations/20260817000100_avatars_storage_privado.sql`
- [x] Bucket `avatars` privado (`INSERT ... ON CONFLICT DO UPDATE SET public = FALSE`).
- [x] Policies `avatars_storage_own_insert/select/update/delete` (dueño:
      `(storage.foldername(name))[1] = auth.uid()::text`) + `avatars_storage_admin_select`.
- [x] DROP legacy `avatars_public_select`.
- [x] Migrar `profiles.avatar_url` legacy → path
      (`regexp_replace('^.*/object/public/avatars/', '')`).

### B. Capa de datos (auth_users)
- [x] `crearUrlFirmadaAvatar(path)` → `createSignedUrl(path, 3600)` en datasource,
      repositorio, usecase y registro en `injection.dart`.
- [x] `AvatarSelector._upload`: guardar el **path** (`uploaded`) en vez de `getPublicUrl`.

### C. Widget compartido de avatar
- [x] Helper que resuelve: preset key → ícono pastel; path/URL legacy → URL firmada →
      `CachedNetworkImage`; null + paciente → DiceBear identicon; null + admin/especialista →
      ícono de rol (`AvatarView` en `presentation/widgets/avatar_view.dart`).
- [x] `_Preview` (avatar_selector) resuelve URL firmada; `_AvatarContent`
      (profile_screen) usa el helper (eliminada; `AvatarView` la reemplaza).

### D. DiceBear local
- [x] pubspec: `dicebear_core`, `dicebear_styles`, `flutter_svg` (resueltos 10.6.0/10.5.0/2.3.0).
- [x] Helper: `Style.parse(adventurer)` + `Avatar(style, {'seed': uid})` → `SvgPicture.string(avatar.svg)`.

### E. Verificación
- [x] `flutter analyze` + `flutter test` (80/80).
- [x] Aplicar migración al remoto (`supabase db push --include-all`; remoto en `20260817000100`).
- [x] Build web + deploy Firebase Hosting (https://esteticaybellezastrani.web.app).
- [ ] Probar subida + preview + perfil (smoke test manual en browser).

## Pendientes fuera de alcance
- Versionar `disponibilidad_especialista`, `ubicaciones_especialista`, `contratos`
  (creadas a mano).
- Convertir otros buckets públicos (`contratos`, `fotografias-tratamiento`) a privados.