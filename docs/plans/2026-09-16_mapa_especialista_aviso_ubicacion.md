# Plan — Aviso claro en el mapa del especialista cuando no tiene ubicación

Fecha: 2026-09-16
Estado: APROBADO por el usuario (m0816: "si"). Sin commit.

## Objetivo

Cuando un especialista APROBADO abre el mapa del Marketplace y **no tiene
ubicación guardada** (`ubicaciones_especialista`), el mapa queda vacío sin
explicación. El RPC `obtener_solicitudes_publicadas_geo` (v2,
`20260821000100`) exige `u.ubicacion IS NOT NULL` y `ST_DWithin` (≤ radio del
paciente), por lo que sin ubicación propia el especialista no ve ninguna
solicitud.

Caso reportado: `pac.nuevo@test` publicó "Cauterización de Lunares y Skin Tags"
(Houston, radio 10 km). Se probó con `esp.aprobado@test`, que **no tiene fila en
`ubicaciones_especialista`** → el RPC no devuelve nada y la app no lo explica.
(Verificado: la solicitud SÍ aparece para especialistas dentro del radio, p. ej.
`esp.compliance1@test.com` a 1.9 km.)

Solución acordada (m0811): **aviso claro en el mapa** + CTA para configurar la
ubicación. **No** se cambia el filtro geográfico del RPC ni la BD.

## Cambios

Archivo único: `lib/features/marketplace_citas/presentation/screens/specialist_map_screen.dart`
(ya importa `go_router`, `AppRoutes` y `AppTheme`).

1. **`_buildMap`** (~l.267-289): reemplazar el banner de vacío por dos casos:
   - `state.miLatitud == null || state.miLongitud == null` → `_AvisoUbicacion`
     con CTA "Configurar" → `context.push(AppRoutes.specialistProfile)`.
   - `else if (state.solicitudes.isEmpty)` → texto ajustado
     'No hay solicitudes dentro de tu radio de búsqueda en este momento.'
2. **Nuevo widget privado `_AvisoUbicacion`**: Container blanco (alpha .94,
   `radiusLg`, sombra) con `Icon(location_off_rounded, cGoldAccent)`, texto
   'Aún no has guardado tu ubicación. Configúrala para ver las solicitudes de
   pacientes cercanos.' y `TextButton` "Configurar".
3. **`_recenterMine`**: si no hay ubicación, `SnackBar` informativo (hoy el botón
   no hace nada).

### Sin cambios
RPC `obtener_solicitudes_publicadas_geo`, `marketplace_supabase_datasource`,
`MarketplaceCubit`, tabla `ubicaciones_especialista`, RLS.

## Verificación

- [x] `flutter analyze` limpio.
- [x] `flutter test` (366 tests).
- [ ] Manual en `flutter run -d chrome`: entrar como `esp.aprobado@test` → aviso
      con botón "Configurar" → guardar ubicación en el perfil → volver al mapa →
      aparece la solicitud de `pac.nuevo@test` (dentro del radio de 10 km).

## Notas

- Sin commit (regla del proyecto: preguntar antes de commitear).
- El aviso no hace aparecer la solicitud por sí solo: el especialista debe
  guardar su ubicación (de ahí el CTA).
