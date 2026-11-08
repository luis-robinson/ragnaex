# Path-Specific Rules

Rules in `.claude/rules/` carry `paths:` frontmatter. Claude Code loads a
path-scoped rule **when it READS a file matching one of those globs** — not on
every tool use, and not when it creates one.

Three consequences, and none of them are optional reading:

1. **Reading, not editing.** A rule scoped to a gameplay folder reaches the
   model when a file there is opened. An agent that writes a brand-new file in that
   directory without opening an existing one never sees it. Most work in this
   framework creates files rather than reads them, so this is the common case,
   not the corner case.
2. **Context, not enforcement.** A loaded rule is guidance the model weighs, the
   same as `CLAUDE.md`. Anything that must hold regardless of what the model
   decides belongs in a hook — `.claude/hooks/` already enforces JSON validity
   and commit shape that way.
3. **A rule with no `paths:` loads every session**, at the same priority as
   `.claude/CLAUDE.md`. That is the lever for a rule that must always apply; it
   costs context in every session, so it is a deliberate trade, not a default.

Where a rule duplicates guidance an agent definition already carries, the two
must agree. Contradicting instructions are resolved arbitrarily, so a rule and
an agent stating different versions of the same standard is worse than either
alone.

To see which rules actually load, and why, wire the `InstructionsLoaded` hook —
`.claude/hooks/log-instructions.sh` records every instruction file and its load
reason (`session_start`, `path_glob_match`, `nested_traversal`, `include`,
`compact`) to `production/session-logs/instructions-loaded.log`.

**Globs match regardless of case.** Claude Code 2.1.282 matches `paths:`
gitignore-style and case-insensitively (observed; the docs do not say), so
`Assets/**/UI/**` also matches a Godot project's `assets/ui/` art. That is why
the Unity and Unreal code globs below name their file types.

**RagnaEx adaptation.** This is a Godot-only project, so the Unity/Unreal globs
were dropped and every code rule was re-pointed at the RagnaEx tree (code roots
`core/`, `game/`, `data/`; test root `tools/tests/`). Each re-pointed rule ends
with a `## RagnaEx adaptation` section that wins over the generic lines above
it. See `docs/ccgs-adoption.md`.

| Rule File | Path Pattern | Enforces |
| ---- | ---- | ---- |
| `ragnaex-architecture.md` | `core/**`, `game/**`, `data/**` | **Project golden rules**: sim vs presentation, Balance-only tuning, pt-BR text/comments + English names, static typing, a `check()` per new rule/content, Definition of Done |
| `gameplay-code.md` | `core/sim/**` | Data-driven values (`data/balance.gd`), fixed-tick time, `Sim` autoload + static systems, no UI references |
| `engine-code.md` | `core/**` | No presentation deps in the sim, zero allocs in the tick, measured optimizations |
| `ai-code.md` | `core/sim/ai/**` | Brains emit `InputCommand`s only, sim tick budget, data-driven params |
| `network-code.md` | `core/sim/**` | The sim is the future authoritative server: command-driven, deterministic; save format versioning |
| `ui-code.md` | `game/ui/**` | No game state ownership, pt-BR text (no localization system yet), built in code |
| `design-docs.md` | `design/**`, `docs/**` | GDD sections for new `design/gdd/` docs; legacy pt-BR `docs/` keep their format |
| `narrative.md` | `data/catalog/quests_catalog.gd`, `data/catalog/bots_catalog.gd` | Lore consistency, character voice, pt-BR text |
| `data-files.md` | `data/**` | Catalog/schema rules, constants only in `balance.gd`, generated zone JSON |
| `test-standards.md` | `tools/tests/**` | `check()` in `run_tests.gd`, TEST_SLOT, watch a regression check fail first |
| `prototype-code.md` | `prototypes/**` | Relaxed standards, README required, hypothesis documented |
| `shader-code.md` | `**/*.gdshader` | Naming for new shaders, uniforms, toon merge keys |
| `scene-files.md` | `**/*.tscn`, `**/*.tres` | Hand-edit limits for editor-written scene and resource files |
| `agent-memory.md` | `.claude/agent-memory/**` | The one place an agent may write unasked — and why a temporary absence must never be recorded as a durable fact |
| `skill-authoring.md` | `.claude/skills/**`, `.claude/agents/**` | A check must be able to report that it did not run — the five obligations for verdicts, defaults, skips, sourcing and derived coverage |

Several rules overlap on `core/sim/**` (gameplay, engine, network, and
`ragnaex-architecture`); their RagnaEx sections were written to agree.

> **`skill-authoring.md` is the odd one out and deliberately so.** Every other
> rule here scopes a *game* directory; that one scopes the **framework's own**
> authoring paths. It exists because one failure shape kept recurring across
> unrelated subsystems — a step that could not run producing output
> indistinguishable from a step that ran and found nothing. The same mistake in
> nine places is a missing design rule, not nine mistakes.
