---
paths:
  - "core/**"
  - "game/**"
  - "data/**"
---

# RagnaEx Architecture Rules

Project-specific golden rules (taken from the RagnaEx manual,
`.claude/docs/ragnaex/comandos.md` "Arquitetura" and `save.md` "Definition of
done"). Where a generic CCGS rule disagrees, **this file wins**.

## Simulation vs presentation

- `core/` = **simulation** (the future server). Never import/instantiate
  `Node3D`, `Control`, camera, shaders or `Input` there. Everything that happens
  goes through `core/sim/world_sim.gd` (autoload `Sim`) via `InputCommand`.
  Player and bots are the same thing to the sim — only the command source
  differs.
- `game/` = **presentation**. It reads sim state and never changes
  HP/position/inventory directly: it calls public `Sim` methods (`equip`,
  `use_potion`, `upgrade_mastery`, `try_cast`, ...) or static systems
  (`QuestSystem`, `CraftSystem`), and reacts to `Events` (`core/events.gd`)
  signals.
- `data/` = content. Schemas (Resources) in `data/schemas/`, data in
  `data/catalog/*_catalog.gd` (dictionaries -> Resources in `GameData._ready`).
- Autoload order: `Events`, `Balance`, `GameData`, `Sim`, `SaveSystem`.
- `WorldSim` holds the state and runs tick, spawn, commands, skill pipeline,
  damage/heal/death, movement. Everything else lives in `core/sim/systems/` as
  stateless static functions `f(sim: WorldSim, ...)`. A new rule goes into its
  system; inside the sim call `System.f(self, ...)`. New public API = one
  forwarder at the end of `world_sim.gd`.
- Buffs/debuffs by id via `SimEntity.put_buff/put_debuff/drop_buff/buff_stacks`;
  a new buff needs a body visual in `BuffLooks.LOOKS`.

## Tuning

- **Balancing constants live ONLY in `data/balance.gd`** (autoload `Balance`).
  No tuning literal in `core/` or `game/`; catalog entries are content.

## Language

- Player-facing text: **pt-BR**.
- Code comments: **short, pt-BR**.
- Code names (classes, functions, variables, signals, files): **English**.
- AI/framework files (`.claude/`, `CLAUDE.md`, `project.yaml`, CCGS docs) are
  English; the project manual under `.claude/docs/ragnaex/` stays pt-BR.

## GDScript style

- Static typing everywhere. `var x := ...` only when the type is inferable;
  values from untyped `Array`/`Dictionary` need an explicit type
  (`var d: float = e.position.distance_to(...)`).
- One-line lambdas may hold `a(); b()` but no `if`; signals with logic use named
  methods.
- `lerp`/`lerpf` in `_process`: weight is always `minf(1.0, delta * k)`.
- No large hand-edited `.tscn`: UI and world are built in code.
- A new script with `class_name` is only visible to others after
  `--import`.

## Tests

- **Every new content type or rule gets a `check(...)`** in
  `tools/tests/run_tests.gd` (run alone with `-- --only=<topic>`).
- Tests and reviews use `SaveSystem.TEST_SLOT` (90); never write/delete
  `save_0..4`.

## Definition of Done

1. `--import` + tests pass (0 failed) + smoke test without `SCRIPT ERROR`.
2. No `Node`/`Input` inside `core/`.
3. New content has a check in the tests and is in the README / `docs/DESIGN.md`
   if it changes a rule.

Commands: `project.yaml` `commands.*` and `.claude/docs/ragnaex/comandos.md`.
