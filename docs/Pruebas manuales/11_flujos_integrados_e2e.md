# Pruebas manuales — Flujos integrados (E2E)

| | |
|---|---|
| **Módulo** | Flujos completos que cruzan varios módulos |
| **Fecha** | 2026-08-14 |
| **Versión** | 1.0 |

## Objetivo

Detectar errores de integración entre módulos que las pruebas aisladas no ven: estados que no se propagan, guards que no reaccionan, datos que quedan huérfanos.

## Precondiciones generales

- Cuentas limpias (recién creadas) para los flujos A y B.
- ⚑ Dos dispositivos para concurrencia y desactivación remota.
- Stripe en modo simulado o real (indicar en notas cuál).

---

## E2E-A — Paciente completo: registro → evaluación → reserva publicada

**Módulos**: auth_users, patients_compliance, payments_stripe, catalog_services.

| Paso | Acción | Resultado esperado | Ref |
|---|---|---|---|
| 1 | Registrar paciente nuevo y confirmar correo | Perfil con `activo=false`, rol Paciente | AU-H-02 |
| 2 | Login → `/complete-profile` | Guard de paciente dirige a completar perfil | AU-H-04 |
| 3 | Completar teléfono/dirección y pagar cuota $30 | `payment_completed=true`, `pacientes.activo=true`; pasa al cuestionario | PS-H-01 |
| 4 | Responder cuestionario y elegir modalidad | Evaluación de salud guardada | PC-H-01 |
| 5 | Esperar proceso Qualify | `profiles.activo=true`, evaluación APROBADA con vigencia 365 días | PC-H-03 |
| 6 | Ir al catálogo y seleccionar servicio no facial | Banner verde; modal de pago | CS-H-04 |
| 7 | Pagar totalidad | Solicitud **PUBLICADA**; diálogo de éxito | PS-H-03 |
| 8 | Verificar en BD | `solicitudes.estado=PUBLICADA`, `pagos` PAGADO, transacción PAGO_TOTAL | CS-E-04 |

**Variante A2**: en el paso 3 pulsar "Posponer" → continuar → verificar si Qualify marca `payment_completed=true` sin haber pagado (PC-S-02). **Resultado esperado de negocio: NO debería marcarlo; confirmar el bug.**

---

## E2E-B — Especialista completo: registro → verificación → acepta cita

**Módulos**: auth_users, specialists, admin_config, marketplace_citas, payments_stripe.

| Paso | Acción | Resultado esperado | Ref |
|---|---|---|---|
| 1 | Registrar especialista nuevo | Perfil con `activo=true`, rol Especialista | AU-H-02 |
| 2 | Login → `/specialist` | Redirect automático a onboarding (sin perfil) | SP-E-01 |
| 3 | Completar onboarding (datos + médico regente + especialidades + ubicación) | Especialista creado; navega a documentos | SP-H-01 |
| 4 | Subir IDENTIFICACION y LICENCIA | Filas con `estado_revision=PENDIENTE` | SP-H-02 |
| 5 | "Continuar" | Estado `EN_REVISION`; home muestra estado | SP-H-03 |
| 6 | Como admin: aprobar especialista | `APROBADO`, `activo=true`, `aprobadoPor` | AC-H-02 |
| 7 | Como especialista: firmar contrato | `contrato.firmado=true` | SP-H-06 |
| 8 | Activar disponibilidad | `especialistas.disponible=true` | SP-H-05 |
| 9 | Entrar a `/specialist/map` | Mapa carga; el especialista cumple todos los filtros (aprobado+activo+disponible+online) | MK-H-01 |
| 10 | Aceptar una solicitud PUBLICADA (de E2E-A) | "¡El paciente es tuyo!"; cita creada; solicitud desaparece | MK-H-04 |
| 11 | Verificar cita en `/specialist/mis-citas` | Cita PROGRAMADA listada | TE-H-01 |

---

## E2E-C — Ejecución de cita completa con cobro de saldo

**Módulos**: treatment_execution, payments_stripe, treatment_photos.

| Paso | Acción | Resultado esperado | Ref |
|---|---|---|---|
| 1 | Abrir la cita creada en E2E-B desde la lista | **Resuelto (2026-08-14)**: la navegación desde la lista ya funciona (se pasa el id real en el path); el detalle carga | TE-S-01 |
| 2 | Si el paso 1 falla, entrar por deep link `/specialist/mis-citas/<id real>` | Detalle carga correctamente | TE-H-02 |
| 3 | PROGRAMADA → "Comenzar desplazamiento" | EN_CAMINO + historial | TE-H-02 |
| 4 | "Llegué al domicilio" | LLEGO | TE-H-03 |
| 5 | "Iniciar servicio" | EN_PROCESO + tratamiento INICIADO | TE-H-04 |
| 6 | Guardar evaluación inicial | Persistida | TE-H-05 |
| 7 | Agregar 2 insumos y eliminar 1 | 1 insumo restante | TE-H-06 |
| 8 | Firmar consentimiento | Fila en `consentimientos_tratamiento` | TE-H-08 |
| 9 | "Finalizar tratamiento" con saldo pendiente | Diálogo "Cobrar y Finalizar" | TE-H-09 |
| 10 | Cancelar el pago del saldo | La cita NO finaliza; sigue EN_PROCESO | TE-V-03 |
| 11 | Finalizar de nuevo y pagar el saldo | Cita FINALIZADA, tratamiento COMPLETADO, pago PAGADO, pop automático | TE-H-09 |
| 12 | En EN_PROCESO, tocar "Fotografías del tratamiento" (o deep link `/tratamiento/<id>/fotos`) | **Resuelto (2026-08-14)**: entrada desde el detalle de cita; la galería carga | TF-S-01 |
| 13 | Subir foto POST y eliminarla | Foto creada; al eliminar, **el archivo queda en el bucket** (confirmar TF-S-02) | TF-S-02 |

---

## E2E-D — Bloqueo de especialista por admin

**Módulos**: admin_config, auth_users, specialists. ⚑ Dos dispositivos.

| Paso | Acción | Resultado esperado | Ref |
|---|---|---|---|
| 1 | Especialista aprobado con sesión activa en dispositivo 2 | Mapa/citas accesibles | — |
| 2 | Admin bloquea al especialista con motivo | `BLOQUEADO` + observación | AC-H-04 |
| 3 | En dispositivo 2: navegar cualquier ruta | Guard fuerza logout + redirect a `/` | AU-G-08 |
| 4 | Re-login en dispositivo 2 | Logout forzado inmediato; sin acceso | AU-E-05 |
| 5 | Admin desbloquea (aprueba de nuevo) | Especialista recupera acceso | AC-H-02 |

---

## E2E-E — Desactivación de paciente por admin

**Módulos**: admin_users, auth_users. ⚑ Dos dispositivos.

| Paso | Acción | Resultado esperado | Ref |
|---|---|---|---|
| 1 | Paciente activo con sesión en dispositivo 2 | Catálogo accesible | — |
| 2 | Admin desactiva al paciente | `profiles.activo=false` | AUU-H-02 |
| 3 | En dispositivo 2: navegar a `/profile` | Guard restringe a rutas permitidas (`/complete-profile`, etc.) | AU-G-10 |
| 4 | Admin reactiva | Paciente vuelve a operar normal | AUU-H-03 |

---

## E2E-F — Concurrencia en el marketplace

**Módulos**: marketplace_citas. ⚑ Dos especialistas aprobados en dos dispositivos.

| Paso | Acción | Resultado esperado | Ref |
|---|---|---|---|
| 1 | Publicar una solicitud (pago total, E2E-A) | Visible en ambos mapas | MK-E-04 |
| 2 | Ambos pulsan "Aceptar" casi simultáneamente | Uno recibe `aceptada`; el otro `ASIGNADA` ("ya fue asignado") | MK-S-01 |
| 3 | Verificar en BD | Una única cita creada | MK-S-01 |
| 4 | El perdedor refresca | La solicitud ya no aparece | MK-H-05 |

---

## E2E-G — Logout sin red

**Módulos**: auth_users.

| Paso | Acción | Resultado esperado | Ref |
|---|---|---|---|
| 1 | Sesión activa de cualquier rol | — | — |
| 2 | Activar modo avión | — | — |
| 3 | Cerrar sesión | Sesión local limpiada; navegación a `/` sin error | AU-N-01 |
| 4 | Desactivar modo avión y reabrir la app | Sin sesión restaurada | AU-H-07 |

---

## Resumen de ejecución

| Flujo | Pasos | Pasa | Falla | Bloqueado | Pendiente |
|---|---|---|---|---|---|
| E2E-A | 8 | | | | 8 |
| E2E-B | 11 | | | | 11 |
| E2E-C | 13 | | | | 13 |
| E2E-D | 5 | | | | 5 |
| E2E-E | 4 | | | | 4 |
| E2E-F | 4 | | | | 4 |
| E2E-G | 4 | | | | 4 |
| **Total** | **49** | | | | **49** |
