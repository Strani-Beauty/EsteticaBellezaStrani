# Plan: Verificación E2E del flujo de salud del paciente (11 ítems)

| | |
|---|---|
| **Fecha** | 2026-08-19 |
| **Estado** | APROBADO por el usuario (2026-08-19) |
| **Origen** | Checklist de aceptación del flujo salud/cuestionario/validación (commit `779bc74`) |
| **Proyecto Supabase** | `hhyjremkguvphmjuaazp` |

## Decisiones (confirmadas por el usuario)

- **Método**: manual en la app (`flutter run -d chrome`) con BD remota compartida + contra-pruebas en el SQL Editor de Supabase. Resultados en `docs/pruebas/2026-08-19_salud_paciente_e2e.md`.
- **Paciente nuevo**: se registra `pac.compliance1@test.com` / `Test1234!` desde la app (cubre el ítem 1 desde cero); correo confirmado por SQL.
- **Expediente clínico**: el cuestionario se guarda con fecha tantas veces como se requiera; cada evaluación conserva `fecha_evaluacion` + `version_cuestionario` + snapshot del texto de la pregunta. El vencimiento de 1 año (365 días) aplica solo a la validación Qualify/interna.
- **Versión v2**: se crea y activa a mitad de la prueba para validar la conservación de versión (ítem 6).

## Entorno

- App local (`flutter run -d chrome`): lo desplegado en https://esteticaybellezastrani.web.app NO tiene los cambios de hoy.
- BD remota compartida. Migración `20260818000300_salud_cuestionario_paciente_rls.sql` aplicada (verificada en `supabase migration list`).
- Cuentas: `admin@strani.com` / `Test1234!` + `pac.compliance1@test.com` / `Test1234!` (nueva).
- Servicios con `requiere_telemedicina=true` (seed): Toxina `11111111-1111-1111-1111-111111111111`, Ácido Hialurónico `22222222-…`, Peelings `33333333-…`, Microneedling `44444444-…`, Lipólisis `55555555-…`.

## Ítems a verificar

1. Se puede registrar un paciente.
2. Se puede crear y administrar un cuestionario.
3. Se pueden agregar y modificar preguntas.
4. El paciente puede responder el cuestionario desde Flutter.
5. Las respuestas quedan asociadas al paciente.
6. Se conserva la versión del cuestionario respondido (expediente clínico).
7. Se puede registrar una evaluación de salud.
8. Se puede registrar una validación de Qualify.
9. El sistema calcula/respeta la fecha de vencimiento.
10. Una validación vencida impide continuar con los servicios que la requieren.
11. Una validación vigente permite continuar con el proceso.

## Fases

- **F0 — Precondiciones**: confirmar en SQL Editor estado de `configuracion_sistema.enforce_rn020`, versiones de `cuestionarios`, servicios con `requiere_telemedicina`, y cuentas de prueba.
- **A (ítem 1)**: alta del paciente nuevo en la app (SignUp como Paciente) → confirmar correo por SQL → login → verificar `profiles` + `pacientes` (trigger `handle_new_user`).
- **B (ítems 2-3)**: admin → `/admin` → "Cuestionario de Salud": ver v1 activa + preguntas, editar una pregunta (texto/opciones), crear v2 (inactiva). **Agregar** pregunta vía SQL (insert `preguntas` + `cuestionario_preguntas`) y confirmarla en el cuestionario. — **✅ HECHO (2026-08-19)**: v2 id=5 creada (inactiva); edición de pregunta id=21 (síntomas MULTIPLE) con opción `Ansiedad` añadida (con bug B1 y rediseño B2, ver abajo).
- **C (ítems 4-9)**: paciente completa perfil (fecha_nacimiento/género) → pago $30 (Stripe simulado) → responde el cuestionario real (v1 activa, render por `tipo_respuesta`) → RPC `guardar_respuestas_evaluacion` (evaluación + respuestas con versión/snapshot) → modal de modalidad → Qualify simulado (3 s) → `registrar_validacion_telemedicina` APROBADA con `fecha_validacion`=hoy y `fecha_vencimiento`=+365 días → modal con ambas fechas. — **✅ HECHO (2026-08-19)**: 2 evaluaciones (1ª REQUIERE_REVISION por sentinela "Aspirina", 2ª APTO), versión 1 conservada, snapshot correcto, validación `1dfcd4ec` APROBADA con vencimiento exacto +365 días (ver Hallazgos Fase C).
- **D (ítem 11)**: catálogo → banner "Evaluación Aprobada" → seleccionar servicio con `requiere_telemedicina` (Toxina Botulínica) → modal de pago/reserva (permitido). — **✅ HECHO (2026-08-19)**: banner verde visible (con Ctrl+Shift+R por el bug de estado stale) y modal permitido. Fix del banner con `RouteAware` aplicado y verificado en Fase F.
- **E (ítem 10)**: SQL: vencer la validación (`fecha_vencimiento` al pasado) → catálogo muestra banner VENCIDA → seleccionar servicio → modal "Recordatorio de Expiración" (bloqueado). Contra-prueba trigger RN-020: INSERT `solicitudes` para Toxina → ERROR. — **✅ HECHO (2026-08-19)**: banner naranja + modal de expiración OK; contra-prueba `ERROR P0001 RN-020 ...` desde `validar_rn020_solicitud()` → regla activa en BD (`enforce_rn020=true`).
- **F (ítem 6 + cierre ítem 11)**: admin activa v2 → paciente "Pagar $30 y Renovar" → re-responde el cuestionario (v2, 11 preguntas) → nueva evaluación v2; la v1 previa conserva su versión → nueva validación APROBADA → catálogo permite de nuevo. — **✅ HECHO (2026-08-19)**: evaluación `476f21ee` v2 APTO; v1 previas conservadas; validación `1dfcd4ec` renovada (+365 días); banner verde automático tras fix `RouteAware`. Fijados además: pago directo en renovación (`?pago=1`) y banner re-validado con `RouteObserver`/`didPopNext`.

## SQL de apoyo (SQL Editor)

```sql
-- F0. Estado del sistema
select clave, valor, activo from public.configuracion_sistema where clave = 'enforce_rn020';
select id, nombre, version, activo from public.cuestionarios order by version;
select s.id, s.nombre, s.requiere_telemedicina, s.activo
from public.servicios s where s.activo order by s.nombre;

-- A. Confirmar correo + verificar alta
update auth.users set email_confirmed_at = now() where email = 'pac.compliance1@test.com';
select p.id, p.email, p.role, p.activo, pac.id as paciente_id, pac.activo as pac_activo
from profiles p left join pacientes pac on pac.usuario_id = p.id
where p.email = 'pac.compliance1@test.com';

-- B. Preguntas de la versión activa (orden) + agregar una nueva
select cp.orden, p.id, p.pregunta, p.tipo_respuesta, p.obligatoria
from public.cuestionario_preguntas cp
join public.preguntas p on p.id = cp.pregunta_id
join public.cuestionarios c on c.id = cp.cuestionario_id and c.activo = true
order by cp.orden;
-- (agregar: insert en preguntas + cuestionario_preguntas con orden N)

-- C. Evaluación, respuestas y validación del paciente
select e.id, e.version_cuestionario, e.resultado, e.riesgos, e.fecha_evaluacion
from public.evaluaciones_salud e
join public.pacientes p on p.id = e.paciente_id
join public.profiles pr on pr.id = p.usuario_id
where pr.email = 'pac.compliance1@test.com' order by e.created_at desc;

select e.id evaluacion, r.pregunta_id, r.pregunta_texto, r.respuesta_texto, r.respuesta_boolean
from public.respuestas_salud r
join public.evaluaciones_salud e on e.id = r.evaluacion_id
join public.pacientes p on p.id = e.paciente_id
join public.profiles pr on pr.id = p.usuario_id
where pr.email = 'pac.compliance1@test.com'
order by e.created_at desc, r.pregunta_id;

select v.estado, v.proveedor, v.codigo_referencia, v.fecha_validacion, v.fecha_vencimiento,
       (v.fecha_vencimiento - v.fecha_validacion) as validez
from public.validaciones_telemedicina v
join public.pacientes p on p.id = v.paciente_id
join public.profiles pr on pr.id = p.usuario_id
where pr.email = 'pac.compliance1@test.com' order by v.created_at desc;

-- E. Vencer la validación y contra-prueba trigger RN-020
update public.validaciones_telemedicina v
set fecha_vencimiento = now() - interval '1 day'
from public.pacientes p join public.profiles pr on pr.id = p.usuario_id
where v.paciente_id = p.id and pr.email = 'pac.compliance1@test.com'
  and v.estado = 'APROBADA' and v.fecha_vencimiento > now();

insert into public.solicitudes (paciente_id, servicio_id, estado, fecha_solicitud, deposito_requerido, deposito_pagado)
values ('<paciente_id>', '11111111-1111-1111-1111-111111111111', 'BORRADOR', now(), 100, false);
-- Esperado: ERROR P0001 RN-020.

-- F. Histórico de evaluaciones (expediente clínico)
select e.id, e.version_cuestionario, e.resultado, e.fecha_evaluacion
from public.evaluaciones_salud e
join public.pacientes p on p.id = e.paciente_id
join public.profiles pr on pr.id = p.usuario_id
where pr.email = 'pac.compliance1@test.com' order by e.created_at;
```

## Hallazgos esperados a confirmar

1. El panel admin **no expone "agregar pregunta"** (solo editar + crear versión + activar); agregar una pregunta exige SQL/seed. Evaluar mejora.
2. `crearNuevaVersion` (UI) **no copia `servicio_cuestionarios`** (el seed SQL sí). No afecta el flujo actual (el cuestionario se abre desde complete-profile, no por servicio), pero es deuda.
3. ~~Posible desincronización legacy `checkPatientFlowStatus` vs. datos limpios al renovar~~ → **CONFIRMADO y CORREGIDO**: el banner del catálogo quedaba stale al reutilizarse el widget; se fijó con `RouteAware` + `RouteObserver` (`didPopNext` → `_loadFlowStatus`). El tap siempre validaba en fresco (`ValidarAccesoRN020`).

## Hallazgos F0 (BD real, detectados en 2026-08-19)

1. **Hay 3 cuestionarios `activo=true`** ("Estética y Belleza General" id=1, "Evaluación Clínica General" id=3, "Cuestionario de Salud" id=4). `fetchCuestionarioActivo` toma el más reciente por `created_at` (id=4) → funciona, pero es frágil si se crea otro cuestionario nuevo.
2. **Pregunta #3 del "Cuestionario de Salud" (id=8, autoinmune) quedó sin `riesgo`**: el seed `_seed_pregunta` reutiliza por (texto,tipo) sin actualizar, y esa pregunta ya existía de un cuestionario previo. La sentinela crítica "Condición médica relevante" no dispara. Las demás sentinelas (alergia, embarazo, cicatrización, tabaquismo) sí existen.
3. **Ningún servicio `activo=true` tiene `requiere_telemedicina=true`** (los 5 del seed y los reales con esa bandera están `activo=false`). El gate de la app (`ValidarAccesoRN020`) bloquea todos los servicios al vencer (ítems 10-11 OK a nivel app); el trigger RN-020 a nivel BD solo se demuestra por contra-prueba SQL sobre un servicio con la bandera (p.ej. `11111111-…` Toxina, inactiva).
4. `configuracion_sistema` no es legible por PostgREST (RLS); se verifica `enforce_rn020` por SQL Editor.

## Hallazgos Fase B (2026-08-19)

1. **Bug `updatePregunta` (PGRST204)**: el datasource enviaba la columna `texto` inexistente de `preguntas` → `Could not find the 'texto' column...`. Corregido a `pregunta` en `patients_compliance_supabase_datasource.dart` (~L206).
2. **Riesgo de edición con el diálogo anterior**: con un solo campo de texto "una por línea" el usuario escribió `Ansiedad` en el campo de texto de la pregunta → el guardado **sobrescribió el texto** de id=21. Se restauró por REST el texto original + `Ansiedad` en `opciones`. **Rediseño del `_EditarPreguntaDialog`**: opciones como **chips editables** (X para quitar), campo **blanco, enmarcado y rotulado** "Nuevo síntoma / opción" + botón **Agregar**, bloque de riesgo aparte, guardado persiste la lista de chips. (`admin_cuestionario_screen.dart`)
3. **Pendiente de confirmar**: `_parseRiesgo('')` → `null` (no envía `riesgo` en el payload) al guardar con el diálogo nuevo; verificar que `riesgo` queda `null` y no un objeto vacío.
4. **Bug de layout del diálogo (corregido)**: `Dialog` = `Align`→`ConstrainedBox(minWidth:280)`→`IntrinsicWidth`. Con contenido con `Flexible`/flex (scroll + `Row` con flex), el intrínseco del contenido es `Infinity` → `IntrinsicWidth` recibe `280..Inf` y emite `tight(Infinity)` → `w=Infinity` al contenido → `ElevatedButton` crashea (`BoxConstraints forces an infinite width`) → el diálogo no se pinta y la app se cuelga en web. No bastaron los fixes intermedios (`Container(width:∞)`, `Expanded`→`Flexible`, `ConstrainedBox(maxWidth:480)` debajo del `IntrinsicWidth`, `AlertDialog(constraints:)` porque el outer `IntrinsicWidth` está arriba del `Dialog`). **Fix definitivo (decisión del usuario)**: se eliminó el `ElevatedButton` y la `Row`; la nueva opción se agrega con **Enter** (`onSubmitted` → `_agregarOpcion`) con `prefixIcon "+"` y hint "Escribe el síntoma y presiona Enter". ✓ verificado en web.
5. **Campo JSON de riesgo eliminado del diálogo (decisión del usuario)**: `onGuardar` envía `riesgo: null` → `'riesgo': ?riesgo` (null-aware spread) no incluye la clave → **las sentinelas de riesgo ya configuradas en BD se conservan**. ✓
6. **Obligatoria no se reflejaba en la tarjeta (corregido)**: `PreguntaEntity.props` (Equatable) omitía `obligatoria` → `emit` de recarga era no-op (estado recargado `==` anterior). Fix: `props = [id, texto, tipo, opciones, riesgo, obligatoria, activo, orden]` + `await result.fold(...)` con callbacks async en `crearNuevaVersion`/`activarVersion`/`editarPregunta`. ✓ verificado en web.
7. **Vista de preguntas del admin sin botón para volver (corregido)**: `context.go` no pinta flecha; se añadió `leading` arrow_back → `context.go(AppRoutes.adminDashboard)`. ✓ verificado en web.

## Hallazgos Fase C (2026-08-19)

1. **El paciente respondió el v1 dos veces**: 1ª evaluación (13:52) `REQUIERE_REVISION` — "Aspirina" en pregunta 15 disparó la **sentinela por patrón** `[Medicación anticoagulante]`; 2ª (13:53) `APTO` sin riesgos. La evaluación y el cálculo de riesgo funcionan de extremo a extremo.
2. **Preguntas opcionales sin enviar no generan fila** en `respuestas_salud` (pregunta 15 vacía y 17 omitida en la evaluación APTO). El RPC solo inserta lo que llega; `coalesce(v_valor,'')` no dispara sentinelas con vacío. OK.
3. **Snapshot correcto por tipo**: `respuesta_boolean` (SI_NO), `respuesta_fecha` (FECHA), `respuesta_json` (MULTIPLE), `respuesta_texto` (TEXTO) con el texto real de la pregunta.
4. **`validaciones_telemedicina`** (`1dfcd4ec`): APROBADA, proveedor Telemedicina, `fecha_vencimiento - fecha_validacion = 365 días` exactos. Modal mostrado al usuario.

## Cierre

- Registrar resultados ítem por ítem en `docs/pruebas/2026-08-19_salud_paciente_e2e.md`.
- Si hay hallazgos: proponer fix, aplicar y re-verificar.
- Commit del doc (preguntar antes de commitear).