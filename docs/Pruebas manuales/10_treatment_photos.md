# Pruebas manuales — treatment_photos

| | |
|---|---|
| **Módulo** | treatment_photos (fotografías PRE/POST de tratamiento) |
| **Estado del código** | COMPLETO (datasource + repo + TreatmentPhotosCubit en DI); accesible desde CitaDetalleScreen desde 2026-08-14 |
| **Fecha** | 2026-08-14 |
| **Versión** | 1.0 |

## Alcance

FotografiasScreen (`/tratamiento/:id/fotos`): galería PRE/POST/OTRO, registro por URL, subida binaria, borrado; TreatmentPhotosCubit.

## Fuera de alcance

Creación del tratamiento (doc 09).

## Precondiciones generales

- Un tratamiento existente (crear vía ejecución de cita, doc 09).
- Acceso a la pantalla: desde CitaDetalleScreen (botón "Fotografías del tratamiento") o con **deep link manual** `/tratamiento/<id>/fotos`.

## 1. Camino feliz

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| TF-H-01 | Carga de galería | Tratamiento con fotos | 1. Deep link con id válido | Fotos ordenadas por `fecha_captura` desc; secciones PRE/POST/OTRO con contadores; grid 2 columnas con `CachedNetworkImage` | Alta | | |
| TF-H-02 | Registrar por URL | Formulario | 1. URL válida + descripción + tipo 2. Guardar | `registrarPorUrl` crea fila; aparece en la galería | Alta | | |
| TF-H-03 | Subida binaria | Imagen local | 1. Subir imagen | Bucket `fotografias-tratamiento`, path `<tratId>/<ts>_<ext>`; spinner `uploading`; fila con tipo | Alta | | |
| TF-H-04 | Eliminar fotografía | Foto existente | 1. Eliminar 2. Confirmar | `eliminarFotografia(id)` borra la fila; galería actualizada | Media | | |

## 2. Validaciones y casos negativos

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| TF-V-01 | URL vacía | Formulario | 1. Guardar sin URL | Validator bloquea | Media | | |
| TF-V-02 | URL inválida | Formulario | 1. URL malformada | Error controlado al cargar la imagen; sin crash | Media | | |
| TF-V-03 | Id de tratamiento inválido | Deep link con id inexistente | 1. Cargar | Estado de error con Reintentar | Alta | | |
| TF-V-04 | Galería vacía | Tratamiento sin fotos | 1. Cargar | Vista vacía controlada | Baja | | |

## 3. Roles y permisos (guards / RLS)

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| TF-G-01 | Ruta autenticada | Sin sesión | 1. Deep link | Guard `resolveAuthRedirect` envía a `/` (no es ruta pública) | Alta | | |
| TF-G-02 | Fotos ajenas | Paciente/especialista sin relación | 1. Deep link con tratamiento ajeno | RLS impide leer fotos de otro paciente | Alta | | |
| TF-G-03 | Bucket público | — | 1. Inspeccionar políticas del bucket `fotografias-tratamiento` | Escritura solo autenticados; lectura según diseño (URLs públicas) | Media | | |

## 4. Estados y transiciones

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| TF-E-01 | Secuencia del cubit | Carga | 1. Observar estados | `Loading` → `Loaded(fotografias, uploading)` | Baja | | |
| TF-E-02 | Contadores por tipo | Fotos mixtas | 1. Revisar secciones | Conteo correcto por PRE/POST/OTRO | Media | | |

## 5. Red y edge cases

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| TF-N-01 | Carga sin red | Modo avión | 1. Cargar galería | Estado de error con Reintentar | Alta | | |
| TF-N-02 | Subida sin red | Modo avión | 1. Subir | Error controlado; sin fila con URL muerta | Alta | | |
| TF-N-03 | Imagen muy grande | Foto >10 MB | 1. Subir | Comportamiento definido: progreso o error claro; sin crash | Media | | |
| TF-N-04 | CachedNetworkImage con URL rota | URL 404 | 1. Ver galería | Placeholder/error del widget; sin crash | Baja | | |

## 6. Sospechosos de código

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| TF-S-01 | Ruta muerta | — | 1. Abrir una cita en EN_PROCESO y tocar "Fotografías del tratamiento" | **RESUELTO (2026-08-14)**: se añadió entrada en `CitaDetalleScreen` (EN_PROCESO) que navega a `/tratamiento/<id>/fotos`; verificar la navegación | Crítica | | |
| TF-S-02 | Borrado no limpia el bucket | Foto subida | 1. Eliminar desde la UI 2. Verificar bucket | **Confirmar bug**: `eliminarFotografia` se llama sin `pathEnStorage`; el archivo queda huérfano en Storage | Alta | | |
| TF-S-03 | Doble columna de tipo | Subida nueva | 1. Subir foto 2. Inspeccionar fila en BD | Escribe `tipo_fotografia` y además `tipo_foto` en minúsculas; verificar cuál es la columna oficial del esquema | Media | | |

## Resumen de ejecución

| Total | Pasa | Falla | Bloqueado | Pendiente |
|---|---|---|---|---|
| 20 | | | | 20 |
