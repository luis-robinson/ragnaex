---
paths:
  - "core/sim/ai/**"
---

# AI Code Rules

- AI update budget: 2ms per frame maximum — profile to verify
- All AI parameters must be tunable from data files (behavior tree weights, perception ranges, timers)
- AI must be debuggable: implement visualization hooks for all AI state (paths, perception cones, decision trees)
- AI should telegraph intentions — players need time to read and react
- Prefer utility-based or behavior tree approaches over hard-coded if/else chains
- Group AI must support formation, flanking, and role assignment from data
- All AI state machines must log transitions for debugging
- Never trust AI input from the network without validation

## RagnaEx adaptation

> Added when CCGS was adopted (docs/ccgs-adoption.md). Where a line below
> conflicts with a rule above, **this section wins** for RagnaEx. The project's
> golden rules are in `.claude/rules/ragnaex-architecture.md`.

- RagnaEx AI = `MonsterBrain`, `BotBrain`, `GuardBrain` (`core/sim/ai/`). They
  only emit `InputCommand`s — the same path as the player. Never mutate entity
  state from a brain.
- Budget: the whole sim (all maps) must stay under ~5 ms/tick in the long test
  run and in `tools/tests/sim_probe.tscn` (`--phases`); the "2 ms per frame"
  figure above is replaced by that measurement. Loops over `m["entities"]` test
  distance before calling methods and allocate nothing per entity per tick.
- Tunables live in `data/balance.gd` / catalogs (aggro, leash, ranges).
- "Visualization hooks" and "log every transition" are aspirational: use the
  probes (`band_probe`, `boss_probe`, `raid_probe`, `combat_probe`, `--why`)
  instead of permanent logging.
