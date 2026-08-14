# Plan de pruebas manuales — Índice general

| | |
|---|---|
| **Proyecto** | Estética y Belleza Strani |
| **Fecha** | 2026-08-14 |
| **Versión** | 1.0 |
| **Objetivo** | Pruebas de usuario por módulo, diseñadas para revelar errores de flujo y de código |

## Documentos

| # | Documento | Módulo | Estado del código |
|---|---|---|---|
| 01 | [01_auth_users.md](01_auth_users.md) | Registro, login, recuperación, perfil, sesión | COMPLETO |
| 02 | [02_specialists.md](02_specialists.md) | Onboarding, documentos, verificación, contrato, disponibilidad | COMPLETO |
| 03 | [03_admin_config.md](03_admin_config.md) | Panel admin de verificación de licencias | PARCIAL |
| 04 | [04_admin_users.md](04_admin_users.md) | Gestión de usuarios por admin | COMPLETO |
| 05 | [05_catalog_services.md](05_catalog_services.md) | Catálogo de servicios y reserva | COMPLETO |
| 06 | [06_marketplace_citas.md](06_marketplace_citas.md) | Mapa de solicitudes y aceptación de citas | COMPLETO |
| 07 | [07_patients_compliance.md](07_patients_compliance.md) | Cuestionario, evaluación, dirección, face map | STUB (flujos reales vía legacy) |
| 08 | [08_payments_stripe.md](08_payments_stripe.md) | Pagos Stripe (cuota, reserva, saldo) | COMPLETO |
| 09 | [09_treatment_execution.md](09_treatment_execution.md) | Ejecución de citas a domicilio | COMPLETO |
| 10 | [10_treatment_photos.md](10_treatment_photos.md) | Fotografías de tratamiento | COMPLETO (accesible desde CitaDetalleScreen) |
| 11 | [11_flujos_integrados_e2e.md](11_flujos_integrados_e2e.md) | Flujos completos que cruzan módulos | — |

`reports_dashboards` se omite: el módulo está vacío (sin pantallas, cubits ni rutas).

## Matriz de cuentas de prueba

| Cuenta | Rol | Estado requerido | Se usa en |
|---|---|---|---|
| `admin@test` | Administrador | Activo, con acceso al panel | 03, 04, 11 |
| `esp.nuevo@test` | Especialista | Recién registrado, sin perfil de especialista | 02, 11 |
| `esp.revision@test` | Especialista | Documentos subidos, `EN_REVISION` | 02, 03, 11 |
| `esp.aprobado@test` | Especialista | `APROBADO`, contrato firmado, disponible, con ubicación | 06, 09, 11 |
| `esp.rechazado@test` | Especialista | `RECHAZADO` con observación | 02, 03 |
| `esp.bloqueado@test` | Especialista | `BLOQUEADO` con observación | 02, 03, 11 |
| `pac.nuevo@test` | Paciente | Recién registrado, perfil incompleto | 01, 07, 08, 11 |
| `pac.activo@test` | Paciente | Evaluación `APROBADA` vigente, pagos completos | 05, 11 |
| `pac.vencido@test` | Paciente | Evaluación `VENCIDA` | 05 |
| `pac.rechazado@test` | Paciente | Evaluación `RECHAZADA` | 05 |
| `pac.desactivado@test` | Paciente | `profiles.activo=false` | 04, 11 |
| `esp.desactivado@test` | Especialista | `profiles.activo=false` | 04, 11 |

## Entorno de prueba

- `.env` con `SUPABASE_URL` y `SUPABASE_ANON_KEY` válidos (sin ellos la app muestra pantalla de error al arrancar — caso intencional en 01).
- **Stripe**: sin publishable key o en plataforma web → modo simulado (referencias `STRIPE_SIM_<ts>`). Los casos de pago indican si aplican en modo simulado, real o ambos.
- Edge function `geocode-address` desplegada (geocodificación de direcciones).
- Firebase FCM opcional: la app degrada sin crash si no está configurada.
- Dos dispositivos/sesiones para casos de concurrencia y desactivación remota (marcados con ⚑).

## Convenciones

- **Prioridad**: Crítica (rompe un flujo principal o pierde datos), Alta (función importante degradada), Media (fricción o caso poco frecuente), Baja (cosmético).
- **Resultado**: `Pasa` / `Falla` / `Bloqueado` / pendiente (celda vacía).
- Cada documento termina con una tabla de resumen de ejecución.

### Plantilla de reporte de bug

```
Bug ID: B-<doc>-<n>
Caso relacionado: <ID de caso>
Pasos para reproducir:
Resultado observado:
Resultado esperado:
Severidad: Crítica / Alta / Media / Baja
Evidencia: captura / log
```

## Ejecución recomendada

1. Empezar por 01 (auth) y 02 (specialists): el resto depende de cuentas y estados creados ahí.
2. Continuar con 03 y 04 (admin) para producir estados de verificación/activación.
3. 05–10 en cualquier orden; 08 (pagos) se ejercita dentro de 05, 07 y 09.
4. Cerrar con 11 (flujos integrados) usando cuentas limpias.
