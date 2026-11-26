# Build order — 12 approved specs (2026-11-26)

Proposal for user approval. Each wave ends with: full suite 0 failed, smoke, screenshots in `production/qa/evidence/`,
review, then **commit only on the user's order**. Blender work (Fable only) runs in a parallel art track because it is the
slowest part and several later waves wait on it.

## Dependencies

```
introducao-de-sistemas ─┐
auto-pocao ─────────────┼─ (none)
forja-e-refino-ui ──────┘ ──────────────────────────────┐ (scroll button)
pocoes-de-caca ── cartas ── casa-de-leiloes             │
                    │                                    │
bots-com-memoria ───┼── banco-da-guilda                  │
   (guild)          ├── arena-da-guilda                  │
                    └── guerra-de-guildas                │
momentos-do-mundo ── mvp-premios ────────────────────────┘
```

## Waves

| Wave | Specs | Why here | Agents |
|---|---|---|---|
| 1 | introducao-de-sistemas, auto-pocao, forja-e-refino-ui | No dependencies, small, visible in the first 10 minutes of play | 3 (ui/gameplay) |
| 2 | pocoes-de-caca → cartas (Act I, ~90) → casa-de-leiloes | Loot loop; cards feed the arena, bank, auction and MVP | 2-3 |
| 3 | bots-com-memoria | Roster, rival, guild, Guild window: base for waves 4 and 6 | 2 (ai + ui) |
| 4 | banco-da-guilda, arena-da-guilda | First uses of the guild; the arena needs its map from the art track | 2 |
| 5 | momentos-do-mundo (6 world bosses + Campina chain) → mvp-premios (+ Montaria tab) | Needs the 6 boss models + 6 mounts from the art track, and cards | 2-3 |
| 6 | guerra-de-guildas | The biggest one; needs the guild, bots with roles, castle map and siege props | 2-3 |

## Art track (Fable, in parallel from wave 1)

1. 6 World Boss models (one per band) — needed by wave 5.
2. Card photo frame script (portrait of each monster model, gold frame for cores) — needed by wave 2.
3. `map_guild_grounds` (arena) — needed by wave 4.
4. 6 MVP mounts + barding pieces + colors — needed by wave 5.
5. `map_gvg_field` (2 castles) + ram, cannon, Throne Crystal, guild banners — needed by wave 6.

## Before wave 1

The current batch (uncommitted since a0a3181: Vida da Fé / Legião / Pacto Sombrio, NPC service icons, field mobs x1.5,
Arquivo de Vel'Thar, fortes vivos, 12 new specs) should be committed first so each wave is a clean diff.
