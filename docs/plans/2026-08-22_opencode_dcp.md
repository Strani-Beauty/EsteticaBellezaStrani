# Plan: Configurar DCP (Dynamic Context Pruning) para optimizar instrucciones/prompts

| | |
|---|---|
| **Fecha** | 2026-08-22 |
| **Estado** | APROBADO por el usuario (2026-08-22) |
| **Ámbito** | opencode (plugin `@tarquinen/opencode-dcp`), config global + proyecto |
| **Proyecto** | `C:\esteticaybellezastrani` |

## Objetivo

Instalar y configurar **DCP (Dynamic Context Pruning)** para reducir tokens y
**optimizar las instrucciones/prompts** del asistente: habilitar los **6 prompt
overrides** (system, compress-range, compress-message, context-limit-nudge,
turn-nudge, iteration-nudge) tanto **global** como **por proyecto**, alineados a
`AGENTS.md`, **sin afectar el trabajo del proyecto**.

## Decisiones (respuestas del usuario)

1. Config **global + proyecto** (`.opencode/dcp.jsonc` con prioridad máxima).
2. **Todos** los prompt overrides.
3. Overrides de prompts en **global y proyecto**.
4. Solo configurar si **no afecta el trabajo** del proyecto; documentar.

## Garantías de no impacto

- DCP opera solo sobre el contexto de opencode (poda/compacta mensajes antes de
  enviarlos al LLM; no modifica archivos del proyecto ni el historial de sesión).
- Solo se añaden archivos nuevos: globales en `~/.config/opencode/` (fuera del
  repo) y de proyecto en `.opencode/` (tooling). No se toca `lib/`, `supabase/`,
  `docs/`, `test/`, `pubspec.yaml`.
- `AGENTS.md`, `.env` y `supabase/migrations/**` quedan protegidos de la poda
  (`protectedFilePatterns`) para no perder contexto crítico.
- Trade-off documentado: DCP invalida el prompt-cache tras podar (~85% hit vs
  90% sin él); compensa en sesiones largas.

## Actividades → implementación

- [x] A. Persistir este plan (`docs/plans/2026-08-22_opencode_dcp.md`).
- [x] B. Instalar el plugin global: `opencode plugin @tarquinen/opencode-dcp@latest --global`.
- [x] C. Config global `~/.config/opencode/dcp.jsonc`.
- [x] D. Prompt overrides globales `~/.config/opencode/dcp-prompts/overrides/` (6 archivos).
- [x] E. Config de proyecto `.opencode/dcp.jsonc` (versionable).
- [x] F. Prompt overrides de proyecto `.opencode/dcp-prompts/overrides/` (6 archivos).
- [x] G. Documentación en este plan + archivos de override como documentación viva.
- [x] H. Verificación: `flutter analyze`/`flutter test` intactos (sin cambios de código); `git status` solo con `.opencode/` y docs nuevos.

## Archivos a crear

- `~/.config/opencode/dcp.jsonc`
- `~/.config/opencode/dcp-prompts/overrides/{system,compress-range,compress-message,context-limit-nudge,turn-nudge,iteration-nudge}`
- `.opencode/dcp.jsonc`
- `.opencode/dcp-prompts/overrides/{system,compress-range,compress-message,context-limit-nudge,turn-nudge,iteration-nudge}`
- `docs/plans/2026-08-22_opencode_dcp.md`

## Notas

- DCP escribe sus defaults (y un `README.md` que explica los overrides) bajo
  `~/.config/opencode/dcp-prompts/defaults/` al arrancar con `customPrompts: true`;
  ese README es la fuente autoritativa de la ruta de overrides (se ajusta si difiere).
- Reiniciar opencode tras la configuración (no recarga config en caliente).