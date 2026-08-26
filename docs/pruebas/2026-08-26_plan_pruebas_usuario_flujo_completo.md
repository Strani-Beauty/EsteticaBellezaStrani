# Plan de pruebas de usuario — Flujo completo (Paciente + Especialista)

| | |
|---|---|
| **Fecha** | 2026-08-26 |
| **Versión** | 1.0 |
| **Entorno** | Local `flutter run -d web-server --web-port 8080` o desplegado en web.app |
| **Proyecto Supabase** | `hhyjremkguvphmjuaazp` |
| **Alcance** | Flujo completo del producto: registro → verificación → marketplace → cita → tratamiento |
| **Estado del código** | ⚠️ **EN DESARROLLO** — ver aviso abajo |

> **⚠️ AVISO DE DESARROLLO**
> La aplicación está **en desarrollo activo**. Los módulos implementados se prueban de punta a punta,
> pero el producto **no es apto para producción** y existen partes pendientes o simuladas:
>
> - Evaluación médica **simulada** (Qualify no se integra: la evaluación tarda ~3 s con `Future.delayed`).
> - Pagos Stripe en **modo simulado** (`STRIPE_SIM_<timestamp>`) si no hay `STRIPE_PUBLISHABLE_KEY` o en web.
> - Preguntas tipo `archivo`/`imagen` del cuestionario con placeholder («estará disponible próximamente»).
> - «Cancelación total del servicio» (pago directo del servicio sin solicitud) aún **no implementado**.
> - `buscar_especialistas_cercanos` existe en BD pero **no se usa** en la app.
> - Módulo `reports_dashboards` **vacío** (sin pantallas ni rutas).
> - Ruta `/payment/:id` definida pero **sin pantalla** (muerta).
> - Push FCM **pendiente de verificación** con dispositivo real.
> - Cualquier fallo durante las pruebas debe reportarse (plantilla de bug al final).

## Cuentas de prueba

Clave común: `Test1234!` (matriz seed en `supabase/migrations/20260814000100_seed_cuentas_matriz_prueba.sql`).

| Cuenta | Rol | Estado requerido | Uso en este plan |
|---|---|---|---|
| `pac.nuevo@test` | Paciente | Recién registrado, perfil incompleto | Recorre el onboarding completo (P1–P8) |
| `esp.nuevo@test` | Especialista | Recién registrado, sin perfil | Recorre el onboarding + verificación (E1–E5) |
| `admin@test` | Administrador | Activo | Aprueba documentos y especialista (E5) |
| `pac.activo@test` | Paciente | Evaluación APROBADA vigente, pagos completos | Atajo: probar P4–P8 sin onboarding |
| `esp.aprobado@test` | Especialista | `APROBADO`, contrato firmado, con ubicación | Atajo: probar E6–E10 sin verificación |

> Atajos: si no quieres repetir el onboarding, usa `pac.activo@test` y `esp.aprobado@test`
> (ya seedeados con los estados requeridos).

## Prerrequisitos

- `.env` con `SUPABASE_URL` y `SUPABASE_ANON_KEY` válidos (sin ellos la app muestra error al arrancar).
- Edge function `geocode-address` desplegada (geocodificación de direcciones en perfil/onboarding).
- Confirmación de correo: SMTP configurado **o** alternativamente usar el enlace generado en
  Authentication → Logs / Emails del Dashboard.
- Stripe en modo simulado (sin publishable key) — los cobros devuelven referencia `STRIPE_SIM_*`.
- Migraciones aplicadas al remoto (incluida `20260826000100_face_map_puntos_producto_trazabilidad.sql`).
- **Dos sesiones** (p. ej. pestañas/navegadores o ventanas) o dos dispositivos para el flujo
  especialista (una para `pac.nuevo@test`, otra para `esp.nuevo@test`/`admin@test`).
- Para el tratamiento con cámara/fotos: `image_picker` (en web abre selector de archivos).

## FLUJO PACIENTE — pasos uno a uno

### P1. Ingreso (registro + login)

| # | Ítem | Resultado | Evidencia / observación |
|---|---|---|---|
| P1.1 | En `/` (Welcome) pulsar «Agendar Cita / Soy Paciente» | | |
| P1.2 | En `/login`, tarjeta **Cliente/Paciente** → «Registrar cuenta de Paciente» | | |
| P1.3 | Completar: **Nombre Completo**, Teléfono (opcional), **Correo** (`pac.nuevo@test`), **Contraseña** (≥6) | | |
| P1.4 | Confirmar el correo (enlace en email o en Authentication → Logs) | | |
| P1.5 | Ingresar con `pac.nuevo@test` / `Test1234!` → redirige a completar perfil | | |

> Ya probado: `docs/Pruebas manuales/01_auth_users.md`.

### P2. Perfil completo

| # | Ítem | Resultado | Evidencia / observación |
|---|---|---|---|
| P2.1 | En `/complete-profile`: elegir **avatar** | | |
| P2.2 | **Teléfono de contacto** (obligatorio) | | |
| P2.3 | **Fecha de nacimiento** (date picker) y **Género** (dropdown) | | |
| P2.4 | **Dirección**: escribir dirección → geocodifica → fijar **PIN** en el mapa (lat/lng visibles) | | |
| P2.5 | Pulsar «Guardar e Ir a Pago Stripe ($30)» | | |

### P3. Pago inicial (cuota $30)

| # | Ítem | Resultado | Evidencia / observación |
|---|---|---|---|
| P3.1 | Se abre modal «Paso 2: Pago de Cuota Inicial» por $30 (o «Posponer») | | |
| P3.2 | Pagar (Stripe simulado) → `profiles.payment_completed=true`, `pacientes.activo=true` | | |
| P3.3 | Tras pagar se abre el **cuestionario** (continuar a P5) | | |

> Ya probado: `docs/pruebas/2026-08-19_salud_paciente_e2e.md` (11/11).

### P4. Catálogo → Face Map del paciente (solo si el servicio lo requiere)

| # | Ítem | Resultado | Evidencia / observación |
|---|---|---|---|
| P4.1 | Ir a `/services` (Catálogo), seleccionar un servicio **facial/inyectable** (p. ej. Toxina) | | |
| P4.2 | Si el servicio `requiereFaceMap` o es inyectable → se abre el **Face Map** | | |
| P4.3 | Marcar **≥1 punto** en el canvas (3 vistas: perfil izq / frente / perfil der); comprobar zonas prohibidas (ojos, nariz…) | | |
| P4.4 | Pulsar «Guardar Mapeo en Supabase» → `face_maps` + `face_map_puntos` creados | | |
| P4.5 | Verificar que al re-seleccionar el servicio el mapa vuelve en **solo lectura** (tratamiento aún abierto) | | |

> Si el servicio no es facial/inyectable, se salta este paso. Ya probado (parcial): Face Map del paciente vía
> `patients_compliance` (legacy).

### P5. Encuesta de salud

| # | Ítem | Resultado | Evidencia / observación |
|---|---|---|---|
| P5.1 | Responder el **cuestionario activo** (tipos: sí/no, texto, número, decimal, fecha, lista, múltiple) | | |
| P5.2 | Pulsar «Enviar y Evaluar con Qualify» → RPC `guardar_respuestas_evaluacion` | | |
| P5.3 | Se muestra el **dictamen** (APTO / REQUIERE_REVISION / NO_APTO) | | |

> Ya probado: `docs/pruebas/2026-08-19_salud_paciente_e2e.md` (11/11).

### P6. Evaluación médica

| # | Ítem | Resultado | Evidencia / observación |
|---|---|---|---|
| P6.1 | Si **APTO** → elegir modalidad (Medicina Interna / Telemedicina) → validación registrada (validez 365 días) | | |
| P6.2 | Con `pac.vencido@test` → el catálogo pide **renovar** ($30) | | |
| P6.3 | Con `pac.rechazado@test` → catálogo **bloquea** (dictamen NO APTO) | | |
| P6.4 | Consultar estado en `/estado-salud` (cuota, cuestionario, evaluación, vencimiento) | | |

> Ya probado: `docs/pruebas/2026-08-19_salud_paciente_e2e.md` (11/11). La evaluación es **simulada** (ver aviso).

### P7. Pago del servicio (total o parcial) y publicación

| # | Ítem | Resultado | Evidencia / observación |
|---|---|---|---|
| P7.1 | Desde el catálogo seleccionar servicio(s) con **cantidad** → `SolicitudResumenScreen` | | |
| P7.2 | Configurar **fecha/hora preferida**, **dirección** (guardada) y **radio de búsqueda** | | |
| P7.3 | Elegir pago **parcial** (adelanto 50% por defecto) o **totalidad** (switch) | | |
| P7.4 | Pulsar pagar → Stripe (simulado) → RPC `crear_solicitud_reserva` + `confirmar_deposito_solicitud` | | |
| P7.5 | La solicitud queda **PUBLICADA / BUSCANDO_ESPECIALISTA** | | |

> Ya probado: `docs/pruebas/2026-08-21_solicitudes_reserva_marketplace_e2e.md` (14/14) y
> `docs/pruebas/2026-08-20_catalogos_servicios_e2e.md` (R1–R6 + A–H).

### P8. Ubicación en marketplace y seguimiento

| # | Ítem | Resultado | Evidencia / observación |
|---|---|---|---|
| P8.1 | Ir a `/mis-solicitudes`: ver la solicitud con estado **BUSCANDO_ESPECIALISTA**, total, depósito y saldo pendiente | | |
| P8.2 | (Con el especialista E7) la solicitud pasa a **ACEPTADA** y aparece la cita asignada | | |
| P8.3 | (Con el especialista E8) ver el cambio de estado de la cita en tiempo real (notificación/estado) | | |

> Ya probado (parcial): `docs/pruebas/2026-08-21_solicitudes_reserva_marketplace_e2e.md` (14/14).

## FLUJO ESPECIALISTA — pasos uno a uno

### E1. Ingreso (registro + login)

| # | Ítem | Resultado | Evidencia / observación |
|---|---|---|---|
| E1.1 | En `/` (Welcome) pulsar «Especialistas / Acceso profesional» | | |
| E1.2 | En `/login`, tarjeta **Especialista** → «Registrar cuenta de Especialista» | | |
| E1.3 | Completar: **Nombre Completo**, Teléfono (opcional), **Correo** (`esp.nuevo@test`), **Contraseña** | | |
| E1.4 | Confirmar el correo y **ingresar** → redirige al onboarding | | |

> Ya probado: `docs/Pruebas manuales/01_auth_users.md` y `02_specialists.md`.

### E2. Onboarding (datos personales y profesionales)

| # | Ítem | Resultado | Evidencia / observación |
|---|---|---|---|
| E2.1 | Paso 1 — Datos personales: **nombre**, **teléfono**, **tarifa/hora (USD)**, **dirección** + geocodificación + **PIN** | | |
| E2.2 | Paso 2 — Datos profesionales: **número de licencia**, **médico regente** (o «Registrar nuevo»), **especialidades** | | |
| E2.3 | «Continuar a documentos» → crea `especialistas` en `PENDIENTE` + `ubicaciones_especialista` | | |

### E3. Licencia y documentos

| # | Ítem | Resultado | Evidencia / observación |
|---|---|---|---|
| E3.1 | Subir **Identificación oficial** (cédula/pasaporte) | | |
| E3.2 | Subir **Licencia profesional** | | |
| E3.3 | Subir **Formación** (DIPLOMA o CERTIFICACION) | | |
| E3.4 | Los documentos van a `documentos-especialistas` (bucket privado, path `<especialistaId>/…`) y quedan `PENDIENTE` | | |
| E3.5 | «Continuar» → solicitar verificación → especialista pasa a **EN_REVISION** | | |

> Ya probado: `docs/pruebas/2026-08-18_compliance_e2e.md` (12/12).

### E4. Contrato (opcional)

| # | Ítem | Resultado | Evidencia / observación |
|---|---|---|---|
| E4.1 | Desde el home, tarjeta «Firmar contrato» → `ContractSignatureScreen` | | |
| E4.2 | Firma manuscrita → sube al bucket `contratos` y registra `contratos` firmado (TOUCH) | | |

### E5. Aprobación administrativa

| # | Ítem | Resultado | Evidencia / observación |
|---|---|---|---|
| E5.1 | Con `admin@test` → `/admin/licencias` (`AdminLicenciasScreen`) | | |
| E5.2 | Ver **documentos** del especialista (URL firmada) y **aprobar/rechazar** cada uno | | |
| E5.3 | Comprobar el **expediente** (checklist: documentos aprobados, médico regente activo, ≥1 especialidad, contrato) | | |
| E5.4 | **Aprobar al especialista** (botón verde; deshabilitado si el expediente no cumple) → `APROBADO`, `activo=true` | | |
| E5.5 | (Opcional) Probar **Rechazar** (motivo visible para el especialista) y **Bloquear** | | |

> Ya probado: `docs/pruebas/2026-08-18_compliance_e2e.md` (12/12).

### E6. Ubicación en marketplace

| # | Ítem | Resultado | Evidencia / observación |
|---|---|---|---|
| E6.1 | En el home del especialista activar **Disponibilidad** (switch) | | |
| E6.2 | Conectarse (online: `PresenceService` mantiene `ultima_conexion`) | | |
| E6.3 | Verificar que el especialista aparece en el **mapa** de especialistas aprobados | | |

### E7. Selección de paciente

| # | Ítem | Resultado | Evidencia / observación |
|---|---|---|---|
| E7.1 | `/specialist/map` → ver solicitudes publicadas (pines verdes, datos **anonimizados**) y especialistas online (pines morados) | | |
| E7.2 | Seleccionar la solicitud de `pac.nuevo@test` → bottom sheet con detalle (servicios, precio, preferencia, distancia) | | |
| E7.3 | «Asignarme este paciente» → RPC `aceptar_solicitud` («primer aviso gana») → **cita creada** | | |
| E7.4 | Intentar asignar la misma solicitud desde otra sesión → «ya asignado/expirada» | | |

> Ya probado: `docs/pruebas/2026-08-21_solicitudes_reserva_marketplace_e2e.md` (14/14).

### E8. Cita (ciclo de ejecución)

| # | Ítem | Resultado | Evidencia / observación |
|---|---|---|---|
| E8.1 | `/specialist/mis-citas` → la cita aparece en **Activas** (PROGRAMADA) | | |
| E8.2 | «Comenzar desplazamiento» → **EN_CAMINO** (+ «Navegar al domicilio») | | |
| E8.3 | «Llegué al domicilio» → GPS → **LLEGO** + se muestra la distancia recorrida | | |
| E8.4 | «Iniciar servicio» → **EN_PROCESO** + se **crea el tratamiento** en `PENDIENTE_FIRMA` | | |
| E8.5 | Se abre **Firma del consentimiento** (primer paso obligatorio; el resto bloqueado hasta firmar) | | |
| E8.6 | Firmar → sube al bucket privado `firmas-consentimiento` y el tratamiento pasa a **EN_PROCESO** | | |
| E8.7 | (Negativo) «Cancelar cita» con motivo → **CANCELADA** + historial | | |

> Ya probado: `docs/pruebas/2026-08-24_citas_logistica_e2e.md` (12/14; pendientes ítems 7 y 14).

### E9. Tratamiento PRE

| # | Ítem | Resultado | Evidencia / observación |
|---|---|---|---|
| E9.1 | **Evaluación inicial** (anamnesis) → `evaluacion_inicial` | | |
| E9.2 | **Insumos**: «Agregar insumo» (nombre, fabricante, lote, cantidad, unidad sugerida según `tipo_precio`) | | |
| E9.3 | **Fotos PRE**: desde `/tratamiento/:id/fotos` capturar/seleccionar → bucket privado `fotografias-tratamiento` | | |
| E9.4 | **Face Map del especialista**: `/tratamiento/:id/face-map` → marcar puntos, tocar un punto y **elegir/crear insumo** con **cantidad + unidad + nota** por punto | | |
| E9.5 | «Guardar Face Map» → `face_maps`/`face_map_puntos` con `producto_id`, `cantidad`, `unidad_medida`, `observaciones` | | |
| E9.6 | Comprobar badges por punto («sin producto» / cantidad+unidad) | | |

> Ya probado (parcial): `docs/pruebas/2026-08-25_treatment_execution_e2e.md` (X/12 por completar) y
> `docs/pruebas/2026-08-26_face_map_productos_cierre_e2e.md` (X/10 por completar).

### E10. Tratamiento POST y cierre

| # | Ítem | Resultado | Evidencia / observación |
|---|---|---|---|
| E10.1 | **Fotos POST** (tipo POST en el dropdown) desde la pantalla de fotografías | | |
| E10.2 | «Revisar y finalizar» → `RevisionFinalScreen` con puntos, productos, cantidades, fotos PRE/POST y notas | | |
| E10.3 | **Gate de evidencia mínima**: si falta firma, ≥1 foto PRE, ≥1 foto POST, evaluación o face map completo → alerta y NO cierra | | |
| E10.4 | **Cobro de saldo** (Stripe simulado) si `saldoPendiente > 0` | | |
| E10.5 | «Confirmar y finalizar» → tratamiento **COMPLETADO** + cita **FINALIZADA** + `historial_estados` | | |
| E10.6 | Verificar que la cita desaparece de «Activas» y pasa a Historial | | |

> Ya probado (parcial): `docs/pruebas/2026-08-26_face_map_productos_cierre_e2e.md` (X/10 por completar).

## Comandos de verificación

```powershell
flutter analyze
flutter test
```

## Registro de ejecución

| Fase | Ítems | Resultado |
|---|---|---|
| P1–P3 (auth + perfil + cuota) | P1.1–P3.3 | ✔ ya probado (ref `01_auth_users`, `2026-08-19`) |
| P4 (face map paciente) | P4.1–P4.5 | ⬜ pendiente |
| P5–P6 (encuesta + evaluación) | P5.1–P6.4 | ✔ ya probado (ref `2026-08-19`, 11/11) |
| P7–P8 (pago + marketplace) | P7.1–P8.3 | ✔ ya probado (ref `2026-08-21`, 14/14) |
| E1–E4 (auth + onboarding + docs + contrato) | E1.1–E4.2 | ✔ ya probado (ref `01_auth_users`, `02_specialists`, `2026-08-18`) |
| E5 (aprobación admin) | E5.1–E5.5 | ✔ ya probado (ref `2026-08-18`, 12/12) |
| E6–E7 (marketplace + asignación) | E6.1–E7.4 | ✔ ya probado (ref `2026-08-21`, 14/14) |
| E8 (cita) | E8.1–E8.7 | ✔ parcial (ref `2026-08-24`, 12/14) |
| E9–E10 (tratamiento PRE/POST + cierre) | E9.1–E10.6 | ⬜ pendiente (ref `2026-08-25`, `2026-08-26`) |

## Estado

- `flutter analyze`: 0 issues.
- `flutter test`: 366/366.
- Ítems ya probados con evidencia en los docs de `docs/pruebas/` referenciados arriba.
- Ítems pendientes de control manual: **X/… PASS** (completar tras la ejecución).

## Plantilla de reporte de bug

```
Bug ID: B-USU-<n>
Caso relacionado: <P1.1 | E5.4 | …>
Pasos para reproducir:
Resultado observado:
Resultado esperado:
Severidad: Crítica / Alta / Media / Baja
Evidencia: captura / log / fila de BD
```