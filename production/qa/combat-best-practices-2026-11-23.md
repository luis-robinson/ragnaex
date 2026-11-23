# Combat best practices — checkable criteria for RagnaEx (2026-11-23)

Research note (game-designer). No code changed. Scope: action-RPG / ARPG / action-MMO combat for a
high top-down camera (52°), cursor-facing characters, MOBA-style aim, dash + guard/parry, 6 skills + R,
group-first bosses with telegraphed signatures, bot parties.

**How to read the numbers.** Most published "typical values" come from fighting-game frame data,
practitioner articles and community wikis, not from official studio specs. Each row says how firm the
number is: **[firm]** = official/primary or measured research, **[practice]** = widely repeated
practitioner rule of thumb, **[uncertain]** = single or weak source, verify in playtest.
60 Hz is assumed (1 frame = 16.7 ms; the sim tick is 60 Hz: `INPUT_BUFFER_TICKS 15` = 0.25 s).

RagnaEx values quoted below were read on 2026-11-23 from `data/balance.gd`, `docs/DESIGN.md`
("Combate: resposta", "Escudos", "Chefes", "Visual"), `game/player/camera_rig.gd`,
`game/fx/fx_manager.gd`, `game/ui/settings_panel.gd`.

---

## 1. Feel / "juice"

| # | Practice | Why | Typical value | Source | How to check in RagnaEx (now) |
|---|---|---|---|---|---|
| F1 | Hit-stop on both attacker and target, scaled by weight | Freezing only the target reads as a hiccup; freezing both sells contact | Light 2-4 f (33-67 ms), heavy 6-12 f (100-200 ms), boss slam/crit up to ~20 f; > 20 f reads as a bug **[practice/uncertain]** | gamejuice "hit stop frame trick"; uhiyama-lab UE5 notes; Monster Hunter Wilds beta feedback (players missed hitstop) **[firm as a direction, not a number]** | `HIT_STOP_FRAMES_BASIC = 2`, `WeaponArcs.FAMILIES[].stop_mult`, `STOP_CAP_FRAMES`, local only (attacker+victim) — good. Check: `combat_probe` + `arc_film.sh` strips; target heavy 2H/finisher ≥ 6 f, crit/finisher ≥ basic × 2, cap ≤ 12 f in group fights (5 players stacking stops must not stall the boss read) |
| F2 | Hit-stop is local, never global, in multi-actor fights | Global freeze in a 5-player + adds fight makes everything stutter | 0 global freeze; local only | MH/fighting-game convention **[practice]** | Already local (`WeaponArcs`). Keep a check that no code path sets `Engine.time_scale` for hits |
| F3 | Hit reaction direction follows the blow | Impact that flows with the attack direction reads as physical | Flinch/knockback vector = attacker→target or skill direction | Diablo IV dev update (hit effects flow with spell/melee direction, hit location from anim data) **[firm]** | Check `EntityView` hit clip: does the flinch/particles use the source direction? Film `--mob_strip=<m> --anim=hit` from 2 sides |
| F4 | Screen shake: short, decaying, directional, noise not white-random; only for *your* big events | Top-down camera: shake moves the whole battlefield and ground telegraphs; random jitter reads as noise | 0.1-0.3 s, fast decay; smooth noise or sine, slight bias opposite to the hit/fire direction; never on allies' hits | Vlambeer/Nijman "juice" talk lineage; gamejuice checklist; Godot forum game-feel checklist **[practice]** | `camera_rig.gd` uses `randf_range` per frame (white noise) with linear decay 2.0/s; amplitudes 0.03-0.12. **Check:** (a) switch to noise/directional, (b) confirm shake fires only for player-owned or player-targeted events, (c) add a 0-100% slider (see A2) |
| F5 | Impact frame = damage tick = SFX = VFX (same frame) | Any offset > ~1-2 frames reads as "floaty" | ≤ 1 frame between anim impact, damage, sound onset, spark | Game-feel guides ("visual, sound, shake on the same frame") **[practice]** | `combat_probe` "impacto do clipe no tick do dano" already measures; extend to SFX onset (`Sfx` play call in the same tick as `Events` damage). FLAG > 1 tick |
| F6 | Sound layering: transient (click/crack) + body (weapon/material) + tail (whoosh/echo), own hits louder than others' | The transient carries "hit"; layering conveys weight; ducking others keeps your feedback legible | 3 layers; own hits +3-6 dB vs allies **[uncertain value]** | General audio-design practice **[practice]** | `Sfx.VOL`, `THEME_SOUND`, `EFFECT_SOUND`: verify allies' hit sounds are attenuated vs the player's in a 5-bot boss fight (smoke prints `SMOKE SOM:`) |
| F7 | Damage numbers: aggregate, cap, size by importance | 5-player fights generate hundreds of pops; numbers hide telegraphs | Cap per target, merge repeats, crit bigger, allies' numbers smaller/optional | WoW 11.2 spell density / FFXIV practice (filter others' effects) **[firm for the filter idea]** | `FloatText`: pool 48, 4/target, ×N merge, others' "Esquiva!" only ≤ 16 m — good. Missing: option to hide allies' numbers entirely |
| F8 | Readability over spectacle: telegraphs and enemy tells must win over player VFX | FFXIV Dawntrail and WoW players complain about effects hiding mechanics | Player VFX alpha/brightness below boss ground markers; markers drawn on top | FFXIV forum "Dawntrail battle effects readability"; WoW spell density **[firm as problem statement]** | Screenshot a 5-player boss fight at peak (all ults) and confirm every active `DANGER*` marker edge is visible; zone/aura player decals never use red-orange |

## 2. Responsiveness

| # | Practice | Why | Typical value | Source | How to check in RagnaEx |
|---|---|---|---|---|---|
| R1 | Input-to-visible-response latency budget | Fast action games degrade from ~60-100 ms extra delay; perception threshold can be ~40 ms for sensitive tasks | First visible response (anim start, facing turn, sound) ≤ 1-2 frames after the sim accepts; end-to-end ≤ ~100 ms **[firm that ~100 ms matters; exact threshold task-dependent]** | Claypool et al. CS:GO latency study (WPI); NVIDIA "Latency of 30 ms benefits FPS tasks"; NTNU latency review | `combat_probe` "latência do comando". Note: sim on a worker thread (`SimSync`) adds up to 1 tick; measure with `--sim_sync` on/off and keep the delta ≤ 1 tick |
| R2 | Input buffer for the next action | Players press early; dropped inputs feel like "the game ate my button" | Fighting games 3-8 f (50-133 ms); action/ARPG 100-250 ms; only the latest input kept **[firm for FG numbers; ARPG range = practice]** | Capcom SFV seminar (3 f normals, 6 f specials); Tekken 8 buffer (8 f); SSBWiki buffer | `INPUT_BUFFER_TICKS = 15` (0.25 s) — top of the range; good for a mouse game. Check: buffer keeps the *latest* input, held LMB does not overwrite a queued skill (DESIGN says so) |
| R3 | Startup / active / recovery is explicit per move; cancels only in recovery | Startup = commitment; recovery = punish window; cancel rules make skill expression | Light basics startup 4-8 f; heavy 12-20 f; recovery cancellable by dash at any time, by skill after impact | SFV frame-data primers; PoE2 director: "Canceling changes a huge amount of stuff" **[practice]** | `CHAIN_AFTER_IMPACT = 0.05` (skill/attack after impact), dash cancels anything (refund before impact). Check: `combat_probe` 0 FLAGs; add per-skill startup histogram so no non-ultimate damage skill has startup > 0.6 s without movement allowed |
| R4 | Dash/dodge always available as an "out", with a cost that prevents spam-immunity | The universal cancel is what makes action combat feel fair; costs keep telegraphs relevant | Cooldown 1-3 s or a 2-charge bar; i-frames 0.2-0.5 s **[practice]** | GW2 dodge: 50 of 100 endurance (2 dodges) **[firm]**; Hades dash identity; PoE2 roll no cooldown but no phasing **[firm]** | `DASH_COOLDOWN 1.6`, `DASH_IFRAMES 0.2` (= whole dash), `DASH_CHARGE_WINDOW 0.9`. Check: no boss signature can be fully negated by chaining 2 dashes if it is meant to be positional (zone damage is not dash-able only if it lingers > i-frames — confirm lingering zones tick after i-frames end) |
| R5 | Mobility while attacking is tiered by commitment | Full-stop attacks + telegraphs = "stand and trade" or frustration; full mobility = no commitment | Basics 50-80% move speed, long casts 0-30%, charges/leaps 0 | Lost Ark / PoE2 / Drakantos-style norm **[practice]** | DESIGN: 60% during hits/fast spells, 25% long spells, 0 dashes — inside range. Check list per skill in `combat_probe` |
| R6 | Cursor-facing rules: face cursor on press, lock facing from startup to impact, free after | Avoids "spin attacks" from mouse jitter while staying responsive | Facing snaps on press (≤ 1 frame), locked during active frames | Drakantos wiki (character faces cursor, no target system) **[firm for Drakantos design]** | DESIGN: face follows cursor after impact, basic until impact. Check: a skill aimed at A then mouse flicked to B mid-startup hits A (except TARGET skills) |
| R7 | Soft lock / aim assist only for TARGET skills and boss lock; never steals aim of DIRECTION skills | Mouse aim is the skill; auto-aim on skillshots removes it | Snap radius ~1-1.5 m around cursor for TARGET; boss lock opt-in | Drakantos (no target system) vs Lost Ark/BDO (soft target) **[practice]** | `BossLock` (Tab) exists, opt-in, only real bosses — good. Check TARGET skills pick the hostile nearest the *cursor*, not the player |

## 3. Telegraphs and enemy design

| # | Practice | Why | Typical value | Source | How to check in RagnaEx |
|---|---|---|---|---|---|
| T1 | Minimum warning scales with damage and with how much movement the answer needs | Human reaction ~200-300 ms; the player also has to travel | Trash melee wind-up ≥ 0.35-0.5 s; elite/ranged ≥ 0.6-0.8 s; boss one-shot/positional ≥ 1.5-3 s; repeated hits in a known sequence ≥ 0.6-0.8 s each **[practice; DS3 analysis gives ≥ 340 ms for a dodge-able melee]** | Game Developer "Anatomy of an enemy attack in Dark Souls 3"; "Enemy attacks and telegraphing"; reaction-time literature | `BOSS_SIG_WARN_MIN 1.5`, `BOSS_SIG_REPEAT_WARN_MIN 0.8`, `SIEGE_HARASS_WARN 1.2`, Act III gaze 3.0 — good. **Gap:** no stated minimum for trash/elite skill wind-ups. Add a check: every monster skill with damage > X% of a same-level player's HP has startup ≥ 0.5 s |
| T2 | Damage snapshot rule is explicit and consistent | FFXIV hits on telegraph disappearance, not on the VFX; inconsistency feels unfair | One rule: damage resolves when the marker fills/vanishes | FFXIV community wiki "Common mechanics and markers" **[firm]** | Check all `BossSignatures` and `barrage` resolve on the tick the marker finishes, VFX after |
| T3 | Colour/shape grammar, learned once, reused everywhere | Players read fights by the "language" of markers | Damage = one warm hue; safe = cool; share/soak = distinct (gold); control = purple; identity by shape, not hue | FFXIV markers ("learn the encounter design language"); WoW forum asks for standardized telegraphs | Already codified (`FxManager.DANGER*`, gold = split, purple = control). Check: no boss marker uses a hue outside the grammar (`_check_boss_sig_rules` style) and every marker also differs by **shape/pattern** (needed for A1) |
| T4 | Body tell + ground marker, not ground marker alone | Ground marker gives size; body tell gives timing; experienced players read the body | Every telegraphed attack has a distinct wind-up pose ≥ 6 f | FFXIV forum ("floor telegraph is a size indicator"); Elden Ring players reading arms | `--mob_strip=<m> --anim=<clip>`: wind-up pose readable from the 52° camera (arms above head silhouette, not only foreshortened) |
| T5 | Enemy archetypes per pack: melee rusher, ranged, caster/healer, tank, summoner; 2-3 roles per pack | Mixed packs force positioning and target priority instead of AoE spam | Pack 3-6 trash with ≤ 1 caster/healer; elites ≤ 1 per pack | Diablo IV "what does this monster need to do" (design goal per monster) **[firm as intent]**; WoW M+ creature-ability emphasis (TWW) **[firm]** | Audit `maps_catalog` spawners: count packs with ≥ 2 archetypes per band (target ≥ 60%) |
| T6 | Elites = modifier on a known base, readable, capped | Unreadable stacked affixes are the top M+/D3 complaint; WoW moved challenge from affixes to creature abilities | 1-2 modifiers per elite, each with its own visual; no hidden damage multipliers | WoW TWW affix update (simplified, passive affixes; damage removed from affixes) **[firm]** | Elites today = stat multipliers (`ELITE_HP_MULT 5`, `ATK 2`, scale 1.6) + Kings. Option for design: 1 readable modifier (e.g. shielding, haste, frost-trail) — design decision, not a defect |
| T7 | Avoid "stand in place and trade" | If nothing needs to be moved away from, DPS checks decide everything | Every enemy ≥ trash-elite has 1 thing worth dodging; boss: ≥ 2 positional mechanics/min | Lost Ark counters/stagger; PoE2 roll design ("skill is the answer to telegraphs") | `boss_probe --bands` already requires 4+ skills/min, 2+ hits/min on kiters at 9.5 m. Add for trash: `band_probe` reports % of damage taken from dodgeable skills (target ≥ 30%) **[target uncertain]** |
| T8 | Aggro/threat readable: who the enemy targets is visible | Tanks need to know they hold aggro; others need to know when they pull it | Target line/marker on bosses; threat warning to DPS | MMO convention (WoW/FFXIV enmity list) **[practice]** | Check HUD shows boss target and a "you have aggro" cue on the player; bots already reason about threat |

## 4. Boss design for groups

| # | Practice | Why | Typical value | Source | How to check in RagnaEx |
|---|---|---|---|---|---|
| B1 | Layer mechanics: one new mechanic per phase, combine later (scaffolding) | Overlapping new mechanics = noise, not challenge | P1 teach 1-2, P2 add 1, P3 combine; intro solo before combo | Flow/scaffolding; FFXIV fight structure **[practice]** | Each boss `phases` entry adds ≤ 1 new signature; review `docs/DESIGN.md` Chefes table |
| B2 | Role checks are explicit: tank (positional/buster), healer (raid-wide), DPS (adds/ward/interrupt), everyone (movement) | Group-first game: each role must feel needed | ≥ 1 check per role per fight | Lost Ark counter (anyone can counter), stagger/destruction roles **[firm]** | `boss_probe --comp=... --why`: frente, cura_tq, baixa, lacaio kill time. Check each group boss has a tank buster, a raid-wide, an add/ward |
| B3 | Interrupt/counter window as a shared verb | Gives DPS a reactive skill check; Lost Ark's blue-glow counter is the canonical example | Distinct colour glow; window 0.5-1.5 s; payoff = stagger 2-5 s | Lost Ark counter guides (Mein-MMO, Sportskeeda) **[firm for the pattern; window values uncertain]** | `BOSS_CHANNEL_STAGGER 3.0` exists; parry (0.22 s) is the personal counter. Optional design: a group-wide "counterable" glow on some boss skills |
| B4 | Enrage is a visible timer, soft first | Hard enrages punish slow groups; soft enrage (damage ramp) is gentler | Soft ramp at ~1.5-2× expected kill time; announce it | MMO convention **[practice]** | `berserk_after` + `BOSS_BERSERK_MULT 1.6`; check the boss announces it (chat/HUD line + visual) and that a 4-player group never meets it (trio kill 30-70 s) |
| B5 | Adds have a purpose and a priority cue | Adds without purpose = AoE fodder; with ward/heal = target swap check | Add priority visible (icon/plate colour); ≤ 6 live adds | WoW/FFXIV practice **[practice]** | `ward` phases exist; check add plates show the ward link |
| B6 | Group-size scaling stays inside a stated band | Group-first: fight must stress a full party without wiping randoms | Full party win 80-100%, solo 20-40% for group bosses | RagnaEx own bands (`boss_probe --bands`) | Already measured; keep `BOSS_CROWD_MULT` rechecks after combat changes |
| B7 | Readability with 5 players: own effects full, allies' reduced, boss markers on top | WoW 11.2 Spell Density: own always full, allies reduced/essential | 3-step option: Everything / Reduced / Essential | WoW 11.2 (Blizzard Watch, Icy Veins) **[firm]** | Not implemented. Add option + check that markers stay visible at "Everything" |
| B8 | Accessibility of mechanics: no mechanic only by colour or only by sound | Colour-blind/deaf players | Shape + colour + (optional) sound | Game Accessibility Guidelines ("no essential info by colour alone") **[firm]** | Check every signature has a distinct shape/edge pattern and a `SIG_WARN` sound (already checked) |

## 5. Skill / build design

| # | Practice | Why | Typical value | Source | How to check in RagnaEx |
|---|---|---|---|---|---|
| S1 | Button count: 6-8 active + 1 ultimate + dash + basic | More buttons than the hand reaches = bloat; fewer = shallow | Lost Ark 8, D4 6, PoE2 ~8-10, GW2 10 | Genre survey **[practice]** | 6 + R + dash + LMB/RMB = 10 verbs — inside the band; ascension adds 4 slots (7-0): watch for bloat at 45 |
| S2 | Rotation depth from interactions, not from more buttons | Synergy (setup → payoff) gives decisions per press | ≥ 1 setup→payoff pair per build (mark/consume, seed/burst, combo) | PoE2 ("dodge roll came from wanting differences between skills") | Sunder/seed/combust/momentum exist; check each build's priority list includes ≥ 1 pair |
| S3 | Cooldowns: short (filler) / medium (rotation) / long (burst/defence); charges for skills you want to "bank" | Mixed cadence makes rhythm; charges give agency over timing | Filler 0-4 s, rotation 6-15 s, burst 30-90 s; 2-3 charges | Genre practice **[practice]** | `SKILL_CHARGE_MAX 3`, `SKILL_CHARGE_MIN_CD`. `skill_audit.tscn` (`WEAK` < 60% median) — add a cadence histogram per build |
| S4 | Ultimate: rare, telegraphed to allies, ~45-90 s cadence | Peak moment; must not stack all at once (screen wash) | 45-60 s to first charge | RagnaEx GDD `ultimates-lv40.md` target 45-60 s | `boss_probe --ult` line `ULT`; `BOT_ULT_STAGGER 3.0` avoids bot stacking — good |
| S5 | TTK targets per tier anchor all tuning | D4 calls TTK one of the most important metrics | Trash 1-3 s (1-3 hits for AoE builds), elite 8-20 s, field boss 30-90 s, group boss 60-180 s **[practice; D4 confirms TTK as anchor, not values]** | Diablo IV IGN interview via Wowhead **[firm for "TTK is the anchor"]** | `band_probe` (hunt of 4 mobs), `boss_probe` trio 30-70 s. Gap: no stated TTK for trash per band — add to `docs/DESIGN.md` and probe |
| S6 | No dominant option | Strictly better skills kill choice (Sirlin degenerate play) | Each build within ±15% of median DPS at equal gear **[practice]** | `skill_audit`/`web_probe` | `Balance.WEB_GAIN_*` ranges + memory note: Lâminas stuck low — recheck |

## 6. Defensive play

| # | Practice | Why | Typical value | Source | How to check in RagnaEx |
|---|---|---|---|---|---|
| D1 | Two defensive verbs with different costs: dodge (mobility, cooldown) and guard (stay, resource) | Choice between repositioning and holding; tanks hold, others move | Dodge i-frames 0.2-0.5 s; guard with drain/break | GW2 endurance; Lost Ark; PoE2 | Dash + guard (MP drain 2/s, break at 0, `BLOCK_ARC_DEG 140`) — good |
| D2 | Parry window narrow and rewarding, with a lockout against mashing | Skill expression; mash lockout prevents degenerate spam | 0.15-0.3 s window, mash cooldown ~0.5-1 s | Fighting-game/Souls convention **[practice]** | `PARRY_WINDOW 0.22`, `PARRY_COOLDOWN 0.9`, 90% reduction — inside range |
| D3 | Unblockable/undodgeable is marked distinctly | Players must know when guard won't work | Distinct colour/shape ("zone, leave it") | RagnaEx decision 2026-11-13 (ground zones not dodged by AGI) | Check: ground zones show they ignore guard too (if they do) |
| D4 | i-frames cover direct hits, not lingering zones or DoTs | Otherwise dash-spam trivialises mechanics | Lingering zone ticks after i-frames | PoE2 no-phasing decision **[firm]** | `DASH_IFRAMES` excludes DoT; verify lingering zones |
| D5 | Healing in action combat: burst heals on cooldown + HoT + positional (ground) heals; healer must also have offence | Action healers die of boredom with pure targeting; ground heals reward positioning | Healer offence 30-60% of a DPS **[uncertain]** | GW2/Lost Ark support design **[practice]** | `boss_probe` `cura_tq`, `baixa`; check Bishop builds' damage share |
| D6 | Unkillable states impossible | Stacked reductions → immortality | Total mitigation cap < 100% (e.g. ≤ 90%) except parry windows | Balance practice | Guard cap 60% + hold 25% + parry 90% of the rest ≈ 98.5% only in 0.22 s window; check sustained guard + barrier + mana shield + ally/summon guard caps can't reach 100% in a probe |

## 7. Top-down camera specifics

| # | Practice | Why | Typical value | Source | How to check |
|---|---|---|---|---|---|
| C1 | Occluders between camera and player fade; characters keep silhouette/outline | High camera still hides the player behind roofs/trees | Fade to ≤ 30% opacity; outline/x-ray on player | ARPG convention (D3/D4/PoE) **[practice]** | Obstacles at 72% transparency (DESIGN "Visual"). Check boss arenas have no occluders over ground markers |
| C2 | Ground markers above ground decals and dressing, below characters | Markers are the gameplay layer | Render order fixed | FFXIV marker practice | `--screenshot` in act2/act3 arenas with dressing |
| C3 | Telegraph legibility at 52°: thick edge + filling interior | Foreshortening thins edges along the view axis | Edge ≥ 0.15-0.25 m world **[uncertain]** | Practice | Measure on `--lock_shot`/boss shots: edge visible at 24 m camera distance |
| C4 | Silhouette over detail; head/shoulders carry identity (high camera) | Seen from above, heads dominate | Class readable from the top in a crowd | RagnaEx art guide (helmet/shoulders first) | Lineup `--view=game` |
| C5 | Effect budget in large groups (allies reduced, cull far VFX) | Draw cost and visual clutter | Allies' VFX ≤ 50% density at "Reduced" | WoW Spell Density | `--perf` boss fight with 5 + ults |

## 8. Accessibility and options

| # | Practice | Why | Typical value | Source | RagnaEx status |
|---|---|---|---|---|---|
| A1 | Colour-blind safe telegraphs (shape + colour, plus palette presets) | ~8% of men are colour-blind; red/green confusion | Deuteranopia/protanopia/tritanopia presets or a high-contrast marker mode | Game Accessibility Guidelines **[firm]** | **Missing** in `settings_panel.gd` (only graphics, volumes, tips) |
| A2 | Screen shake slider/toggle | Motion sickness | 0-100% | Halo Infinite 0-100% shake/blur sliders; Xbox XAG 117 **[firm]** | **Missing** (`camera_rig.add_shake` has no scale) |
| A3 | Flash/effect intensity, photosensitivity testing | Seizure risk; clutter | Reduce flashes; test per XAG 118 | Xbox XAG 118 **[firm]** | **Missing**; hit flash + glow should honour an intensity scale |
| A4 | Allies' effect density | Clutter, perf | Everything/Reduced/Essential | WoW 11.2 **[firm]** | **Missing** |
| A5 | Hold-to-attack and hold-to-cast (no mashing) | RSI, comfort | Hold LMB repeats basics; option for auto-repeat skills **[practice]** | GAG motor guidelines | Hold LMB basic exists; check holding a skill key recasts at cooldown |
| A6 | Remappable keys | Motor accessibility | All actions remappable | GAG basic **[firm]** | Check InputMap remap UI (not seen in settings panel) |
| A7 | Damage numbers/text size scaling | Low vision | 80-150% text scale | GAG; Can I Play That low-vision guide | Check |

---

## The 15 criteria that matter most (pass/fail)

1. Anim impact, damage tick, SFX onset and spark on the same tick (≤ 1 tick) for every skill — `combat_probe`.
2. Hit-stop local only; basic 2 f, heavy/finisher ≥ 6 f, cap ≤ 12 f.
3. Command-to-first-visible-response ≤ 2 ticks (33 ms) with the threaded sim; end-to-end ≤ 100 ms.
4. Input buffer 0.15-0.25 s, latest input wins, held basic never overwrites a queued skill (now 0.25 s).
5. Dash cancels any startup/recovery; skills chain only after impact; 0 FLAGs in `combat_probe`.
6. Dash i-frames ≤ 0.3 s and never protect against lingering zones or DoT ticks.
7. Telegraph minimums: trash ≥ 0.5 s for any hit > 20% HP, elites ≥ 0.8 s, boss signatures ≥ 1.5 s, sequence hits ≥ 0.8 s (only bosses checked today).
8. Damage resolves when the marker completes, never earlier, for every boss mechanic.
9. Colour grammar plus a distinct shape/edge pattern per mechanic type; nothing essential conveyed by colour alone.
10. Ground markers stay visible at the 5-player + ults peak (screenshot test), above dressing and under no occluder.
11. Every group boss has a tank check, a healer/raid-wide check, an add/ward check and ≥ 2 positional mechanics per minute.
12. Soft enrage is announced, and a full 4-5 bot party never reaches it (kill inside 30-150 s).
13. TTK targets are written per tier (trash/elite/field boss/group boss) and probed per band (trash TTK is missing today).
14. No build falls outside ±15% of the median at equal gear; no mitigation stack sustains 100%.
15. Options: screen-shake slider, colour-blind/high-contrast marker mode, allies' effect density, flash intensity (all missing today).

## Gaps found in RagnaEx (observations, not verdicts)

- `camera_rig.gd` shake is white noise (`randf_range` per frame), linear decay, no user scale.
- `settings_panel.gd` has graphics, volumes and tips only: no shake, colour-blind, effect density or flash options.
- No stated warning minimum for trash/elite monster skills (bosses have `BOSS_SIG_WARN_MIN`).
- No written trash/elite TTK target per band.
- Allies' VFX/number density is not adjustable (`FloatText` already caps and merges).

## Sources

- Hit-stop/juice: https://gamejuice.pages.dev/articles/hit-stop-frame-trick · https://uhiyama-lab.com/en/notes/ue/game-feel-hit-feedback/ · https://forum.godotengine.org/t/game-feel-checklist-for-godot-4-hit-stop-trauma-shake-coyote-time-and-more/145340 · https://gamedeveloper.com/design/vlambeer-co-founder-shares-advice-on-building-better-action-games · https://gamejuice.pages.dev/articles/game-juice-checklist-30-techniques · https://www.ssbwiki.com/Hitlag
- Monster Hunter Wilds hitstop: https://www.pcgamer.com/games/rpg/monster-hunter-wilds-game-director-says-the-betas-missing-hitstop-has-already-been-tweaked-thanks-to-very-positive-feedback-from-hitstop-hungry-veteran-hunters · https://gamesradar.com/games/monster-hunter/putting-beta-feedback-into-action-monster-hunter-wilds-devs-show-off-improved-hitstop-and-reworked-weapons-that-feel-how-you-remember-them
- Diablo IV hit effects / TTK: https://www.wowhead.com/fr/news/diablo-iv-ign-interview-combat-design-and-visuals-information-versus-immersion-329803 · https://news.blizzard.com/pl-pl/article/23665024/piekielny-kwartalnik-diablo-iv-czerwiec-2021
- Frame data / buffer: https://game.capcom.com/cfn/sfv/column/131432?lang=en · https://hotspawn.com/fgc/guide/tekken-8-taking-advantage-of-the-input-buffer · https://www.ssbwiki.com/Buffer · https://primagames.com/eguides/street-fighter-v-eguide/primer/reading-frame-data
- Latency: https://web.cs.wpi.edu/~claypool/papers/csgo-net-local-21/paper.pdf · https://research.nvidia.com/sites/default/files/pubs/2019-11_Latency-of-30/FPS_Tasks_sa2019_AuthorVersion.pdf · https://ntnu.no/ojs/index.php/nikt/article/download/5252/4728/20457 · https://www.gamedeveloper.com/game-platforms/feature-game-feel---the-secret-ingredient-
- Telegraphs: https://www.gamedeveloper.com/game-platforms/anatomy-of-an-enemy-attack-in-dark-souls-3 · https://gamedeveloper.com/design/enemy-attacks-and-telegraphing · https://ffxiv.consolegameswiki.com/wiki/Common_mechanics_and_markers · https://forum.square-enix.com/ffxiv/threads/508358-Dawntrail-Battle-Effects-Readability-and-Visual-Clutter · https://us.forums.blizzard.com/en/wow/t/common-npcboss-mechanics-that-should-be-given-more-standardized-telegraphs/1239130
- Lost Ark counter/stagger: https://mein-mmo.de/en/lost-ark-how-to-counter-attacks-from-bosses,787486 · https://sportskeeda.com/esports/lost-ark-boss-monster-guide-when-counterattack · https://www.mmogah.com/news/lost-ark/lost-ark-mechanics-guide-counter-stagger-weak-point
- WoW affixes / spell density: https://blizzardwatch.com/2024/06/17/dungeon-affix-changes-war-within/ · https://warcraft.wiki.gg/wiki/Mythic%2B_affix · https://blizzardwatch.com/2025/07/28/blizzard-adding-new-ways-reduce-spell-density-better-performance-visibility-patch-11-2 · https://www.icy-veins.com/wow/news/too-many-spells-on-screen-patch-11-2-fixes-that-with-one-simple-setting/
- PoE2 dodge/cancel: https://www.pcgamer.com/path-of-exile-2-is-building-on-a-decade-of-action-rpg-depth-but-its-the-no-cooldown-dodge-roll-im-really-psyched-about · https://sportskeeda.com/mmo/path-exile-2-developers-say-phasing-dodge-rolls-will-make-easier-counter-body-blocks · https://www.pcgamesn.com/path-of-exile-2/drops-crafting-uncut-gems
- GW2 dodge: https://wiki.guildwars2.com/wiki/dodge · https://wiki.guildwars2.com/wiki/Endurance
- Hades dash: https://aftermath.site/supergiant-hades-2-dash-chronos-difficulty/
- Drakantos controls: https://thegameswiki.com/drakantos/wiki/gameplay
- Accessibility: https://gameaccessibilityguidelines.com/?p=21 · https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/117 · https://learn.microsoft.com/en-ie/gaming/accessibility/xbox-accessibility-guidelines/118 · https://www.pcgamer.com/most-games-today-still-hide-common-avoidable-accessibility-issues · https://caniplaythat.com/basic-accessibility-options-for-blind-and-low-vision-players/

Not found / unverified: no primary GDC slide with hit-stop frame counts; no official GW2 base-dodge evade duration (wiki says it lasts while endurance is spent); no Drakantos dodge description; Lost Ark counter window length; ARPG trash TTK numbers (practice only).
