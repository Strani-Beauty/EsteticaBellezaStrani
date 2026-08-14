# Pruebas manuales — specialists

| | |
|---|---|
| **Módulo** | specialists (onboarding, documentos, verificación, contrato, disponibilidad, presencia, perfil) |
| **Estado del código** | COMPLETO (datasource + 22 usecases + PresenceService en DI) |
| **Fecha** | 2026-08-14 |
| **Versión** | 1.0 |

## Alcance

SpecialistHomeScreen (`/specialist`), SpecialistOnboardingScreen (`/specialist/onboarding`), SpecialistDocumentsScreen (`/specialist/documents`), SpecialistProfileScreen (`/specialist/profile`), ContractSignatureScreen (`/specialist/contract`), SpecialistsCubit, PresenceService, entidades `EstadoVerificacion`/`TipoDocumento`.

## Fuera de alcance

Panel admin que aprueba/rechaza (doc 03), marketplace (doc 06), ejecución de citas (doc 09).

## Precondiciones generales

- Cuentas: `esp.nuevo`, `esp.revision`, `esp.aprobado`, `esp.rechazado`, `esp.bloqueado`, `admin@test`.
- Al menos un médico regente ACTIVO existente en BD.
- Permisos de ubicación y cámara/galería según plataforma.

## 1. Camino feliz

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| SP-H-01 | Onboarding completo | `esp.nuevo` logueado | 1. Entrar a `/specialist` 2. Paso 1: nombre, teléfono, tarifa, dirección (geocoding + mapa) 3. Paso 2: médico regente activo, ≥1 especialidad 4. Enviar | `createSpecialist` + `guardarEspecialidades` + `saveLocation` (EWKT `SRID=4326;POINT(lng lat)`); navega a documentos | Crítica | | |
| SP-H-02 | Subida de documentos requeridos | Perfil creado | 1. `/specialist/documents` 2. Subir IDENTIFICACION 3. Subir LICENCIA | Archivos en bucket `documentos-especialistas` (`<espId>/<ts>.<ext>`); filas con `estado_revision=PENDIENTE`, `activo=true` | Crítica | | |
| SP-H-03 | Solicitar verificación | Ambos documentos subidos | 1. Pulsar "Continuar" | `solicitarVerificacion` → estado `EN_REVISION`; navega al home | Crítica | | |
| SP-H-04 | Home del aprobado | `esp.aprobado` | 1. Entrar a `/specialist` | Tarjetas: verificación APROBADO, perfil, disponibilidad, documentos, contrato; `_MapaPacientesCard` y `_MisCitasCard` visibles (aprobado + disponible) | Alta | | |
| SP-H-05 | Toggle de disponibilidad | Home cargado | 1. Activar/desactivar switch | Upsert en disponibilidad + `especialistas.disponible` sincronizado | Alta | | |
| SP-H-06 | Firma de contrato | Sin contrato firmado | 1. `/specialist/contract` 2. Dibujar firma 3. Confirmar | PNG en bucket `contratos`; `firmarContrato` con `metodo_firma=TOUCH`; `contrato.firmado=true` | Crítica | | |
| SP-H-07 | Guardar ubicación | Onboarding o perfil | 1. Elegir punto en el mapa 2. Guardar | `ubicaciones_especialista` con geometría EWKT correcta | Alta | | |
| SP-H-08 | Pull-to-refresh del home | Home cargado | 1. Deslizar hacia abajo | `loadDashboard` recarga todo sin duplicar estado | Baja | | |
| SP-H-09 | Edición de perfil personal | Perfil existente | 1. `/specialist/profile` 2. Editar nombre/teléfono/dirección/tarifa 3. Guardar | Actualiza `profiles` + datos personales; verificación intacta | Media | | |
| SP-H-10 | Edición de perfil profesional | Perfil existente | 1. Editar licencia/médico regente/especialidades 2. Guardar | `actualizarDatosProfesionales` + `guardarEspecialidades` (reemplaza conjunto: delete+insert) | Alta | | |

## 2. Validaciones y casos negativos

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| SP-V-01 | Paso 1 con campos vacíos | Onboarding | 1. Dejar nombre/teléfono/dirección vacíos 2. Continuar | Validators bloquean el paso | Alta | | |
| SP-V-02 | Paso 2 sin especialidades | Onboarding paso 2 | 1. Sin seleccionar especialidad 2. Enviar | Snackbar exigiendo ≥1 especialidad; no se guarda | Alta | | |
| SP-V-03 | Médico regente obligatorio | Onboarding paso 2 | 1. Dropdown vacío 2. Enviar | Validator obliga a seleccionar | Alta | | |
| SP-V-04 | Dropdown solo muestra activos | Médicos regentes con uno PENDIENTE | 1. Abrir dropdown | Solo aparecen ACTIVOS | Media | | |
| SP-V-05 | Nuevo médico regente | Onboarding paso 2 | 1. Diálogo "registrar médico regente" 2. Datos válidos | Creado con `PENDIENTE`/`activo=false`; queda seleccionado pero no cuenta como válido hasta aprobación admin | Alta | | |
| SP-V-06 | Firma vacía | `/specialist/contract` | 1. Sin dibujar nada 2. Confirmar | Validación impide firmar | Media | | |
| SP-V-07 | Subida de archivo inválido | Documentos | 1. Archivo corrupto o extensión extraña | Error controlado por snackbar; sin crash | Media | | |
| SP-V-08 | "Continuar" deshabilitado | Falta IDENTIFICACION o LICENCIA | 1. Observar el botón | Deshabilitado hasta tener ambos requeridos | Alta | | |

## 3. Roles y permisos (guards / RLS)

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| SP-G-01 | Paciente a rutas de especialista | Sesión de paciente | 1. Deep link `/specialist`, `/specialist/documents`, `/specialist/contract` | Redirect por rol | Crítica | | |
| SP-G-02 | Sin sesión a `/specialist` | Sin sesión | 1. Deep link | Redirect a `/` | Alta | | |
| SP-G-03 | Dueño no puede auto-aprobarse | `esp.revision` | 1. Intentar update directo de `estado_verificacion` (vía cliente/consola) | Trigger `trg_proteger_verificacion_especialista` lo impide; el dueño solo INSERT en PENDIENTE y autosolicitud `PENDIENTE/RECHAZADO → EN_REVISION` | Crítica | | |
| SP-G-04 | Dueño no puede revisar sus documentos | `esp.revision` | 1. Intentar update de `estado_revision`/`revisado_por` | Trigger `trg_proteger_revision_documento` lo impide | Crítica | | |
| SP-G-05 | RLS de documentos | `esp.nuevo` | 1. Listar documentos propios | Solo ve sus propios documentos | Alta | | |

## 4. Estados y transiciones

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| SP-E-01 | Redirect sin perfil | Especialista sin registro | 1. Entrar a `/specialist` | BlocListener redirige a onboarding con `extra:''` | Crítica | | |
| SP-E-02 | Redirect sin datos profesionales | Perfil sin médico regente o sin especialidades | 1. Entrar a `/specialist` | Redirect a onboarding con id | Alta | | |
| SP-E-03 | Redirect por documentos faltantes | Perfil completo, sin IDENTIFICACION/LICENCIA activos | 1. Entrar a `/specialist` | Redirect a documentos | Alta | | |
| SP-E-04 | Rechazado no es redirigido | `esp.rechazado` con docs faltantes | 1. Entrar a `/specialist` | Se queda en el home para leer el motivo (excepción del redirect) | Alta | | |
| SP-E-05 | Motivo de rechazo visible | `esp.rechazado` | 1. Ver `_VerificationCard` | Estado RECHAZADO + observación en rojo + botón "Corregir y reenviar" | Alta | | |
| SP-E-06 | Reenvío tras rechazo | `esp.rechazado` | 1. Corregir documentos 2. "Corregir y reenviar" | `solicitarVerificacion` → `EN_REVISION` de nuevo | Crítica | | |
| SP-E-07 | Documento rechazado exige re-subida | Documento con `estado_revision=RECHAZADO` (`activo=false`) | 1. Entrar al home | El home vuelve a exigir el documento (cuenta como no subido); re-subir crea nueva fila | Alta | | |
| SP-E-08 | Bloqueado | `esp.bloqueado` | 1. Entrar a `/specialist` | Estado BLOQUEADO con observación visible; sin acceso a mapa/citas | Alta | | |
| SP-E-09 | Transiciones válidas de verificación | Distintos estados | 1. Verificar matriz: PENDIENTE→EN_REVISION (dueño); EN_REVISION→APROBADO/RECHAZADO (admin); APROBADO→BLOQUEADO (admin) | Solo el rol autorizado dispara cada transición | Crítica | | |
| SP-E-10 | Presencia heartbeat | Sesión de especialista | 1. Mantener app abierta 60+ s | `en_linea=true`, `ultima_conexion` actualizada cada ~60 s | Media | | |
| SP-E-11 | Offline al pausar | Sesión de especialista | 1. Enviar app a segundo plano | Marca offline al pausar; limpia sesión local en `detached` | Media | | |

## 5. Red y edge cases

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| SP-N-01 | Onboarding sin red | Modo avión | 1. Enviar onboarding | `ServerFailure` → estado `SpecialistsError` con mensaje; sin crash | Alta | | |
| SP-N-02 | Subida de documento sin red | Modo avión | 1. Subir archivo | Error controlado; sin fila huérfana con URL inválida | Alta | | |
| SP-N-03 | Geocoding sin red / edge function caída | Dirección nueva | 1. Geocodificar | Fallback o error claro; el usuario puede elegir punto en mapa | Media | | |
| SP-N-04 | Dashboard con tablas vacías | Especialista recién creado | 1. `loadDashboard` | Estado `Loaded` con colecciones vacías; sin null errors | Alta | | |
| SP-N-05 | `createSpecialist` duplicado | Especialista ya existente | 1. Forzar segunda creación | Violación de unicidad (23505/duplicate) tolerada → recarga dashboard | Media | | |

## 6. Sospechosos de código

| ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas |
|---|---|---|---|---|---|---|---|
| SP-S-01 | Licencia perdida en `_VerificationCard` | Especialista sin perfil | 1. Teclear licencia en el campo 2. Provocar rebuild (teclado, resize, scroll) 3. Revisar el campo | **RESUELTO (2026-08-14)**: `_VerificationCard` es ahora StatefulWidget con controller persistente; el texto ya no se pierde en rebuilds | Alta | | |
| SP-S-02 | Botón envía licencia vacía | Especialista sin perfil | 1. Teclear licencia 2. Pulsar "Solicitar verificación" | **RESUELTO (2026-08-14)**: el botón envía la licencia tecleada (`_enviar`); si está vacía muestra snackbar y no crea el especialista | Alta | | |
| SP-S-03 | Carrera de `solicitarVerificacion` | Documentos completos | 1. Pulsar "Continuar" 2. Observar el home inmediatamente | **Confirmar bug**: `go(home)` sin `await` → el home puede mostrar PENDIENTE en vez de EN_REVISION (refrescar después corrige) | Alta | | |
| SP-S-04 | `version_documento` no incrementa | Documento re-subido | 1. Re-subir el mismo tipo de documento | `version_documento` queda en 1 siempre; verificar si se pierde trazabilidad | Media | | |
| SP-S-05 | Disponibilidad sin ubicación | Sin `ubicaciones_especialista` | 1. Activar disponibilidad | No rompe; el mapa luego no tendrá punto propio | Media | | |

## Resumen de ejecución

| Total | Pasa | Falla | Bloqueado | Pendiente |
|---|---|---|---|---|
| 44 | | | | 44 |
