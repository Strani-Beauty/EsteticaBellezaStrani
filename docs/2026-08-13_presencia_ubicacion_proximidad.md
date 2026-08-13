# Presencia Online/Offline, ubicaciones_especialista y PostGIS para proximidad

**Fecha:** 2026-08-13
**Rama:** `main`
**Migración:** `supabase/migrations/20260813050000_presencia_ubicacion_proximidad.sql`
**Plan:** `docs/plans/2026-08-13_presencia_ubicacion_proximidad.md`

---

## 1. Contexto y objetivo

Se implementaron tres objetivos de producto más un requisito de privacidad:

1. **Online/Offline**: mecanismo de presencia para indicar disponibilidad ante solicitudes (heartbeat en BD).
2. **`ubicaciones_especialista`**: registrar la ubicación del especialista cuando esté disponible (hoy la tabla existía pero nunca se escribía desde la app).
3. **PostGIS**: dejar lista la estructura (índices GIST + RPC de proximidad) para futuras búsquedas por cercanía.
4. **Privacidad (RN-018)**: la dirección del paciente en el mapa NO debe ser precisa para especialistas no asignados.

---

## 2. Estado previo relevante

- `especialistas.disponible` (toggle manual "acepto citas") ya existía, sincronizado con `disponibilidad_especialista`.
- El mapa (`fetchEspecialistasAprobados`) filtraba `estado_verificacion=APROBADO AND activo=true AND disponible=true`.
- `ubicaciones_especialista` ya tenía `ubicacion geography(Point,4326)` + `latitud/longitud/precision_metros/fecha_actualizacion`, **pero el flujo de la app nunca escribía ahí**: el onboarding guardaba lat/lng solo en `profiles`; `saveLocation`/`saveUbicacion` existían en cubit/repo/datasource sin invocarse.
- No existía noción de presencia online/offline (el mapa era pull-to-refresh, sin realtime).
- RLS de `direcciones_paciente`: la policy `direccion_paciente_especialista_cita` solo deja leer la dirección exacta al especialista **ya asignado**; el join embebido en `fetchSolicitudesPendientes` devolvía `null` para especialistas no asignados (el mapa no pintaba pacientes).

---

## 3. Cambios realizados

### 3.1 Migración `20260813050000_presencia_ubicacion_proximidad.sql` (idempotente)

- Columnas en `especialistas`: `en_linea BOOLEAN NOT NULL DEFAULT FALSE`, `ultima_conexion TIMESTAMPTZ`.
  - Fuera del trigger `proteger_verificacion_especialista` (que solo protege columnas de verificación), actualizables por el dueño.
- Índices espaciales GIST:
  - `idx_ubicaciones_especialista_ubicacion` sobre `ubicaciones_especialista(ubicacion)`.
  - `idx_direcciones_paciente_ubicacion` sobre `direcciones_paciente(ubicacion)`.
- RPC `buscar_especialistas_cercanos(p_lat, p_lng, p_radio_metros, p_limit)` — `SECURITY DEFINER`, `ST_DWithin` + orden `<->`, devuelve solo especialistas `APROBADO + activo + disponible + en_linea + ultima_conexion < 3 min` con `distancia_metros`. **Preparada, no cableada a UI**.
- RPC `obtener_solicitudes_publicadas_geo()` — `SECURITY DEFINER`; devuelve a especialistas `latitud_aprox`/`longitud_aprox` **truncadas a 3 decimales (~110 m)** + `ciudad` + servicio/precio/radio/expiración/estado, **sin `direccion`** ni coordenadas exactas.
- `GRANT EXECUTE ... TO authenticated` en ambas RPCs.

> Nota técnica: PostGIS vive en el esquema `extensions`; las RPCs usan `SET search_path = public, extensions` y el cast `::extensions.geography`.

### 3.2 Presencia online/offline (Dart)

- `especialista_entity.dart` / `especialista_model.dart`: campos `enLinea` + `ultimaConexion` (parseo `en_linea`/`ultima_conexion`, `copyWith`, `props`).
- `specialists_supabase_datasource.dart`: `marcarPresencia(especialistaId, {required bool enLinea})` — update ligero sin tocar `updated_at`.
- `i_specialists_repository.dart` + `specialists_repository_impl.dart`: `marcarPresencia(...) → Either<Failure, void>`.
- **Nuevo** `lib/features/specialists/data/services/presence_service.dart` (patrón `FcmTokenService`):
  - `start(usuarioId)`: resuelve `especialistaId` vía `getEspecialistaByUsuarioId` (no-op si no es especialista), marca online y lanza `Timer.periodic(60s)`.
  - `markOnline()` / `markOffline()`; umbral de expiración en `AppConstants.umbralOnlineSegundos = 180`.
- `app_constants.dart`: `heartbeatPresencia`, `umbralOnlineSegundos`, `rpcBuscarEspecialistasCercanos`, `rpcObtenerSolicitudesPublicadasGeo`.
- `injection.dart`: registro de `PresenceService` (lazy singleton).
- `app.dart` (`_SessionLifecycleGate`):
  - `AuthAuthenticated` + `isSpecialist` → `presence.start(profile.id)`; `AuthUnauthenticated` → `markOffline()`.
  - `didChangeAppLifecycleState`: `resumed` → online; `inactive`/`paused`/`hidden`/`detached` → offline.

### 3.3 Ubicación en `ubicaciones_especialista`

- `specialist_onboarding_screen.dart` (`_guardarProfesional`): tras obtener `especialistaId`, llama `cubit.saveLocation(...)` con `_selectedLocation` (PIN del mapa), guardando la fila en `ubicaciones_especialista` (incluye `ubicacion` EWKT). Con esto `fetchMiUbicacion` del mapa devuelve datos reales.

### 3.4 Gating visible + privacidad del paciente

- `marketplace_supabase_datasource.dart`:
  - `fetchEspecialistasAprobados`: añade `.eq('en_linea', true)` + `.gt('ultima_conexion', cutoff)` y selecciona `en_linea`.
  - `fetchSolicitudesPendientes`: pasa a usar la RPC `obtener_solicitudes_publicadas_geo` (ubicación aproximada, sin dirección exacta).
- `especialista_mapa_entity.dart` / `especialista_mapa_model.dart`: campo `enLinea`.
- `solicitud_pendiente_model.dart`: parsea la forma plana de la RPC (coords truncadas + `ciudad`; `direccion` siempre `null`).
- `specialist_map_screen.dart`: el detalle muestra `Área` (ciudad) en vez de `direccion` exacta.

---

## 4. Seguridad y estabilidad

- Las dos RPCs son `SECURITY DEFINER` con `SET search_path = public, extensions`, evitando exponer una policy de lectura abierta sobre `ubicaciones_especialista` y sin filtrar coordenadas crudas de pacientes.
- La dirección exacta del paciente queda exclusivamente en `direccion_paciente_especialista_cita` (post-asignación).
- Heartbeat: 1 update/min solo con app en foreground; el umbral de 3 min tolera cierres forzados sin apagado limpio.
- Presencia (`en_linea`) y `disponible` son independientes; elegibilidad = `APROBADO + activo + disponible + en_linea`.

---

## 5. Verificación

- `flutter analyze` → sin issues.
- `flutter test` → 14/14.
- `flutter build web` → OK.
- `supabase migration list` → `20260813050000` aplicada en Local y Remote.

---

## 6. Pendientes / verificación manual sugerida

1. **Especialista** (cuenta real o de seed):
   - Abrir la app → `en_linea=true` y `ultima_conexion` se actualiza cada 60s.
   - Pasar a segundo plano / cerrar → `en_linea=false`.
   - Onboarding → se crea la fila en `ubicaciones_especialista`.
   - Mapa de pacientes → los pacientes aparecen con ubicación aproximada (~110 m) y `Área` (ciudad), sin dirección exacta.
2. **Administrador / SQL**: probar `buscar_especialistas_cercanos(lat, lng, radio)` y `obtener_solicitudes_publicadas_geo()` para validar el retorno.
