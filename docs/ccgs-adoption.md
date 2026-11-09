# Claude Code Game Studios — adoption notes (RagnaEx)

RagnaEx adopted an **adapted selection** of the open-source framework
**Claude Code Game Studios** (CCGS, MIT licence) on 2026-11-08.

- Upstream: https://github.com/Donchitos/Claude-Code-Game-Studios
- Version: **v1.2.0**, commit `05ad7c8a5b8aa2aa86bbd3439ae7cf7295cac418`
  ("Release 1.2.0 — the main path, rebuilt and tested")
- Licence: copied to `.claude/CCGS-LICENSE`
- Decisions (user): adapted selection, not verbatim; automation mode **guided**;
  AI/framework files in English, game docs and player text stay pt-BR; every
  adaptation is listed below.

## What was copied

| Upstream path | Here | Count |
|---|---|---|
| `.claude/agents/*.md` | `.claude/agents/` | 37 of 49 (plus 3 RagnaEx agents = 40) |
| `.claude/skills/*/` | `.claude/skills/` | 71 of 74 (plus 7 RagnaEx skills = 78) |
| `.claude/hooks/` | `.claude/hooks/` | 18 files (17 hooks + `yaml-helper.sh`) |
| `.claude/scripts/` | `.claude/scripts/` | 35 helpers |
| `.claude/rules/` | `.claude/rules/` | 14 (+ `ragnaex-architecture.md` = 15) |
| `.claude/docs/` (incl. `templates/`, `director-gates/`, `hooks-reference/`) | `.claude/docs/` | 24 docs + `workflow-catalog.yaml` + 71 template files + 28 director gates + 6 hook references |
| `.claude/statusline.sh` | `.claude/statusline.sh` | referenced by `settings.json` |
| `docs/engine-reference/godot/` + `docs/engine-reference/README.md` | same | Godot only |
| `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md`, `docs/WORKFLOW-GUIDE.md` | `docs/` | no name collision, so not moved to `docs/ccgs/` |
| `project.yaml` (template) | `project.yaml` | filled for RagnaEx |
| `.gitattributes`, `.worktreeinclude` | repo root | LF for `*.sh`/`*.awk`/`.claude/**/*.md` (bash hooks break on CRLF) |
| `LICENSE` | `.claude/CCGS-LICENSE` | |

New empty framework directories: `design/gdd/`, `production/`, `prototypes/`
(each with `.gitkeep`).

## What was dropped, and why

- **Agents**: `unity-*` (5), `unreal-specialist`, `ue-*` (4) — not our engine;
  `godot-csharp-specialist` — GDScript only; `godot-gdextension-specialist` — no
  native code, no addons.
- **Skills**: `day-one-patch`, `launch-checklist`, `localize` — release/launch
  and localization work that does not apply yet (no store release, no
  localization system; player text is pt-BR in code).
- `docs/engine-reference/unity/`, `docs/engine-reference/unreal/` — not our engine.
- `studio-tests/` (the framework's own QA), `src/`, the template's `design/` and
  `production/` placeholders, `docs/CLAUDE.md`, `docs/architecture/`,
  `docs/registry/`, `docs/migration-guide-v1.1.md`, `docs/skill-flow-diagrams.md`,
  `CHANGELOG.md`, `CONTRIBUTING.md`, `SECURITY.md`, `UPGRADING.md`, `.github/` —
  framework-repo material, not needed to run it (read them upstream).

## Adaptations (numbered)

1. **Merged agents `world-builder` and `qa-tester`.** CCGS file as the base,
   plus a `## RagnaEx` section at the end carrying the project's original pt-BR
   text (catalogs, AI files, commands, probes, report format). Frontmatter
   changed: `world-builder` gains `Bash` (CCGS disallowed it; ours runs the
   Godot tests) and its description now covers world content (monsters/AI,
   maps, loot, quests, recipes, bots) besides lore; both keep the project's
   model pins (`world-builder: opus`, `qa-tester: sonnet`) instead of CCGS's
   `inherit`.
2. **Kept RagnaEx agents** `class-designer`, `blender-modeler`, `reviewer` and
   added them to `.claude/docs/agent-roster.md` (class-designer under
   game-designer/systems-designer; blender-modeler under
   art-director/technical-artist; reviewer under lead-programmer, behind
   `/code-review` and our `/review`). The roster's Unity/Unreal/C#/GDExtension
   sections were replaced by a "not adopted" note.
3. **Our agents/skills re-pointed to the moved manual.** `class-designer`,
   `reviewer`, `world-builder` ("Leia `CLAUDE.md`…") and `blender-layout`
   ("Layout de zonas") now name `.claude/docs/ragnaex/*.md`, because a subagent
   that *reads* CLAUDE.md with the Read tool does not get `@` imports expanded.
4. **No skill renamed.** No CCGS skill has the same name as ours (`test`,
   `review`, `new-content`, `build-models`, `layout-zone`, `layout-check`,
   `blender-layout`). Note: our `review` skill shadows Claude Code's bundled
   `/review` alias (CCGS's `code-review` shadows the bundled `/code-review`);
   `.claude/docs/skills-reference.md` was updated to say so and lists our 7
   skills. The 3 dropped skills are marked "not adopted" there.
5. **`setup-engine`**: the only top-level Unity example (`/setup-engine unity`)
   now reads `/setup-engine godot`. There were no Unity/Unreal reference files
   inside the skill; its `references/*.md` still contain engine-conditional
   Unity/Unreal branches (≈120 mentions) — left as is, they are never taken
   with `engine.name: Godot`.
6. **Code root override** (`engine.code_roots`, list). Upstream hard-codes the
   Godot code root to `src/`. `resolve_code_root()` in
   `.claude/hooks/yaml-helper.sh` gained step 0: an `engine.code_roots` list
   (project.local.yaml, then project.yaml) wins and is printed space-joined
   (`core game data\tengine.code_roots`). New helpers: `resolve_code_roots`
   (one per line), `code_root_regex` (`^(core|game|data)/`), all dispatchable as
   `bash .claude/hooks/yaml-helper.sh <fn>`.
7. **Test root override** (`engine.test_root`). New `resolve_test_root()`
   (same file): `engine.test_root` wins, else the engine table
   (Godot `tests/unit tests/integration`). RagnaEx: `tools/tests`.
8. **Callers made multi-root aware**: `session-start.sh` (TODO/FIXME count over
   every root), `detect-gaps.sh` (source count over every root; a root *named*
   `core`/`engine` counts as the core-systems dir; `gameplay/` looked up under
   each root), `validate-commit.sh` (staged-path filter via `code_root_regex`),
   `statusline.sh` (stage ladder), `.claude/scripts/project-state.sh` (reads
   `engine.code_roots`, sums source files), `code-markers.sh` (scans each
   root), `write-guard.sh` (prototype-isolation roots), `project-coherence.sh`
   and `asset-scan.sh` (scan the code roots instead of `src/`).
9. **`validate-commit.sh` hardcoded-value scan skips `data/`.** `data/` *is* the
   data layer (catalogs, `balance.gd`), so the "may contain hardcoded gameplay
   values" warning would fire on every catalog commit. The TODO-owner scan still
   covers `data/`.
10. **Docs for the overrides**: `code-root-resolution.md` (step 0 + "The test
    root" section: a `tests/unit/[system]/` file means a `_check_<system>` in
    `tools/tests/run_tests.gd`), `directory-structure.md` ("RagnaEx layout"
    tree above the generic tables), `effects-map.md` (new
    `## engine.code_roots and engine.test_root` section).
11. **Rules re-pointed** (`paths:`; all Unity/Unreal globs dropped):
    gameplay-code → `core/sim/**`; ai-code → `core/sim/ai/**`; engine-code →
    `core/**`; ui-code → `game/ui/**`; data-files → `data/**`; scene-files →
    `**/*.tscn`, `**/*.tres` (`.tres` kept: Godot resources); shader-code →
    `**/*.gdshader`; test-standards → `tools/tests/**`; design-docs →
    `design/**`, `docs/**`; prototype-code → `prototypes/**`; narrative →
    `data/catalog/quests_catalog.gd`, `data/catalog/bots_catalog.gd`;
    network-code → `core/sim/**`. `agent-memory` and `skill-authoring` unchanged.
12. **Rule conflicts resolved** — each re-pointed rule ends with a
    `## RagnaEx adaptation` section that wins over the generic lines:
    - gameplay: "no static singletons / use DI" → the single autoload `Sim`
      owns all state and systems are stateless static `f(sim, ...)` (the sim is
      injected); "delta time" → fixed sim tick; "data files" → `data/balance.gd`
      + catalogs; "unit tests" → `check()` in `run_tests.gd`; design-doc
      references in comments optional (short pt-BR comments).
    - engine: "engine" = `core/` sim; dependency direction `game/ -> core/`;
      RAII and deprecation periods/migration guides not required (single team;
      save migrations instead).
    - ai: 2 ms/frame budget replaced by the sim's ~5 ms/tick measurement
      (`sim_probe`); brains only emit `InputCommand`s; probes instead of
      permanent transition logging.
    - network: no netcode yet; the sim *is* the future authoritative server
      (command-driven, deterministic); save format = current wire format.
    - ui: no localization system (pt-BR strings in code, `localize` not
      adopted); gamepad/scalable text/colorblind are goals, not blockers.
    - data-files: `data/` is GDScript; JSON rules only for the *generated*
      `data/zones/*.json` (never hand-edited; named `<zona>.json`); constants
      only in `balance.gd`.
    - test-standards: gdUnit4 naming replaced by `_check_<topic>` +
      `check(cond, msg)`; `TEST_SLOT`; probes are measurement tools.
    - design-docs: 8-section GDD standard only for new `design/gdd/` docs;
      the pt-BR `docs/` keep their format.
    - narrative: content lives in catalogs; pt-BR; canon in `docs/DESIGN.md` and
      `docs/roteiro_*.md`; no canon-level tags.
    - scene-files: UI/world built in code, no large hand-edited `.tscn`.
    - shader-code: existing shader names grandfathered; toon merge keys.
    - `.claude/docs/rules-reference.md` table rewritten for these paths.
13. **New rule `.claude/rules/ragnaex-architecture.md`** (`core/**`, `game/**`,
    `data/**`): sim vs presentation split, autoload order, static systems,
    Balance-only tuning, pt-BR text/comments + English names, static typing,
    a `check()` for every new rule/content, `TEST_SLOT`, Definition of Done.
14. **`project.yaml`**: engine Godot 4.7.2 / GDScript / Forward+, `physics`
    describes the custom y=0 sim, `engine.path` = the console exe (Godot is not
    on PATH; lets `project-coherence.sh` find it), `code_roots`/`test_root`,
    specialists without the dropped GDExtension agent (`additional: []`),
    GDScript naming, `testing.framework: custom`, OS-aware `commands`
    (`import`, `test`, `smoke`, `run`; the `windows` values call
    `C:/Users/luisf/Desktop/Godot_v4.7.2-stable_win64_console.exe` directly —
    no spaces, so they run from Git Bash *and* PowerShell; the
    `.\tools\godot.ps1` forms are in comments), `build: "[TO BE CONFIGURED]"`
    (no export presets; the framework forbids guessing one).
    `modes.automation: guided`, `modes.rigor: standard` only — the six
    rigor-fronted knobs (`review_mode`, `workflow`, `docs.density`, `qa.level`,
    `story_granularity`, `team.size`) are deliberately absent.
    `project.stage: Production` seeded directly (MVP complete) instead of via
    `/start` + `/gate-check`; `production/stage.txt` was not written.
    `commands.import` is a RagnaEx key (not in the CCGS schema).
15. **`docs/engine-reference/godot/VERSION.md`**: "Installed at pin time" filled
    with the probed `4.7.2.stable.official.ed1daf0bf`.
16. **`.gitignore`**: added `CLAUDE.local.md`, `project.local.yaml`,
    `production/session-state/`, `production/session-logs/`,
    `.claude/agent-memory/`, `.claude/worktrees/`.
17. **CLAUDE.md** rewritten in the CCGS layout (English): stack, structure
    import, Godot engine-reference import, technical preferences, coordination
    rules import, a **guided** collaboration protocol (user decides major
    design/architecture/scope; agent proceeds on minor ones and logs them;
    commits/pushes/merges/deletes always need the user's instruction), coding
    standards import + pointer to the RagnaEx rule, context management.
    The whole previous CLAUDE.md moved **verbatim** to `.claude/docs/ragnaex/`
    (`comandos.md` = intro + Comandos + Arquitetura, `conteudo.md`, `zonas.md`,
    `desempenho.md`, `estilo.md` = "Estilo GDScript", `modelos.md`, `save.md` =
    Save + Definition of done), each with a one-line HTML marker comment, and
    imported with `@` in the original order. Verified: the 258 non-blank lines
    of the old file equal the concatenation of the imports, in order.
18. **`.claude/settings.json`**: upstream `statusLine`, `worktree`,
    `defaultMode`, deny list and full `hooks` block merged with our allow list
    (all kept) and `enableAllProjectMcpServers: true`; our two deny entries kept
    alongside upstream's; the Unreal-only `Edit(**/*.uasset)` /
    `Edit(**/*.umap)` denies dropped.

## Environment notes

- Hooks are bash scripts run under **Git Bash** (Windows). Python 3 is required
  (`python`), and is present.
- **jq is not installed.** Every hook falls back to awk/grep for JSON input
  (`.claude/scripts/hook-input.sh`), so nothing is lost; installing jq
  (`winget install jqlang.jq`) only makes parsing more robust.

## How to update from upstream later

1. Clone upstream at the new tag next to the repo; read its `UPGRADING.md` and
   `CHANGELOG.md` for the range since v1.2.0.
2. Diff `upstream/.claude/{agents,skills,hooks,scripts,rules,docs}` against
   ours, **excluding** the dropped files listed above and our own files
   (`class-designer`, `blender-modeler`, `reviewer`, the 7 RagnaEx skills,
   `.claude/docs/ragnaex/`, `.claude/rules/ragnaex-architecture.md`).
3. Re-apply the adaptations: search for `RagnaEx adaptation` / `RAGNAEX
   ADAPTATION` (hooks, scripts, docs, rules) and `## RagnaEx` (merged agents);
   every patch site is marked. Items 6-10 and 12 are the ones an upstream change
   is most likely to overwrite.
4. Bump `framework.version` / `last_upgraded` in `project.yaml`.
5. Re-run the sanity checks: each hook with a sample payload
   (`.claude/docs/hooks-reference/hook-input-schemas.md`),
   `bash .claude/hooks/yaml-helper.sh resolve_config --keys review_mode,automation,workflow`,
   `bash .claude/hooks/yaml-helper.sh resolve_code_root` (must print
   `core game data`), `bash .claude/scripts/project-state.sh`.

## Known gaps

- 10 skill files still *say* `src/…` and 23 say `tests/unit|integration/…`
  in prose/examples. They are not rewritten one by one; they resolve through
  `code-root-resolution.md` (step 0 + test-root section) and
  `directory-structure.md`, which state how to read those paths in RagnaEx.
- `.claude/scripts/test-scaffold.sh` and the `/test-setup`, `/test-helpers`,
  `/regression-suite` skills scaffold **gdUnit4** under `tests/`. Not adapted:
  do not run them on RagnaEx (tests are `check()`s in `run_tests.gd`).
- `.claude/scripts/content-count.sh` keeps its Godot `assets src` roots and
  folder-name content rules; RagnaEx content lives in GDScript catalogs, so its
  counts are not meaningful here.
- 17 framework files still name the dropped agents (`godot-csharp-specialist`,
  `godot-gdextension-specialist`, Unity/Unreal specialists) inside
  engine-conditional branches; with `engine.name: Godot` and
  `language: GDScript` they are not selected.
- `.claude/docs/workflow-catalog.yaml` (the `/help` phase map) still lists
  `/localize` (optional, Polish) and `/launch-checklist` (required, Release).
  Copy those skills from upstream before entering Release.
- `detect-gaps.sh` will report "sparse design docs" and "no docs/architecture"
  at session start: RagnaEx's design lives in pt-BR `docs/DESIGN.md`, not in
  `design/gdd/` GDDs or ADRs. Accurate by CCGS's definition; silence it by
  reverse-documenting (`/reverse-document`) when the user wants to.
- `.claude/docs/technical-preferences.md` is still the template (all
  `[TO BE CONFIGURED]`); `project.yaml` is authoritative, so it was not filled.
- Some helpers read `commands.test` only in the simple-string form; the
  OS-aware map we use is covered for Godot discovery by `engine.path`.
