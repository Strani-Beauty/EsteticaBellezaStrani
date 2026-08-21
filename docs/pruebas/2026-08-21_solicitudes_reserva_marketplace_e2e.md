# Pruebas manuales — Solicitudes, Reserva y Marketplace (E2E)

| | |
|---|---|
| **Fecha** | 2026-08-21 |
| **Versión** | 1.0 |
| **Commit** | (pendiente) |
| **Entorno** | Local `flutter run -d web-server --web-port 8080` (NO el desplegado en web.app) |
| **Plan** | `docs/plans/2026-08-21_solicitudes_reserva_marketplace.md` |
| **Proyecto Supabase** | `hhyjremkguvphmjuaazp` |
| **Confirmación de correo** | Desactivada en Supabase para pruebas |

## Configuración previa

- Migración `20260821000100_solicitudes_reserva_marketplace.sql` aplicada (SQL Editor o `supabase db push`).
- `configuracion_sistema.enforce_pago_real = 'false'` (pruebas simuladas sin dinero real). Para validar el gate de producción, cambiarlo a `'true'`.
- Stripe en test mode (tarjeta `4242 4242 4242 4242`) o modo simulado (`STRIPE_SIM_…` sin clave).

## Cuentas

| Rol | Email | Clave |
|---|---|---|
| Paciente con APTO + dirección principal | `pac.compliance1@test.com` | `Test1234!` |
| Especialista APROBADO (coincide) | `esp.aprobado@test` | `Test1234!` |
| Especialista APROBADO (coincide, 2º para concurrencia) | `esp.aprobado2@test` | `Test1234!` |

## Checklist de aceptación — flujo paciente (Act. 1-7)

| # | Ítem | Resultado | Evidencia / observación |
|---|---|---|---|
| P1 | Seleccionar un servicio del catálogo → abre el Resumen (no pago directo) | | |
| P2 | Resumen muestra servicio(s), precio total, depósito (adelanto %) y saldo | | |
| P3 | Multi-servicio: "Agregar" otro servicio recalcula total y depósito | | |
| P4 | Fecha/hora preferida y radio configurado visibles en el resumen | | |
| P5 | Dirección principal cargada (sin dirección → bloqueo con aviso) | | |
| P6 | Confirmar → solicitud `PENDIENTE_PAGO` + `solicitud_detalles` + `pagos` PARCIAL | | |
| P7 | Pagar depósito (4242) → confirmación → `PUBLICADA` con `fecha_expiracion` y `radio_busqueda` | | |
| P8 | Con `enforce_pago_real=true`, el paciente no puede publicar por su cuenta (solo webhook) | | |
| P9 | "Mis Solicitudes" lista la solicitud con estado y montos | | |

## Checklist de aceptación — marketplace y cita (Act. 8-14)

| # | Ítem | Resultado | Evidencia / observación |
|---|---|---|---|
| M1 | La solicitud aparece solo a especialistas APROBADOS dentro del radio (geofencing) | | |
| M2 | El mapa muestra la solicitud multi-servicio (nombres, cantidades, total) y la preferencia de fecha | | |
| M3 | El especialista solo ve ubicación aproximada (3 decimales) + ciudad, sin dirección (RN-018) | | |
| M4 | First-Accept: 2 especialistas aceptan a la vez → 1 gana, el otro recibe aviso | | |
| M5 | Al aceptar se crea la cita PROGRAMADA con `fecha_inicio = fecha_programada` y solicitud `ACEPTADA` | | |
| M6 | El ganador ve la dirección exacta en Mis Citas → detalle (RLS asignado) | | |
| M7 | `historial_estados` registra SOLICITUD (creación, publicación, aceptación) y CITA (programada) | | |
| M8 | Los especialistas del radio (excepto ganador) reciben notificación `SOLICITUD_ASIGNADA` | | |

## Comandos de verificación

```powershell
flutter analyze
flutter test
```

## Estado

- Migración aplicada al remoto: **[x] sí** (SQL Editor + fixes 00200/00300/00400; registradas en `schema_migrations`).
- Smoke tests BD (con rollback): crear → confirmar → PUBLICADA → aceptar → cita + historial + notificaciones **OK**.
- `flutter analyze`: 0 issues
- `flutter test`: 141/141
- **Pendiente**: ejecutar el checklist E2E en la app (`flutter run -d web-server --web-port 8080`).
