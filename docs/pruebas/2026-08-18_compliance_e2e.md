# Pruebas manuales — Compliance del especialista (E2E)

| | |
|---|---|
| **Fecha** | 2026-08-18 |
| **Versión** | 1.0 |
| **Commit** | `8e51419` |
| **Entorno** | Local `flutter run -d chrome` (NO el desplegado en web.app) |
| **Plan** | `docs/plans/2026-08-18_verificacion_compliance_especialista.md` |

## Cuentas

| Rol | Email | Clave |
|---|---|---|
| Administrador | `admin@strani.com` | `Test1234!` |
| Especialista aprobado | `especialista1@test.com` | `Test1234!` |
| Especialista nuevo (registrado en la app) | `esp.compliance1@test.com` | `Test1234!` |

## Checklist de aceptación

| # | Ítem | Resultado | Evidencia / observación |
|---|---|---|---|
| 1 | El especialista puede cargar sus documentos | ✅ | 3 documentos subidos (tras fix del picker, ver Hallazgos) |
| 2 | Los archivos quedan almacenados de forma privada | ✅ | Bucket `documentos-especialistas` `public=false`; filas guardan path |
| 3 | Cada documento tiene su propio estado | ✅ | 3 filas independientes: PENDIENTE, version 1, activo=true |
| 4 | El administrador puede revisar cada documento | ✅ | Panel admin muestra cada documento con botones aprobar/rechazar |
| 5 | El administrador puede aprobarlo o rechazarlo | ✅ | IDENTIFICACION aprobada; LICENCIA rechazada |
| 6 | Al rechazarlo puede indicar el motivo | ✅ | BD: `observacion_revision='Texto ilegible'`, `activo=false` |
| 7 | El especialista recibe la notificación correspondiente | ✅ | Trigger creó fila `DOCUMENTO_RECHAZADO`; en app: campanita con badge `1`, pantalla con "Documento rechazado" y motivo/versión, al leerla la campana se actualiza (tras fixes UX de Fase C) |
| 8 | Puede reemplazar únicamente el documento rechazado | ✅ | Reintentar licencia → fila `v2 PENDIENTE` activa (v1 queda inactiva); trigger bloquea apilar otro pendiente (400 correcto). Ver fix de tile en Hallazgos |
| 9 | Los documentos aprobados permanecen aprobados | ✅ | IDENTIFICACION sigue `v1 APROBADO` activa; la v1 de licencia quedó inactiva y la sección del home muestra solo la versión vigente |
| 10 | No accede al Marketplace con requisitos pendientes | ✅ | Home sin tarjetas mapa/citas (condicionales a `isApproved && disponible`), toggle de disponibilidad deshabilitado y `/specialist/map` → "Acceso restringido" |
| 11 | Con expediente completo + contrato → Verificado | ✅ | Admin aprobó en el panel. SQL: `estado_verificacion=APROBADO`, `activo=true`; notificación `VERIFICACION_APROBADA` creada (sin leer) |
| 12 | Verificado puede activar disponibilidad y recibir solicitudes | ✅ | Tras Verificado: toggle de disponibilidad habilitado, tarjetas "Mapa de pacientes"/"Mis citas" visibles, `/specialist/map` sin "Acceso restringido", mapa carga solicitudes. Aceptó solicitud de María González (`paciente1@test.com`) → cita `374df368-b260-49de-b36f-b6d784c7504c` `PROGRAMADA`, solicitud `80000000-...-0001` → `ACEPTADA` |

## Datos de la prueba

- Especialista nuevo: email `esp.compliance1@test.com`, rol Especialista (registrado en la app)
- Documentos subidos en Fase A: IDENTIFICACION, LICENCIA, CERTIFICACION (todas PENDIENTE, versión 1, activo)
- Contrato firmado: ✅ (Fase F) — `c23313d7-9208-45d0-8eab-df5233f23245`, `firmado=true`, `version_contrato=1` (tras fix del modelo + migración `20260818000100_contratos_version_integer.sql`)

## Consultas SQL de apoyo (SQL Editor)

```sql
-- 0. Médicos regentes ACTIVOS (precondición onboarding)
select id, nombre, activo, estado from medicos_regentes where activo = true;

-- 1. Especialista nuevo y su estado
select e.id, e.usuario_id, p.email, e.estado_verificacion, e.activo,
       e.disponible, e.medico_regente_id
from especialistas e
join profiles p on p.id = e.usuario_id
where p.email = '<email_nuevo>';

-- 2. Documentos del especialista (estado/versión/motivo por documento)
select d.tipo_documento, d.estado_revision, d.version_documento, d.activo,
       d.observacion_revision, d.revisado_por, d.fecha_revision
from documentos_especialista d
where d.especialista_id = '<especialista_id>'
order by d.tipo_documento, d.version_documento;

-- 3. Contrato
select id, firmado, fecha_firma, metodo_firma
from contratos where especialista_id = '<especialista_id>';

-- 4. Especialidades asignadas
select especialidad_id from especialista_especialidades
where especialista_id = '<especialista_id>';

-- 5. Notificaciones recibidas por el especialista
select id, titulo, mensaje, tipo, leida, fecha_envio
from notificaciones where usuario_id = '<usuario_id>'
order by fecha_envio desc;
```

## Contra-pruebas (triggers/RLS)

```sql
-- A. Trigger bloquea APROBADO con expediente incompleto (ejecutar mientras
--    falte algún requisito del especialista nuevo). Esperado: error de trigger.
-- Contra-prueba A (negativa, sobre especialista con expediente INCOMPLETO
--    julio12@gmail.com / fde6e88a-dc21-46d7-a70c-72dd882b36c6)
-- Esperado: ERROR P0001 (validar_habilitacion_especialista).
-- RESULTADO: ✅ "No se puede aprobar: el expediente no está completo
-- (documentos aprobados, datos profesionales y contrato firmado)."
-- Nota: la contra-prueba sobre esp.compliance1 dio "sin error" porque su
-- expediente ya estaba completo (positivo correcto); quedó en EN_REVISION por
-- el begin/rollback.
update public.especialistas
   set estado_verificacion = 'APROBADO'
 where id = '<especialista_id>';

-- B. No-admin no puede modificar estado (SQL Editor corre como postgres y
--    auth.uid() es NULL → no admin). Esperado: error de trigger.
update public.especialistas
   set estado_verificacion = 'EN_REVISION'
 where id = '<especialista_id>';
-- Nota: el chequeo real de "el dueño no puede auto-aprobarse" se cubre en la
-- app (el especialista no tiene botón de aprobar) + los triggers A/B.
```

## Registro de ejecución

| Fase | ítems | Resultado |
|---|---|---|
| A — Onboarding y subida | 1, 2, 3 | ⬜ |
| B — Revisión admin | 4, 5, 6 | ⬜ |
| C — Notificación | 7 | ✅ |
| D — Re-subida de rechazado | 8, 9 | ✅ |
| E — Bloqueo de marketplace | 10 | ✅ |
| F — Verificado gated | 11 | ✅ |
| G — Disponibilidad | 12 | ✅ |

## Hallazgos

1. **BUG FIX (Fase A)**: `_seleccionarArchivo` (`specialist_documents_screen.dart`) iniciaba `tipoElegido=null` y para requisitos sin alternativas (identificación/licencia) hacía `return` sin abrir el picker. Fix: `tipoElegido ??= requisito.tipo`. Verificado con analyze + 81/81 tests.
2. **UX (Fase C)**: en la pantalla de Documentos, el botón "Reintentar" se cortaba a lo ancho (ancho fijo 108px) y el motivo del rechazo no destacaba. Fix: botón con `ConstrainedBox(maxWidth:150)` que crece según el texto + motivo en caja resaltada (rojo). Además se agregó la campanita (`NotificacionesBell`) al AppBar de Documentos para poder abrir y marcar leída la notificación sin salir de la pantalla.
3. **BUG FIX (Fase D)**: `_buildTile` (`specialist_documents_screen.dart`) daba prioridad a `rechazado` sobre `enRevision`: tras re-subir (v2 PENDIENTE) el tile seguía en "Rechazado" con "Reintentar" y el segundo intento chocaba con el trigger 400 "Ya tienes un documento pendiente". Fix: precedencia `aprobado > enRevision > rechazado > pendiente` y motivo de la última versión (`rechazado.last`). El trigger ya impedía apilar PENDIENTES (correcto).
4. **BUG FIX (Fase D, home)**: `DocumentosSection` listaba todas las filas de la BD (v1 RECHAZADA + v2 PENDIENTE) y el diálogo "Subir" ofrecía tipos ya en revisión (el trigger los rechazaba con 400). Fix: nuevo helper `documentosVigentes` (una fila por tipo, la de mayor versión) y `tiposSubiblesDocumentos` ahora excluye también tipos con documento ACTIVO PENDIENTE. Confirmado el hallazgo previsto del plan.
5. **BUG FIX (Fase E)**: el botón "Volver" de `_AccesoRestringido` (`specialist_map_screen.dart`) usaba `Navigator.pop()`. Al llegar a `/specialist/map` por URL directa (sin pantalla debajo en el stack) quedaba una pantalla en blanco. Fix: `context.canPop() ? context.pop() : context.go(AppRoutes.specialistHome)`, mismo patrón que la pantalla de documentos.
6. **BUG FIX + MIGRACIÓN (Fase F)**: la columna `contratos.version_contrato` nació como texto y PostgREST la devuelve como string → `ContratoModel.fromJson` reventaba (`TypeError: "1" is not a subtype of num?`) al firmar el primer contrato. Fix doble: modelo robusto (`int.tryParse`) + migración `20260818000100_contratos_version_integer.sql` que normaliza la columna a `INTEGER` (idempotente, solo altera si sigue en texto).
7. **DEUDA / datos legacy (Fase F)**: `especialista1-4@test.com` (seed) están `estado_verificacion=APROBADO` pero `cumple_requisitos_habilitacion=false` (expediente incompleto según el criterio actual). Consecuencia: `aceptar_solicitud` los rechazaría del marketplace. Requiere decisión de producto (backfill o mantener legacy). No se modifica en esta prueba.
8. **BUG FIX + MIGRACIÓN (Fase G)**: el mapa de especialistas (`fetchEspecialistasAprobados`) fallaba con `PGRST100`/`PGRST200`. Dos causas: (a) `profiles(full_name)` ambiguo (dos FKs a profiles) — fix con hint `profiles!especialistas_usuario_id_fkey(full_name)`; (b) `ubicaciones_especialista` no tenía FK hacia `especialistas` (tabla creada a mano sin constraint) → PostgREST no resolvía el embed y rechazaba el `order=...`/`limit=1` embebido — fix: migración `20260818000200_ubicaciones_especialista_fk.sql` (ADD CONSTRAINT idempotente + limpieza de huérfanos) + quitar los modifiers embebidos y ordenar por `created_at` desc en el cliente (`EspecialistaMapaModel`).
9. **UX MENOR (Fase G)**: el RPC `obtener_solicitudes_publicadas_geo` no filtra `fecha_expiracion`, así que el mapa muestra solicitudes vencidas; al aceptarlas el RPC devuelve `EXPIRADA` ("Esta solicitud ya expiró"). Recomendado: añadir `AND (s.fecha_expiracion IS NULL OR now() < s.fecha_expiracion)` al RPC. Durante la prueba se refrescó `fecha_expiracion` de las solicitudes seed (+3 días).
