---
paths:
  - "core/sim/**"
---

# Gameplay Code Rules

- ALL gameplay values MUST come from external config/data files, NEVER hardcoded
- Use delta time for ALL time-dependent calculations (frame-rate independence)
- NO direct references to UI code — use events for cross-system communication
  (Godot signals, C# events, Unreal delegates)
- Every gameplay system must implement a clear interface
- State machines must have explicit transition tables with documented states
- Write unit tests for all gameplay logic — separate logic from presentation
- Document which design doc each feature implements in code comments
- No static singletons for game state — use dependency injection

## Examples

**Correct** (data-driven) — Godot:

```gdscript
var damage: float = config.get_value("combat", "base_damage", 10.0)
var speed: float = stats_resource.movement_speed * delta
```

Unity (values from a ScriptableObject):

```csharp
float damage = combatConfig.BaseDamage;
float speed = stats.MovementSpeed * Time.deltaTime;
```

Unreal (values from a data asset):

```cpp
const float Damage = CombatConfig->BaseDamage;
const float Speed = Stats->MovementSpeed * DeltaTime;
```

**Incorrect** (hardcoded):

```gdscript
var damage: float = 25.0   # VIOLATION: hardcoded gameplay value
var speed: float = 5.0      # VIOLATION: not from config, not using delta
```

## RagnaEx adaptation

> Added when CCGS was adopted (docs/ccgs-adoption.md). Where a line below
> conflicts with a rule above, **this section wins** for RagnaEx. The project's
> golden rules are in `.claude/rules/ragnaex-architecture.md`.

- **Data-driven values** = `data/balance.gd` (every tuning constant, autoload
  `Balance`) and the content catalogs `data/catalog/*_catalog.gd` (GDScript
  dictionaries turned into Resources in `GameData._ready`). A GDScript catalog
  counts as a data file; a literal in `core/` or `game/` does not.
- **Time**: the sim is a fixed-tick loop (`WorldSim.tick`), not a frame loop.
  Use the tick's dt / tick counts and `Balance` durations; never `_process`
  delta inside `core/` (there are no Nodes there).
- **Singletons**: "no static singletons" is replaced by our pattern — the single
  autoload `Sim` (`WorldSim`) owns ALL game state; systems in
  `core/sim/systems/` are stateless static functions `f(sim: WorldSim, ...)`
  (the sim is injected as the first parameter). Do not add other stateful
  singletons; new rules go into their system, new public API is one forwarder at
  the end of `world_sim.gd`.
- **Events**: cross-layer communication is the `Events` autoload
  (`core/events.gd`) signals; the sim never references `game/`.
- **Tests**: "unit tests for all gameplay logic" = a `check(...)` in
  `tools/tests/run_tests.gd` for every new rule/content.
- **Design-doc reference in comments**: optional; comments are short and pt-BR.
  Larger rules are documented in `docs/DESIGN.md` / README instead.
