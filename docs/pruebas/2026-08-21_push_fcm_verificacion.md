# Pruebas manuales — Push FCM real: solicitud aceptada por otro especialista

| | |
|---|---|
| **Estado** | ⬜ **PENDIENTE** (preparada 2026-08-21; requiere dispositivo/emulador real) |
| **Fecha de preparación** | 2026-08-21 |
| **Plan** | `docs/plans/2026-08-21_solicitudes_reserva_marketplace.md` |
| **Proyecto Supabase** | `hhyjremkguvphmjuaazp` |
| **Edge function** | `send-push` (FCM HTTP v1, operativa) |

## Objetivo

Confirmar que cuando un especialista acepta una solicitud, los especialistas del radio que "perdieron" reciben el **push FCM** en su dispositivo.

## Datos verificados en BD (2026-08-21) que condicionan la prueba

- **Ganador** (único habilitado para aceptar): `esp.compliance1@test.com` / `Test1234!` (ESPECIALISTA TEST 2, `29.7534, -95.3336`).
- **Perdedor candidato** (APROBADO en radio, recibe el push): `especialista1@test.com` / `Test1234!` (Dr. Carlos Medina, `29.7604, -95.3698`, ~3.6 km).
- ⚠️ Hoy **no hay** `dispositivos_usuario` (tokens FCM) ni dirección del paciente en `direcciones_paciente` → hay que prepararlos (sección Preparación).

## Precondiciones

1. **Dispositivo/emulador Android** (recomendado) con la app desde este repo (`android/app/google-services.json` ya existe). iOS requiere APNs firmado; **web no aplica** (FCM web necesita VAPID y `getToken(vapidKey:)`, que hoy no se usa).
2. La app registra el token al iniciar sesión: `app.dart` → `FcmTokenService.registerCurrentDevice` → pide permiso y guarda en `dispositivos_usuario`.

## Preparación (una vez)

**A. Crear la dirección del paciente** (el resumen exige `direcciones_paciente` con `ubicacion`). En SQL Editor, para `pac.compliance1@test.com` (paciente `818399b1-15dc-4848-a65a-2e221aa9cef3`), cerca del ganador:

```sql
INSERT INTO public.direcciones_paciente
  (paciente_id, direccion, ciudad, estado, codigo_postal, es_principal, latitud, longitud, ubicacion, created_at)
VALUES (
  '818399b1-15dc-4848-a65a-2e221aa9cef3',
  'Real Push Test St 1000', 'Houston', 'TX', '77001', true,
  29.7560, -95.3500,
  ST_SetSRID(ST_MakePoint(-95.3500, 29.7560), 4326)::geography,
  now()
);
```
(distancia al perdedor ≈ 2 km → dentro del radio de 10 km.)

**B. Confirmar config** (ya está): `enforce_pago_real='false'`, `push_notifications='true'`, `edge_function_base_url` y `anon_key` en `configuracion_sistema`; secret `FCM_SERVICE_ACCOUNT` seteado; `pg_net` habilitado (migración `20260821000600`).

## Ejecución

1. **Dispositivo A (ganador)**: `flutter run -d <android>` → login `esp.compliance1@test.com` / `Test1234!` → **acepta el permiso de notificaciones**. Log esperado: `✅ [FCM] Token registrado`.
2. **Dispositivo B (perdedor)**: `flutter run -d <android>` → login `especialista1@test.com` / `Test1234!` → acepta el permiso. **Dejar la app en segundo plano** (o matarla) para que el push se muestre en la bandeja.
3. **Paciente**: login `pac.compliance1@test.com` → `/services` → tocar un servicio → Resumen → "Pagar depósito" (modo simulado) → solicitud `PUBLICADA` (confirmar en "Mis Solicitudes").
4. **Dispositivo A (ganador)**: entrar a `/specialist/map`, ver la solicitud (dentro del radio) → "Asignarme este paciente".
5. **Observar Dispositivo B**: debe aparecer en la bandeja **"Solicitud asignada — La solicitud de <paciente> ya fue asignada a otro especialista."**

## Verificación técnica

- `notificaciones` en BD para `especialista1@test.com` con `tipo='SOLICITUD_ASIGNADA'` (in-app).
- Edge Functions → logs de `send-push`: invocación con `"sent":1` (o `net._http_response` con `status_code: 200` y `sent:1`).
- En Dispositivo B, al abrir la campana de notificaciones, ver el ítem `SOLICITUD_ASIGNADA`.

## Límites / follow-ups posibles

- **Foreground**: no hay handler `FirebaseMessaging.onMessage` → el push NO se muestra si la app está en primer plano (solo segundo plano/cerrada). Para banner en foreground habría que añadir un handler de local notification (tarea aparte).
- **Web**: requeriría VAPID + service worker; hoy no está.
- **Ganador**: solo `esp.compliance1@test.com` está habilitado para aceptar; los demás APROBADOS del radio solo reciben la notificación.
