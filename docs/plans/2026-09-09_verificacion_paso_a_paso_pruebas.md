# Guía de verificación paso a paso — Pruebas manuales (hojas 01 y 02)

**Fecha**: 2026-09-09
**Origen**: `Pruebas_manuales_App.xlsx`, hojas `01_auth_users` y `02_specialists` — fallas corregidas y pendientes.
**App en vivo**: https://esteticaybellezastrani.web.app
**Credenciales**: TODAS las cuentas `*@test` usan la contraseña `Test1234!`.

## Alcance aprobado
- Validar los fixes ya desplegados (Bloque A).
- Recorrer pendientes de `01_auth_users` (Bloque B) y `02_specialists` SP-E/SP-N/SP-S (Bloques C/D).
- Incluir fix de código nuevo: **SP-S-03** (esperar `solicitarVerificacion` antes de navegar al home).

## Estado de cuentas en Supabase (ref hhyjremkguvphmjuaazp)
| Email | Rol | activo | Especialista |
|---|---|---|---|
| admin@test | Administrador | true | — |
| esp.aprobado@test | Especialista | true | APROBADO (docs y regente OK) |
| esp.bloqueado@test | Especialista | true | BLOQUEADO |
| esp.desactivado@test | Especialista | false | APROBADO |
| esp.rechazado@test | Especialista | true | RECHAZADO |
| esp.revision@test | Especialista | true | EN_REVISION (sin docs) |
| espec.nuevo@test | Especialista | true | null (sin fila) |
| pac.activo@test | Paciente | true | — |
| pac.desactivado@test | Paciente | false | — |
| pac.nuevo@test | Paciente | false | — |

---

## Bloque A — Validar correcciones desplegadas (commit 7650bc5/3da05e9)

### A1 · AU-V-08 — Cambio de contraseña valida la actual
Usuario: `pac.activo@test` / `Test1234!`
Pasos: Perfil → Cambiar contraseña.
1. Actual `ClaveErronea123`, nueva `NuevaClave99`, confirmar → **Esperado (vista)**: snackbar roja *"Credenciales inválidas. Verifica tu correo y contraseña."* y NO cambia. **Supabase**: la contraseña sigue siendo la anterior.
2. Ahora actual `Test1234!`, nueva `NuevaClave99` → **Esperado**: *"Contraseña actualizada correctamente."* y vuelve a /profile. **Supabase**: cambió.
3. Restaurar: actual `NuevaClave99`, nueva `Test1234!`.

### A2 · SP-V-05 — Registrar médico regente (sin 42501)
Usuario: `espec.nuevo@test` / `Test1234!` (sin fila especialista → entra al onboarding).
Pasos: `/specialist` → onboarding paso 1 (licencia, ej. `TX-LIC-NVO1`) → paso 2 → *"Registrar nuevo médico regente"* → Nombre `Dra. Regente Prueba`, Licencia `TX-REG-9001` (teléfono/correo opcionales) → Guardar.
**Esperado (vista)**: NO aparece error 42501/policy. **Supabase**: fila nueva en `medicos_regentes` con `estado='PENDIENTE'`, `activo=false`.

### A3 · SP-V-04 — Dropdown solo regentes activos
Misma sesión, onboarding paso 2, abrir selector de médico regente.
**Esperado (vista)**: solo aparece *Dr. Regente Test* (ACTIVO); *Dra. Regente Prueba* no aparece (PENDIENTE). **Supabase**: la vista `medicos_regentes_publico` (sin teléfono/correo) filtrada `activo=true`.

### A4 · SP-V-07 — Reemplazar documento en revisión
Usuario: `esp.revision@test` / `Test1234!` (EN_REVISION sin docs).
Pasos: `/specialist` → pantalla Documentos → subir identificación (PDF/PNG) → queda *"En revisión"* → tocar **Reemplazar** en esa fila → subir otro archivo.
**Esperado (vista)**: reemplaza sin error y sigue *"En revisión"*; tras forzar un error de red, Adjuntar/Reemplazar siguen respondiendo (la UI no queda muerta). **Supabase**: UNA sola fila `documentos_especialista` tipo IDENTIFICACION con `version_documento` 1→2 y `updated_at` renovado (no una segunda fila PENDIENTE).

### A5 · SP-G-01 / SP-G-03 — SnackBar al redirigir por rol
- G-01: login `pac.activo@test`, navegar a `.../specialist`. **Esperado**: termina en `/services` + snackbar *"No eres especialista. Pasa a Servicios."*.
- G-03: login `esp.aprobado@test`, navegar a `.../admin`. **Esperado**: termina en el panel de especialista + snackbar *"No eres administrador. Accede a tus datos de especialista."*.

### A6 · AU-H-08 / AU-H-09 — Flecha de volver
- H-08: `pac.activo@test`, abrir Perfil desde el menú → flecha ← en AppBar → **Esperado**: vuelve a Servicios.
- H-09: `esp.aprobado@test`, *Mi información* → flecha ← → **Esperado**: vuelve al panel de especialista.

---

## Bloque B — Pendientes `01_auth_users`

### B1 · AU-G-06 / G-09 / G-10 / G-11 — Rutas (cubiertas por tests)
Cubiertas por `test/route_guard_test.dart` (verde). Verificación manual opcional:
- G-11 (sin sesión, ventana incógnito): abrir `/`, `/services`, `/face-map-questionnaire`, `/auth/reset-password` → **Esperado**: accesibles, sin redirect.
- G-10: login `pac.desactivado@test`, ir a `/profile` → **Esperado**: redirige a `/complete-profile`.

### B2 · AU-E-03 — Aviso cuenta pendiente
Usuario: `pac.nuevo@test` / `Test1234!`.
Pasos: login. **Esperado (vista)**: cae en `/complete-profile` con su checklist/aviso; sin error. **Supabase**: `profiles.activo=false`, sin `pacientes` completos.

### B3 · AU-E-04 / AU-H-10 — Recuperación de contraseña (requiere SMTP)
Usuario: `pac.activo@test`.
Pasos: en login → *"¿Olvidaste tu contraseña?"* → abrir el enlace de recuperación del correo → pantalla `/auth/reset-password` → nueva `NuevaClave88` + confirmar.
**Esperado (vista)**: *"Contraseña actualizada correctamente."* y pide re-login (NO queda con sesión iniciada). **Supabase**: contraseña cambiada.
Restaurar a `Test1234!` después. Si el correo nunca llega → marcar AU-H-10/AU-E-04 como *"no ejecutable (requiere SMTP)"*.

### B4 · AU-N-03 / AU-N-04 / AU-N-05 · AU-S-03
- AU-N-03 (`.env` incompleto): verifica el asistente localmente en modo build (`AppEnv.validate()` lanza `StateError` si faltan SUPABASE_URL/ANON_KEY). No aplica a web.
- AU-N-04/05 (FCM): requieren binario Android/local. Preguntar si se prueba en Android.
- AU-S-03 (createProfile tolerante): verificación local en modo build: login con fila de `profiles` ya existente → upsert sin crash.

---

## Bloque C — SP-E verificación de estados (el orden importa: encadena estados)

### C1 · SP-E-01 — Redirect sin perfil (Crítica)
Usuario: `espec.nuevo@test`. Ir a `/specialist`. **Esperado (vista)**: redirige al onboarding completo (paso 1). **Supabase**: sin cambios.

### C2 · SP-E-02 — Redirect sin datos profesionales (Alta)
Usuario: `esp.revision@test`. Ir a `/specialist`. **Esperado (vista)**: redirige al onboarding al paso de datos profesionales (tiene fila pero sin médico regente/especialidades).

### C3 · SP-E-03 — Redirect por documentos faltantes (Alta)
Usuario: `espec.nuevo@test` tras completar onboarding (o cuenta con docs faltantes y no rechazada). **Esperado (vista)**: se abre la pantalla de Documentos.

### C4 · SP-E-04 — Rechazado NO es redirigido (Alta)
Usuario: `esp.rechazado@test`. Ir a `/specialist`. **Esperado (vista)**: se queda en el panel (excepción: no va a documentos) para poder leer el motivo.

### C5 · SP-E-05 — Motivo de rechazo visible (Alta)
Misma sesión que C4. **Esperado (vista)**: tarjeta de verificación con badge rojo RECHAZADO, *"Motivo: Documentación ilegible. Reenvíe licencia vigente."* en rojo y botón **Corregir y reenviar**.

### C6 · SP-E-06 — Reenvío tras rechazo (Crítica)
Desde C5: **Corregir y reenviar** → Documentos → corregir/re-subir licencia → Continuar → vuelve al panel. **Supabase**: `especialistas.estado_verificacion` RECHAZADO → EN_REVISION.

### C7 · SP-E-07 — Documento rechazado exige re-subida (Alta)
Producción: el admin rechaza el documento recién enviado de `esp.revision@test` (o `esp.rechazado@test`). Luego el especialista entra a `/specialist`. **Esperado (vista)**: el panel vuelve a exigir ese documento (cuenta como no subido); re-subir crea una fila nueva PENDIENTE. **Supabase**: nueva fila `documentos_especialista` PENDIENTE del tipo rechazado.

### C8 · SP-E-08 — Bloqueado (Alta)
Usuario: `esp.bloqueado@test`. Ir a `/specialist`. **Esperado (vista)**: badge rojo BLOQUEADO + *"Motivo: Cuenta bloqueada por incumplimiento contractual."* visible; NO aparecen tarjetas Mapa/Mis citas/Liquidaciones. **Supabase**: `estado_verificacion='BLOQUEADO'`.

### C9 · SP-E-09 — Transiciones válidas (Crítica)
Usuario: `admin@test`, panel de verificación de admin.
- Aprobar a `esp.revision@test`. **Esperado**: EN_REVISION → APROBADO (ok).
- Bloquear a `esp.aprobado@test`. **Esperado**: APROBADO → BLOQUEADO (ok).
- Intentar transiciones prohibidas (p.ej. degradar APROBADO→PENDIENTE) → **Esperado**: error del trigger; solo el rol autorizado dispara cada transición.

### C10 · SP-E-10 — Heartbeat de presencia (Media)
Usuario: `esp.aprobado@test`. Dejar el panel abierto 60+ segundos. **Supabase**: `en_linea=true` y `ultima_conexion` actualizándose ~cada 60s.

### C11 · SP-E-11 — Offline al pausar (Media, Android)
Enviar la app a segundo plano → **Esperado**: se marca offline al pausar; en `detached` se limpia la sesión local.

---

## Bloque D — SP-N y SP-S

### D1 · SP-N-01/02/03 — Sin red (Alta/Media)
Simular sin red (DevTools → Network → Offline, o modo avión):
- N-01: `espec.nuevo@test`, enviar onboarding → **Esperado**: error controlado con mensaje; sin crash; la UI sigue usable.
- N-02: subir documento → **Esperado**: error controlado; SIN fila huérfana `documentos_especialista` con URL inválida.
- N-03: geocodificar con la edge function caída → **Esperado**: fallback o error claro; el usuario aún puede elegir el punto en el mapa.

### D2 · SP-N-04 — Dashboard con tablas vacías (Alta)
Usuario: `espec.nuevo@test` (sin fila especialista). **Esperado (vista)**: dashboard carga en estado cargado con colecciones vacías; sin errores null.

### D3 · SP-N-05 — createSpecialist duplicado (Media)
`espec.nuevo@test`, doble toque en *"Solicitar verificación"* → **Esperado**: sin crash; la violación de unicidad 23505 se tolera y recarga el dashboard.

### D4 · SP-S-01 — Licencia persistente (Alta)
`espec.nuevo@test`, en el home sin perfil: teclear licencia y provocar rebuild (navegar/volver, pull-to-refresh) → **Esperado**: el texto persiste (controller persistente). RESUELTO (2026-08-14).

### D5 · SP-S-02 — Botón con licencia vacía (Alta)
`espec.nuevo@test`, campo vacío + *"Solicitar verificación"* → **Esperado (vista)**: snackbar *"Ingresa el número de licencia para solicitar la verificación."* y NO se crea fila de especialista. RESUELTO (2026-08-14).

### D6 · SP-S-03 — Carrera de `solicitarVerificacion` (Alta) ← FIX INCLUIDO
Tras el fix (esperar la solicitud antes de navegar): completar documentos y tocar **Continuar** → **Esperado (vista)**: el panel muestra EN_REVISION de inmediato (sin PENDIENTE obsoleto intermedio). **Supabase**: `estado_verificacion='EN_REVISION'`.

### D7 · SP-S-04 — version_documento incrementa (Media)
Re-subir el mismo tipo dos veces vía **Reemplazar** → **Supabase**: `version_documento` 1→2→3 en la misma fila.

### D8 · SP-S-05 — Disponibilidad sin ubicación (Media)
`esp.aprobado@test`, activar *disponible* sin ubicación guardada → **Esperado**: no rompe; el mapa después no muestra punto propio.

---

## Verificaciones en Supabase (read-only) que ejecuto tras tus pasos
- A2: fila `Dra. Regente Prueba` con `estado='PENDIENTE'`, `activo=false`.
- A4: `version_documento` 1→2 en una sola fila (sin segunda PENDIENTE).
- C6/C8/C9/D6: `estado_verificacion` resultante.
- D1(N-02): sin filas huérfanas.
- D7: `version_documento` 1→2→3.

## Checkpoints
- [ ] Guía persistida
- [ ] Fix SP-S-03 implementado (`_continuar` async + await)
- [ ] `flutter analyze` y `flutter test` en verde
- [ ] Reporte al usuario para ejecución manual
