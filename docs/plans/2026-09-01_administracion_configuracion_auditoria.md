# Plan: Administración, Configuración y Auditoría

| | |
|---|---|
| **Fecha** | 2026-09-01 |
| **Estado** | APROBADO por el usuario (2026-09-01) |
| **Proyecto Supabase** | `hhyjremkguvphmjuaazp` |
| **Decisiones tomadas** | (1) RBAC **completo en runtime**: función `tiene_permiso(codigo)` + seeds de `permisos`/`rol_permisos` + gating de tiles del dashboard por permisos; `is_administrador()` se mantiene como super-rol. (2) Auditoría en **todas las tablas sensibles** (especialistas, documentos_especialista, liquidaciones_especialistas, pagos_especialistas, profiles, roles, permisos, rol_permisos, configuracion_sistema, citas, solicitudes, transacciones, pagos, tratamientos). (3) Notificaciones de pago **in-app + push FCM** (patrón `trg_notificar_cambio_estado_cita` con pg_net→`send-push`). |

## Contexto

El panel administrativo ya está implementado (rutas `/admin`, RLS admin, gestión de usuarios, verificación de licencias, roles/permisos gestionables, configuración, conciliación, liquidaciones, notificaciones). La auditoría identificó:

- **No existe auditoría**: ni tabla, ni RPC, ni UI. `historial_estados` actúa de facto como log de transiciones pero **sin policy de SELECT admin** (el admin no puede leerlo).
- **RBAC esqueletizado**: `permisos`/`rol_permisos` sin seeds ni lógica; la autorización real es `profiles.role == 'Administrador'` (string). El catálogo se gestiona pero no se aplica.
- **2 huecos de seguridad**: `admin_resumen_kpis()` y `eliminar_servicio()` son SECURITY DEFINER **sin chequeo admin** + GRANT authenticated → cualquier usuario autenticado los ejecuta.
- **Faltan notificaciones de eventos de pago** (depósito confirmado, saldo pagado, liquidación pagada/generada).
- **Sin pantalla dedicada de gestión de pacientes** (solo activar/desactivar en lista de usuarios).

## Actividades → implementación

### A. Migración `supabase/migrations/20260901000100_admin_seguridad_auditoria.sql`

- [x] A1. `admin_resumen_kpis()`: añadir `IF NOT public.is_administrador() THEN RETURN json_build_object('error','NO_AUTORIZADO'); END IF;` al inicio (SECURITY DEFINER, CREATE OR REPLACE).
- [x] A2. `eliminar_servicio(uuid)`: añadir `IF NOT public.is_administrador() THEN RETURN json_build_object('ok',false,'motivo','NO_AUTORIZADO'); END IF;` (CREATE OR REPLACE).
- [x] A3. Policy `historial_estados_admin_select` ON `historial_estados` FOR SELECT TO authenticated USING `public.is_administrador()`.
- [x] A4. Tabla `auditoria` (id uuid PK gen_random_uuid, usuario_id uuid REFERENCES profiles ON DELETE SET NULL, accion text, entidad text, entidad_id text, detalle jsonb, fecha timestamptz default now()) + índices (entidad, fecha DESC, usuario).
- [x] A5. Función `registrar_auditoria(p_usuario_id uuid, p_accion text, p_entidad text, p_entidad_id text, p_detalle jsonb)` SECURITY DEFINER (INSERT en auditoria; GRANT authenticated).
- [x] A6. Trigger genérico `auditar_entidad()` (AFTER INSERT/UPDATE/DELETE) con filtro por columnas sensibles vía TG_ARGV; aplicado con `trg_auditoria_*` en: profiles, especialistas, documentos_especialista, liquidaciones_especialistas, pagos_especialistas, roles, permisos, rol_permisos, configuracion_sistema, citas, solicitudes, transacciones, pagos, tratamientos.
- [x] A7. RLS en `auditoria`: `auditoria_admin_select` (SELECT admin-only).

### B. RBAC en runtime (migración `20260901000200_rbac_permisos_runtime.sql`)

- [x] B1. Función `tiene_permiso(codigo text)` SECURITY DEFINER con cache por sesión keyed por usuario (`'app.mis_permisos_' || regexp_replace(auth.uid()::text, ...)`) para evitar N+1 y el bug de herencia entre usuarios.
- [x] B2. Seeds idempotentes de `permisos` (13 códigos `admin.*`: dashboard, usuarios, pacientes, cuestionario, catalogo, licencias, configuracion, conciliacion, auditoria, roles, comisiones, especialidades, medicos).
- [x] B3. Seeds de `rol_permisos` para el rol Administrador (todos los `admin.%`).
- [x] B4. Policy de lectura: `permisos_admin_all`/`rol_permisos_admin_all` ya existen (20260822000100). Sin cambios.

### C. Capa Dart RBAC

- [x] C1. `lib/features/admin_config/domain/usecases/get_mis_permisos.dart`: `GetMisPermisos` → `Either<Failure, List<String>>` vía RPC `mis_permisos()`.
- [x] C2. `admin_config_supabase_datasource.dart`: `fetchMisPermisos()` — RPC `mis_permisos()` (SECURITY DEFINER, devuelve `text[]`); RPC registrado en `app_constants.dart` (`rpcMisPermisos`).
- [x] C3. `AdminDashboardCubit` carga `misPermisos` junto a KPIs; `AdminDashboardLoaded` expone `permisos: Set<String>`.
- [x] C4. Gatear tiles del dashboard con helper `bool _tiene(String codigo)` (fallback: si no hay permisos cargados muestra todo; el super-rol Administrador tiene los 13 seeds).

### D. Notificaciones de pago (migración `20260901000300_notificaciones_pagos.sql`)

- [x] D1. Helper `notificar_usuario_push(uuid, titulo, mensaje, tipo, data)` SECURITY DEFINER: INSERT in-app + push FCM vía pg_net→`send-push` (config `push_notifications`/`edge_function_base_url`/`anon_key`).
- [x] D2. `confirmar_pago_saldo`: notifica al paciente «Saldo pagado / tratamiento completado» (tipo PAGO).
- [x] D3. `registrar_pago_especialista`: notifica al especialista «Liquidación pagada» con monto (tipo LIQUIDACION).
- [x] D4. `generar_liquidaciones`: dentro del loop, notifica al especialista «Nueva liquidación disponible» (tipo LIQUIDACION).
- [x] D5. Implementado dentro de los RPCs redefinidos (confirmar_deposito_solicitud, confirmar_pago_saldo, registrar_pago_especialista, generar_liquidaciones) con el patrón `notificar_usuario_push`.

### E. Gestión de pacientes (Act 2)

- [x] E1. `admin_users_supabase_datasource.dart`: `fetchPacientesAdmin()` — select `pacientes(id, usuario_id, activo, profiles(full_name, email, phone, activo))`.
- [x] E2. Usecase `get_pacientes.dart` + `PacienteAdminModel`/`PacienteAdminEntity` + impl repositorio.
- [x] E3. Pantalla `admin_pacientes_screen.dart` (listar + activar/desactivar vía `setActivo` con `canToggle`) + ruta `/admin/pacientes` + tile en dashboard (permiso `admin.pacientes`).
- [x] E4. Cubit `AdminPacientesCubit` + DI.

### F. UI auditoría

- [x] F1. `admin_auditoria_screen.dart`: filtros (entidad dropdown, accion dropdown, rango de fechas) + lista cronológica con detalle expandible (usuario, entidad, acción, id, JSON del cambio).
- [x] F2. Capa: `AuditoriaSupabaseDataSource.fetchAuditoria(filtros)` + `AuditoriaFiltros` + `GetAuditoria` usecase + `AdminAuditoriaCubit` + DI (módulo nuevo `lib/features/auditoria/`).
- [x] F3. Ruta `/admin/auditoria` + tile en dashboard (permiso `admin.auditoria`).

### G. Verificación

- [x] G1. `flutter analyze` 0 issues + `flutter test` 366/366.
- [x] G2. Migraciones aplicadas al remoto (00100→00200→00300) y verificadas: policies `auditoria_admin_select`/`historial_estados_admin_select`, 14 triggers `trg_auditoria_*`, funciones `mis_permisos`/`tiene_permiso`/`registrar_auditoria`/`auditar_entidad`/`notificar_usuario_push`, 17 permisos seed + 13 rol_permisos de Administrador, RPCs blindados con `is_administrador()`.
- [x] G3. **Pruebas de control (11/11 PASS)** ejecutadas contra el remoto vía RLS simulado
  (`SET LOCAL ROLE authenticated` + `set_config('request.jwt.claims', …)`, transacción con
  `ROLLBACK`, script `verify_control.js` en el workdir de pgcheck). Resultado por control:
  1. Admin accede al panel — `is_administrador()=true`; especialista `false`.
  2. Usuarios sin permiso no acceden a funciones admin — `tiene_permiso(admin.usuarios)=false`;
     `admin_resumen_kpis()` → `{error:'NO_AUTORIZADO'}`; `eliminar_servicio(uuid)` → `{ok:false,'NO_AUTORIZADO'}`.
  3. Roles con permisos diferenciados — rol de prueba con solo `admin.auditoria` → `mis_permisos()=["admin.auditoria"]`;
     rol Administrador → 13 permisos.
  4. Activar/desactivar usuarios — admin UPDATE profiles OK (41 perfiles); especialista UPDATE a otro → 0 filas.
  5. Consultar especialistas y pacientes — admin lee 13 especialistas y 22 pacientes.
  6. Configuraciones administrables — admin lee 19 claves y edita; especialista ve 0 filas.
  7. Notificaciones registradas — 7 existentes; admin INSERT OK.
  8. Eventos importantes generan notificaciones — los 4 RPCs de pago llaman `notificar_usuario_push`.
  9. Operaciones críticas generan auditoría — admin lee 30 filas; 14 triggers `trg_auditoria_*` activos; especialista ve 0 filas.
  10. Auditoría identifica usuario/fecha/operación — `accion`, `entidad`, `usuario_id`, `fecha`, `detalle` presentes.
  11. Permisos en interfaz y en datos — `tiene_permiso(admin.auditoria)`: admin `true`, especialista `false`;
      interfaz gateada por `_tiene()` + route guard `isAdmin`.
  (La prueba manual en la UI con `admin@test` queda para la sesión interactiva del usuario.)
- [ ] G4. Prueba funcional del panel completo (navegación, permisos, config, notificaciones, auditoría).

## Notas

- `is_administrador()` se mantiene como super-rol; `tiene_permiso()` complementa para gating fino de UI/acciones.
- Auditoría: los triggers corren como SECURITY DEFINER (owner) e insertan sin violar RLS; la lectura es solo admin.
- La tabla `auditoria` NO debe auditarse a sí misma (evitar bucle).
- Patrón de errores `Either<Failure,T>` y cubits inyectando usecases por nombre.
- Los RPCs `notificar_*` de push ya existen (send-push); reutilizar `notificar_solicitud_asignada_push` como referencia.

## Complemento (misma fecha) — fix de caché en `tiene_permiso`

Durante la verificación remota se detectó que la caché de `tiene_permiso` no estaba
keyed por usuario: en una misma transacción el especialista heredaba los permisos del
admin (`tiene_permiso('admin.auditoria')` daba `true`). Se corrigió en la migración
`20260901000200` con clave de caché por sesión y por usuario
(`'app.mis_permisos_' || regexp_replace(auth.uid()::text, '[^a-z0-9_]', '', 'g')`;
los nombres GUC solo admiten `[a-z0-9_]` y un uuid con guiones produce
`invalid configuration parameter name`). Migración re-aplicada al remoto y verificada:
admin → 13 permisos; especialista → `mis_permisos()=[]` y `tiene_permiso(admin.*)=false`.