# Plan: Re-probar auth (doc 01) — push de migraciones, backfill de metadata y SMTP

| | |
|---|---|
| **Fecha** | 2026-08-14 |
| **Origen** | Continuación de `2026-08-14_reparar_flujo_auth_tests_manuales.md`. Fase 2 (código) ya commiteada (`728c4d8`); quedan pendientes aplicar migraciones y re-probar. |
| **Estado** | APROBADO por el usuario (2026-08-14). |
| **Alcance** | Solo re-pruebas de auth_users (doc 01). Hojas 02-04 del Excel fuera de alcance. |

## Contexto verificado en esta PC

- `supabase migration list` → `20260814000000` y `20260814000100` **pendientes** (Local only); las ~20 anteriores están aplicadas en remoto.
- Fixes de Fase 2 confirmados en código: `phone` en `signUp`/`createProfile` (`auth_supabase_datasource.dart:43,155,173`), `resendConfirmationEmail` (datasource→repo→cubit→estado `AuthConfirmationResent`), botón "Reenviar correo" (`login_screen.dart:542-552`).
- El trigger `handle_new_user` ya existe desde `20260804000100`; el backfill de la 14000000 cubre cuentas creadas a mano.
- Resultados Excel hoja 01: AU-H-01 Pasa, AU-H-02 Falla (phone NULL + sin provider), AU-H-03 Falla (no llega correo). Resto sin ejecutar.

## Fase 1 — Base de datos

### 1.1 Migraciones aplicadas (2026-08-14, en esta PC)

1. `20260814000200_backfill_metadata_auth_users.sql` — backfill `raw_app_meta_data` (providers email), backfill de `phone` en metadata desde `profiles` y sincronización inversa; cleanup de cuentas matriz rotas (unconfirmed, sin provider) para que AU-H-02 sea re-probable.
2. `20260814000050_corregir_fk_medico_regente.sql` — **nueva** (encontrada al aplicar): la BD viva tenía la FK errónea `especialistas_medico_regente_id_fkey` → `profiles(id)` (creada a mano) además de la correcta `fk_especialistas_medico_regente` → `medicos_regentes(id)`. Rompía el seed Y el onboarding real (la app escribe `medico_regente_id` en `createSpecialist`). La migración elimina cualquier FK sobre esa columna que apunte a `profiles`.

### 1.2 Ajustes al seed `20260814000100_seed_cuentas_matriz_prueba.sql`

- `SET search_path = public, extensions;` tras `CREATE EXTENSION pgcrypto` (la conexión de `db push` no resolvía `crypt`/`gen_salt` → error `gen_salt does not exist`).
- Los triggers `trg_proteger_verificacion_especialista` y `trg_proteger_revision_documento` se **desactivan** durante el seed y se **reactivan** al final (tratan la sesión de migración como no-admin, `auth.uid() = NULL`, y bloqueaban insertar los estados finales de la matriz).

### 1.3 Aplicado

```powershell
supabase db push --yes
```

OK — las 4 migraciones (14000000, 14000050, 14000100, 14000200) aplicadas y registradas (verificado con `supabase migration list`).

### 1.4 Verificación post-push

```sql
SELECT email, role, activo, phone FROM public.profiles ORDER BY email;
SELECT email, estado_verificacion FROM public.profiles p
LEFT JOIN public.especialistas e ON e.usuario_id = p.id
WHERE p.role = 'Especialista' ORDER BY p.email;
```

Nota: sin Docker/psql en esta máquina no se pudo volcar datos; la verificación de filas queda para el SQL Editor (Fase 2/3).

### 1.5 Fix RLS: recursión infinita 42P17 (descubierto en la re-prueba)

Al re-probar por REST se detectó que **cualquier** query a `profiles` devolvía
500 `{"code":"42P17","message":"infinite recursion detected in policy for relation \"profiles\""}`
— era la causa raíz de AU-H-04/05/06 ("Perfil no encontrado, contacta a soporte")
y rompía el panel admin de usuarios (AUU-H-01).

Cadena del bucle (PostgreSQL detecta recursión transitiva entre policies):
`profiles_especialista_cita` (subquery inline → `citas`/`solicitudes`/`especialistas`)
→ policies de esas tablas con `(SELECT p.role FROM profiles p WHERE p.id = auth.uid())`
→ re-entrada en RLS de `profiles` → bucle.

Fix (mismo patrón que `is_administrador()`): envolver la lógica en un helper
`SECURITY DEFINER` que corre como `postgres` (dueño, elude RLS). La policy queda
como llamada a función sin subquery → se corta la cadena.

- `20260814000600_fix_profiles_especialista_cita.sql` — helper `public.especialista_tiene_cita_con(target_profile_id UUID)` + policy `profiles_especialista_cita` → `USING (public.especialista_tiene_cita_con(id))`. Elimina la función de diagnóstico `_diag_profiles()`.
- `20260814000700_fix_pacientes_especialista_cita.sql` — mismo bucle análogo en `pacientes` (`pacientes_especialista_cita` → `solicitud_paciente_own` con subquery inline a `pacientes`); reutiliza el mismo helper con `USING (public.especialista_tiene_cita_con(usuario_id))`.

Verificación REST (token por cuenta, sin Docker/psql):
- `pac.activo@test` → `profiles` y `pacientes` devuelven solo su propia fila (200).
- `esp.aprobado@test` → `profiles` propia + `especialistas` con `profiles!especialistas_usuario_id_fkey` (200).
- `admin@test` → `profiles` devuelve los 37 perfiles (200), `especialistas` todos (200), `pacientes` [] (solo `own_paciente_access`; sin policy de admin sobre `pacientes`).

Nota: el embed `especialistas/profiles` es ambiguo (2 FKs) — la app usa `profiles!especialistas_usuario_id_fkey`.

## Fase 2 — Config dashboard (manual, en la otra PC)

1. Authentication → Email: mantener **Confirm email ON** y **configurar SMTP con Gmail/Google Workspace** (host `smtp.gmail.com`, puerto 465/587, App Password). Guía completa en `docs/2026-08-14_config_email_smtp.md`. Sin SMTP, los correos no se entregan (bloquea AU-H-03).
   - Alternativa de prueba sin SMTP: Authentication → Logs / Emails → copiar el enlace de confirmación generado.
2. Authentication → URL Configuration: Site URL y Redirect URLs correctos (`http://localhost` para web, deep link `com.example.esteticaybellezastrani://`).

## Fase 3 — Re-pruebas (solo doc 01)

1. AU-H-02: re-registrar con la cuenta limpia o un email nuevo; verificar en BD que `profiles.phone` y la metadata quedan con el valor.
2. AU-H-03: confirmar con SMTP o con el enlace de Authentication → Logs.
3. Re-ejecutar el resto de casos del doc 01 (AU-H-04…12, AU-V-01…12, AU-G-01…11, AU-E-01…05, AU-N-01…06, AU-S-01…03).
4. Actualizar la hoja `01_auth_users` del Excel (`Pruebas_manuales_01-04.xlsx`) y el resumen.

## Seguimiento (fuera de este ciclo)

- Versionar en una migración `disponibilidad_especialista`, `ubicaciones_especialista` y `contratos` (necesarias para docs 02/09).
- Ejecutar hojas 02-04 del Excel.

## Checklist

- [x] Plan persistido en `docs/plans/` (este archivo).
- [x] Migraciones `20260814000200_backfill_metadata_auth_users.sql` y `20260814000050_corregir_fk_medico_regente.sql` creadas.
- [x] `supabase db push` aplicado (14000000 + 14000050 + 14000100 + 14000200).
- [x] Verificación post-push (perfiles + matriz especialistas) — vía REST en esta PC (sin SQL Editor): login OK de las 12 cuentas matriz; `profiles`/`pacientes` sin recursión 42P17 tras los fixes 14000600/14000700.
- [ ] SMTP Gmail/Workspace configurado en el dashboard o alternativa Logs (`docs/2026-08-14_config_email_smtp.md`).
- [ ] Re-pruebas doc 01 + Excel actualizado.
- [ ] Commit + push (mensaje en español, confirmado por el usuario).
