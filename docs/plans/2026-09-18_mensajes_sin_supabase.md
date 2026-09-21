# Plan — Reemplazar mensajes "Supabase" por texto amigable

Fecha: 2026-09-18
Estado: APROBADO por el usuario (m1409). Sin commit.

## Objetivo

El usuario final no sabe qué es Supabase. Los mensajes visibles que mencionan
"Supabase" crean confusión y deben cambiarse a texto amigable. Se reemplazan SOLO
los strings visibles en la UI; los `debugPrint`, comentarios, nombres de clases
(`SupabaseService`, datasources) y `package:supabase_flutter` se dejan intactos.

## Cambios

| # | Archivo:línea | Antes | Después |
|---|---|---|---|
| 1 | `complete_profile_screen.dart:264` | `'✅ Datos guardados en Supabase correctamente.'` | `'✅ Datos guardados correctamente.'` |
| 2 | `patient_address_screen.dart:184` | `'✅ Dirección y posición exacta guardadas en Supabase exitosamente.'` | `'✅ Dirección y posición guardadas exitosamente.'` |
| 3 | `patient_address_screen.dart:194` | `'Error al guardar en Supabase: $e'` | `'Error al guardar la dirección. Intenta de nuevo.'` (se conserva `$e` en `debugPrint`, no en UI) |
| 4 | `patient_address_screen.dart:389` | `_isSaving ? 'Guardando en Supabase...' : 'Confirmar y Guardar Ubicación'` | `_isSaving ? 'Guardando...' : 'Confirmar y Guardar Ubicación'` |
| 5 | `face_map_questionnaire_screen.dart:614` | `_isSaving ? 'Guardando en Supabase...' : 'Guardar Mapeo en Supabase (face_maps)'` | `_isSaving ? 'Guardando...' : 'Guardar Mapeo Facial'` |

### Sin cambios
- `debugPrint('⚠️ Supabase Edge Function...')` en `supabase_service.dart:193,281`
  (logs de consola, invisibles al usuario).
- Comentarios de código, `SupabaseService`, datasources, imports.
- BD, RLS, cubits, datasources.

## Verificación

- [x] `flutter analyze` limpio.
- [x] `flutter test` (370).
- [ ] Manual: guardar perfil / dirección / face map → snackbars sin "Supabase".

## Notas

- Sin commit (regla del proyecto: preguntar antes).