# Prueba manual UI completa — Integración General (PENDIENTE documentado)

| | |
|---|---|
| **Fecha** | 2026-09-02 |
| **Versión** | 1.0 |
| **Entorno** | Desplegado en `https://esteticaybellezastrani.web.app` o local `flutter run -d web-server --web-port 8080` |
| **Plan** | `docs/plans/2026-09-02_integracion_pruebas_e2e.md` |
| **Proyecto Supabase** | `hhyjremkguvphmjuaazp` |

## Estado

- La validación de extremo a extremo de las **15 actividades se ejecutó por simulación
  RPC/BD** (scripts `verify_e2e_consistencia.js`, `verify_e2e_flujos.js`,
  `verify_e2e_integral.js`, todos con ROLLBACK) — ver
  `docs/pruebas/2026-09-02_integracion_e2e_log.md` (B: 18 PASS/1 hallazgo, C: 18/18,
  D: 8/8).
- **Este checklist es la prueba MANUAL en la interfaz web, pendiente de ejecutar**
  con las cuentas de prueba. Cada ítem se completa al verificar visualmente el flujo.

## Cuentas (clave `Test1234!`)

| Rol | Email | Notas |
|---|---|---|
| Administrador | `admin@test` | Panel admin completo |
| Especialista (habilitado) | `especialista1@test.com` | APROBADO, con geo, en línea, pasa habilitación |
| Especialista (habilitado 2) | `esp.compliance1@test.com` | APROBADO, con geo, pasa habilitación |
| Especialista (control negativo) | `esp.aprobado@test` | APROBADO pero **sin geo** (no ve solicitudes en marketplace) |
| Paciente activo | `pac.activo@test` | Onboarding completo, dirección + telemedicina |
| Paciente nuevo | `pac.nuevo@test` | Inactivo → debe completar onboarding |

## Checklist de aceptación

| # | Actividad | Ítem manual | Resultado | Evidencia / observación |
|---|---|---|---|---|
| 1 | Act 1 | Registrar un especialista nuevo, subir documentos (3 requeridos + contrato + médico regente + especialidad) y verificar que el admin lo aprueba desde `/admin/licencias`; el especialista recibe la notificación "Verificación aprobada" y puede activar disponibilidad | ☐ PENDIENTE | |
| 2 | Act 2 | Registrar `pac.nuevo@test`: completar perfil → dirección (geocodificación) → cuota $30 → cuestionario de salud → modalidad → telemedicina APROBADA → queda `activo` y puede reservar | ☐ PENDIENTE | |
| 3 | Act 3 | Como paciente activo: elegir servicio en catálogo → resumen → dirección → pago depósito (Stripe test 4242...) → la solicitud aparece en "Mis solicitudes" como PUBLICADA | ☐ PENDIENTE | |
| 4 | Act 4 | Como `especialista1@test.com`: el mapa del marketplace muestra la solicitud con coordenadas aproximadas; `esp.aprobado@test` (sin geo) NO la ve | ☐ PENDIENTE | |
| 5 | Act 5 | First-Accept: el primer especialista que acepta crea la cita; un segundo intento devuelve "asignada/vencida" | ☐ PENDIENTE | |
| 6 | Act 6 | Antes de aceptar, la hoja del paciente NO muestra dirección ni teléfono; después de aceptar, el detalle de la cita sí muestra la dirección exacta y permite navegar | ☐ PENDIENTE | |
| 7 | Act 7 | Ciclo de atención completo en la cita: comenzar desplazamiento → (simular) llegada → iniciar servicio → firmar consentimiento → evaluar → productos → fotografías PRE/POST → face map → revisar y finalizar → cita FINALIZADA + tratamiento COMPLETADO | ☐ PENDIENTE | |
| 8 | Act 8 | Financiero: el paciente paga el saldo (Stripe) tras el servicio → transacción SALDO APROBADO → el admin ve la transacción y el detalle financiero por cita en `/admin/conciliacion` | ☐ PENDIENTE | |
| 9 | Act 9 | Admin genera el corte semanal (`/admin/datos-maestros/comisiones`): agrupa por especialista con bruto/comisión/neto y detalle por cita; sin duplicados | ☐ PENDIENTE | |
| 10 | Act 10 | Admin aprueba la liquidación (EN_REVISION→APROBADA) y registra pago manual con método/referencia/comprobante → liquidación PAGADA; el especialista ve su historial y el comprobante firmado en "Mis liquidaciones" | ☐ PENDIENTE | |
| 11 | Act 11 | Notificaciones push/in-app: paciente recibe "Solicitud aceptada", "Especialista en camino", "Cita completada"; especialista recibe "Nueva solicitud en tu zona", "Liquidación pagada"; campana con contador | ☐ PENDIENTE | |
| 12 | Act 12 | Calificaciones post-atención: el paciente califica al especialista (1-5 + comentario) desde "Mis solicitudes" (FINALIZADA); el especialista califica al paciente desde el detalle de la cita finalizada; el promedio aparece en la hoja del especialista del mapa y en su perfil | ☐ PENDIENTE | |
| 13 | Act 13 | Consistencia de estados: recorrer las pantallas verificando que estados de solicitud/cita/pago/tratamiento/liquidación se muestran coherentes y que no hay montos en cero | ☐ PENDIENTE | |
| 14 | Act 14 | Anotar en este checklist cualquier error/inconsistencia visualizado (nuevo hallazgo manual) | ☐ PENDIENTE | |
| 15 | Act 15 | Prueba integral en vivo: 2 pacientes + 2 especialistas, 2 solicitudes simultáneas, 1 cita completada + 1 cancelada, finanzas, calificaciones, notificaciones, KPI del dashboard admin | ☐ PENDIENTE | |

## Comandos de verificación

```powershell
flutter analyze
flutter test
```

## Notas

- La activación de la telemedicina en la UI usa el RPC `registrar_validacion_telemedicina`
  (en pruebas el proceso se dispara desde el selector de modalidad con un delay simulado).
- En producción `enforce_pago_real` debe pasar a `true` y `simular_llegada` a `false`.
- Los flujos ya validados a nivel BD se listan en el log `2026-09-02_integracion_e2e_log.md`;
  este checklist solo cubre la verificación visual/interactiva en la interfaz.