# Pruebas manuales — Panel de administración (Dashboard) E2E

| | |
|---|---|
| **Fecha** | 2026-08-22 |
| **Versión** | 1.0 |
| **Commit** | (pendiente) |
| **Entorno** | Local `flutter run -d web-server --web-port 8080` o desplegado en web.app |
| **Plan** | `docs/plans/2026-08-22_admin_dashboard.md` |
| **Proyecto Supabase** | `hhyjremkguvphmjuaazp` |

## Cuentas

| Rol | Email | Clave |
|---|---|---|
| Administrador | `admin@test` o `admin@strani.com` | `Test1234!` |

## Checklist de aceptación

| # | Ítem | Resultado | Evidencia / observación |
|---|---|---|---|
| 1 | `/admin` es un dashboard con KPIs (solicitudes por estado, citas activas, especialistas pendientes, médicos pendientes, ingresos, usuarios) | | |
| 2 | Tarjetas agrupadas: Administrativo (Usuarios, Cuestionario, Catálogo, Licencias) | | |
| 3 | Tarjetas agrupadas: Datos Maestros (Roles y Permisos, Configuración, Comisiones y Liquidaciones, Especialidades, Médicos Regentes) | | |
| 4 | Licencias es una vista propia (`/admin/licencias`) con expedientes y aprobar/rechazar/bloquear | | |
| 5 | `/admin/configuracion` lista y permite editar claves (guardado persiste) | | |
| 6 | `/admin/datos-maestros/roles` crea/edita roles, activa/desactiva y asigna/quita permisos | | |
| 7 | `/admin/datos-maestros/especialidades` crea/edita y activa/desactiva especialidades | | |
| 8 | `/admin/datos-maestros/medicos-regentes` registra y aprueba médicos regentes | | |
| 9 | `/admin/datos-maestros/comisiones` lista liquidaciones y pagos (y enlaza a configuración) | | |
| 10 | Guard de rol: un especialista/paciente no accede a `/admin/*` | | |
| 11 | RLS: solo admin lee/escribe `configuracion_sistema`, `roles`, `comisiones`, etc. | | |

## Comandos de verificación

```powershell
flutter analyze
flutter test
```

## Estado

- `flutter analyze`: 0 issues.
- `flutter test`: 148/148.
- Migración `20260822000100` aplicada y verificada (KPIs con datos reales).
