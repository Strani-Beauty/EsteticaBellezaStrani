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
