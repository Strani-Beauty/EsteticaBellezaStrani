# 14 — Seguridad, Privacidad, Validaciones y Manejo de Errores

**Proyecto:** Estética y Belleza Strani
**Fecha:** 2026-09-07
**Versión:** 1.0
**Objetivo:** dictamen de las 15 actividades de seguridad/privacidad/validaciones/errores, evidencia de la auditoría aplicada y checklist manual de verificación antes de las pruebas manuales por módulo.

> **Auditoría aplicada (2026-09-07):** migración `supabase/migrations/20260907000000_seguridad_auditoria_grants_rls_storage.sql` aplicada en vivo y verificada con sondeos RLS (`probes_rls.js`). `flutter analyze` 0 issues, `flutter test` 366 aprobados. Detalle del plan en `docs/plans/2026-09-07_auditoria_seguridad_pre_pruebas_manuales.md`.

---

## 1. Dictamen por actividad

| ID | Actividad | Dictamen | Evidencia clave |
|----|-----------|----------|-----------------|
| A.1 | Revisar y validar las políticas RLS de las tablas con información sensible | **CUMPLE** | RLS habilitada en todas las tablas sensibles (verificado con `pg_policies` en vivo). Se eliminaron 6 policies "blanket" (`USING true`) que anulaban las restrictivas en `direcciones_paciente`, `evaluaciones_salud`, `respuestas_salud`, `validaciones_telemedicina`, `preguntas`, `cuestionarios`. Las policies correctas por tabla quedan efectivas. |
| A.2 | Paciente solo consulta/modifica lo que le pertenece | **CUMPLE** | Policies `own_profile_access`, `own_paciente_access`, `direccion_paciente_own`. Sondeo: `pac.activo@test` ve 0 filas de direcciones/respuestas/evaluaciones/solicitudes ajenas (antes 6/61/10/12/2) y solo su propio `profile`. |
| A.3 | Especialista accede solo a pacientes/citas según negocio | **CUMPLE** | `cita_especialista_own`, `pacientes_especialista_cita`, `solicitud_especialista_asignado_select`, `pago_especialista_cita_read` restringen al especialista con cita asignada. |
| A.4 | Especialista no ve dirección exacta pre-aceptación | **CUMPLE** | RPC `obtener_solicitudes_publicadas_geo` devuelve lat/lng truncados (~110 m) + ciudad, nunca dirección exacta (RN-018). `SolicitudPendienteModel` fuerza `direccion: null`. La política `Especialista ve dirección tras aceptar cita` solo aplica con cita PROGRAMADA/FINALIZADA. Sondeo `esp.aprobado@test`: 0 filas de dirección exacta pre-aceptación. |
| A.5 | Admin solo operaciones autorizadas por su rol | **CUMPLE** | Policies `is_administrador()` en operaciones de escritura; `admin_resumen_kpis`/`eliminar_servicio` con chequeo admin verificado en vivo. `REVOKE EXECUTE` de `registrar_auditoria`, `notificar_usuario_push`, `enviar_recordatorios_cita` a `anon`/`authenticated`/`PUBLIC` (proacl final: solo `postgres`/`service_role`). |
| A.6 | Almacenamiento privado de documentos, fotos, consentimientos | **CUMPLE** | Buckets privados: `documentos-especialistas`, `firmas-consentimiento`, `fotografias-tratamiento`, `avatars`, `comprobantes-pagos` y ahora `contratos`. Públicos solo catálogo (`imagenes-servicios`). |
| A.7 | URL de un archivo no permite acceso directo sin autorización | **CUMPLE** | Todos los flujos sensibles usan `createSignedUrl(path, 3600)`. `contratos` pasó a privado: sondeo anon → 400. |
| A.8 | Protección de documentos de especialistas, fotos de pacientes/tratamientos | **CUMPLE** | Policies de storage `*_own_select`/`*_admin_select` verificadas; `contrato_storage_own_select` soporta paths nuevo e histórico; `comprobante_storage_especialista_select` para el dueño. |
| A.9 | Intentos de acceso directo a registros ajenos rechazados | **CUMPLE** | Sondeos post-migración: `pac.activo@test`, `esp.aprobado@test`, `pac.nuevo@test` → 0 filas de datos ajenos en todas las tablas probadas. |
| A.10 | Datos incompletos/inválidos en formularios | **CUMPLE** (tras correcciones) | Añadidas validaciones: fecha de nacimiento (obligatoria, no futura, edad ≥ 10) y género en complete-profile; ubicación confirmada en el mapa (complete-profile y dirección del paciente); tarifa horaria (obligatoria y > 0) en onboarding de especialista. `_getDireccionPrincipal` ahora lanza error claro si falta dirección principal. |
| A.11 | Errores de comunicación con servicios externos (Stripe/Qualify) | **CUMPLE** | `mensajeDeErrorAmigable()` en `failures.dart` filtra `PostgrestException`/`ClientException`/etc.; 4 usecases de pagos lo aplican. `revision_final_screen` ya traduce motivos de saldo. Qualify sigue simulado (delay 3 s) y degrada con mensaje claro sin red. |
| A.12 | Pagos fallidos/interrupciones/reintentos sin duplicados | **CUMPLE** | `confirmar_pago_saldo` devuelve `YA_REGISTRADA` si ya existe transacción SALDO APROBADO; `registrar_pago_fallido` evita duplicar FALLIDAS en reintentos del webhook; `registrar_pago_especialista` devuelve `YA_PAGADA`. Webhook Stripe delega en RPCs (ver skill stripe-pagos-strani). |
| A.13 | Operaciones críticas no se ejecutan dos veces | **CUMPLE** | `aceptar_solicitud` (UPDATE atómico + `GET DIAGNOSTICS`), `confirmar_pago_saldo` (`YA_REGISTRADA`), `generar_liquidaciones` (solo si `NOT EXISTS liquidacion_detalles`), `registrar_pago_especialista` (`YA_PAGADA`). En Dart, guard de doble-ejecución en `treatment_execution_cubit.avanzar()` y `marketplace_cubit.aceptandoId`. |
| A.14 | Mensajes de error claros, sin exponer tecnicismos | **CUMPLE** (tras correcciones) | `mensajeDeErrorAmigable()` oculta detalles técnicos; los repositorios traducen motivos RPC a mensajes de usuario; se mantiene `AuthFailure`/`ValidationFailure`/`PermissionFailure` tipados. |
| A.15 | Prueba general de seguridad | **CUMPLE** | Auditoría completa (plan 2026-09-07): inventario RLS, verificación BD read-only, sondeos RLS pre/post, migración aplicada, `flutter analyze` 0 issues, `flutter test` 366 OK. Pendiente solo la ejecución manual de este checklist. |

---

## 2. Correcciones aplicadas (resumen)

1. `REVOKE EXECUTE` (incl. `PUBLIC`) de `registrar_auditoria`, `notificar_usuario_push`, `enviar_recordatorios_cita`.
2. Eliminadas 6 policies blanket `USING true` en tablas de datos clínicos/direcciones/cuestionarios.
3. `solicitud_especialista_select_publicada` restringida a especialistas APROBADOS y activos.
4. `medicos_regentes`: lectura completa solo admin; vista pública `medicos_regentes_publico` sin teléfono/correo para especialistas.
5. Bucket `contratos` privado; `subirFirmaContrato` guarda path y sirve con URL firmada.
6. `respuestas_salud`: el paciente solo SELECT/INSERT (sin UPDATE/DELETE).
7. RPC `registrar_validacion_telemedicina`: ya no marca `payment_completed` sin pago real.
8. Cuentas seed `*@test`: contraseñas rotadas (ver sección 4).

---

## 3. Checklist manual de seguridad

Formato: Caso ID | Título | Pasos | Resultado esperado | Prioridad | Estado

### 3.1 RLS y acceso por rol

| Caso | Título | Pasos | Resultado esperado | Prioridad | Estado |
|------|--------|-------|--------------------|----------|--------|
| PS-R-01 | Paciente no lee datos de otro paciente | Login `pac.activo@test`; abrir perfil/dirección/salud; en SQL Editor consultar `profiles`, `pacientes`, `direcciones_paciente`, `respuestas_salud` de otra cuenta | Solo sus propios registros (0 filas ajenas) | Crítica | ⬜ |
| PS-R-02 | Especialista no ve dirección exacta pre-aceptación | Login `esp.aprobado@test`; ver marketplace (solicitudes publicadas) | Sin dirección exacta: solo ciudad y coordenadas aprox (~110 m) | Crítica | ⬜ |
| PS-R-03 | Especialista ve dirección tras aceptar cita | Aceptar solicitud; abrir detalle de cita en ejecución | Dirección y coordenadas exactas visibles solo con cita asignada | Alta | ⬜ |
| PS-R-04 | Especialista no asignado no ve citas/pacientes ajenos | `esp.nuevo@test` intenta ver citas/pacientes de `esp.aprobado@test` | 0 filas (RLS) | Crítica | ⬜ |
| PS-R-05 | Admin accede a operaciones administrativas | Login `admin@test`; panel de licencias, KPIs, auditoría, configuración | Acceso completo solo al admin; un paciente no ve esas pantallas | Alta | ⬜ |
| PS-R-06 | Paciente no ve solicitudes de otros pacientes | `pac.nuevo@test` consulta solicitudes publicadas | 0 filas | Crítica | ⬜ |
| PS-R-07 | Médicos regentes sin teléfono/correo para especialistas | `esp.aprobado@test` abre onboarding (médicos regentes) | Ve nombre/licencia pero NO teléfono/correo | Alta | ⬜ |
| PS-R-08 | No se puede invocar funciones sensibles desde la app | Con sesión `authenticated` intentar `registrar_auditoria`, `notificar_usuario_push`, `enviar_recordatorios_cita` vía RPC/edge | Rechazo (sin permiso EXECUTE) | Crítica | ⬜ |

### 3.2 Storage y URLs firmadas

| Caso | Título | Pasos | Resultado esperado | Prioridad | Estado |
|------|--------|-------|--------------------|----------|--------|
| PS-S-01 | Documentos de especialistas con URL firmada | Especialista sube documento; abrir en el panel | Se sirve con URL firmada; la URL sin token devuelve 400/403 | Crítica | ⬜ |
| PS-S-02 | Firmas de contrato privadas | `esp.aprobado@test` firma contrato; abrir la URL de la firma en modo incógnito | No accesible sin token; bucket `contratos` es privado | Crítica | ⬜ |
| PS-S-03 | Fotografías de tratamiento privadas | Especialista sube foto de tratamiento; compartir URL | Solo accesible con URL firmada (paciente dueño/especialista/admin) | Alta | ⬜ |
| PS-S-04 | Comprobantes de pago privados | Admin sube comprobante en liquidación | Solo admin/dueño con URL firmada | Alta | ⬜ |
| PS-S-05 | Imágenes de catálogo públicas (intencional) | Abrir imagen de servicio de catálogo | Accesible sin auth (catálogo) | Media | ⬜ |
| PS-S-06 | Firmas de consentimiento privadas | Completar tratamiento con firma; abrir URL | Solo con URL firmada | Alta | ⬜ |

### 3.3 Validaciones

| Caso | Título | Pasos | Resultado esperado | Prioridad | Estado |
|------|--------|-------|--------------------|----------|--------|
| PS-V-01 | Fecha de nacimiento y género obligatorios | Complete-profile sin fecha/género → Guardar | Mensaje claro y no avanza | Alta | ⬜ |
| PS-V-02 | Fecha de nacimiento válida | Ingresar fecha futura o edad < 10 | Rechazo con mensaje | Alta | ⬜ |
| PS-V-03 | Ubicación confirmada en el mapa | Guardar perfil sin buscar/confirmar ubicación en el mapa | Mensaje "Confirma tu ubicación en el mapa" | Alta | ⬜ |
| PS-V-04 | Tarifa horaria del especialista | Onboarding con tarifa vacía, 0 o texto no numérico | Rechazo con mensaje | Media | ⬜ |
| PS-V-05 | Solicitud de servicio sin dirección principal | Paciente sin dirección principal intenta reservar | Error claro: "Primero guarda una dirección principal..." | Crítica | ⬜ |

### 3.4 Manejo de errores e idempotencia

| Caso | Título | Pasos | Resultado esperado | Prioridad | Estado |
|------|--------|-------|--------------------|----------|--------|
| PS-E-01 | Error de red al pagar | Activar modo avión durante un pago | Mensaje claro sin tecnicismos (sin `PostgrestException`) | Alta | ⬜ |
| PS-E-02 | Doble tap en aceptar solicitud | Aceptar solicitud dos veces rápido | Se procesa una sola vez (segunda → error controlado) | Crítica | ⬜ |
| PS-E-03 | Reintento de confirmar pago de saldo | Confirmar saldo con mismo ref Stripe dos veces | `YA_REGISTRADA`, sin pago/transacción duplicada | Crítica | ⬜ |
| PS-E-04 | Doble avance de tratamiento | Avanzar cita (EN_CAMINO→LLEGO→EN_PROCESO) dos veces | Transición única controlada | Alta | ⬜ |
| PS-E-05 | Generar liquidación dos veces | Ejecutar `generar_liquidaciones` sobre la misma semana | No duplica `liquidacion_detalles` | Crítica | ⬜ |
| PS-E-06 | Pago Qualify sin pago real | Completar dictamen APTO sin pagar cuota inicial | `payment_completed` permanece false hasta el pago real | Crítica | ⬜ |

---

## 4. Nota de credenciales

Las contraseñas de las cuentas `*@test` fueron **rotadas** (2026-09-07) y quedaron documentadas en `supabase/.temp/seed_passwords.txt` (archivo ignorado por git — NO committear). Las cuentas `@test.com` (p. ej. `admin@strani.com`, `paciente1@test.com`) conservan la clave original `Test1234!`.