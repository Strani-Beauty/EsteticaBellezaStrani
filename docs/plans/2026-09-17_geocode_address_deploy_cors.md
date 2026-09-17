# Plan — Desplegar edge function `geocode-address` y eliminar el error CORS

Fecha: 2026-09-17
Estado: APROBADO por el usuario (m0987: "aprobado"). Sin commit.

## Diagnóstico (verificado)

- `OPTIONS https://hhyjremkguvphmjuaazp.functions.supabase.co/geocode-address` → **404**
  `{"code":"NOT_FOUND","message":"Requested function was not found"}` → la función
  **nunca se desplegó**.
- El preflight 404 (no 2xx) es el origen del error de Chrome *"HTTP status of preflight
  request didn't indicate success"* que aparece al navegar y volver a bienvenida (la app
  invoca geocoding/reverse desde el navegador). La app funciona por el fallback directo
  a Nominatim (`_reverseViaNominatimFallback`), pero la consola muestra el error.
- Referencia: `create-payment-intent` está desplegada y su preflight responde 200 con
  `access-control-allow-origin: *` + `access-control-allow-headers` → el patrón local de
  `geocode-address` (maneja `OPTIONS` vía `handleOptions` y soporta reverse `{lat,lng}`)
  quedará correcto una vez desplegado.
- El CLI (v2.113.0) exige `supabase/config.toml` desde la v2.106
  (`failed to load config: supabase/config.toml not found`) → hay que crearlo.

## Cambios

### 1. `supabase/config.toml` (nuevo, mínimo)
```toml
project_id = "hhyjremkguvphmjuaazp"

[functions.geocode-address]
verify_jwt = true
```
`verify_jwt = true` es el default del CLI; se declara explícito porque la función valida
JWT con `getUserFromRequest`. No habilita dev local (eso requiere Docker).

### 2. Autenticación y deploy
- `supabase login` (interactivo, abre el navegador; guarda token en
  `%USERPROFILE%\.supabase\access-token`).
- `supabase functions deploy geocode-address --use-api --project-ref hhyjremkguvphmjuaazp`
  (`--use-api` bundle server-side, sin Docker).

## Verificación

- [x] `curl -X OPTIONS .../geocode-address` → 200 + CORS headers
      (`access-control-allow-origin: *` + `access-control-allow-headers`).
- [x] POST autenticado (login gotrue `pac.nuevo@test`): con `{lat:29.7604,lng:-95.3698}`
      → `{found:true,address:"West Walker Tunnel, Downtown, Houston, ..."}`; con
      `{address:"Main St, Houston, TX"}` → coords. Sin auth → 401 (verify_jwt ok).
- [ ] En la app: tocar el mapa llena el campo sin error CORS en consola.

## Notas

- Sin commit (regla del proyecto: preguntar antes).
- No se cambia código Dart; solo deploy + config.