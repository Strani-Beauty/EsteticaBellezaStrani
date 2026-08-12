# Plan: Importar catálogo real de servicios (desde SERVICIOS.xlsx)

**Fecha:** 2026-08-13
**Origen:** `C:\Desarrollo\SERVICIOS.xlsx` — catálogo real de servicios (serán los del sistema).
**Decisiones:** categorías capitalizadas · flags auto por categoría · alcance completo (migración + doc + imágenes).

---

## Estado

- [x] Migración seed (3 categorías + 19 servicios)
- [x] Extracción y mapeo de imágenes a `assets/images/service_<slug>.png` (14 imágenes)
- [x] Documentación (resumen total)
- [x] Verificación (`flutter analyze` limpio + `flutter test` 14/14 + `flutter build web` OK)
- [x] Aplicar migración al remoto (`supabase db push`)

---

## Datos extraídos del Excel

- 5 hojas: `Hoja1` (catálogo maestro, 16 imágenes), `inyectables`, `faciales y piel`, `contorno corporal`, `Hoja4` (notas).
- **19 servicios**, 3 categorías, 16 imágenes embebidas (PNG).

### Categorías (BD)
1. `Inyectables`
2. `Faciales y Piel`
3. `Contorno Corporal`

### Servicios (19) — ver `docs/2026-08-13_catalogo_servicios_reales.md`

## Reglas de mapeo

- `tipo_precio`: "por seccion"/"x sesion" → `POR_SESION`; "la uni"/"25 +" → `POR_UNIDAD`; resto → `PRECIO_FIJO`.
- `precio_base`: valor numérico extraído del texto de precio.
- Flags: Inyectables/Faciales → `requiere_face_map=true`; demás flags `false`.
- Imagen: `assets/images/service_<slug>.png` (convención existente `_slugify`).

## Archivos

- `supabase/migrations/20260813030000_seed_servicios_reales.sql` (nuevo)
- `assets/images/service_*.png` (16 imágenes)
- `docs/2026-08-13_catalogo_servicios_reales.md` (nuevo)
