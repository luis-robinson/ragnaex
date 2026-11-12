# Act II playtest pass (levels 30-40), 2026-11-12

QA lead: playtest of Act II as a player sees it, then small fixes.
Worktree `.claude/worktrees/p5-tour` (wt/p5-tour, master fcb72e3 plus the integration baseline). Nothing committed.

## What ran

| Run | Result |
|---|---|
| Tours (`-- --autostart=ranger --level=35 --tour=... --tour_map=<m>`, windowed) | city_port 12, field_coast 13, dg_goblin 5, field_steppe 14, fort_trolls/fort_fire/fort_war 4 each, in_port_tavern 1, in_port_warehouse 1 = **58 screenshots**, 0 SCRIPT ERROR. In `production/qa/evidence/p5-tour/` |
| `band_probe --from=30 --to=40 --only=audit` | `BAND_END flags=0`. Quest XP = 55% of 30->40. Quests per level `{30:7, 31:9, 32:7, 33:6, 34:4, 35:33, 36:10, 37:7, 38:2, 39:1}` |
| `boss_probe --party=4 --trials=6` (random group) | Tide Mother 1/6, Agitator-Mor 4/6, Troll King 5/6, Crossbow Master 5/6, Ghar 4/6, 0 SCRIPT ERROR. With 6 trials the spread is about ±20 points, so this is a sanity check only, not a calibration (the table in `docs/DESIGN.md` used 40 trials) |

Tour limitation: the tour ignores `--level`, so the player is level 1. The player was one-shot at some stops
(`field_steppe` 06 mamutes and 10 passo_kharzun show the death or respawn screen instead of the place). Those two stops were
not covered visually.

## Findings

| # | Map | What | Sev | Screenshot | Fix / proposal |
|---|---|---|---|---|---|
| 1 | city_port -> field_coast | Main-line quest `hx_scout` "Olhos na Costa" said to leave by the **south** gate. The Costa exit is through the **west** gate (portal at -84,-30; south gate = docks). It sent the player the wrong way on the main line. | S3 | tour_city_port_10_portao_oeste.png, tour_city_port_11_garganta_costa.png | **FIXED**: `quests_catalog.gd` (map_hint, description, dialog_progress) and `docs/roteiro_30_35.md` now say "portão oeste" |
| 2 | all | The death panel was hardcoded to "Renascendo em Aldara... (-3% XP)", even when the player respawns at a bound crystal (Porto, Posto). The sim message also had a grammar error: "Renascendo em Vale de Aldara". | S3 | tour_field_steppe_10_passo_kharzun.png | **FIXED**: `hud.gd` reads `PortalSystem.home_of(player)` and `Balance.DEATH_XP_PENALTY`. `world_sim.gd` and the HUD say "no Vale de Aldara", "no Porto Esperança" and so on |
| 3 | all (global chat) | Bot travel lines had wrong gender and number: "vou caçar na Vale de Aldara", "na Bastião da Aurora", "na Covil do Carniçal", "indo pra Estepes". The party whisper had the same error ("bora caçar na %s"). | S4 | tour_city_port_11, tour_dg_goblin_00_entrada.png, tour_field_coast_11_chegada.png | **FIXED**: `BotsCatalog.place_article/place_words` derive the article from the place name: "no Vale", "nas Estepes", "pro Arraial". The `leaving` lines use `{pra}/{em}/{nome}`. `bot_brain.gd` formats both lines |
| 4 | Act II (no crystal bound) | Dying anywhere in Act II without binding a crystal sends the player back to Aldara (Act I start town). From there the trip back is ship + Costa. Respawn town = `GameData.town_map_id()` unless `bind_map` is set. | S3 | (rule: `PortalSystem.home_of`) | **PROPOSAL** (design call): bind the Porto crystal automatically when `hx_crossing` is completed, or make the Act II default town `city_port` once the player has reached it |
| 5 | dg_goblin | At the dungeon arrival (0,44), Lv 30 goblin lancers at the bridge aggro and hit the player within about 2 s of loading in. | S3 | tour_dg_goblin_00_entrada.png | **PROPOSAL**: move the first `SPAWN_mob_goblin_lancer` back 6-8 m or reserve the arrival square (Blender zone data, so not changed here) |
| 6 | dg_goblin | Lancers at the entrance are Lv 30 in a map labelled "Lv 32-35". | S4 | tour_dg_goblin_00_entrada.png | PROPOSAL: confirm whether this is intended (an entry room for easing in) or raise the spawner level |
| 7 | city_port garganta (40,-60); field_steppe Desertores camp | FPS dropped to 32-33 (red HUD) at these two stops. The other stops ran at 42-60. | S3 | tour_city_port_06_garganta.png, tour_field_steppe_07_desertores.png | **PROPOSAL**: measure with `-- --perf --perf_at=40,-60` on city_port and `--perf_at=-34,-78` on field_steppe (vegetation density or shadows suspected) |
| 8 | fort_trolls, fort_fire, fort_war | Large flat dark-grey unlit patches on the ground around the arrival and paths. This looks like a ground-patch layer or a big shadow. | S4 | tour_fort_trolls_00_chegada.png, tour_fort_fire_00_chegada.png, tour_fort_war_00_chegada.png | DEFERRED: fort models are being replaced on another branch. Re-check after that merge |
| 9 | field_steppe Posto, Desertores, forts (braziers) | Campfires and braziers show the fire as a flat solid orange polygon, with no glow, flicker or particles. | S4 | tour_field_steppe_00_posto_caravana.png, tour_fort_war_00_chegada.png | PROPOSAL: give the fire material a `glow_*` or emissive value, or add a small particle fire to `prop` fires in Godot (no Blender rebuild needed) |
| 10 | field_coast Santuário Afogado | A brown, torn-looking shard mesh sticks through the shrine's white floor next to the pillars. | S4 | tour_field_coast_11_chegada.png | PROPOSAL: check `act2_dress.coast` near (92,18) for a decal or rock overlapping the shrine (Blender, not changed here) |
| 11 | global chat | "DROPOU MOEDA LENDÁRIA!!!" from 4 to 5 bots in a row within seconds fills the chat window. | S4 | tour_city_port_11_garganta_costa.png | PROPOSAL: cooldown on the global loot brag (one per N s across all bots) |
| 12 | global chat (Act II maps) | System broadcast "Caranguejo-Rei do Lago emerge do lago!" (Act I, Aldara) appears while the player is in Act II maps. | S4 | tour_field_steppe_00_posto_caravana.png | PROPOSAL: send the world-boss announcement only to players in the same act or in a neighbouring map |
| 13 | quests (ascension) | Ascension collects that need boss drops: `hx_asc2_elementalist` 3 Tide Essence (about 24 Tide Mother kills by the audit estimate), `hx_asc_necromancer` 2 Tide Essence (about 16), `hx_asc2_necromancer` 2 War Drum Hide (about 16 Agitator-Mor kills). | S3 | band_probe audit | **PROPOSAL** (balance): quest-only drop (100% while the quest is active) or count 1 |
| 14 | levels 38-39 | Thin quest coverage at the top of the band: 2 quests at 38, 1 at 39 (hunts carry it). | S4 | band_probe audit | Info for the Kharzun phase |
| 15 | dev tool | `--tour` ignores `--level` and the level-1 tourist gets one-shot (HP refill each frame does not stop burst damage). | S4 | tour_field_steppe_06_mamutes.png | PROPOSAL: make the tour player invulnerable (or apply `--level`) in `dev_runner._tour` |
| 16 | Tide Mother | 1/6 wins with a random 4-bot group (calibrated 67.5% over 40). | — | boss_probe log | Watch item only: re-run `--trials=40` before reading anything into it |

**Counts:** S1 0 · S2 0 · S3 6 (#1, #2, #4, #5, #7, #13) · S4 9 · watch 1. Fixed: 3 (#1, #2, #3).

## Fixes (files)

- `data/catalog/quests_catalog.gd`: `hx_scout` text, south gate -> west gate.
- `docs/roteiro_30_35.md`: same correction.
- `data/catalog/bots_catalog.gd`: `MASC_PLACE_WORDS`, `place_article`, `place_words`. `leaving` lines use named marks.
- `core/sim/ai/bot_brain.gd`: leaving line and party whisper use `place_words`.
- `core/sim/world_sim.gd`: death notification "Renascendo no/na ...".
- `game/ui/hud.gd`: death panel shows the real respawn map and the penalty taken from `Balance`.
- `tools/tests/run_tests.gd` (`_check_bot_chat`): articles (no/na/nas/pro), no leftover mark in any map's travel line, and the fixture includes the new marks.
  The fixture check was seen failing (3 bad lines) before the fixture update. The article check cannot run against the old code because `place_words` did not exist there.

## Round 2 (same day): the coordinator applied the recommended option for each proposal while the user was away

| # | Status | What changed / result |
|---|---|---|
| 1 | FIXED (round 1) | south gate -> west gate |
| 2 | FIXED (round 1) | death panel shows the real respawn map |
| 3 | FIXED (round 1, confirmed) | round-2 tour chat shows "vou caçar no Covil do Carniçal", "indo pro Vale de Aldara" |
| 4 | **FIXED** | When the player completes `hx_crossing`, the Porto Esperança crystal becomes the respawn point. Message: "Ponto de retorno: Cristal de Retorno de Porto Esperança...". Bots are not affected. `MapsCatalog.QUEST_BIND`, `PortalSystem.quest_bind/bind_map_crystal/_bind_at` (shared with `bind_crystal`), `QuestSystem.complete` (player only). Old saves past `hx_crossing` with no bind get the port on load (`SaveSystem.apply_to`); a save that already has a crystal keeps its own. Check `_check_act2_playtest` |
| 5 | OPEN (Blender), proposal | The level fix is not data-only: `MonsterDef.level` is fixed per monster, and the dungeon's spawners live in the generated `data/zones/dg_goblin.json` (6 `goblin_lancer` at (0,25), r 12, plus 3 more at (-22,15) and (-37,-5)). Options: (a) in `build_dungeons.py`, swap the entrance lancers for `goblin_impaler` (Lv 33) and move the spawner 6-8 m back from the arrival (0,44), then re-export; (b) add a per-spawner `level` to the sim (new rule, needs a design call). Both are listed only, not done |
| 6 | OPEN, proposal | Same root cause as #5 (see option a) |
| 7 | MEASURED, not reproduced at steady state | `--perf --perf_at` (level-1 ranger, about 8 s): port gorge 56.5 fps, 570 draws, gpu 5.7 ms; port plaza 59.0 fps, 1202 draws; Deserters' camp 59.1 fps, 1405 draws, 387 visible objects; Steppe Posto 59.3 fps, 1361 draws. Sim tick 6.4 ms (port) and 9.0 ms (Steppe; `map_field_steppe` 3.4 ms, `commands` 4.5 ms). The gorge shows `physics_ms` averaging 38 against 6.6 in the plaza, which points to sim/physics spikes, not rendering. The round-2 tour again showed 33 fps at the Deserters' camp about 3.6 s after teleporting, so the drop looks like a transient right after arrival (first view of the area: shaders, pruning or the sim catching up), not a steady cost. Proposal: run `--soak=60 --soak_map=field_steppe` with `PerfWatch` to catch the spike phases |
| 8 | DEFERRED | fort-model branch |
| 9 | **FIXED** | `Materials.fire` shader (camera-facing yellow core, edge in the material colour, flicker, above the bloom threshold) for `glow_brasa*`, `glow_lava` and the `fire` material. Screenshot: `evidence/p5-tour/round2/tour_field_steppe_07_desertores.png` (before: `tour_field_steppe_07_desertores.png`) |
| 10 | OPEN (Blender) | listed only |
| 11 | **FIXED** | Bot "DROPOU MOEDA LENDÁRIA!!!" limited to 1 per map every `Balance.BOT_LOOT_SHOUT_GAP` (60 s) (`LootSystem.loot_shout_ok`). Check |
| 12 | **FIXED** | "<boss> emerge do lago!" no longer fires on the spawner's first fill (map loading while the player is only passing through on a save load or teleport), only on a real respawn with the player in the map (`MobSystem`, `sp.primed`). No automated check. Seen in the round-2 tour: `round2/tour_field_steppe_00_posto_caravana.png` chat shows only "Smoke entrou no jogo", where round 1 showed "Caranguejo-Rei do Lago emerge do lago!" |
| 13 | **FIXED** | While a COLLECT quest asks for an item from a boss's loot table, the boss drops 1 for each holder who still needs it, owner-locked like the personal legendary drop (`LootSystem.quest_needs`). Counts unchanged. Check, including a real Tide Mother kill |
| 14 | info | unchanged |
| 15 | **FIXED** | `--tour` applies `--level` (web spent like a bot) and keeps the player in i-frames. The two missing Steppe stops were re-shot at level 37: `evidence/p5-tour/round2/tour_field_steppe_06_mamutes.png`, `..._10_passo_kharzun.png` (14 stops, 0 SCRIPT ERROR) |
| 16 | RESOLVED (no tuning) | Tide Mother `--party=4 --trials=40`: **26/40 = 65%**, 2.3 deaths, 33.9 s, against the calibrated 67.5% / 2.2 / 37 s. Within noise |

Round-2 tests: targeted (`--only=act2_playtest,bot_chat,save,party`) 384 passed, 0 failed. Full suite 70253 passed, 0 failed (round 1: 70257; the total moves with world-state loops, and this run had no failures). Smoke `--autostart=ranger` and `--autostart=necromancer`: 0 SCRIPT ERROR.
