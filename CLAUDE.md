# RagnaEx — Claude Code Game Studios (adapted)

Single-player 2.5D "MMO" prototype with bots, run as a small game studio of
coordinated Claude Code subagents (Claude Code Game Studios v1.2.0, adapted —
see `docs/ccgs-adoption.md`). Each agent owns a domain; the RagnaEx project
manual (pt-BR) is imported below and loads every session.

## Technology Stack

- **Engine**: Godot 4.7.2 (Forward+), no addons
- **Language**: GDScript (static typing)
- **Version Control**: Git, trunk-based (`main`); feature work in worktrees/branches
- **Build System**: none yet (no export presets); the game runs from the project
  (`.\tools\godot.ps1 --path .`). Commands live in `project.yaml` `commands.*`.
- **Asset Pipeline**: Blender scripts in `tools/blender/` -> GLB in `assets/models/`
  (Blender MCP); icons by `tools/icons/*.tscn`; zones from
  `tools/blender/zones/build_<zona>.py` -> `map_<zona>.glb` + `data/zones/<zona>.json`
- **Tests**: custom runner `tools/tests/run_tests.gd` (`tools/tests/tests.tscn`,
  27k+ `check()`s) + `*_probe.tscn` measurement tools. Not gdUnit4.
- **Code roots**: `core/` (simulation, future server), `game/` (presentation),
  `data/` (content + `balance.gd`) — `engine.code_roots` in `project.yaml`.

## Project Structure

@.claude/docs/directory-structure.md

## Engine Version Reference

<!-- ENGINE-REFERENCE-IMPORT: /setup-engine rewrites the line below. -->
@docs/engine-reference/godot/VERSION.md

## Technical Preferences

`project.yaml` at the repo root is the primary config store — engine, code and
test roots, specialists, naming, commands, modes, stage. Skills resolve it via
`resolve_config` (see `.claude/docs/config-resolution.md`). Code root:
`bash .claude/hooks/yaml-helper.sh resolve_code_root` (-> `core game data`).
`.claude/docs/technical-preferences.md` is the legacy fallback only.

## Coordination Rules

@.claude/docs/coordination-rules.md

The roster (`.claude/docs/agent-roster.md`) includes the RagnaEx specialists
`class-designer`, `world-builder`, `blender-modeler`, `qa-tester` and `reviewer`;
prefer them for RagnaEx-specific work.

## Collaboration Protocol (automation mode: GUIDED)

`modes.automation: guided` in `project.yaml`. Every non-trivial task follows
**Question -> Options -> Decision -> Draft -> Approval** for the decisions that
matter, and proceeds without asking on the ones that do not:

- **The user decides** (always ask, with options): major design choices (new
  mechanics, classes, zones, economy/balance direction), architecture (anything
  touching the sim/presentation split, save format, new systems or autoloads),
  scope changes, and anything in `modes.automation_always_ask` (scope changes,
  file deletions, schema changes by default).
- **The agent proceeds and logs** on minor decisions: implementation details
  inside an approved plan, naming, local refactors, test additions, tuning inside
  an approved range. Record each one in the session state
  (`production/session-state/active.md`) or the task report so the user can
  review it.
- **Always the user's explicit instruction**: commits, pushes, merges, branch
  deletion, and deleting files. Never push or force anything on your own.
- Show drafts or summaries before asking for approval; multi-file changes are
  approved as a changeset.
- A skipped or dismissed question is not an answer: act on nothing, re-ask in
  plain text and wait.
- Started outside this folder? Warn first: hooks, deny rules and the guided
  mode load only when Claude Code starts here.

See `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md` and `.claude/docs/automation-modes.md`.

## Coding Standards

@.claude/docs/coding-standards.md

RagnaEx golden rules (win over generic standards): `.claude/rules/ragnaex-architecture.md`
(loads with any file in `core/`, `game/`, `data/`). Language: AI/framework files in
English; player text and code comments in pt-BR; code names in English.

## Context Management

Read `.claude/docs/context-management.md` on demand. Two load-bearing conventions:

- **`production/session-state/active.md` is the session checkpoint.** The file is
  the memory, not the conversation. Read it first after any compaction, crash, or
  `/clear`.
- **Helpers in `.claude/scripts/` emit observations, never verdicts.** A script
  that scores or judges will eventually contradict a mode or override it cannot
  see. (Cited by `artifact-check.sh` and `adr-dep-graph.sh`.)

## RagnaEx Manual (pt-BR, imported verbatim)

The former CLAUDE.md, unchanged, split by topic. Edit these files, not this one.

@.claude/docs/ragnaex/comandos.md
@.claude/docs/ragnaex/conteudo.md
@.claude/docs/ragnaex/zonas.md
@.claude/docs/ragnaex/desempenho.md
@.claude/docs/ragnaex/estilo.md
@.claude/docs/ragnaex/modelos.md
@.claude/docs/ragnaex/save.md
