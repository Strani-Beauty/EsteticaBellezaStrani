# Plan: Presencia Online/Offline, ubicación en `ubicaciones_especialista` y PostGIS listo

**Fecha:** 2026-08-13
**Origen:** 3 objetivos de producto (online/offline ante solicitudes, tabla de ubicaciones, estructura PostGIS para proximidad) + recordatorio de privacidad: la dirección del paciente en el mapa NO debe ser precisa.

**Decisiones confirmadas:**
- Presencia: heartbeat en BD (columnas en `especialistas`), online = `en_linea AND ultima_conexion > now() - 3 min`.
- Ubicación: PIN manual existente del onboarding (sin `geolocator`).
- Gating: `en_linea` cableado en mapa y RPC desde ya.
- Privacidad paciente (RN-018): coordenadas truncadas a 3 decimales (~110 m) + solo `ciudad`, sin `direccion` ni coords exactas para especialistas no asignados.

---

## Estado

- [x] Fase 0 — Migración `20260813050000_presencia_ubicacion_proximidad.sql`
- [x] Fase 1 — Presencia online/offline (entity/model, `marcarPresencia`, `PresenceService`, DI, lifecycle)
- [x] Fase 2 — `ubicaciones_especialista` (onboarding guarda ubicación)
- [x] Fase 3 — Gating visible (filtro `en_linea` en mapa + RPC obfuscado de solicitudes)
- [x] Verificación local (`flutter analyze` limpio, `flutter test` 14/14, `flutter build web` OK)
- [x] Aplicar migración al remoto (`supabase db push`)

---

## Fase 0 — Migración (idempotente)

1. Columnas de presencia en `especialistas`: `en_linea BOOLEAN DEFAULT FALSE`, `ultima_conexion TIMESTAMPTZ` (fuera del trigger protegido; actualizables por el dueño).
2. Índices GIST: `ubicaciones_especialista(ubicacion)` y `direcciones_paciente(ubicacion)`.
3. RPC `buscar_especialistas_cercanos(p_lat, p_lng, p_radio_metros, p_limit)` — `SECURITY DEFINER`, `ST_DWithin` + `<->`, solo `APROBADO+activo+disponible+en_linea+fresco`, devuelve `distancia_metros`. `GRANT EXECUTE TO authenticated`. No se cablea a UI.
4. RPC `obtener_solicitudes_publicadas_geo()` — `SECURITY DEFINER`; devuelve a especialistas `latitud_aprox`/`longitud_aprox` truncadas a 3 decimales + `ciudad` + servicio/precio/radio/expiración/estado, **sin `direccion`** ni coordenadas exactas. La dirección exacta queda en la policy `direccion_paciente_especialista_cita` (post-asignación).

## Fase 1 — Presencia

- `especialista_entity.dart` / `especialista_model.dart`: `enLinea` + `ultimaConexion`.
- `specialists_supabase_datasource.dart`: `marcarPresencia(especialistaId, {enLinea})` (update ligero sin `updated_at`).
- `i_specialists_repository.dart` + impl: `marcarPresencia(...) → Either<Failure, void>`.
- `presence_service.dart`: `start(usuarioId)` (resuelve especialista, no-op si no lo es), heartbeat `Timer.periodic(60s)`, `markOffline()`, `dispose()`.
- `app_constants.dart`: `heartbeatPresencia`, `umbralOnlineSegundos`, nombres RPC.
- `injection.dart`: registrar `PresenceService`.
- `app.dart` (`_SessionLifecycleGate`): arranque en `AuthAuthenticated`+`isSpecialist`; offline en `AuthUnauthenticated`/`paused`/`inactive`/`detached`.

## Fase 2 — Ubicación

- `specialist_onboarding_screen.dart` (`_guardarProfesional`): tras obtener `especialistaId`, `saveLocation` con `_selectedLocation`.

## Fase 3 — Gating visible

- `marketplace_supabase_datasource.dart`: `fetchEspecialistasAprobados` + `.eq('en_linea', true)` y frescura; `fetchSolicitudesPendientes` vía RPC obfuscado.
- `especialista_mapa_entity.dart` / `especialista_mapa_model.dart`: `enLinea`.
- `solicitud_pendiente_model.dart`: parsear forma plana del RPC.
- `specialist_map_screen.dart`: detalle muestra `ciudad` (área) en vez de `direccion` exacta.

## Seguridad / estabilidad

- RPCs `SECURITY DEFINER` + `SET search_path = public` (sin exponer coords crudas de pacientes ni una policy de lectura abierta).
- Heartbeat: 1 update/min solo con app en foreground; umbral 3 min tolera cierres forzados.
- Presencia y `disponible` son independientes; elegibilidad = `APROBADO + activo + disponible + en_linea`.
