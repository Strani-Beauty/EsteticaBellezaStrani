# Plan — Revisión de producto: correcciones de UI/UX (7 puntos)

Fecha: 2026-09-28
Estado: APROBADO por el usuario (m0222: "aprobado"). Implementado; sin commit.

## Origen

Documento "Revisión de producto - App Strani" (`C:\Desarrollo\Revisión APP.docx`)
con 7 observaciones (6 de Clientes/Especialista + 1 de Administrador no listada
en el mensaje). Decisiones confirmadas por el usuario (m0220, todas las
recomendadas): #3 aplicar ámbar a TODOS los avisos de evaluación médica; #4
propagar el servicio por query param con texto que aclara la cuota inicial; #5
la barra cuenta solo preguntas respondibles (excluye archivo/imagen); #7
persistir el "visto" en BD + UI.

## P1 — Chips de categoría no resaltan (BUG)

`lib/features/catalog_services/presentation/cubits/catalog_cubit.dart`
- [x] `CatalogLoaded.copyWith`: conservar `selectedCategoriaId` cuando no se pasa
      y añadir flag explícito `clearCategoria` para "Todos" (=null).
- [x] `selectCategoria`: el 2º emit conserva la categoría elegida.

## P2 — Flecha back del login

`login_screen.dart`, `services_dashboard_screen.dart`, `welcome_screen.dart`
- [x] Entrar al login con `context.push` desde catálogo (`:477`, `:93`) y welcome (`:46`, `:191`).
- [x] Flecha del login: `context.canPop() ? context.pop() : context.go(AppRoutes.welcome)`, tooltip "Volver".
- [x] Listener de sesión expirada (`services_dashboard_screen.dart:425`) se mantiene en `go`.
- Nota: "Volver a selección" ya no existe (eliminado en `265e13f`).
- [ ] (Opcional) limpiar test E2E obsoleto `integration_test/app_test.dart:38`. (no hecho)

## P3 — Avisos de evaluación médica en ámbar (todos)

`services_dashboard_screen.dart` (`_buildStatusBanner` ramas PENDIENTE y VENCIDA),
`service_detail_screen.dart` (`_buildBadgeEvaluacion` y caja $30 del CTA)
- [x] Fondo `cPastelGold`, borde e ícono `cGoldAccent`, texto 13px w600.

## P4 — Mensaje de reserva en "Perfil del Paciente"

`services_dashboard_screen.dart` (`:370`, `:407`), `complete_profile_screen.dart`
- [x] Propagar `?servicio=<nombre>` (URL-encoded) desde evaluación pendiente y renovación.
- [x] Aviso al inicio: "Para continuar con la reserva, completa los siguientes datos."
      + "Vas a pagar $30 USD (cuota inicial de la evaluación médica) para reservar: [servicio]".
      Si no hay servicio (onboarding general), solo el primer mensaje.

## P5 — Barra de progreso del cuestionario

`patient_questionnaire_screen.dart`
- [x] Denominador = preguntas respondibles (excluir `archivo/imagen`), igual que el numerador.
- [x] Contador `X / Y` con el nuevo total; al responder todas → 100%.

## P6 — Flecha back del panel del especialista

`specialist_home_screen.dart` (`:48-63`)
- [x] `leading` con `context.canPop() ? context.pop() : context.go(AppRoutes.welcome)`.
- [ ] (Opcional) `specialist_profile_screen.dart:229-233` usar `canPop()/pop`. (no hecho)

## P7 — Gate de revisión de documentos (BD + UI)

Nueva migración `supabase/migrations/20260928000100_documentos_visto_revision.sql` (idempotente)
- [x] Columnas `visto_por uuid REFERENCES profiles(id) ON DELETE SET NULL`, `visto_en timestamptz`.
- [x] RPC `marcar_documento_visto(p_documento_id uuid)` SECURITY DEFINER (`is_administrador()`), audita `DOCUMENTO_VISTO`.
- [x] Extender `proteger_revision_documento()`: el no-admin no escribe `visto_por/visto_en`;
      `RAISE` si pasa a APROBADO/RECHAZADO con `visto_en IS NULL`.
- [x] Añadir `visto_por`/`visto_en` al trigger `trg_auditoria_documentos_especialista`.
- [x] Entidad/modelo `vistoPor`/`vistoEn`; datasource + repo + usecase + cubit.
- [x] `admin_licencias_screen.dart`: marcar visto al abrir el ojo; gate de Aprobar/Rechazar
      hasta `vistoEn != null`; refrescar el diálogo.

## Verificación

- [x] `flutter analyze` limpio.
- [x] `flutter test` (370, All tests passed!).
- [x] Migración #7 aplicada por pooler + verificación de columnas/RPC/trigger/policies
      (columnas visto_en/visto_por; rpc marcar_documento_visto; triggers
      trg_proteger_revision_documento y trg_auditoria_documentos_especialista;
      grant EXECUTE a authenticated = true).
- [ ] Manual en `flutter run -d chrome`: P1–P6 y P7.

## Notas

- Sin commit (regla del proyecto: preguntar antes).
