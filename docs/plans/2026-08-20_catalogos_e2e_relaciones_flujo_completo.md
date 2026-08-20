# Plan: E2E Catálogo — Actividades 12 y 13 (relaciones y flujo completo)

| | |
|---|---|
| **Fecha** | 2026-08-20 |
| **Estado** | APROBADO por el usuario (2026-08-20) |
| **Proyecto Supabase** | `hhyjremkguvphmjuaazp` |
| **Plan de origen** | `docs/plans/2026-08-19_catalogo_servicios_semana6.md` (Act. E2 — Actividades 12 y 13 pendientes) |

## Contexto

El catálogo de servicios quedó implementado y verificado a nivel de código el 2026-08-19
(commit `3cf9de9`; `flutter analyze` 0 issues; `flutter test` 130/130; migración
`20260819000000_catalog_admin_rls_relaciones.sql` aplicada al remoto). Quedaron pendientes
las **pruebas manuales E2E (Actividades 12 y 13)** del plan de semana 6, que se ejecutan hoy
siguiendo el mismo formato que las E2E de compliance (2026-08-18) y salud del paciente
(2026-08-19).

- **Act. 12** — Probar con diferentes servicios, especialidades y requisitos que las
  relaciones (`servicio_especialidades`, `servicio_cuestionarios`, flags del servicio)
  funcionan correctamente.
- **Act. 13** — Validar el flujo completo desde la creación de un servicio hasta su
  visualización y selección por un paciente elegible.

## Estado real verificado en BD (2026-08-20, lectura vía PostgREST anon)

- 40 migraciones aplicadas al remoto (Local == Remote).
- 19 servicios **activos**: 12 con "Cuestionario de Salud" **v2 (id=5) obligatorio** +
  `requiere_face_map=true`; 1 con `requiere_face_map=true` **sin cuestionario**
  (Desintoxicación Facial Profunda `ced81223`); 6 sin requisitos ni face map
  (Contorno Corporal, Radiofrecuencia, etc.).
- `servicio_especialidades` = 31 filas; `servicio_cuestionarios` = 18 filas.
- 5 servicios **inactivos** enlazados al cuestionario **v1 (id=4)** (Ácido Hialurónico,
  Lipólisis Alta Frecuencia, Microneedling, Peelings Médicos, Toxina Botulínica) → Nota 1
  del plan de origen; **no afectan el catálogo activo hoy**.
- Hallazgo de inspección: `cuestionarios` es legible solo por `authenticated` (RLS
  `cuestionario_read`); el join `cuestionarios(nombre)` de `fetchRequisitosServicio`
  funciona para sesiones reales (paciente/admin), devuelve null solo para `anon`.

## Decisiones confirmadas (2026-08-20)

1. **Nota 1 (links a v1)**: se documenta como deuda técnica, **sin migrar**. Los 5 servicios
   afectados están inactivos; solo se re-enlazaría si se activan en el futuro.
2. **Cuentas**: se reutilizan las existentes — `admin@strani.com`, `pac.compliance1@test.com`
   (APTO v2), `esp.compliance1@test.com` (APROBADO/verificado), `esp.aprobado@test`
   (APROBADO; Medicina Estética + Toxina Botulínica). Se registra paciente nuevo solo si el
   caso lo requiere.
3. **Servicio de prueba de la Act. 13**: se crea en la app con `requiere_face_map=false` y
   cuestionario 5 obligatorio (para ejercitar el modal de requisitos sin interferir con el
   face map); **al final se deja desactivado** (el CRUD admin no borra servicios).

## Actividades → ejecución

### 1. Preparación de datos (SQL Editor / API)
- [x] Confirmar migraciones aplicadas (`supabase migration list`).
- [x] Consultar especialistas APROBADO/activos y sus `especialista_especialidades`
      (esp.compliance1 y esp.aprobado) para elegir el caso de no-coincidencia.
- [x] Confirmar evaluación APTO de `pac.compliance1@test.com` para cuestionario id=5
      y validación vigente (RN-020 APROBADA).

> **Hallazgo bloqueante resuelto (2026-08-20)**: el INSERT de `solicitudes` fallaba con
> `42501` porque existía un trigger **huérfano** en el remoto, `tr_log_solicitud_estado`
> (AFTER INSERT, creado a mano en SQL Editor, ausente de migraciones), cuya función
> `log_solicitud_estado_change()` insertaba en `historial_estados` con `tipo_entidad='SOLICITUD'`
> usando los permisos del paciente; la única policy de esa tabla (`historial_cita_own`) solo
> cubre `CITA` de especialistas. La app nunca usa historial para SOLICITUD. Se eliminó vía
> migración `20260820000200_remove_tr_log_solicitud_estado.sql` (DROP TRIGGER + DROP FUNCTION
> IF EXISTS) y el INSERT del paciente ya devuelve HTTP 201. Diagnóstico previo con
> `20260820000100_diag_solicitud_triggers.sql` (función `_diag_solicitud_triggers`).

### 2. Act. 12 — Matriz de relaciones
- [x] R1. Servicio con cuestionario obligatorio (sin face map). Se creó en la app
      `TEST E2E Sin FaceMap` (id `9a42322c`, precio 200, categoría 16, cues 5 obligatorio,
      sin especialidades) tras hallazgo: todos los servicios existentes con cues 5 tienen
      `requiere_face_map=true` y el paso 2 (face map) corre antes que el paso 3 (requisitos),
      por lo que el modal no se dispararía con Relleno de Labios. Probado:
      `paciente1@test.com` (sin APTO) → modal "Requisito de salud pendiente"; 
      `pac.compliance1@test.com` (APTO v2) → pasa al modal de pago.
- [x] R2. Desintoxicación Facial Profunda `ced81223` (face map, sin cuestionario) →
      flujo face map, sin modal de requisitos. OK.
- [x] R3. Cavitación Corporal `d727d7fb` (sin relaciones ni face map) → sin requisito
      ni face map → modal de pago directo. OK.
- [x] R4. Match de especialidades en marketplace (vía API): `aceptar_solicitud` con
      esp.compliance1 (esp 15/21/5) sobre Relleno de Labios (esp 1+14) →
      `NO_COINCIDE_ESPECIALIDAD`; con esp.aprobado (esp 1/15) → `OK` + cita creada.
      Ver también Sec. 4 (geo).
- [x] R5. Servicio sin `servicio_especialidades` → visible para todos: se creó
      `TEST-R5-SinEspecialidad` (sin filas) y ambos especialistas lo vieron en
      `obtener_solicitudes_publicadas_geo`.
- [x] R6. RPC `reemplazar_servicio_especialidades`/`reemplazar_servicio_cuestionarios`
      verificados: al asignar esp 17 al TEST-R5 ambos especialistas dejan de verlo en geo;
      al añadir cuestionario id=5 obligatorio, `fetchRequisitosServicio` lo refleja.
      No-admin (esp.compliance1) recibe `P0001 Solo administradores...` en ambos RPC.

> **Hallazgo menor (UI)**: tras crear un servicio, el listado de servicios del admin no
> lo muestra hasta recargar la página (el cubit emite feedback pero la lista no refresca
> en el widget abierto; al volver y re-entrar sí aparece). Anotado para el reporte.

### 3. Act. 13 — Flujo completo (checklist de 10 ítems)
- [x] A. Admin crea/administra categorías. (creado TEST E2E en tab Categorías y Servicios)
- [x] B. Admin crea servicio (precio + `tipo_precio` + duración) y lo edita. (TEST E2E: 200 / PRECIO_FIJO / 25 min)
- [x] C. Admin asocia especialidades y cuestionarios al servicio. (cues 5 obligatorio; 0 especialidades)
- [x] D. Servicio inactivo no aparece al paciente. (TEST E2E desactivado → no visible para paciente)
- [x] E. Especialista sin la especialidad requerida no puede recibir el servicio.
      (contra-prueba API: `NO_COINCIDE_ESPECIALIDAD` + geo 0 filas)
- [x] F. Paciente que no cumple los requisitos no puede continuar. (= R1a)
- [x] G. Paciente elegible puede seleccionar el servicio. (= R1b)
- [x] H. El precio estimado se muestra correctamente antes de continuar. (Cavitación → $80)

### 4. Contra-pruebas (SQL Editor)
- [x] `aceptar_solicitud` con especialista sin coincidencia → `NO_COINCIDE_ESPECIALIDAD`
      (esp.compliance1 sobre Relleno de Labios); con coincidencia → `OK` (esp.aprobado).
- [x] `obtener_solicitudes_publicadas_geo`: esp.compliance1 → 0 filas para Relleno de
      Labios (esp 1+14) pero sí para TEST-R5 (sin especialidades); esp.aprobado → 1 fila
      (Relleno de Labios). Tras asignar esp 17 al TEST-R5, ambos dejan de verlo.
- [x] RLS escritura: INSERT/UPDATE/DELETE en `servicios` por no-admin → 403;
      esp.compliance1 en `reemplazar_*` → P0001 (solo admin).
- [x] Bonus: INSERT de `solicitudes` por el paciente → HTTP 201 tras el fix del trigger.

### 5. Cierre
- [x] Registrar hallazgos y resumen final en
      `docs/pruebas/2026-08-20_catalogos_servicios_e2e.md`.
- [x] Si hay bugs → fix + `flutter analyze` + `flutter test`; anotar commits.
      (no hubo fixes Dart; solo se limpió el trigger huérfano por migración — ver hallazgo)

## Entorno / comandos

- CLI Supabase vinculado al proyecto `hhyjremkguvphmjuaazp`.
- E2E manual: `flutter run -d chrome` en `localhost:5000` (NO el desplegado en web.app).
- Confirmación de correo desactivada en Supabase para pruebas.
- Verificación de código tras cualquier fix: `flutter analyze` + `flutter test`.

## Hallazgo potencial a observar (de lectura de código, 2026-08-20)

- En `ServicesDashboardScreen._onServiceSelected`, tras completar un **face map nuevo**
  (rama `else`), el flujo no abre el modal de pago automáticamente; el paciente debe volver
  a tocar el servicio. No afecta la Act. 13 (servicio sin face map), pero se anota si aparece
  durante la Act. 12 (R2).