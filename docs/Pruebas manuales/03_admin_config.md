# Pruebas manuales — admin_config

| | |
|---|---|
| **Módulo** | admin_config (panel admin de verificación de licencias, documentos y médicos regentes) |
| **Estado del código** | PARCIAL (DI vacío; AdminDashboardScreen usa SpecialistsCubit del módulo specialists) |
| **Fecha** | 2026-08-14 |
| **Versión** | 1.0 |

## Alcance

AdminDashboardScreen (`/admin`): lista de especialistas con estado de verificación, acciones aprobar/rechazar/bloquear, revisión de documentos, aprobación de médicos regentes, enlace a `/admin/usuarios`.

## Fuera de alcance

Gestión de activación de usuarios (doc 04), flujo del especialista que envía documentos (doc 02).

## Precondiciones generales

- Cuenta `admin@test` (rol Administrador).
- Especialistas en distintos estados: `esp.nuevo` (PENDIENTE), `esp.revision` (EN_REVISION), `esp.aprobado`, `esp.rechazado`, `esp.bloqueado`.
- Al menos un médico regente PENDIENTE y uno ACTIVO.

## 1. Camino feliz

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| AC-H-01 | Carga del panel | Admin logueado | 1. Entrar a `/admin` | `loadAllEspecialistas()`: lista con badge de estado, licencia, fecha de solicitud; documentos por especialista; médicos regentes | Crítica | | |
| AC-H-02 | Aprobar especialista | `esp.revision` | 1. Pulsar "Aprobar" | `updateVerificacion` → `APROBADO`, `activo=true`, `aprobadoPor`=id del admin, fechas; observación limpiada | Crítica | | |
| AC-H-03 | Rechazar con motivo | `esp.revision` | 1. "Rechazar" 2. Escribir motivo 3. Confirmar | `RECHAZADO` + observación guardada; el especialista ve el motivo en su home | Crítica | | |
| AC-H-04 | Bloquear con motivo | `esp.aprobado` | 1. "Bloquear" 2. Motivo 3. Confirmar | `BLOQUEADO` + observación; especialista pierde acceso al marketplace | Crítica | | |
| AC-H-05 | Ver documento | Documento con adjunto | 1. Pulsar "Ver" | `url_launcher` abre la URL del archivo | Media | | |
| AC-H-06 | Aprobar documento | Documento EN_REVISION | 1. "Aprobar documento" | `revisarDocumento` → `APROBADO`, `activo=true`, `revisado_por`, `fecha_revision` | Alta | | |
| AC-H-07 | Rechazar documento | Documento EN_REVISION | 1. "Rechazar documento" 2. Motivo | `RECHAZADO` + `observacion_revision` + `activo=false` | Alta | | |
| AC-H-08 | Aprobar médico regente | Médico PENDIENTE | 1. "Aprobar médico regente" | `aprobarMedicoRegente` → ACTIVO; aparece en dropdowns de onboarding | Alta | | |
| AC-H-09 | Enlace a usuarios | Panel cargado | 1. Pulsar enlace a `/admin/usuarios` | Navega correctamente | Baja | | |

## 2. Validaciones y casos negativos

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| AC-V-01 | Rechazo con motivo vacío | Diálogo de motivo | 1. Confirmar con texto vacío | **Confirmar comportamiento**: el diálogo permite confirmar vacío → `observacion=null`; verificar qué ve el especialista (sin motivo) | Alta | | |
| AC-V-02 | Motivo >500 caracteres | Diálogo de motivo | 1. Teclear 501 caracteres | `maxLength 500` recorta; no se envía más | Baja | | |
| AC-V-03 | Documento sin adjunto | Fila sin archivo | 1. Pulsar "Ver" | Snackbar indicando que no hay adjunto; sin crash | Media | | |
| AC-V-04 | Lista vacía | Sin especialistas | 1. Cargar panel | Vista vacía controlada; sin crash | Baja | | |

## 3. Roles y permisos (guards / RLS)

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| AC-G-01 | Paciente a `/admin` | Sesión de paciente | 1. Deep link `/admin` | Guard redirige por rol | Crítica | | |
| AC-G-02 | Especialista a `/admin` | Sesión de especialista | 1. Deep link `/admin` | Guard redirige a `/specialist` | Crítica | | |
| AC-G-03 | Sin sesión a `/admin` | Sin sesión | 1. Deep link | Redirect a `/` | Crítica | | |
| AC-G-04 | RLS de aprobación | Paciente/especialista | 1. Intentar `updateVerificacion` vía cliente | RLS/policies lo impiden; solo `Administrador` | Crítica | | |
| AC-G-05 | Admin ve especialistas pendientes | Admin | 1. Cargar panel | `loadAllEspecialistas` incluye médicos regentes PENDIENTE y documentos de todos | Media | | |

## 4. Estados y transiciones

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| AC-E-01 | Badge por estado | Especialistas en cada estado | 1. Revisar la lista | Badge correcto para PENDIENTE/EN_REVISION/APROBADO/RECHAZADO/BLOQUEADO | Media | | |
| AC-E-02 | Motivo visible en lista | Rechazado/bloqueado | 1. Revisar tarjeta | Motivo de rechazo/bloqueo mostrado | Alta | | |
| AC-E-03 | Efecto de aprobar en el especialista | `esp.revision` | 1. Aprobar 2. Login como el especialista | Especialista ve APROBADO; tarjetas de mapa/citas disponibles si cumple el resto | Crítica | | |
| AC-E-04 | Efecto de bloquear en sesión activa | ⚑ `esp.aprobado` con sesión abierta en otro dispositivo | 1. Bloquear como admin 2. Navegar en el dispositivo del especialista | Guard detecta `activo=false`/bloqueado y fuerza logout | Alta | | |
| AC-E-05 | Documentos por especialista | Varios documentos | 1. Expandir sección | Cada documento con su estado de revisión y acciones | Media | | |

## 5. Red y edge cases

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| AC-N-01 | Carga sin red | Modo avión | 1. Entrar a `/admin` | `_ErrorView` con botón "Reintentar" | Alta | | |
| AC-N-02 | Acción sin red | Modo avión | 1. Aprobar | Snackbar de error; estado sin cambiar | Alta | | |
| AC-N-03 | Reintentar tras error | Error de carga previo | 1. Pulsar "Reintentar" | Recarga el panel correctamente | Media | | |
| AC-N-04 | URL de documento rota | URL inválida en BD | 1. "Ver" | Error controlado; sin crash | Baja | | |

## 6. Sospechosos de código

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| AC-S-01 | Módulo sin datasource propio | — | 1. Revisar que toda acción pasa por SpecialistsCubit | Documentar dependencia: admin_config no tiene DI propio; fallos del módulo specialists afectan este panel | Baja | | |
| AC-S-02 | Bloqueo sin motivo | Diálogo | 1. Bloquear con motivo vacío | `observacion=null`; especialista bloqueado sin explicación — decidir si es aceptable | Media | | |

## Resumen de ejecución

| Total | Pasa | Falla | Bloqueado | Pendiente |
|---|---|---|---|---|
| 29 | | | | 29 |
