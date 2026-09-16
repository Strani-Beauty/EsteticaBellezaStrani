# Plan — Resumen de solicitud no detecta la dirección guardada del paciente

Fecha: 2026-09-16
Estado: APROBADO por el usuario (m0754: "ambos" → fallback en lectura + backfill SQL). Sin commit.

## Objetivo

La vista **Resumen de la solicitud** (`solicitud_resumen_screen.dart`) muestra
"Debes registrar una dirección antes de continuar" aunque el paciente tenga
dirección guardada. Causa raíz (confirmada en BD por pooler): la dirección se
guarda en `profiles` (`address`, `latitude`, `longitude`) pero la pantalla la
lee **solo de `direcciones_paciente`** (vía `fetchMiDireccionPrincipal`). La
mayoría de pacientes tienen `profiles.address` poblado y 0 filas en
`direcciones_paciente`; solo `complete_profile_screen` insertaba ahí, y solo
después del pago de $30.

RLS verificado: `direccion_paciente_own` (FOR ALL) permite al paciente
insertar/leer sus propias direcciones vía `pacientes.usuario_id = auth.uid()`.

## Cambios

### 1. Espejo al guardar (causa raíz — futuras lecturas nunca fallan)
- `patient_address_screen.dart` `_saveLocation`: tras `SupabaseService.updateProfileData`,
  llamar `SupabaseService.savePatientAddress(profileId: user.id, ...)`.
- `profile_screen.dart` `_guardar` (rama paciente): tras `AuthCubit.updateProfile`,
  si la dirección no está vacía, llamar `SupabaseService.savePatientAddress(...)`.
- `complete_profile_screen.dart`: llamar `savePatientAddress` en `_guardarDatos`
  (justo tras `updateProfileData`) y **eliminar** la llamada duplicada del modal
  Stripe (línea 516) para evitar filas dobles.

`savePatientAddress` ya existe (`supabase_service.dart:588`): marca las previas
`es_principal=false` e inserta la nueva con `es_principal=true`.

### 2. Fallback de lectura auto-reparador
`solicitudes_reserva_supabase_datasource.dart` `fetchMiDireccionPrincipal`: si no
hay fila en `direcciones_paciente`, leer `profiles` (`address`, `latitude`,
`longitude`) del perfil; si hay dirección, INSERT espejo en `direcciones_paciente`
(`paciente_id`, `direccion`, `latitud`, `longitud`, `es_principal: true`) y
devolver la entidad. Sana a los pacientes existentes al abrir el resumen.

### 3. Migración SQL de backfill (una pasada)
Nueva `supabase/migrations/20260916000200_direcciones_paciente_backfill.sql`
(idempotente):
- **Fix de esquema (hallazgo durante la ejecución)**: `ciudad`, `estado` y
  `codigo_postal` eran `NOT NULL` en el remoto, pero `savePatientAddress` inserta
  sin esas columnas → **todo guardado de dirección fallaba en silencio** (bug de
  raíz). La migración hace `ALTER COLUMN ... DROP NOT NULL` en las 3, alineando
  el esquema con lo que el código ya asumía.
- INSERT INTO `direcciones_paciente` (paciente_id, direccion, latitud, longitud,
  es_principal) SELECT desde `profiles` JOIN `pacientes` por `usuario_id`, solo
  donde `address` no vacía y el paciente no tenga ya dirección (`WHERE NOT EXISTS`).

Aplicada al remoto por pooler (CLI da 401 sin `supabase login`): 6 → 19 filas
(13 insertadas), 0 pendientes.

## Verificación

- [x] `flutter analyze` limpio.
- [x] `flutter test` (366 tests).
- [x] Pooler: pacientes con `profiles.address` y 0 filas pasan a tener 1 fila
      principal tras backfill (pending=0).
- [ ] Manual (`flutter run -d chrome`): paciente con dirección → Resumen muestra
      la dirección y permite pagar/confirmar sin bloqueo.

## Notas

- Sin commit (regla del proyecto: preguntar antes de commitear).