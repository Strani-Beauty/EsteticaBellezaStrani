# Plan: Corrección de fallas críticas detectadas en pruebas manuales

**Fecha**: 2026-09-09
**Origen**: `Pruebas_manuales_App.xlsx`, hojas `01_auth_users` y `02_specialists` (fallas/bloqueos + comentarios UX aprobados). Se obvian los `Pendiente`.

## Decisiones de alcance (aprobadas por el usuario)
- SP-V-05 → Opción A: función `SECURITY DEFINER` `registrar_medico_regente` (RPC) + datasource con `.rpc()`.
- Comentarios UX a incluir: **SP-G-01/SP-G-03** (SnackBar en redirect por rol) y **AU-H-08/AU-H-09** (flechas de volver). **SP-H-06** (texto de contrato) NO incluido.
- AU-G-10 / AU-G-11 → solo paso de reproducción/verificación (el guard ya parece cumplir).
- SP-V-07 → problema real: "no permite resubida/reemplazo de documentos ya cargados (en caso de error)". No whitelist de formatos.

---

## 1. AU-V-08 — Cambio de contraseña no valida la actual (Alta)
- Causa: `ChangePasswordScreen._submit` solo envía `_newCtrl`; `changePassword` → `updateUser()` de GoTrue no verifica la contraseña actual. `changePassword` también lo usa `completePasswordReset` (sin contraseña vieja) → NO endurecer ruta compartida.
- Cambios:
  - `i_auth_repository.dart`: nuevo `changePasswordWithVerification({required currentPassword, required newPassword})`.
  - `auth_supabase_datasource.dart`: `updatePasswordWithCurrent` → `signInWithPassword(email: usuarioActual.email, password: current)` (falla `invalid_credentials`, ya mapeado) → si ok `updateUser(UserAttributes(password: new))`.
  - `auth_repository_impl.dart`: implementar con `Either`; `changePassword` intacto para reset.
  - `auth_cubit.dart`: nuevo método, patrón de perfil refrescado.
  - `change_password_screen.dart` `_submit`: pasar `_currentCtrl.text`.

## 2. SP-V-05 — Insert médico regente 42501 (Alta, Bloqueado)
- Causa confirmada: `createMedicoRegente` hace `insert(...).select().maybeSingle()` (RETURNING); tras endurecimiento `20260907` SELECT en `medicos_regentes` es solo-admin → especialista no puede leer fila → 42501.
- Fix:
  - Migración nueva `supabase/migrations/20260909_000001_registrar_medico_regente_rpc.sql`: `registrar_medico_regente(p_nombre, p_numero_licencia DEFAULT NULL, p_telefono DEFAULT NULL, p_correo DEFAULT NULL)` SECURITY DEFINER, inserta `estado='PENDIENTE', activo=false`, retorna jsonb `{id,nombre,numero_licencia,estado,activo}` (sin contacto). `REVOKE EXECUTE ... FROM anon, public; GRANT EXECUTE ... TO authenticated`. Idempotente.
  - Datasource `createMedicoRegente` → `_client.rpc('registrar_medico_regente', {...})`, parsear con `MedicoRegenteModel.fromJson`.
  - Aplicar migración con `supabase db push`; verificar policies con pg (solo lectura).

## 3. SP-V-07 — No permite resubir/reemplazar documentos (Media)
- Causas: (a) `uploadDocument`/`registerDocument` del cubit retornan en silencio si el estado ya no es `SpecialistsLoaded` (tras un error que emitió `SpecialistsError` y descartó datos) → toques no responden; (b) un PENDIENTE del mismo tipo no se puede corregir: la tile no muestra botón y el trigger `proteger_revision_documento` bloquea apilar otro PENDIENTE.
- Cambios:
  - Cubit: en upload/register no descartar estado cargado al fallar — conservar snapshot `SpecialistsLoaded` y exponer el mensaje (revisar `copyWith`/consumidores).
  - Datasource `registerDocumento`: si existe PENDIENTE activo de `(especialista_id, tipo_documento)` → `UPDATE` esa fila (`url_archivo`, `nombre_archivo`, `version_documento+1`, `updated_at`); si APROBADO → error amigable; si no → INSERT PENDIENTE. Permitido por trigger/RLS.
  - UI `specialist_documents_screen.dart`: `_DocumentoTile` estado `enRevision` → acción secundaria "Reemplazar" reusando `_seleccionarArchivo` con tipo forzado. Considerar borrar storage viejo (bucket público, path `<espId>/<epoch>.ext`).
  - Sin migración.

## 4. AU-G-10 / AU-G-11 — Verificación de rutas (Alta/Media)
- El guard ya parece cumplir. Solo reproducción en web (paciente desactivado fuera de whitelist; sesión nula en públicas). Corregir solo si se confirma bug.

## 5. Comentarios UX aprobados
- **SP-G-01/03**: SnackBar informativa al redirigir por rol. `MaterialApp` con `scaffoldMessengerKey` global; `resolveAuthRedirect`/`_redirectByRole` muestra mensaje.
- **AU-H-08/09**: `leading` explícito en `profile_screen.dart` (línea 51) y `specialist_profile_screen.dart` (línea 211). Confirmar destino de flecha.

## Verificación
- `flutter analyze`, `flutter test`.
- Aplicar migración RPC y verificar RLS en remoto.
- Reproducción manual web: AU-V-08, SP-V-05, SP-V-07, AU-G-10/11, snackbars, flechas.

## Archivos a tocar
- Migración nueva (1 SQL).
- auth: i_auth_repository, auth_supabase_datasource, auth_repository_impl, auth_cubit, change_password_screen.
- specialists: specialists_supabase_datasource, specialists_cubit, specialist_documents_screen.
- Perfiles: profile_screen, specialist_profile_screen.
- Router/app: app.dart (scaffoldMessengerKey), app_routes/route_guard.

## Checkpoints
- [ ] Plan persistido
- [ ] AU-V-08
- [ ] SP-V-05 (migración + datasource + push)
- [ ] SP-V-07
- [ ] SP-G-01/03
- [ ] AU-H-08/09
- [ ] flutter analyze + test
- [ ] Migración remota + verificación AU-G-10/11