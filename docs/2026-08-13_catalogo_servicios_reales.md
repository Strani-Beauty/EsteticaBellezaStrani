# Catálogo real de servicios (importado desde SERVICIOS.xlsx)

**Fecha:** 2026-08-13
**Origen:** `C:\Desarrollo\SERVICIOS.xlsx`
**Migración:** `supabase/migrations/20260813030000_seed_servicios_reales.sql`
**Plan:** `docs/plans/2026-08-13_catalogo_servicios_reales.md`

---

## Resumen total

- **19 servicios** en **3 categorías**.
- **16 imágenes** extraídas del Excel (PNG); **14** mapeadas a servicios (ver tabla de imágenes abajo).

### Categorías

| Categoría | Descripción |
|---|---|
| Inyectables | Tratamientos inyectables de armonización y rejuvenecimiento facial. |
| Faciales y Piel | Tratamientos faciales y de cuidado de la piel. |
| Contorno Corporal | Tratamientos de remodelación y contorno corporal. |

### Servicios

| # | Categoría | Servicio | Precio | Tipo de precio | Face map |
|---|---|---|---|---|---|
| 1 | Inyectables | Relleno de Labios con Ácido Hialurónico | $450.00 | fijo | sí |
| 2 | Inyectables | Botox (Toxina Botulínica) | $9.95 | /unidad | sí |
| 3 | Inyectables | Rejuvenecimiento con Ácido Hialurónico | $450.00 | fijo | sí |
| 4 | Inyectables | Sculptra | $600.00 | fijo | sí |
| 5 | Inyectables | Hilos Tensores | $350.00 | fijo | sí |
| 6 | Inyectables | Rinomodelación con Ácido Hialurónico | $450.00 | fijo | sí |
| 7 | Inyectables | Hidrolipoclasia en Papada | $145.00 | /sesión | sí |
| 8 | Inyectables | Full Face con Ácido Hialurónico | $1,995.00 | fijo | sí |
| 9 | Inyectables | PDRN de Salmón (Rejuvenecimiento Regenerativo) | $450.00 | /sesión | sí |
| 10 | Inyectables | Exosomas (Regeneración Celular Avanzada) | $450.00 | /sesión | sí |
| 11 | Faciales y Piel | Fibroblast (Plasma Pen) | $250.00 | fijo | sí |
| 12 | Faciales y Piel | Desintoxicación Facial Profunda Carelika Skin Care | $180.00 | fijo | sí |
| 13 | Faciales y Piel | Microneedling (Inducción de Colágeno) | $250.00 | fijo | sí |
| 14 | Contorno Corporal | Cauterización de Lunares y Skin Tags (Acrocordones) | $25.00 | /unidad | no |
| 15 | Contorno Corporal | Cavitación Corporal Ultrasónica | $80.00 | fijo | no |
| 16 | Contorno Corporal | Radiofrecuencia Facial y Corporal | $80.00 | fijo | no |
| 17 | Contorno Corporal | Ultrasonido Estético Facial y Corporal | $80.00 | fijo | no |
| 18 | Contorno Corporal | Drenaje Linfático Facial y Corporal | $80.00 | fijo | no |
| 19 | Contorno Corporal | Postoperatorio de Cirugía Plástica | $120.00 | fijo | no |

---

## Mapeo de imágenes → servicios

Convención de assets del código: `assets/images/service_<slug>.png` (slug = minúsculas, sin acentos, espacios → `_`).

> ⚠️ El Excel tiene imágenes colocadas de forma inconsistente (algunas en columnas C/E en vez de FOTO, imágenes repetidas y dos decorativas). El mapeo se hizo por los anclajes de la columna FOTO (D) del drawing XML, la señal más fiable disponible. **Revisar visualmente y corregir si alguna imagen no corresponde.**

| Imagen original | Archivo en assets | Servicio |
|---|---|---|
| image1.png | `service_relleno_de_labios_con_acido_hialuronico.png` | Relleno de Labios |
| image13.png | `service_botox_toxina_botulinica.png` | Botox |
| image5.png | `service_rejuvenecimiento_con_acido_hialuronico.png` | Rejuvenecimiento con Ácido Hialurónico |
| image7.png | `service_sculptra.png` | Sculptra |
| image6.png | `service_hilos_tensores.png` | Hilos Tensores |
| image8.png | `service_rinomodelacion_con_acido_hialuronico.png` | Rinomodelación |
| image10.png | `service_hidrolipoclasia_en_papada.png` | Hidrolipoclasia en Papada |
| image11.png | `service_full_face_con_acido_hialuronico.png` | Full Face |
| image4.png | `service_pdrn_de_salmon_rejuvenecimiento_regenerativo.png` | PDRN de Salmón |
| image14.png | `service_exosomas_regeneracion_celular_avanzada.png` | Exosomas |
| image3.png | `service_fibroblast_plasma_pen.png` | Fibroblast |
| image9.png | `service_desintoxicacion_facial_profunda_carelika_skin_care.png` | Desintoxicación Facial Carelika |
| image12.png | `service_microneedling_induccion_de_colageno.png` | Microneedling |
| image2.png | `service_cauterizacion_de_lunares_y_skin_tags_acrocordones.png` | Cauterización de Lunares y Skin Tags |
| image15.png | *(no usado — decorativo/logo)* | — |
| image16.png | *(no usado — decorativo)* | — |

**Servicios sin imagen** (5, marcados "N/A" en el Excel): Cavitación, Radiofrecuencia, Ultrasonido, Drenaje Linfático, Postoperatorio.

---

## Descripciones completas

Cada servicio en el Excel incluye una ficha estructurada: **¿Qué es?**, **¿Qué puedes esperar?** (beneficios), **Áreas más tratadas** / **Técnicas incluidas** y **Preguntas frecuentes**. En la BD se cargó el párrafo principal ("¿Qué es?") en `servicios.descripcion`. La ficha completa queda pendiente de un futuro detalle de servicio.

---

## Notas de importación

- **Idempotente**: la migración solo inserta servicios/categorías que no existan por nombre (comparación `lower`). No altera filas existentes.
- **`tipo_precio`**: "por sección"/"x sesión" → `POR_SESION`; "la uni"/"25 +" → `POR_UNIDAD`; resto → `PRECIO_FIJO`.
- **`requiere_face_map`**: `true` para Inyectables y Faciales y Piel (dispara el cuestionario Face Map); `false` para Contorno Corporal.
- Los demás flags (`requiere_telemedicina`, `requiere_fotos`, `requiere_consentimiento`) quedan en `false` por defecto.

**Limpieza de seed de prueba**: `supabase/migrations/20260813040000_limpiar_servicios_prueba.sql` desactiva (`activo=false`) los 14 servicios y 8 categorías del seed anterior. Se usó soft-delete en vez de `DELETE` porque están referenciados por solicitudes/citas de prueba (FK).

---

## Diseño de la tarjeta del catálogo (UI)

Archivo: `lib/features/catalog_services/presentation/screens/services_dashboard_screen.dart` (clase privada `_ServiceCard`).

### Layout (de arriba hacia abajo)
1. **Título** del servicio — prominente (17px, `FontWeight.w700`, hasta 2 líneas) + **precio** a la derecha (`_formatPrice`).
2. Chip de **categoría** (10px, `AppTheme.cPastelPurple`).
3. **Descripción** — fuente pequeña (11px, `height 1.35`), completa (sin truncar).
4. **Imagen** — al pie, en `AspectRatio(1:1)` con `BoxFit.cover`.

### Estructura de la tarjeta
```
Column(
  Expanded(SingleChildScrollView( título + precio + categoría + descripción )), // crece sin recortar
  AspectRatio(1:1, imagen),                                                     // cuadrado fijo al pie
)
```
El bloque de texto va dentro de `SingleChildScrollView` para que nunca se recorte si la descripción es larga.

### Grilla (en `_buildCatalog`)
- `GridView.builder` con `SliverGridDelegateWithFixedCrossAxisCount`.
- Columnas: **3** desktop (≥1000px), **2** tablet (≥600px), **1** móvil.
- `childAspectRatio`: desktop `0.60` · tablet `0.55` · móvil `0.68` (cuanto menor, más altas las tarjetas).

---

## Convención de imágenes

- Ruta: `assets/images/service_<slug>.png` (carpeta ya registrada en `pubspec.yaml`).
- `slug` = `_slugify(nombre)` (minúsculas, sin acentos, espacios → `_`, se eliminan paréntesis/símbolos). Está implementado en el mismo archivo.
- **Tamaño uniforme: 900×900 px (cuadrado, recorte centrado)**. Se normalizaron con `System.Drawing` (PowerShell): recorte centrado a cuadrado + redimensionado.
- Extensión soportada por `_ServiceHeroImage` (prueba en orden): `.jpg`, `.jfif`, `.png`, `.webp`. Si no existe ninguna, muestra un gradiente + ícono (`_iconForServicio`).

---

## Guía de mantenimiento (próximos cambios)

### Agregar un servicio nuevo
1. Crear migración idempotente (patrón `INSERT ... SELECT ... WHERE NOT EXISTS` de `20260813030000_seed_servicios_reales.sql`), con su `categoria_id` (por nombre), `nombre`, `descripcion`, `precio_base`, `tipo_precio::public.tipo_precio_enum` y `requiere_face_map`.
2. Colocar la imagen normalizada (900×900) en `assets/images/service_<slug>.png`.
3. `supabase db push`.

### Modificar un servicio existente
- **Datos/precios/descripción**: migración `UPDATE public.servicios ... WHERE lower(nombre) = ...`.
- **Imagen**: reemplazar `assets/images/service_<slug>.png` (mantener 900×900).

### Cambiar el diseño de la tarjeta
- Todo el markup está en `_ServiceCard` y `_buildHero` / `_ServiceHeroImage` de `services_dashboard_screen.dart`.
- Ajustar tamaños/alturas desde `_buildCatalog` (columnas y `childAspectRatio`).

### Quitar un servicio del catálogo
- Soft-delete: `UPDATE public.servicios SET activo = false WHERE lower(nombre) = ...` (el catálogo filtra `activo=true`). Evita `DELETE` si puede estar referenciado por `solicitudes`.

### Nota sobre `tipo_precio` (enum)
- `PRECIO_FIJO`, `POR_UNIDAD`, `POR_JERINGA`, `POR_SESION`, `POR_PLAN` (`servicio_entity.dart`).
- En SQL siempre castear: `'POR_SESION'::public.tipo_precio_enum`.
