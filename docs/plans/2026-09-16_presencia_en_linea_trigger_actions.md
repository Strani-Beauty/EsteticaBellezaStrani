# Plan — Marcar `en_linea=true` en acciones explícitas del especialista

Fecha: 2026-09-16
Estado: APROBADO por el usuario (m0920: "¿no debería colocar en_linea=true cuando pulse
disponible?, ¿y si no, cuando entre al mapa de marketplace busqueda de pacientes?").
Sin commit.

## Objetivo

El mapa de pacientes (`specialist_map_screen.dart`) y el RPC
`obtener_solicitudes_publicadas_geo` solo muestran especialistas con
`en_linea=true` + `ultima_conexion` < 180 s. El heartbeat de presencia
(`PresenceService.start`) solo se disparaba por el `BlocListener<AuthCubit>` al
autenticarse, y si la sesión se restaura sin emitir `AuthAuthenticated` (o el
especialista no está en esa pestaña), `en_linea` queda en false aunque el
especialista esté usando la app.

Solución acordada: disparar `sl<PresenceService>().start(usuarioId)` (que marca
`en_linea=true` vía `markOnline()` y arma el heartbeat de 60 s) en dos acciones
explícitas del especialista:
1. Activar el switch **"Disponible"**.
2. Entrar al **mapa de pacientes** (marketplace).

## Cambios

### `lib/features/specialists/presentation/widgets/disponibilidad_card.dart`
- Parámetro nuevo `String? usuarioId`.
- En `onChanged` del Switch: tras `toggleDisponibilidad`, si el switch queda en ON
  y hay `usuarioId`, llama `sl<PresenceService>().start(usuarioId)`.
- Imports añadidos: `app/core/di/injection.dart`, `features/specialists/data/services/presence_service.dart`.

### `lib/features/specialists/presentation/screens/specialist_home_screen.dart`
- `DisponibilidadCard(...)` pasa `usuarioId: context.read<AuthCubit>().currentProfile?.id`.

### `lib/features/marketplace_citas/presentation/screens/specialist_map_screen.dart`
- En `initState` (addPostFrameCallback), tras `loadDashboard`, llama
  `sl<PresenceService>().start(usuarioId)`.
- Imports añadidos: `app/core/di/injection.dart`, `features/specialists/data/services/presence_service.dart`.

### Sin cambios
RPC, BD, RLS, `PresenceService` (su guard `_started` lo hace idempotente).

## Verificación

- [x] `flutter analyze` limpio.
- [x] `flutter test` (366 tests).
- [ ] Manual en `flutter run -d chrome`: esp.aprobado@test activa "Disponible" y/o
      entra al mapa → en BD `en_linea=true` y `ultima_conexion` actualizándose
      cada 60 s; otro especialista con el mapa abierto lo ve (pin morado).

## Notas

- Sin commit (regla del proyecto: preguntar antes de commitear).
- `PresenceService.start` es idempotente: si el heartbeat ya corre, no se duplica.