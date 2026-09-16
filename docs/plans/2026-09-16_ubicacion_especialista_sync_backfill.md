# Plan — Sincronizar y hacer backfill de la ubicación del especialista en `ubicaciones_especialista`

Fecha: 2026-09-16
Estado: APROBADO por el usuario (m0842: "a" → Opción A). Sin commit.

## Objetivo

El mapa del Marketplace y el RPC `obtener_solicitudes_publicadas_geo` usan la
tabla `ubicaciones_especialista`, pero la dirección del especialista se guarda en
`profiles` (`address`, `latitude`, `longitude`, columnas de
`20260804000100_secure_supabase_setup.sql`). No hay trigger que sincronice ambas.

Caso real verificado por pooler: `esp.aprobado@test` (user `90000000-...-0004`,
especialista `c0000000-0000-0000-0000-000000000002`, APROBADO y activo) tiene
`address/latitude/longitude` en `profiles` (29.7579, -95.3445) pero **0 filas** en
`ubicaciones_especialista` → el RPC exige `u.ubicacion IS NOT NULL` y nunca lo
devuelve. En cambio `esp.compliance1@test.com` tiene 1 fila y sí ve solicitudes.

Opción A (aprobada): **sincronizar al guardar Datos personales** en el perfil +
**backfill SQL** para especialistas existentes. Sin tocar el RPC ni la BD de lectura.

## Cambios

### 1. `lib/features/specialists/presentation/screens/specialist_profile_screen.dart`
En `_guardarPersonal` (l.118-140), tras `guardarDatosPersonales(...)` y antes de
`authCubit.refreshProfile()`:
```dart
final especialista = _especialista;
if (especialista != null &&
    isValidMapCoordinate(_selectedLocation.latitude, _selectedLocation.longitude)) {
  await specialistsCubit.saveLocation(
    especialistaId: especialista.id,
    latitud: _selectedLocation.latitude,
    longitud: _selectedLocation.longitude,
  );
}
```
Mismo patrón que `_guardarProfesional` (l.162-170). `_especialista` getter existe
(l.202-205). El onboarding NO se toca: en su paso 0 el especialista nuevo aún no
tiene `especialista.id`, y `_guardarProfesional` ya persiste la ubicación.

### 2. Migración `supabase/migrations/20260916000300_ubicaciones_especialista_backfill.sql`
Idempotente, sin RLS. INSERT en `ubicaciones_especialista` desde `profiles` JOIN
`especialistas` para APROBADOS activos con coords válidas que no tengan fila geo:
```sql
INSERT INTO public.ubicaciones_especialista
    (especialista_id, latitud, longitud, ubicacion, precision_metros, fecha_actualizacion, created_at)
SELECT e.id, p.latitude, p.longitude,
       ('SRID=4326;POINT(' || p.longitude || ' ' || p.latitude || ')')::geography,
       0, now(), now()
  FROM public.profiles p
  JOIN public.especialistas e ON e.usuario_id = p.id
 WHERE p.latitude IS NOT NULL AND p.longitude IS NOT NULL
   AND e.estado_verificacion = 'APROBADO'
   AND e.activo = true
   AND NOT EXISTS (
       SELECT 1 FROM public.ubicaciones_especialista ue
        WHERE ue.especialista_id = e.id
   );
```
Se aplica por pooler (el CLI da 401 sin `supabase login`).

### Sin cambios
RPC `obtener_solicitudes_publicadas_geo`, `specialist_map_screen.dart` (aviso ya
implementado), cubits, datasources, onboarding.

## Verificación

- [x] `flutter analyze` limpio.
- [x] `flutter test` (366 tests).
- [x] Pooler: `esp.aprobado@test` `ub_count` pasa de 0 a 1; el RPC
      `obtener_solicitudes_publicadas_geo` (como `c0000000-0002`) devuelve la
      solicitud `5a77a2c9` de `pac.nuevo@test` (~4.4 km, radio 10 km).
- [ ] Manual en `flutter run -d chrome`: como `esp.aprobado@test`, el mapa ya no
      muestra el aviso de ubicación y aparece la solicitud; editar Datos
      personales deja la ubicación actualizada en `ubicaciones_especialista`.

## Notas

- Sin commit (regla del proyecto: preguntar antes de commitear).