# Plan: Avatares creativos DiceBear por preset + fix de subida/preview de foto

Fecha: 2026-08-17
Estado: aprobado por usuario, en implementación

## Contexto / quejas del usuario

1. "Los avatares a seleccionar siguen siendo los mismos": los presets del ingreso de
   datos del paciente son íconos pastel de Material; el plan anterior solo puso
   DiceBear para el caso "sin avatar".
2. "La foto no la sube o no la muestra": la foto del paciente sigue sin mostrarse en
   el círculo designado. El flujo nuevo guarda el **path** y lo lee con URL firmada,
   pero:
   - `_SignedAvatar` resuelve la URL firmada solo en `initState()` → estado viejo si
     cambia el valor o falla la primera vez (no reintenta).
   - El mecanismo `createSignedUrl` (POST `/object/sign`, requiere policy de SELECT
     del bucket) aún no se ha validado en vivo (compartido con documentos de
     especialistas, que tampoco tiene smoke test).
   - Posible caché del Service Worker de Flutter web sirviendo la build vieja.

## Decisiones del usuario

- Generador de presets: **DiceBear local** (offline, determinístico; ya integrado).
- Variación: **8 estilos distintos** (adventurer, avataaars, lorelei, micah,
  fun_emoji, open_peeps, big_ears, miniavs), seed fijo por clave → mismo avatar siempre.

## Tareas

### A. Presets creativos con DiceBear (sin migración)
- [x] Helper `presentation/widgets/avatar_preset.dart`: `AvatarPreset` (key, label,
      style, seed, color), lista `avatarPresets` (claves `avatar_1..8`), `presetFor`,
      `isPresetKey`, `dicebearSvg(style, seed)`, `dicebearSvgFor(key)`, `presetColorFor`
      (estilos cacheados en un `Map<String, Style>`).
      Nota: `dicebear_core` exporta un tipo `Color` que choca con Flutter; se importa
      con prefijo `as dicebear` para evitar el conflicto.
- [x] `avatar_selector.dart`: usar `avatarPresets`; `_PresetTile` renderiza el SVG
      DiceBear (`SvgPicture.string`) en vez del ícono Material; `AvatarSelector` pasa a
      `StatefulWidget` con estado de subida (botón con spinner mientras sube, snackbar
      con el error real).
- [x] `avatar_view.dart`: rama preset renderiza el SVG DiceBear; rama null+paciente
      sigue generando DiceBear (adventurer + seed); quitar dependencia a
      `AvatarSelector` (rompe el import circular).

### B. Fix de la foto (subida + preview)
- [x] `_SignedAvatar`: `didUpdateWidget` re-resuelve si cambia `value`; estado `_error`
      con el motivo real; tap sobre el fallback reintenta; `debugPrint` del error.
- [x] Smoke test en vivo del flujo `createSignedUrl`: **verificado por el usuario** —
      los 8 presets DiceBear se ven distintos y la foto subida se muestra en la vista
      previa y en el perfil (hard refresh). No se requirió migración correctiva.

### C. Verificación
- [x] `flutter analyze` + `flutter test` (80/80).
- [x] Smoke test web con **hard refresh** (descartar Service Worker):
      1. Ingreso de datos: tiles DiceBear distintos por preset + preview según preset. ✅
      2. Subir foto → preview muestra la foto; re-entrar → persiste. ✅
      3. Perfil: DiceBear / preset / foto. ✅
- [x] Build web + deploy Firebase (https://esteticaybellezastrani.web.app).

## Pendientes fuera de alcance
- Buckets públicos restantes (`contratos`, `firmas`, `fotografias-tratamiento`).
- Revert de la confirmación de correos de pruebas (`20260817010002`).