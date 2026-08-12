# Plan: Contrato/firma manuscrita, refuerzo de verificación y disponibilidad upsert

**Fecha:** 2026-08-13
**Origen:** revisión de 3 puntos (contratos, estado PENDIENTE, disponibilidad_especialista).
**Decisiones:** firma manuscrita (trazo) subida al bucket `contratos`; ajustar trigger para permitir que el especialista cambie su propio `disponible`.

---

## Estado

- [x] Fase 1 — Contrato + firma manuscrita
- [x] Fase 2 — Refuerzo verificación en `aceptar_solicitud`
- [x] Fase 3 — Disponibilidad upsert + sincronización
- [x] Verificación local (`flutter analyze` limpio, `flutter test` 14/14, `flutter build web` OK)
- [x] Aplicar migraciones al remoto (`supabase db push`)

---

## Fase 1 — Contrato + firma manuscrita (punto 1)

- [x] **1.1 Migración** `supabase/migrations/20260813020000_contratos_storage_firma.sql`: bucket público `contratos` + storage policies.
- [x] **1.2 Datasource** `subirFirmaContrato` en `specialists_supabase_datasource.dart`.
- [x] **1.3 Repo** `subirFirmaContrato` en `i_specialists_repository.dart` + impl.
- [x] **1.4 Cubit** `firmarContratoConFirma` (sube firma + `signContract`).
- [x] **1.5 Pantalla** `contract_signature_screen.dart`.
- [x] **1.6 UI** `_ContratoCard` botón "Firmar contrato".
- [x] **1.7 Router** ruta `/specialist/contract`.

## Fase 2 — Refuerzo verificación (punto 2)

- [x] **2.1 Migración** `aceptar_solicitud` valida APROBADO + activo → `motivo 'NO_APROBADO'`.

## Fase 3 — Disponibilidad upsert + sync (punto 3)

- [x] **3.1 Migración** trigger `proteger_verificacion_especialista` (quitar `disponible` del UPDATE protegido).
- [x] **3.2 Datasource/repo** `upsertDisponibilidad` + setear `especialistas.disponible` (vía `UpdateEspecialista`).
- [x] **3.3 Cubit** `toggleDisponibilidad` → upsert + sync `disponible`.
- [x] **3.4 Marketplace** `.eq('disponible', true)` en `fetchEspecialistasAprobados`.
- [x] **3.5 Limpieza** quitadas `rpcEspecialistasCercanos`/`rpcValidarDisponibilidad`.

## Verificación

- [ ] `flutter analyze`, `flutter test`, `flutter build web`.
- [ ] Aplicar migraciones con `supabase db push` (confirmación usuario).
