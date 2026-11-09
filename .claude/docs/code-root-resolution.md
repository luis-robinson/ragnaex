# Code Root Resolution

Shared procedure for any skill that reads, scans, counts or writes game source
files. **An unresolved code root means the check did not run.** This file gives
the resolution order.

`.claude/docs/directory-structure.md` is the authority for which directory holds
code. This file is the procedure for applying it.

## The roots

| `engine.name` | Code root | Why it cannot be `src/` |
|---|---|---|
| Godot | `src/` | No constraint; Godot loads from `res://` anywhere under the project root |
| Unity | `Assets/` | Unity compiles **only** `Assets/` and `Packages/` |
| Unreal | `Source/<Module>/` | UnrealBuildTool discovers modules under `Source/`; content lives in `Content/` |

`src/` is the **Godot row of that table, not a universal path.**

## Resolution order

0. **Explicit override (RagnaEx adaptation).** `engine.code_roots` — a list —
   from `project.local.yaml`, then `project.yaml`, wins over everything below.
   RagnaEx sets `[core, game, data]`. `resolve_code_root` then prints the roots
   joined by spaces (`core game data`, source `engine.code_roots`);
   `resolve_code_roots` prints one per line and `code_root_regex` prints an
   ERE for path filters (`^(core|game|data)/`). A skill that scans "the code
   root" scans **every** listed root; a skill that writes picks the root the
   architecture rule assigns (`core/` simulation, `game/` presentation, `data/`
   content and tuning — see `.claude/rules/ragnaex-architecture.md`).
1. `engine.name` from `project.local.yaml`, then `project.yaml`.
2. The legacy mirror: an `Engine:` line in
   `.claude/docs/technical-preferences.md`. A value of `[TO BE CONFIGURED]`
   does not count.
3. Derivation from the tree, but **only when it is unambiguous**. Exactly one of
   `src/`, `Assets/` or `Source/` present means that is the root. Two or more
   present means the project is genuinely undecidable — do not guess. Compare the
   names exactly as the directory listing spells them: on Windows and default
   macOS an existence test for `Assets/` also succeeds on Godot's own `assets/`,
   which would make `src/` + `assets/` look ambiguous and a lone `assets/` look
   like Unity.
4. Otherwise: **unresolved.**

The hooks already implement exactly this as `resolve_code_root()` in
`.claude/hooks/yaml-helper.sh` (callable directly:
`bash .claude/hooks/yaml-helper.sh resolve_code_root`). Skills must match its semantics so that a hook
and a skill never disagree about where the code lives.

## Unresolved does not default to `src/`

This is the rule the whole file exists for, and it is obligation 2 of
`.claude/rules/skill-authoring.md`: an absent value may not default to the
permissive one.

**For a read or scan:** report `NOT ASSESSED — code root unresolved` and say
which check did not run. Never report zero hits.

A scan anchored to a root the project does not use matches nothing, and
**nothing is indistinguishable from a clean result.** A localization check finds
no hardcoded strings; a security scan finds no secrets; a content audit counts
no implemented content; a stage detector counts no source files and calls a
finished project greenfield. Every one of those reads as a pass. This has been
found repeatedly across skills and hooks, which is why the resolution lives in
one place now.

**For a write:** do not write. Report the unresolved root and stop.

Writing game code to the wrong root is worse than a false pass, because it
produces a project that cannot build: on Unity, source placed outside `Assets/`
is never compiled and never appears in the editor, so the work is silently
inert. Resolving the engine in order to pick a specialist agent is **not** the
same as resolving the code root — a skill can do the first correctly and still
write to the wrong directory.

## Applying it

Where a skill says `src/`, read it as *the code root* and substitute the table
above. Where a skill greps, glob the resolved root. Where a skill writes,
write under the resolved root and use the engine's own conventions beneath it
(`Assets/Scripts/<System>/` on Unity, `Source/<Module>/<System>/` on Unreal).

## The test root (RagnaEx adaptation)

The same override exists for tests: `engine.test_root` (a path, or a list)
wins over the engine's test-root table in `directory-structure.md`.
`resolve_test_root` in `yaml-helper.sh` prints `<dirs>	<source>`. RagnaEx sets
`tools/tests`: one hand-rolled runner, `tools/tests/run_tests.gd`
(`check(...)` calls, scene `tools/tests/tests.tscn`), plus the `*_probe.tscn`
tools beside it. Where a skill says `tests/unit/[system]/` or
`tests/integration/[system]/`, read it as **a new `_check_<system>` function
in `tools/tests/run_tests.gd`** (run alone with `-- --only=<system>`), not a
new file. gdUnit4 is not used; do not scaffold it (`/test-setup`).
