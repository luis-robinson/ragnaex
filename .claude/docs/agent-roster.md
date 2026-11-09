# Agent Roster

The following agents are available. Each has a dedicated definition file in
`.claude/agents/`. Use the agent best suited to the task at hand. When a task
spans multiple domains, the coordinating agent (usually `producer` or the
domain lead) should delegate to specialists.

Which model an agent runs on is set by the `model:` line in its own file;
`model-tiers.md` lists the agents that pin one. Every other agent runs on the
session's model.

## Tier 1 -- Leadership Agents
| Agent | Domain | When to Use |
|-------|--------|-------------|
| `creative-director` | High-level vision | Major creative decisions, pillar conflicts, tone/direction |
| `technical-director` | Technical vision | Architecture decisions, tech stack choices, performance strategy |
| `producer` | Production management | Sprint planning, milestone tracking, risk management, coordination |

## Tier 2 -- Department Lead Agents
| Agent | Domain | When to Use |
|-------|--------|-------------|
| `game-designer` | Game design | Mechanics, systems, progression, economy, balancing |
| `lead-programmer` | Code architecture | System design, code review, API design, refactoring |
| `art-director` | Visual direction | Style guides, art bible, asset standards, UI/UX direction |
| `audio-director` | Audio direction | Music direction, sound palette, audio implementation strategy |
| `narrative-director` | Story and writing | Story arcs, world-building, character design, dialogue strategy |
| `qa-lead` | Quality assurance | Test strategy, bug triage, release readiness, regression planning |
| `release-manager` | Release pipeline | Build management, versioning, changelogs, deployment, rollbacks |
| `localization-lead` | Internationalization | String externalization, translation pipeline, locale testing |

## Tier 3 -- Specialist Agents
| Agent | Domain | When to Use |
|-------|--------|-------------|
| `systems-designer` | Systems design | Specific mechanic implementation, formula design, loops |
| `level-designer` | Level design | Level layouts, pacing, encounter design, flow |
| `economy-designer` | Economy/balance | Resource economies, loot tables, progression curves |
| `gameplay-programmer` | Gameplay code | Feature implementation, gameplay systems code |
| `engine-programmer` | Engine systems | Core engine, rendering, physics, memory management |
| `ai-programmer` | AI systems | Behavior trees, pathfinding, NPC logic, state machines |
| `network-programmer` | Networking | Netcode, replication, lag compensation, matchmaking |
| `tools-programmer` | Dev tools | Editor extensions, pipeline tools, debug utilities |
| `ui-programmer` | UI implementation | UI framework, screens, widgets, data binding |
| `technical-artist` | Tech art | Shaders, VFX, optimization, art pipeline tools |
| `sound-designer` | Sound design | SFX design docs, audio event lists, mixing notes |
| `writer` | Dialogue/lore | Dialogue writing, lore entries, item descriptions |
| `world-builder` | World/lore design | World rules, faction design, history, geography |
| `qa-tester` | Test execution | Writing test cases, bug reports, test checklists |
| `performance-analyst` | Performance | Profiling, optimization recs, memory analysis |
| `devops-engineer` | Build/deploy | CI/CD, build scripts, version control workflow |
| `analytics-engineer` | Telemetry | Event tracking, dashboards, A/B test design |
| `ux-designer` | UX flows | User flows, wireframes, accessibility, input handling |
| `prototyper` | Rapid prototyping | Throwaway prototypes, mechanic testing, feasibility validation |
| `security-engineer` | Security | Anti-cheat, exploit prevention, save encryption, network security |
| `accessibility-specialist` | Accessibility | WCAG compliance, colorblind modes, remapping, text scaling |
| `live-ops-designer` | Live operations | Seasons, events, battle passes, retention, live economy |
| `community-manager` | Community | Patch notes, player feedback, crisis comms, community health |

## Engine-Specific Agents (Godot only in RagnaEx)

The Unity (`unity-*`), Unreal (`unreal-specialist`, `ue-*`), Godot C#
(`godot-csharp-specialist`) and GDExtension (`godot-gdextension-specialist`)
agents were **not adopted**: RagnaEx is Godot 4.7.2 + GDScript only, no addons,
no native code. See `docs/ccgs-adoption.md`.

| Agent | Subsystem | When to Use |
| ---- | ---- | ---- |
| `godot-specialist` | Godot 4 (engine lead) | GDScript patterns, node/scene architecture, signals, Godot optimization |
| `godot-gdscript-specialist` | GDScript | Static typing, design patterns, signals, coroutines, GDScript performance |
| `godot-shader-specialist` | Shaders/Rendering | Godot shading language (toon/outline shaders), particles, post-processing |

## RagnaEx Project Specialists

Kept from the project's own setup (their files are in pt-BR and carry the
project's pipelines). They sit under the CCGS department that owns their domain
and are preferred over the generic specialist for RagnaEx-specific work.

| Agent | Works under | Domain | When to Use |
| ---- | ---- | ---- | ---- |
| `class-designer` | `game-designer` / `systems-designer` | Classes, skills, mastery/web, talents, attributes/stats, gear, combat feel, character visuals/animation in Godot | New or rebalanced skills, damage/block formulas, buffer/cancel/hit-stop, hotbar |
| `blender-modeler` | `art-director` / `technical-artist` | Blender via MCP: chibi characters, monsters, props, zones; GLB export to `assets/models/` | Any 3D art, animation, material work ("make model X prettier"); needs Blender + blender-mcp |
| `reviewer` | `lead-programmer` (the reviewer behind `/code-review` and our `/review` skill) | Independent review against the RagnaEx rules: sim/presentation split, balance, combat feel, GDScript quality, tests, models | End of a task or before a commit; returns APPROVED/REJECTED with actionable items |

Two CCGS agents were **merged** with the project's versions of the same name:
`world-builder` (CCGS lore role + RagnaEx world content: monsters/AI, maps,
loot, quests, recipes, bots) and `qa-tester` (CCGS test-case writer + RagnaEx
import/tests/smoke runner). Each has a `## RagnaEx` section at the end.
