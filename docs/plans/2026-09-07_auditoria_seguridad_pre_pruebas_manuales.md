# Plan: Auditoría de Seguridad, Privacidad, Validaciones y Manejo de Errores (pre-pruebas manuales)

**Fecha:** 2026-09-07
**Objetivo:** dictamen CUMPLE/PARCIAL/NO CUMPLE por cada una de las 15 actividades de seguridad del checklist de pruebas manuales, verificación contra la BD real (solo-lectura), y aplicación de todas las correcciones de seguridad detectadas antes de ejecutar las pruebas manuales.

**Decisión del usuario (aprobada 2026-09-07):** Auditoría + correcciones (todas). Verificación BD remota de solo-lectura vía pooler (driver pg) con sondeos RLS usando cuentas `*@test`. Documentación en `docs/plans/` y `docs/Pruebas manuales/`.

---

## Fase 1 — Persistir el plan
- [x] Crear este archivo de plan con checkpoints por sub-tarea.

## Fase 2 — Verificación BD read-only (pooler pg, solo SELECT/catálogo)
- [x] Estado de migraciones aplicadas (funciones/policies vivas).
- [x] Grants de `registrar_auditoria`, `notificar_usuario_push`, `enviar_recordatorios_cita` (confirmar `GRANT EXECUTE TO authenticated`).
- [x] Confirmar DROP de `_diag_profiles` y `_diag_solicitud_triggers`.
- [x] Confirmar fix aplicado de `admin_resumen_kpis`/`eliminar_servicio` (chequeo admin).
- [x] Confirmar cuentas seed `*@test` presentes (incl. `admin@test`).
- [x] Publicidad real de buckets storage (contratos, documentos, fotografias, firmas, comprobantes, avatars, imagenes-servicios).
- [x] Snapshot de policies por tabla sensible (profiles, pacientes, solicitudes, direcciones_paciente, respuestas_salud, medicos_regentes, pagos, transacciones).

## Fase 3 — Sondeos RLS con cuentas de test (solo SELECT de prueba)
- [x] Paciente intenta leer perfil/paciente/dirección/solicitudes/pagos de otro paciente → 0 filas.
- [x] Especialista (no asignado) consulta dirección exacta pre-aceptación y solicitudes publicadas de otros → sin dirección exacta.
- [x] Especialista verifica lat/lng truncados (~110 m) del RPC geo.
- [x] `admin@test` verifica operaciones administrativas correctas.
- [x] Bucket contratos legible sin auth (URL pública).

## Fase 4 — Dictamen por actividad (evidencia en `docs/Pruebas manuales`)
- [x] Redactar dictamen para las 15 actividades (A.1–A.15).

## Fase 5 — Correcciones (todas)
- [x] 5.1 Revocar `GRANT EXECUTE TO authenticated` de `registrar_auditoria`, `notificar_usuario_push`, `enviar_recordatorios_cita` (aplicado, verificado: solo `postgres`/`service_role`).
- [x] 5.2 Restringir `solicitud_especialista_select_publicada` a especialistas APROBADOS; ocultar telefono/correo/numero_licencia en `medicos_regentes` a no-admin (vista pública `medicos_regentes_publico`).
- [x] 5.3 Bucket `contratos` → privado + `createSignedUrl` en `subirFirmaContrato`.
- [x] 5.4 `respuesta_salud_paciente_own` quitar UPDATE/DELETE (SELECT+INSERT).
- [x] 5.5 Rotar contraseñas de cuentas seed `*@test` (documentadas en `supabase/.temp/seed_passwords.txt`, conservadas para pruebas manuales).
- [x] 5.6 Dart: validaciones (fecha nacimiento/género, tarifa horaria, dirección+coordenadas), error claro si falta dirección principal, guard doble-ejecución en `treatment_execution.avanzar()`, traducción de errores crudos a mensajes de usuario (incl. motivos de pagos), `saveQualifyTestValidation` no marca `payment_completed` sin pago real.
- [x] 5.7 Aplicar migración idempotente con `supabase db push` + `flutter analyze` + `flutter test` (migración `20260907000000` aplicada y verificada en vivo; `flutter analyze` 0 issues; `flutter test` 366 OK).

## Fase 6 — Documentación
- [x] Actualizar `docs/Pruebas manuales` con dictamen por actividad y checklist manual de seguridad (`14_seguridad_privacidad.md` + índice).