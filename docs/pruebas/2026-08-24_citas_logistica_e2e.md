# Pruebas manuales — Gestión de Citas y Logística del Servicio (E2E)

| | |
|---|---|
| **Fecha** | 2026-08-24 |
| **Versión** | 1.0 |
| **Commit** | (pendiente) |
| **Entorno** | Local `flutter run -d web-server --web-port 8080` o desplegado en web.app |
| **Plan** | `docs/plans/2026-08-24_citas_logistica.md` |
| **Proyecto Supabase** | `hhyjremkguvphmjuaazp` |

## Cuentas

| Rol | Email | Clave |
|---|---|---|
| Especialista | (usuario especialista APROBADO) | (su clave) |
| Paciente | (usuario paciente) | (su clave) |

## Prerrequisitos

- Migración `20260824000100_cita_estados_logistica.sql` **aplicada al remoto**
  (2026-08-24, `supabase db push` vía pooler sesión 6543).
- Un especialista APROBADO + activo, un paciente con solicitud reservada y
  depósito pagado (flujo de marketplace ya existente).

## Checklist de aceptación

| # | Ítem | Resultado | Evidencia / observación |
|---|---|---|---|
| 1 | `/specialist/mis-citas` muestra 2 tabs: **Activas** (pendientes/próximas) e **Historial** (finalizadas/canceladas/no completadas) | | |
| 2 | En detalle de cita (PROGRAMADA) aparece "Comenzar desplazamiento" y "Navegar al domicilio" | | |
| 3 | Al pulsar "Navegar al domicilio" se abre la app de mapas con el destino (lat/lon del domicilio; fallback a búsqueda por dirección) | | |
| 4 | La dirección exacta del paciente NO se muestra en el mapa de solicitudes públicas (solo lat/lon aproximada ~110 m); se ve completa solo en la cita aceptada | | |
| 5 | "Comenzar desplazamiento" → estado EN_CAMINO; historial CITA con registro | | |
| 6 | En EN_CAMINO: "Llegué al domicilio" pide permiso de ubicación (GPS), pasa a LLEGO y registra `latitud_llegada/longitud_llegada/distancia_recorrida` (mensaje con distancia en m) | | |
| 7 | Si se niega el permiso de ubicación, NO se avanza de estado y se muestra el motivo | | |
| 8 | En LLEGO: "Iniciar servicio" pasa a EN_PROCESO y crea el tratamiento | | |
| 9 | Saltos inválidos de estado (p.ej. PROGRAMADA→EN_PROCESO directo vía SQL/REST) son rechazados por el trigger (RAISE EXCEPTION) | | |
| 10 | "Cancelar cita" disponible en estados activos: exige motivo, pasa a CANCELADA y registra historial con `motivo_cancelacion` y `usuario_id` | | |
| 11 | Paciente recibe notificación in-app (campana) en cada cambio de estado de su cita (EN_CAMINO, LLEGO, EN_PROCESO, FINALIZADA, CANCELADA) | | |
| 12 | Push FCM: con `push_notifications=true` y dispositivo registrado, el paciente recibe push en los mismos cambios | | |
| 13 | Paciente en `/mis-solicitudes` ve el estado de la cita (En camino / En el lugar / En proceso / Finalizada / Cancelada) | | |
| 14 | No se puede crear una segunda cita activa para una solicitud ya ACEPTADA (claim atómico de `aceptar_solicitud`) | | |

## Comandos de verificación

```powershell
flutter analyze
flutter test
```

## Estado

- `flutter analyze`: 0 issues.
- `flutter test`: 148/148.
- Migración `20260824000100` aplicada al remoto vía `supabase db push` (pooler sesión 6543) el 2026-08-24. Queda pendiente ejecutar el checklist manual de aceptación en un dispositivo con permisos de ubicación.