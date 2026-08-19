# Pruebas manuales — Flujo de salud del paciente (E2E)

| | |
|---|---|
| **Fecha** | 2026-08-19 |
| **Versión** | 1.0 |
| **Commit** | (pendiente) |
| **Entorno** | Local `flutter run -d chrome` en `localhost:5000` (NO el desplegado en web.app) |
| **Plan** | `docs/plans/2026-08-19_verificacion_salud_paciente_e2e.md` |
| **Confirmación de correo** | Desactivada en Supabase para pruebas |

## Cuentas

| Rol | Email | Clave |
|---|---|---|
| Administrador | `admin@strani.com` | `Test1234!` |
| Paciente nuevo (registrado en la app) | `pac.compliance1@test.com` | `Test1234!` |

## Checklist de aceptación

| # | Ítem | Resultado | Evidencia / observación |
|---|---|---|---|
| 1 | Se puede registrar un paciente | ✅ | Registrado en la app. BD: `profiles` id `e1db7e73-0f3d-4b37-aec0-99fea2c50ace` (role Paciente, `activo=false`) + `pacientes` id `818399b1-15dc-4848-a65a-2e221aa9cef3` (`activo=false`) creados por `handle_new_user`; puede autenticarse |
| 2 | Se puede crear y administrar un cuestionario | ✅ | "Crear nueva versión" en app creó `cuestionarios` id=5 "Cuestionario de Salud" **version=2, `activo=false`** (clonando preguntas desde v1) |
| 3 | Se pueden agregar y modificar preguntas | ✅ | Modificar: edición de la pregunta id=21 (síntomas, MULTIPLE) desde la app; opciones pasaron a incluir `Ansiedad`. Agregar: pregunta id=22 "¿Cuentas con seguro médico vigente?" (SI_NO) insertada por REST y vinculada a la **v2** (id=5) con `orden=11` → v2 queda con **11 preguntas**. Hallazgos B1-B3 (ver abajo) |
| 4 | El paciente puede responder el cuestionario desde Flutter | ⬜ | |
| 5 | Las respuestas quedan asociadas al paciente | ⬜ | |
| 6 | Se conserva la versión del cuestionario respondido | ⬜ | |
| 7 | Se puede registrar una evaluación de salud | ⬜ | |
| 8 | Se puede registrar una validación de Qualify | ⬜ | |
| 9 | El sistema calcula/respeta la fecha de vencimiento | ⬜ | |
| 10 | Una validación vencida impide continuar | ⬜ | |
| 11 | Una validación vigente permite continuar | ⬜ | |

## Datos de la prueba

- Paciente nuevo: `pac.compliance1@test.com`, rol Paciente (registrado en la app).
- Cuestionario objetivo: **"Cuestionario de Salud" id=4 v1 activa** (la más reciente por `created_at` → la que `fetchCuestionarioActivo` selecciona), 10 preguntas.
- Servicios activos: todos con `requiere_telemedicina=false` (hallazgo F0.3). Para ítems 10-11 se usa un servicio activo sin face map (p.ej. Cavitación Corporal `d727d7fb-…`); el gate de app bloquea/permite para cualquier servicio. Contra-prueba trigger RN-020 sobre `11111111-…` (Toxina, inactiva, `requiere_telemedicina=true`).

## Registro de ejecución

| Fase | Ítems | Resultado |
|---|---|---|
| F0 — Precondiciones | — | ⬜ |
| A — Alta de paciente | 1 | ✅ |
| B — Admin cuestionario | 2, 3 | ✅ |
| C — Cuestionario + evaluación + Qualify | 4, 5, 6, 7, 8, 9 | ✅ |
| D — Vigente permite continuar | 11 | ✅ |
| E — Vencida impide continuar | 10 | ✅ |
| F — Conservación de versión + cierre | 6, 11 | ✅ |

## Hallazgos F0

1. **3 cuestionarios `activo=true`** (id 1, 3, 4). `fetchCuestionarioActivo` toma el más reciente (id=4 "Cuestionario de Salud") → correcto, pero frágil.
2. **Pregunta #3 del Cuestionario de Salud (id=8, autoinmune) sin `riesgo`**: seed reutiliza por (texto,tipo) sin actualizar; la sentinela crítica no dispara. Las demás sentinelas (alergia, embarazo, cicatrización, tabaquismo) sí.
3. **Ningún servicio activo tiene `requiere_telemedicina=true`**. Gate de app bloquea/permite igual (ítems 10-11); trigger RN-020 se demuestra por contra-prueba SQL sobre servicio inactivo con la bandera.
4. `configuracion_sistema` no legible por PostgREST (RLS) → verificar `enforce_rn020` por SQL Editor.

## Hallazgos Fase B

1. **Bug `updatePregunta` (PGRST204)**: el datasource enviaba la columna `texto` inexistente → `Could not find the 'texto' column of 'preguntas'`. Corregido a `pregunta`. Requiere hot restart para ver el fix.
2. **Riesgo de edición con el diálogo anterior**: con el campo único de texto (una por línea) el usuario no detectó dónde escribir el síntoma y el guardado **sobrescribió el texto de la pregunta** (id=21 quedó `pregunta="Ansiedad"`). Se restauró el texto correcto por REST y se **rediseñó `_EditarPreguntaDialog`**: las opciones ahora son **chips** (se ven y se quitan con la X) + campo **blanco, enmarcado y con label** "Nuevo síntoma / opción" + botón **Agregar**; el campo de riesgo es un bloque aparte (evita confusiones). El guardado persiste la lista de chips.
3. **Riesgo JSON eliminado del diálogo de edición (decisión del usuario)**: se quitó el campo "Regla de riesgo (JSON)" de `_EditarPreguntaDialog`. El guardado envía `riesgo: null` → el `?riesgo` del payload no lo incluye → **las sentinelas de riesgo ya configuradas en BD se conservan** (el admin ya no puede editarlas desde la app por ahora).
4. **Bug de layout del diálogo (corregido, causa raíz)**: `Dialog` = `Align`→`ConstrainedBox(minWidth:280)`→`IntrinsicWidth` → el contenido recibe `280..Infinity`; con contenido con flex (`Flexible` del scroll + `Row` con `Flexible`/`Expanded` + `ElevatedButton`), el intrínseco es `Infinity` y `IntrinsicWidth` emite `tight(Infinity)` (`w=Infinity`) → **`ElevatedButton` (ButtonStyleButton) no tolera ancho infinito** → `BoxConstraints forces an infinite width` → el diálogo no se pinta y la app se cuelga en web (en widget-test no crashea: el `IntrinsicWidth` recibe ancho acotado). No bastaron: `Container(width:double.infinity)`→quitado, `Expanded`→`Flexible`, `ConstrainedBox(maxWidth:480)` debajo del `IntrinsicWidth`, ni `AlertDialog(constraints: maxWidth:480)` (el outer `IntrinsicWidth` de `_DialogSizes` está **arriba** del `Dialog`). **Fix definitivo (decisión del usuario)**: se eliminó el `ElevatedButton` y la `Row` del contenido; la nueva opción se agrega con **Enter** en el campo (`onSubmitted` → `_agregarOpcion`) con `prefixIcon "+"`. ✓ verificado en web (el diálogo abre y edita).
5. **Obligatoria no se reflejaba en la tarjeta (corregido, causa raíz)**: al guardar un cambio de `obligatoria` (id=21 persistido con `true` en BD vía `updatePregunta`), el reload en `AdminCuestionarioCubit.loadPreguntas` hacía `emit(copyWith(preguntas: ...))` que era **no-op**: `PreguntaEntity.props` (Equatable) solo tenía `[id, texto, tipo, orden]`, **omitía `obligatoria`** → el estado recargado (obligatoria=true) era `==` al anterior (false) → `emit` no disparaba rebuild → el chip seguía en "Opcional" (el SnackBar sí salía porque cambia `feedback`). **Fix**: se amplió `PreguntaEntity.props` a `[id, texto, tipo, opciones, riesgo, obligatoria, activo, orden]`. Verificado con test de cubit + repo fake (rojo antes, verde después) y `flutter test` completo en verde (95). ✓ verificado en web.
6. **Vista de preguntas del admin sin botón para volver (corregido)**: `AdminCuestionarioScreen` se navega con `context.go(AppRoutes.adminCuestionario)` desde el dashboard → GoRouter no pinta flecha de regreso. **Fix**: `leading` en el AppBar con `arrow_back_rounded` → `context.go(AppRoutes.adminDashboard)` (tooltip "Volver al panel admin"). ✓ verificado en web.

## Hallazgos Fase C

1. **El paciente respondió el v1 dos veces** (permite re-evaluar): la 1ª (13:52) dio `REQUIERE_REVISION` — respondió "Aspirina" en la pregunta 15 (medicamentos) y la **sentinela por patrón disparó** riesgo `[Medicación anticoagulante]`; la 2ª (13:53) dio `APTO` sin riesgos. La sentinela de riesgo funciona correctamente de extremo a extremo.
2. **Preguntas opcionales no enviadas no generan fila** en `respuestas_salud`: en la evaluación `APTO` faltan las filas de la pregunta 15 (texto, dejada en blanco) y 17 (numérica, omitida). No es un error: el RPC solo inserta las que llegan en el payload, y el cálculo de sentinelas usa `coalesce(v_valor,'')` (vacío no dispara).
3. **`respuestas_salud` guarda snapshot correcto**: `pregunta_texto` con el texto real de la pregunta (no corrupto), y por tipo: `respuesta_boolean` (SI_NO), `respuesta_fecha` (FECHA), `respuesta_json` (MULTIPLE) y `respuesta_texto` (TEXTO).
4. **`validaciones_telemedicina` de Fase C** (`1dfcd4ec`, proveedor Telemedicina): `fecha_validacion` 2026-08-19T13:53:40 y `fecha_vencimiento` 2027-08-19T13:53:40 → **+365 días exactos**. El usuario confirmó el modal con las fechas en pantalla.

## Hallazgos Fase D

1. **Banner del catálogo desincronizado (confirma el hallazgo esperado #3)**: `_buildStatusBanner` depende de `_evaluationStatus`, que solo se computa en `initState` (`_loadFlowStatus`). Si la pantalla `/services` ya estaba viva antes de que existiera la validación, al volver con `context.go('/services')` tras Qualify el widget se reutiliza y el banner queda en PENDIENTE (morado "Evaluación Médica requerida...") aunque la validación ya esté APROBADA. El tap sí valida en fresco (`ValidarAccesoRN020` en `_onServiceSelected`) → el modal abre permitido. **Con Ctrl+Shift+R el banner verde "Evaluación Aprobada (Telemedicina)" aparece** y el ítem 11 se verifica. Fix propuesto (pendiente): refrescar `_loadFlowStatus` al re-entrar a la ruta (p.ej. `RouteAware`/`didChangeDependencies` o re-validar al quedar visible).

## Hallazgos Fase E

1. **Banner vencido y modal de expiración en app** ✅: con `fecha_vencimiento` en el pasado, el catálogo muestra "⚠️ Evaluación Médica Expirada (Pasó 1 Año)" y al tocar un servicio sale el modal "Recordatorio de Expiración" (bloqueado, "Pagar $30 y Renovar"). Coherente con `ValidarAccesoRN020` (`VENCIDA → allowed:false`).
2. **`configuracion_sistema.enforce_rn020` está en `true`** (demostrado por la contra-prueba P0001; la fila no es legible por PostgREST por RLS).

## Contra-pruebas (triggers/RLS)

1. **Trigger RN-020 (Fase E)** ✅: con la validación vencida, `INSERT` en `solicitudes` (Toxina `11111111-…`, `requiere_telemedicina=true`) → `ERROR P0001: RN-020: El servicio requiere validación de telemedicina vigente (APROBADA, sin vencer)` desde `validar_rn020_solicitud()` (línea 29 RAISE). La regla está **activada en BD** (`enforce_rn020` verdadero), no solo en app.

## Hallazgos Fase F (renovación + conservación de versión)

1. **El botón "Pagar $30 USD y Renovar" iba al formulario de datos en vez de al pago (corregido)**: `_showExpirationReminderModal` hacía `context.push(AppRoutes.completeProfile)` → pantalla de perfil con datos ya ingresados. **Fix**: navega a `'${AppRoutes.completeProfile}?pago=1'` y `CompleteProfileScreen` lee `GoRouterState.of(context).uri.queryParameters['pago']` (leído en `didChangeDependencies`, no en `initState` — evita el error `dependOnInheritedWidgetOfExactType<_ModalScopeStatus>`) y al terminar de precargar datos abre **directo el modal "Paso 2: Pago de Cuota Inicial"** (skip del formulario). ✓ verificado en web.
2. **Banner del catálogo seguía desactualizado tras la renovación (corregido de raíz)**: pese a que con Ctrl+Shift+R aparecía, en el flujo real el widget de `/services` se reutiliza y `_evaluationStatus` quedaba en VENCIDA tras Qualify (el tap sí validaba en fresco). **Fix definitivo**: `ServicesDashboardScreen` ahora es `RouteAware`, con un `RouteObserver` global registrado en GoRouter (`observers: [routeObserver]`, parámetro correcto en `go_router ^14.6.3`, no `navigatorObservers`) y en `didPopNext` re-ejecuta `_loadFlowStatus()` → el banner se actualiza solo al volver a la pantalla. ✓ verificado en web.
3. **Renovación completa (ítems 6 + 11)** ✅: admin activó v2 → paciente "Pagar $30 y Renovar" (pago directo) → respondió el cuestionario **v2** (cuestionario id=5) → Qualify → nueva validación APROBADA. En BD: evaluación `476f21ee` con `version_cuestionario=2` (APTO); las previas `3dc2996a`/`ce529d81` **conservan `version_cuestionario=1`** (expediente clínico intacto); validación `1dfcd4ec` renovada: `fecha_validacion` 14:25:18, `fecha_vencimiento` +365 días exactos. Catálogo: banner verde y selección de servicio permitida.

## Resumen final (11 ítems)

| # | Ítem | Estado |
|---|---|---|
| 1 | Se puede registrar un paciente | ✅ |
| 2 | Se puede crear y administrar un cuestionario | ✅ |
| 3 | Se pueden agregar y modificar preguntas | ✅ |
| 4 | El paciente puede responder el cuestionario desde Flutter | ✅ |
| 5 | Las respuestas quedan asociadas al paciente | ✅ |
| 6 | Se conserva la versión del cuestionario respondido (expediente clínico) | ✅ |
| 7 | Se puede registrar una evaluación de salud | ✅ |
| 8 | Se puede registrar una validación de Qualify | ✅ |
| 9 | El sistema calcula/respeta la fecha de vencimiento | ✅ |
| 10 | Una validación vencida impide continuar | ✅ |
| 11 | Una validación vigente permite continuar | ✅ |