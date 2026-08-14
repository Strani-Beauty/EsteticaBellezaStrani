# Plan — Documentos de pruebas manuales por módulo

- **Fecha**: 2026-08-14
- **Estado**: aprobado por el usuario
- **Autor**: asistente (opencode)

## Objetivo

Crear un plan de pruebas de usuario para cada módulo desarrollado hasta ahora, con casos diseñados para revelar errores de flujo y de código. Cada módulo tendrá su documento en `docs/Pruebas manuales/`.

## Decisiones tomadas (confirmadas con el usuario)

- `reports_dashboards` se **omite**: el módulo está vacío (sin pantallas, cubits ni rutas).
- Se crean además dos documentos transversales: índice general y flujos integrados E2E.
- Formato de casos: **tabla completa** (ID, título, precondiciones, pasos, resultado esperado, prioridad, resultado, notas).

## Inventario de módulos (estado real verificado en código)

| Módulo | Estado | Evidencia |
|---|---|---|
| auth_users | COMPLETO | datasource real + repo + cubit en DI |
| specialists | COMPLETO | datasource real + 22 usecases + PresenceService |
| admin_config | PARCIAL | DI vacío; la UI usa SpecialistsCubit |
| admin_users | COMPLETO | datasource real + cubit en DI |
| catalog_services | COMPLETO | datasource real + cubit en DI |
| marketplace_citas | COMPLETO | datasource con RPCs + cubit en DI |
| patients_compliance | STUB | repo const delegando en SupabaseService legacy; sin cubit |
| payments_stripe | COMPLETO | datasource real + cubit factory; sin pantallas propias |
| reports_dashboards | STUB TOTAL | carpeta vacía (se omite) |
| treatment_execution | COMPLETO | datasource real + 12 usecases |
| treatment_photos | COMPLETO | datasource real + cubit; ruta inalcanzable desde la UI |

## Entregables

- [x] `docs/plans/2026-08-14_pruebas_manuales_por_modulo.md` (este archivo)
- [x] `docs/Pruebas manuales/00_indice_general.md`
- [x] `docs/Pruebas manuales/01_auth_users.md`
- [x] `docs/Pruebas manuales/02_specialists.md`
- [x] `docs/Pruebas manuales/03_admin_config.md`
- [x] `docs/Pruebas manuales/04_admin_users.md`
- [x] `docs/Pruebas manuales/05_catalog_services.md`
- [x] `docs/Pruebas manuales/06_marketplace_citas.md`
- [x] `docs/Pruebas manuales/07_patients_compliance.md`
- [x] `docs/Pruebas manuales/08_payments_stripe.md`
- [x] `docs/Pruebas manuales/09_treatment_execution.md`
- [x] `docs/Pruebas manuales/10_treatment_photos.md`
- [x] `docs/Pruebas manuales/11_flujos_integrados_e2e.md`

## Estructura común de cada documento

1. Encabezado: módulo, estado del código, fecha, versión.
2. Alcance y fuera de alcance.
3. Precondiciones generales (cuentas, entorno, Stripe simulado).
4. Tablas de casos por sección: camino feliz → validaciones y negativos → roles/permisos (guards + RLS) → estados y transiciones → red y edge cases.
5. Sección **Sospechosos de código**: casos dirigidos a confirmar o refutar bugs potenciales detectados al leer el código.
6. Resumen de ejecución (contadores Pasa/Falla/Bloqueado/Pendiente).

Formato de fila: `ID | Título | Precondiciones | Pasos | Resultado esperado | Prioridad | Resultado | Notas`.
Prioridades: Crítica / Alta / Media / Baja.

## Puntos calientes detectados en el código (los casos deben atacarlos)

1. Navegación rota al detalle de cita: `MisCitasScreen` usa `push('/specialist/mis-citas/:id', extra: id)` pero `CitaDetalleScreen` lee `pathParameters['id']` → recibe el literal `':id'`.
2. Ruta de fotografías `/tratamiento/:id/fotos` inalcanzable desde la UI.
3. Botón logout de `ProfileScreen` en modo no-edición muestra snackbar sin ejecutar `signOut`.
4. `_VerificationCard` (home sin perfil): controller inline pierde texto en rebuilds y el botón envía licencia vacía (`onCreate('')`).
5. `solicitarVerificacion` sin `await` antes de `go(home)` → el home puede cargar estado viejo.
6. Qualify siempre aprueba y marca `payment_completed=true` aunque el paciente pospusiera el pago de $30.
7. Pago solo-depósito deja la solicitud en `BORRADOR` (no aparece en el marketplace).
8. `registerInitialPayment` no toca `profiles.activo` (la activación depende de `saveQualifyTestValidation`).
9. `avanzar` no valida transiciones de estado y traga errores (fold descarta la failure).
10. Eliminar fotografía no borra el archivo del bucket (`pathEnStorage` nunca se pasa desde la UI).
11. Deep-links con sesión de otro rol (paciente → `/admin`, `/specialist`).
12. Especialista/admin desactivado vía admin_users → guard fuerza logout.
13. PaymentSheet cancelado → el flujo debe abortarse sin registros huérfanos.
14. Documento rechazado (`activo=false`) exige re-subida; `version_documento` nunca incrementa.
15. Concurrencia en `aceptar_solicitud` ("primer aviso gana") y fold que ignora failures en `MarketplaceCubit.aceptar`.

## Verificación final

- Listar `docs/Pruebas manuales/` y confirmar los 12 archivos.
- IDs de casos consistentes entre el índice y los documentos.
- No se toca código → no requiere `flutter analyze` / `flutter test`.
