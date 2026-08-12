# Contrato con firma manuscrita, verificación en aceptación y disponibilidad

**Fecha:** 2026-08-13
**Rama:** `main` — commit `d9e6797`
**Plan:** `docs/plans/2026-08-13_contrato_disponibilidad_verificacion.md`

---

## 1. Contexto y motivo

Se revisaron tres puntos de la gestión de especialistas para identificar qué faltaba implementar:

1. Registro de la información contractual mediante la tabla `contratos`, dejando preparada la firma digital.
2. Estado inicial del especialista como **Pendiente de Verificación**, sin operar en el Marketplace hasta ser aprobado.
3. `disponibilidad_especialista` para definir cuándo puede prestar servicios.

### Resultado del diagnóstico

| Punto | Estado previo | Acción |
|---|---|---|
| Contrato + firma | Datos/RLS/repositorio listos, **pero sin UI** (`signContract` nunca se invocaba) | Pantalla de firma manuscrita + subida al bucket `contratos` |
| Estado PENDIENTE | Código completo; **gap en BD**: el RPC `aceptar_solicitud` no validaba aprobación | Refuerzo en el RPC |
| Disponibilidad | INSERT en cada toggle (acumulaba filas) y **no sincronizaba** `especialistas.disponible` | Upsert + sincronización del flag |

---

## 2. Cambios realizados

### 2.1 Fase 1 — Contrato con firma manuscrita

**Migración** `supabase/migrations/20260813020000_contratos_storage_firma.sql`:
- Crea el bucket público `contratos`.
- Storage policies: el especialista sube su firma (`<especialistaId>/<archivo>`), lectura pública.

**Código** (módulo `specialists`):
- `subirFirmaContrato` en datasource, repositorio e interfaz: sube la imagen PNG al bucket `contratos` y devuelve la URL pública.
- Usecase `SubirFirmaContrato` (`get_contrato.dart`).
- Cubit `firmarContratoConFirma`: sube la firma y registra el contrato con `metodo_firma=TOUCH` y `url_documento` = URL de la imagen.
- Pantalla `contract_signature_screen.dart`: texto del contrato + `Signature` (package `signature`) + botón "Firmar contrato".
- `_ContratoCard` (home): muestra estado y, si no está firmado, botón "Firmar contrato" que navega a `/specialist/contract`.
- Ruta nueva `AppRoutes.specialistContract = '/specialist/contract'` (queda bajo el guard de especialista).

### 2.2 Fase 2 — Refuerzo de verificación en la aceptación

**Migración** `supabase/migrations/20260813020100_aceptar_solicitud_validar_especialista.sql`:
- La función `aceptar_solicitud` ahora valida que el especialista tenga `estado_verificacion = 'APROBADO'` y `activo = true` antes de reclamar la solicitud.
- Si no cumple, devuelve `{'aceptada': false, 'motivo': 'NO_APROBADO'}`.

**Código** (módulo `marketplace_citas`):
- `ResultadoAceptacionEntity.noAprobado` (getter para el motivo `NO_APROBADO`).
- Cubit `aceptar`: rama nueva que muestra feedback "Solo los especialistas verificados y activos pueden aceptar solicitudes".

### 2.3 Fase 3 — Disponibilidad upsert + sincronización

**Migración** `supabase/migrations/20260813020200_disponibilidad_own_update.sql`:
- Ajusta el trigger `proteger_verificacion_especialista` para que el **dueño** pueda actualizar su propio `disponible` (se quita de la lista protegida en UPDATE).
- Se mantienen protegidos `estado_verificacion`, `activo`, `aprobado_por`, fechas y `observacion`. En INSERT sigue exigiendo PENDIENTE/activo=false/disponible=false.

**Código**:
- `upsertDisponibilidad` en datasource/repositorio: inserta si no existe, actualiza si existe (una única fila vigente por especialista).
- Usecase `UpsertDisponibilidad` (`set_disponibilidad.dart`).
- Cubit `toggleDisponibilidad`: usa upsert y sincroniza `especialistas.disponible` vía `UpdateEspecialista`.
- Marketplace `fetchEspecialistasAprobados`: añade `.eq('disponible', true)`.
- Limpieza: se eliminaron las constantes RPC muertas `rpcEspecialistasCercanos` y `rpcValidarDisponibilidad` de `app_constants.dart`.

---

## 3. Seguridad (defensa en profundidad)

- **Verificación**: el estado inicial sigue siendo `PENDIENTE` (trigger en INSERT), la aprobación queda reservada al admin (trigger en UPDATE), y ahora también la **aceptación de solicitudes** exige APROBADO+activo en BD (no solo en la UI).
- **Disponibilidad**: el especialista puede alternar solo su propio `disponible`; no puede auto-cambiarse `estado_verificacion`, `activo`, `aprobado_por` ni `observacion`.
- **Storage**: la subida de firma de contrato valida que el primer folder del path sea el `id` del especialista autenticado.

---

## 4. Aplicación

Las 3 migraciones se aplicaron al remoto con `supabase db push`:

1. `20260813020000_contratos_storage_firma.sql`
2. `20260813020100_aceptar_solicitud_validar_especialista.sql`
3. `20260813020200_disponibilidad_own_update.sql`

Verificación: `supabase migration list` muestra las 3 como aplicadas en Remote.

---

## 5. Verificación de código

- `flutter analyze` → sin issues.
- `flutter test` → 14/14.
- `flutter build web` → OK.

---

## 6. Git

| | |
|---|---|
| Commit | `d9e6797` |
| Mensaje | `Contrato con firma manuscrita, verificación en aceptar_solicitud y disponibilidad upsert` |
| Rama | `main` → pusheado a `origin/main` |

---

## 7. Verificación manual sugerida

1. **Contrato**: con una cuenta de especialista, en el home → "Firmar contrato" → dibujar firma → guardar. Verificar que aparece "Contrato firmado" y que en `contratos` se crea la fila con `firmado=true` y `url_documento` apuntando a la imagen en el bucket `contratos`.
2. **Verificación**: un especialista NO aprobado (PENDIENTE/RECHAZADO/BLOQUEADO) no debe poder aceptar solicitudes; el RPC responde `NO_APROBADO` (aunque la UI ya lo oculta).
3. **Disponibilidad**: alternar el toggle → debe persistir en `disponibilidad_especialista` (una sola fila vigente) y reflejarse en `especialistas.disponible`; el mapa de pacientes solo muestra especialistas APROBADOS, activos y disponibles.
