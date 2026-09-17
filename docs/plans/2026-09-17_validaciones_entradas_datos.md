# Plan — Validación de todas las entradas de datos

Fecha: 2026-09-17
Estado: APROBADO por el usuario (m1081: "aprobar"). Sin commit.

## Objetivo

Auditar y asegurar que todas las entradas de datos tengan su respectiva validación:
correo con formato correcto, teléfono de 10-15 dígitos numéricos con "+" opcional
(E.164 flexible, decisión m1052), campos opcionales validados solo si se rellenan,
numéricos > 0 y valores de configuración según su `tipoDato`.

Los seeds de prueba se adaptan a las validaciones (decisión m1074: "Adapta los
seeds") porque los emails `@test` sin punto y los teléfonos `+1 555 01NN` (8 dígitos
con espacios) no pasarían el nuevo regex; de lo contrario el login bloquearía las
cuentas de la matriz.

## Cambios

### 1. Nuevo `lib/app/core/utils/validators.dart`
```dart
final _emailRegex = RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
final _telefonoRegex = RegExp(r'^\+?\d{10,15}$');

String? validarCorreo(String? v, {bool requerido = true})
  // vacío → 'Ingresa tu correo' si requerido, sino null; formato → 'Correo no válido'
String? validarTelefono(String? v, {bool requerido = true})
  // vacío → 'Ingresa tu teléfono' si requerido, sino null; formato →
  // 'Teléfono no válido (10-15 dígitos, + opcional)'
```

### 2. Pantallas
- `login_screen.dart`: correo → `validarCorreo()`; teléfono registro (L352) →
  `validarTelefono(requerido: false)`; diálogo Recuperar contraseña (L518-539)
  TextField crudo → `Form` + `TextFormField` con `validarCorreo()`.
- `complete_profile_screen.dart` teléfono (L614-624) → `validarTelefono()`.
- `profile_screen.dart` (sin Form): envolver columna en `Form(key: _formKey)` +
  `GlobalKey<FormState>`; nombre (L297) 'Ingresa tu nombre'; teléfono (L302)
  `validarTelefono(requerido: false)`; `_guardar()`: `validate()` al inicio.
- `specialist_onboarding_screen.dart` teléfono (L330-331) → `validarTelefono()`.
- `specialist_profile_screen.dart` (sin Form): envolver columna de Datos personales
  en `Form` + GlobalKey; helper `_field` + parámetro `validator`; nombre 'Ingresa tu
  nombre'; teléfono `validarTelefono()`; tarifa `double.tryParse` null o `<=0` →
  'Ingresa un monto válido mayor a 0'; `_guardarPersonal()`: `validate()` al inicio.
- `registrar_medico_regente_dialog.dart`: teléfono (L83) `validarTelefono(requerido:
  false)`; correo (L93) `validarCorreo(requerido: false)`.
- `admin_servicio_detail_screen.dart`: precio validator + `<= 0` → 'Debe ser mayor
  a 0'; duración + `<= 0` → 'Debe ser mayor a 0'.
- `admin_configuracion_screen.dart` `_editar` (L85-128): TextField → Form +
  TextFormField con validador según `item.tipoDato`: `NUMERIC` → double.tryParse,
  `BOOLEAN` → 'true'/'false' (case-insensitive), resto texto libre.

### 3. Seeds adaptados
- `20260814000100_seed_cuentas_matriz_prueba.sql`: emails `@test` → `@test.com`
  (12, en insert y todas las referencias `p.email=`/`IN`), teléfonos
  `+1 555 01NN` → `+15550100NN`, `LIKE '%@test'` → `LIKE '%@test.com'`.
- `20260814000200_backfill_metadata_auth_users.sql` y
  `20260814000300_fix_login_cuentas_seed.sql`: misma sustitución;
  `diag.%@test` → `diag.%@test.com`.
- Docs `docs/Pruebas manuales/*`: emails de la matriz → `@test.com`.
- `supabase/.temp/seed_passwords.txt` (local, gitignored): actualizar emails (no se
  commitea).

### 4. Migración remota `supabase/migrations/20260917000100_seeds_emails_telefonos_validos.sql`
Idempotente, aplicar por pooler:
- `auth.users.email` y `profiles.email` = `regexp_replace(email, '@test$', '@test.com')`
  WHERE `LIKE '%@test'`.
- `auth.identities.identity_data.email` ídem (gotrue).
- `profiles.phone` de la matriz por CASE → `+15550100NN`.

## Verificación

- [x] `flutter analyze` limpio.
- [x] `flutter test` (366 tests).
- [x] Pooler: 0 emails `LIKE '%@test'` sin punto (auth.users/profiles/identities);
      teléfonos de la matriz corregidos (`+15550100NN`, incluido `pac.activo` que
      tenía `+1 666 0108`). Quedan 2 cuentas de prueba ajenas a la matriz con
      teléfono inválido (`pac.nuevo.miguel@test.com`, `Luislira@test.com`) — no
      bloquean login, fuera de alcance.
- [ ] Manual en `flutter run -d chrome`: login con `admin@test.com`; validaciones
      de correo/teléfono en cada formulario.

## Notas

- Sin commit (regla del proyecto: preguntar antes).