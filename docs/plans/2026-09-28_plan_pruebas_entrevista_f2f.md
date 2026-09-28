# Plan — Pruebas manuales Entrevista Médica F2F (médico interno)

Fecha: 2026-09-28
Estado: APROBADO por el usuario (m0328: "si"). Sin commit.
Alcance: guía paso a paso para probar la entrevista F2F por videollamada
(agenda admin → videollamada Jitsi → consentimiento → notas/grabación →
dictamen del examen médico total → desbloqueo RN-020).

## Preparación previa (datos)

- Migración `20260928000200_cuestionario_activo_y_passwords_seed.sql` (aplicada):
  - Deja como **único cuestionario activo** "Evaluación Clínica General" (id 3,
    v1: 18 preguntas / 16 obligatorias). Desactiva la v2 "Cuestionario de Salud"
    (id 5) y el resto → el datasource (`order by created_at desc limit 1`) queda
    determinista.
  - Restablece la contraseña de las cuentas seed `*@test.com` a **`Test1234!`**.
  - Nota: el panel admin **no** permite desactivar cuestionarios (solo eliminar
    o activar); por eso el cambio va por migración idempotente.

### Cuentas
| Cuenta | Rol | Uso en la prueba |
|---|---|---|
| `admin@test.com` | Administrador | Agenda, inicia, dictamina |
| `pac.activo@test.com` | Paciente (activo, payment+eval) | Flujo completo / paciente que se une |
| `pac.vencido@test.com` | Paciente (activo=false, validación VENCIDA) | Contra-prueba de bloqueo |
| `pac.rechazado@test.com` | Paciente (activo=false, validación RECHAZADA) | Contra-prueba de bloqueo |

Todas con contraseña `Test1234!` (login `/login`, email + password).

### Config vigente
`enforce_rn020=true`, `push_notifications=true`,
`recordatorio_entrevista_horas_previas=2`. Nota: `edge_function_base_url` y
`anon_key` no están sembradas → **push FCM no**, pero la notificación in-app
(campana) **sí** se registra siempre.

### App
`flutter run -d chrome` (el Jitsi se embebe como iframe solo en web). Requiere
`.env` con `SUPABASE_URL`/`SUPABASE_ANON_KEY`.

## Prueba A — Flujo completo (mecánica F2F)

1. Login **admin** → panel, sección *Administrativo* → tile
   **"Entrevistas Médicas (F2F)"**.
2. FAB **"Agendar"** → acepta el aviso ePHI/HIPAA.
   Paciente `pac.activo@test.com`; fecha/hora (hoy/mañana); duración 30/45/60.
   Botón **"Agendar y notificar al paciente"**.
3. Verificar lista (estado PROGRAMADA) y en BD:
   ```sql
   select id, paciente_id, estado, sala_id, fecha_programada
   from public.entrevistas_medicas order by created_at desc limit 1;
   select titulo, tipo, fecha_envio from public.notificaciones
   order by fecha_envio desc limit 3;   -- 'Entrevista médica agendada'
   select accion from public.auditoria
   where accion='ENTREVISTA_MEDICA_AGENDADA' order by fecha desc limit 1;
   ```
4. Abrir el tile (aviso ePHI) → secciones Datos / Evaluación aplicada /
   Videollamada / Notas / Grabación / Dictamen.
5. **"Iniciar entrevista"** → estado `EN_CURSO`
   (audita `ENTREVISTA_MEDICA_INICIADA`).
6. Videollamada: se embebe `https://meet.jit.si/<sala_id>`; conceder cámara/mic.
7. Notas: escribir "Notas clínicas" + "Hallazgos" → **"Guardar notas"**.
8. Grabación: **"Adjuntar grabación"** (`FileType.video`) → bucket privado
   `entrevistas-medicas/<entrevista_id>/grabacion_<ts>.<ext>`; "Ver grabación"
   (URL firmada).
9. **"Emitir dictamen"** → Apto/No apto + **observaciones obligatorias** →
   emitir **APTO**.
10. Verificar:
    ```sql
    select estado, dictamen, finalizada_at, validacion_id
    from public.entrevistas_medicas where id='<id>';
    select proveedor, estado, fecha_validacion, fecha_vencimiento
    from public.validaciones_telemedicina
    where paciente_id='<paciente_id>' order by created_at desc limit 1;
    select activo, evaluation_passed from public.profiles where id='<usuario_id>';
    ```

## Prueba B — Desbloqueo RN-020 (contra-prueba)

Servicio con `requiere_telemedicina=true` (p. ej. "Estética y Belleza General"):
- **Antes** del dictamen: reserva bloqueada (trigger `validar_rn020_solicitud`).
- **Después** de APTO: reserva permitida (validación `APROBADA`, +365 días).
```sql
select clave, valor from public.configuracion_sistema where clave='enforce_rn020';
select id, nombre, requiere_telemedicina from public.servicios
where requiere_telemedicina = true;
```

## Prueba C — Dictamen NO APTO

Repetir A con **No apto** → `dictamen='NO_APTO'`, validación `RECHAZADA`,
`profiles.activo=false`, notificación "Resultado de tu entrevista médica"
(texto de no aprobado) y bloqueo de reserva.

## Prueba D — Recordatorio (cron)

- Agendar dentro de la ventana (2 h). Forzar el job:
  ```sql
  select public.enviar_recordatorios_entrevista();
  select * from public.recordatorios_entrevista order by fecha_envio desc limit 3;
  select titulo, tipo from public.notificaciones order by fecha_envio desc limit 3;
  ```
- Re-ejecutar: no debe duplicar (PK `entrevista_id`).

## Prueba E — Seguridad / RLS

- Como paciente, llamar `emitir_dictamen_entrevista` → `No autorizado`.
- `registrar_validacion_telemedicina(...)` → EXECUTE revocado (autodictamen).
- `update entrevistas_medicas set estado='COMPLETADA'` como paciente → el
  trigger `trg_proteger_entrevista_medica` lo impide (solo consentimiento/firma).

## Prueba F — Paciente: consentimiento y videollamada

1. Login `pac.activo@test.com` → catálogo → **"Ver mi entrevista médica (F2F)"**
   (o directo `/mi-entrevista`).
2. Firmar consentimiento (lienzo `Signature`) → verificar
   `consentimiento_telemedicina=true` y `firma_consentimiento_url` en el bucket.
3. Solo tras firmar aparece el iframe Jitsi; unirse a la misma sala
   (segunda pestaña) y comprobar audio/vídeo.
4. Campana: notificaciones de agendado y dictamen.

## Matriz mínima

| # | Cuenta(s) | Escenario | Resultado esperado |
|---|-----------|-----------|--------------------|
| A | admin + pac.activo | Agendar→iniciar→notas→grabación→APTO | COMPLETADA, validación APROBADA, RN-020 libre |
| B | pac.activo | Reservar servicio `requiere_telemedicina` antes/después | bloqueado / permitido |
| C | admin + pac.activo | Dictamen NO APTO | RECHAZADA, activo=false |
| D | admin | Forzar `enviar_recordatorios_entrevista()` | 1 notificación, sin duplicados |
| E | pac.* | Intentar RPC admin | `No autorizado` |
| F | pac.activo | Firmar consentimiento y unirse | firma en bucket, iframe activo |

## Hallazgos / gaps conocidos

1. La agenda admin **no tiene filtros de estado** en la UI (el cubit los soporta).
2. Un paciente con `profiles.activo=false` queda atrapado en `/complete-profile`
   por el `route_guard` y no puede abrir `/mi-entrevista` (posible mejora).
3. El diálogo de dictamen **no ofrece `REQUIERE_REVISION`** (solo Apto/No apto),
   aunque el enum/DB lo admiten.
4. Al confirmar "Agendar" en la pantalla de agendado **no** se exige el aviso
   ePHI (sí en el FAB, el detalle y el expediente).
5. **Jitsi público no es apto para ePHI real** (sin BAA); el detalle lo advierte.
   La grabación se adjunta manualmente al bucket privado.
6. No hay seed de paciente "pendiente de dictamen"; para probar ese estado habría
   que manipular validaciones (prueba con datos, fuera de este plan base).
7. El panel admin no permite **desactivar** cuestionarios (solo eliminar/activar).

## Notas

- Sin commit (regla del proyecto: preguntar antes).
