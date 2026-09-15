# Plan — Persistir imágenes de servicios en `imagen_url`

Fecha: 2026-09-15
Estado: APROBADO por el usuario (m0203: "aprobado"). Sin commit.

## Objetivo

Las 19 imágenes de servicio que hoy viven como assets locales
(`assets/images/service_<slug>.<ext>`) referenciadas por slug del nombre deben
**persistirse en la tabla** (`servicios.imagen_url`) y cargarse desde ahí. Verificado
en BD: 35 servicios, `imagen_url` NULL en todos; bucket público `imagenes-servicios`
existe con 0 objetos.

- Ruta en bucket: `<servicioId>/imagen_principal.<ext>` (decisión usuario m0201).
- 16 servicios sin asset local quedan con `imagen_url` NULL (gradiente+ícono).
- La tarjeta conserva el fallback a asset local cuando `imagen_url` está NULL.

## Hallazgos de la revisión (m0195)

- Mecanismo actual en `_ServiceCard._buildHero` (`services_dashboard_screen.dart`):
  1. `imagenUrl` no vacío → `Image.network`.
  2. Si no → asset local `assets/images/service_<slug>.<ext>` (`_slugify` + `_ServiceHeroImage`).
  3. Si no → gradiente + ícono.
- 19 assets locales existen y su slug coincide 1:1 con 19 nombres de servicio.
- Subida a storage exige `authenticated` + rol `Administrador`
  (policy `servicio_imagen_admin_insert`). `admin@test` (rol Administrador, activo,
  verificado por pooler) + `.env` con `SUPABASE_URL`/`SUPABASE_ANON_KEY`.

## Cambios

### 1. Script de carga único (datos remotos; no es migración SQL)
Node en `C:\Users\Jaime\AppData\Local\Temp\opencode\pgcheck` (patrón base64 AGENTS.md),
NO se commitea (usa credenciales de seed):
1. Leer `SUPABASE_URL`/`SUPABASE_ANON_KEY` de `.env`.
2. Login gotrue `POST /auth/v1/token?grant_type=password` con `admin@test` → `access_token`.
3. Listar `id, nombre` de `public.servicios` por pooler.
4. Por servicio: `slug = slugify(nombre)` → buscar `assets/images/service_<slug>.*`.
5. Subir: `POST /storage/v1/object/imagenes-servicios/<id>/imagen_principal.<ext>`
   con `Authorization: Bearer <token>` y `x-upsert: true` (idempotente).
6. `UPDATE public.servicios SET imagen_url = '<url pública>' WHERE id = <id> AND imagen_url IS NULL`.
7. Reporte: subidos / sin asset / fallos.

Seguridad: bucket público (catálogo no sensible); JWT admin cumple la policy de
subida; RLS de `servicios` ya expone `imagen_url` (SELECT público). Sin cambios de RLS.

### 2. Código Dart — sin cambios
- `_buildHero` ya carga desde `imagen_url` (paso 1) → los 19 saldrán de storage.
- Fallback asset/ícono se conserva para los 16 con NULL.

## Verificación

- [x] Pooler: 19 servicios con `imagen_url` no NULL, 16 NULL, 35 total.
- [x] GET a 2 URLs públicas → 200 `image/jpeg` (Botox y Cauterización de Lunares).
- [x] `flutter analyze` sin issues y `flutter test` (366 tests) — sin cambios de código.

> Nota: `x-upsert: true` en el upload dispara un UPDATE interno sin policy
> (`AccessDenied`). Se subió SIN `x-upsert` (200) y el script resultó idempotente.
> Quedaron 3 objetos de prueba huérfanos (`90000000-.../prueba_{v2,v3,v4}.webp`)
> no limpiables vía API/SQL (sin policy de DELETE/UPDATE ni owner en pooler).

## Notas
- Sin commit (regla del proyecto: preguntar antes de commitear).