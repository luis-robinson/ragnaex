# Combat audit 2026-11-23 (measurement + reading, no code changes)

Author: class-designer agent. Scope: the CURRENT combat of RagnaEx (master @ 48e8431), to plan improvements.
All numbers below were measured today unless marked "(notes)". Raw outputs were kept in the agent scratchpad
(not in the repo): `combat.txt`, `audit.txt`, `anim.txt`, `dps.txt`, `hp.txt`, `startup.txt`.

Commands run (headless, non-console exe, max 2 Godot at once):
- `tools/tests/combat_probe.tscn -- --verbose` (all 24 builds, level 30)
- `tools/tests/skill_audit.tscn`
- `tools/tests/anim_probe.tscn` (149 models, 1800 clips)
- `tools/tests/dps_probe.tscn -- --levels=30,45 --secs=30 --trials=2`
- `tools/tests/hp_probe.tscn -- --levels=30,45`
- a scratchpad `-s` script that dumps startup/active/recovery of every class skill (294, Supremas excluded)

Boss numbers come from `production/session-state/agent-act3-*.md` (not re-run).

---

## 1. Measured numbers (summary)

### 1.1 Responsiveness (`combat_probe`, level 30, 24 builds)
- `PROBE_END flags=0`. 0 SCRIPT ERROR. Command latency 0 ticks in every build; `parado_na_tela` 0.00 s everywhere.
- Held basic cadence (hits/s): Assassin 2.75 (all 3), Ranger Caçador 2.25, Lanceiro/Fera 2.00, Elementalist 1.75,
  Guardião Verde 1.75, most melee 1.50, Executor and Atirador 1.25. Worst gap between held hits: 16 ticks (Executor).
- Largest bone turn in one frame found by `--verbose` ("tranco"): 100° `upper_arm.L` in `atk_finisher`
  (`ber_overhead`, 2.1x neighbours), 93° `atk_sweep` (`pal_holy_strike`), 83-87° `atk_leap` (`ber_leap`, 1.7-1.8x),
  85-89° `buff_guard` hand.R. All below the 140° FLAG; these are the "fast arcs" listed as accepted in memory.

### 1.2 Skill numbers (`skill_audit`, 169 skills audited)
- `AUDIT_END weak=26` (below 60% of class-band median ef/cd).
  Utility/CC that is weak on purpose (docs/skills_review.md): ass_shadowstep 19%, ass_smoke 7%, nec_curse_weakness 6%,
  nec_curse_doom 16%, ran_net 49%, ran_anchor 57%, ass_paralyze 36%, dru_entangle 29%, pal_shield_bash 42%, ber_blade_rush 45%.
  NOT on the "on purpose" list and still weak: ass_pistol_shot 48%, ass_slash_shot 37%, ass_grapple 27%,
  ass_between_eyes 36%, ass_broadside 45% (Corsário's whole kit), ran_predator 31%, ran_snare_toss 54%,
  dru_stampede 54%, dru_ent_roots 41%, ele_frost_nova 48% (was buffed 1.1 -> 1.5, still weak), ele_asc_fusion 23%,
  nec_drain 47%, nec_grim 59%, bis_hammer 51% (buffed once already), pal_brand 52%, ber_warcry 55%.
- Strongest (ef/cd vs median): ber_glad_finale 292%, bis_holy_blow 259%, ran_double_thrust 244%, bis_holy_quake 233%,
  ass_venom_dart 228%, ran_power_shot 222%, nec_decay 208%, pal_shield_throw 190%, bis_faith_leap 189%.

### 1.3 Single-target DPS (`dps_probe`, bot rotation vs a stationary 10M-HP spider, MP refilled every tick)
Median level 30 = 2108, level 45 = 5116. Project rule: builds within +-25% single-target.

| Build | Lv30 vs median | Lv45 vs median |
|---|---|---|
| elementalist/raio | +82% | **+156%** |
| elementalist/fogo | +47% | **+96%** |
| elementalist/gelo | +22% | +66% |
| bishop/inquisidor | +44% | +58% |
| paladin/cruzado | +37% | +24% |
| ranger/atirador | +30% | +30% |
| druid/xama | +1% | +26% |
| druid/fera | -29% | -35% |
| necromancer/invocador | -45% | -32% |
| berserker/executor | -9% | -27% |
| druid/guardiao_verde (tank) | n/a (30) | -59% |
| bishop/sacerdote (healer) | n/a (30) | -70% |

12 of 24 builds are outside +-25% at level 45 (tanks/healer excluded: still 9). The casters scale 30->45 at x3.3-3.4
while melee scale x1.9-2.2. Caveat: MP is refilled every tick, so mana-hungry casters are flattered; the target never
moves; no ascension. Still, raio at 2.5x the median is outside any caveat. dps_probe signature FLAGs: ranger/cacador
+11%/+10% (band is -5..+10%).

### 1.4 Survivability (`hp_probe`)
EHP level 45: Guardião 2826, Guardião Verde 2103 ... Fogo 890, Raio 883, Invocador 744, Pestilento 739, Inquisidor 779.
Tank/glass ratio 3.8x. Evasion: Punhos 24.3%, Lâminas 23.1%, Lanceiro 20.8%, Corsário 20.2% (cap 45).
Observation: `notes=0` for paladin/cruzado and paladin/templario at 30 and 45 (no survival/damage notables bought by
the bot web path), every other non-tank build buys 4. Worth a look in `ProgressionSystem.bot_spend`.

### 1.5 Animation (`anim_probe`, 149 models, 1800 clips)
- Loop seams > 15°: 0. Clips with > 40% dead frames (non-idle): 0.
- Peak bone turn > 60°/frame: 10 clips, worst `mob_troll_thrower attack` 72°, `mob_flayer atk_sweep` 71°,
  `mob_durgash/ghar/ghoul_giant/orc_warlord attack` 68° (shared humanoid boss attack), kit `atk_finisher` 64°.
- Head-below-0.45 m flags (38) are all low-slung creatures (crabs, slime, salamander) whose rest height is already
  < 0.5 m: not a defect.

### 1.6 Skill timing data (294 class skills, Supremas excluded)
Startup buckets: 0.00-0.10 s = 65, 0.15 = 128, 0.20-0.30 = 76, > 0.30 = 25.
- 25 skills break the "startup <= 0.3 s outside ultimates" rule: all summons, big AoEs and heals
  (ele_meteor 0.55, nec_skeleton_king 0.60, nec_lich/nec_army/dru_treant/ele_blizzard/bis_miracle 0.50,
  ran_snipe 0.45, bis_judgement 0.45, nec_demon_form 0.45 with cd 6 s, bis_choir_return 2.5 asc). Either the rule
  needs an explicit "summon/big AoE" exception in the manual or these need trimming.
- 193 of 294 (66%) have startup <= 0.15 s; docs/skills_review.md already notes that 0.15 s shows the impact on the
  2nd frame (little anticipation). Most player skills have near-zero windup, which is great for latency but
  removes the read for allies and the "weight" of hits.

### 1.7 Bosses (notes, not re-run)
- Act III dungeon bosses with full 4-group --asc: Varo 40/40 ~55 s d0.7-0.9, Countess 40/40 ~54 s d0.1-0.4,
  Ressoa 37-40/40 54-76 s, Vessaline 20/20-40/40 92-98 s; random groups 31-34/40.
- Field bosses trio: V 34-37/40 ~50 s, P 36-39/40 30-47 s. Echo (raid, 5) 8-12/20 ~100 s, still above the <= 10%
  target for a 4-group (open in agent-act3-finale.md).
- Group-AI memory (2026-11-10): a 4-bot group never drops below 35% HP even at 4x boss damage; healing quality is
  barely exercised by the probes.

---

## 2. Systems inventory (what exists, where)

### Input -> command
- `game/player/player_controller.gd:23-60` one-shot actions accumulated until the physics tick; held LMB/RMB only if the
  press started in the world (`attack_down/block_down` :69-76). Tab lock :79-107, lock movement :143.
- `core/sim/input_command.gd` (move, aim, attack, block, skill_slot 0-9, potion, dash, jump, mount, recall, ultimate).
- Bindings are fixed (InputMap); no rebinding UI anywhere in `game/` (no `action_erase_events`/`action_add_event`).

### Skill pipeline (sim)
- `WorldSim._apply_command` `core/sim/world_sim.gd:601-777`: input buffer :612-632 (`Balance.INPUT_BUFFER_TICKS` 15 =
  0.25 s, frozen while own skill is before impact), face-cursor :635-641, dash :691-714 (cancels any cast, refunds MP/CD
  before impact :914-922), Suprema :717, skills :721, basic :725, block/parry :734-744, move-while-casting :764-777
  (`CAST_MOVE_MULT` 0.6, heavy 0.25).
- `_can_chain` :890-901: chain `CHAIN_AFTER_IMPACT` 0.05 s after impact; waits for the last `strikes` hit;
  basic->basic keeps weapon rhythm; monsters never chain.
- `try_cast` :945-1025, `_start_skill` :1027, `_update_skill` :1054-1099 (startup/active/recovery, channel pulses
  :1076-1083, strikes :1084-1092), `_apply_skill_body` :1109+, `_apply_effects` :1569+.

### Hit-stop / impact feel
- Sim posts `hit_stop` only when the player is attacker or target (`world_sim.gd:1488-1492`, projectiles :1737, :1833,
  mounted `mounted_combat.gd:135`). Basic = `Balance.HIT_STOP_FRAMES_BASIC` 2; 222 skills set `hit_stop_frames`.
- Presentation `game/fx/fx_manager.gd:284-293`: arc families -> LOCAL freeze of attacker+target (`WeaponArcs.on_hit_stop`
  `weapon_arcs.gd:989`, `stop_mult` per family, cap `STOP_CAP_FRAMES` 8); everything else -> GLOBAL
  `Engine.time_scale = 0.05` + shake `0.03*frames`. Parry -> global 5 frames (:281).
- Weapon arcs (waves 1-6 + forms) `game/fx/weapon_arcs.gd` (FAMILIES :26-71); ranged/staff have no arc by design.
- Hit flash `Balance.HIT_FLASH_TIME` via `entity.hit_flash` (`world_sim.gd:2034`, `entity_view.gd:893, 1245`).
- Flinch: monsters only, 0.22 s `hit` clip, only while IDLE/MOVING (`entity_view.gd:1246-1249, 2126-2128`).

### Damage, crit, evasion, block, guard
- `Combat.calc_damage` `core/sim/combat.gd:107-143`: `atk*power - def*DEF_FACTOR(0.5)`, floor 15% of raw,
  variance +-10%, crit (`crit_mult`, base `CRIT_MULT` 1.5), backstab (+25% crit, +backstab%), block (passive chance with
  shield; held RMB always blocks, +25% reduction, +10 with shield, cap 85%), guard arc 140° (`in_guard_arc` :15).
- `_deal_damage` `world_sim.gd:1918-2047`: dash i-frames, Duelist riposte, parry (90%, window 0.22 s, cd 0.9 s),
  monster front guard, Ghar wall, talents/fusion/curse/ward/DR (`DR_CAP`), evasion roll (:1977, cap 45%, not vs
  telegraphed ground zones), Suprema charge, intercepts, absorb shields, mana shields, leech, threat (:2039).
- Stats formulas `core/sim/stats.gd:152-362` (HP :255, PATK by weapon :259-265, MATK :267, crit :270-272,
  evasion curve :271/:405, block :275-282).

### DoT
- Player DoT: up to `PLAYER_DOT_MAX_STACKS` 3 copies per skill (`_put_dot` :1875); monster DoT renews and lasts x0.7
  (`MONSTER_DOT_TIME_MULT`); pulses every `DOT_PULSE_S` 0.5 s; bleed by %ATK (:1577-1582).

### CC
- `_apply_effects` :1594-1616: slow and root APPEND a new debuff each hit (no renew, no diminishing returns);
  stun sets state with `cc_mult` (`CC_RESIST_CAP` 50%), bosses take 40% (`resists_cc`), pull/knockback skip bosses.
  No CC diminishing returns on players or elites; mount-fall gives 2 s immunity (`MOUNT_CC_IMMUNE`).
- Stun visual = the `hit` clip (`entity_view.gd:2125`); no stun stars/marker and no root/slow entry in `BuffLooks`
  (grep found none).

### Threat / aggro
- Threat += damage x (1 + threat_pct) (`world_sim.gd:2039`); `MobSystem.taunt` :6 (bosses half), `retarget` :16;
  crowd scaling `crowd_of/crowd_mult` :190-212 (`BOSS_CROWD_MULT` [1,1,1,2,3.5,5]).

### Telegraphs
- `FxManager._telegraph` `fx_manager.gd:642+`, grammar constants :628-639 (DANGER carmine, base+growing fill,
  pulsing cream rim; CONTROL purple only for `mob_entangle`), `BossSigView` constants `boss_sig_view.gd:13-20`
  (red / gold split / sand safe / foam).

### Numbers and sound
- `FxManager._on_damage` :161-230 (colour/glyph per kind, crit "!", block shield glyph); non-party fights only within
  16 m and 25% sampled; `FloatText` pool (`float_text.gd`: 48 total, 4 per target, x N merge).
- `Sfx._on_damage` `game/audio/sfx.gd:385-399`: one generic `hit` (8 variants) for every non-magical hit, `crit`
  on top for own crits, `hurt` when the player is hit; magical hits have no impact sound (only the cast/effect sound);
  blocked hits use `block`/`parry`, dodge `dodge`.

### Camera / lock
- `game/player/boss_lock.gd` + `player_controller.gd:79-147`; `CameraRig.add_shake` = max of requests (`camera_rig.gd:82`).

### Ultimates / charges
- `core/sim/systems/ultimate_system.gd` (gain :68-155, cast :200, fire :215), `charge_system.gd`, R key.

### Bot combat AI
- `core/sim/ai/bot_brain.gd`: `_best_skill` :640, `_fill_ok` :764, `_danger_escape` :847, `_sig_spot/_sig_move`
  :992/:1131, `_stun_skill` :1261, `_heal_party` :1906, `_party_threat` :1958, `_tank_pull` :1983, `_role` :2031,
  `_role_spot` :2089, `_opener` :2143, `_threat_budget` :2170, `_peel_target` :2255.

---

## 3. Known issues already written down (existing reviews)

- docs/skills_review.md "Ainda fracas no visual": most skills with 0.15 s startup show the impact on the 2nd frame;
  physical "aço" skills still use the generic white fan; `dru_moonfire` small hit feedback. Pending: physical arrows
  carry a magic-looking white particle trail.
- docs/animations_review.md "O que ficou": `atk_charge` (static pose during the charge), `cast_channel` (small hand
  tremor), `cast_shadow` and `buff_focus` (unreadable from the side), `block` without shield (static);
  0.06 s fades into 2.2x windups give 90-100°/frame arcs (accepted).
- memory combat-fluidity: same candidate list; hand twist fixed; probe must stay at 0 FLAG (it is, today).
- memory skill-chaining: "if a skill gets effects during active/recovery (multi-hit, channel), `_can_chain` must wait"
  -> strikes were handled, **channel was not** (see 4.1).
- memory shields-rework: awaiting playtest on Abraço + held block, 5 MP guard threshold, recoil feel, 140° arc with
  instant turning, charges stopping on hub props, solo Capitão difficulty.
- production/qa/attack-anim-audit-2026-11-14.md: problems 1-8 (ribbon, contact point, global hit-stop, subtle
  anticipation). Arcs waves 1-6 shipped (2aafe87) and solved 1-6 for arc families; 7 (global hit-stop) is solved only
  for arc families; 8 (anticipation for chibi) still open.
- memory balance-refactor / group-first-balance: solo Lâminas ~5/40 and Sacerdote 0/40 accepted as group game;
  measure in groups. Echo raid still too easy for a 4-group (agent-act3-finale.md).

---

## 4. Gaps found in this audit

### 4.1 Channels are cut by chaining (likely bug, code reading)
`_can_chain` (`world_sim.gd:890-901`) only waits for `strikes`. A channel skill (`nec_mind_flay` 4 ticks/2.4 s,
`nec_drain_soul` 5/3 s, `nec_void_beam` 6/3 s, `ber_titan_cyclone` 4/2 s, the Lanceiro channel at skills_catalog:1512)
becomes chainable 0.05 s after its FIRST pulse. Because the current slot is >= 0, even a held LMB (`cmd.attack`,
line 895 lets it through) starts the basic at :725 and `_start_skill` -> `_end_skill` drops the remaining pulses.
A player who keeps LMB held (the normal way to play) gets 1 of 4-6 pulses. The test at run_tests.gd:5782 sends no
input during the channel, so it would not catch this. Not runtime-verified in this audit (a scratch `-s` script
cannot compile `SimEntity` without autoloads); first step of the fix is a failing check.

### 4.2 Balance outliers
See 1.3. Raio/Fogo/Gelo/Inquisidor far above, Fera/Invocador/Executor/Carniceiro/Caçador/Corsário below at 45.
Corsário's skills are also the biggest group of unexplained WEAK entries (1.2).

### 4.3 Feedback holes
- Player and bot characters never flinch when hit (monsters only); getting hit reads only as a red number + flash.
- Monster flinch plays on every hit while idle/moving, including bosses (no `is_boss` guard at entity_view.gd:1246):
  check on film whether bosses jitter under 5-player DPS.
- Stun = generic `hit` clip; no "stunned" marker; root and slow have no body visual (`BuffLooks` has no stun/root/slow).
- Magic hits have no per-target impact sound (only the skill's cast/effect sound at the impact point); physical hits share one `hit` pool for every weapon (no blunt/blade/arrow split).
- No screen-anchored boss HP bar / boss cast bar: boss HP only on the over-head nameplate; the HUD only shows the
  "Travado: <nome>" label and the boss speech banner (`hud.gd:137, 1016`).
- No low-HP warning on screen (the vignette in `main.gd:544` is per-map ambience) and no directional "hit from" cue.
- Global hit-stop still fires when a MONSTER hits the player (targets.has(player)) or for any non-arc player hit:
  the whole world freezes for 2-6 frames each time the player is hit by a pack.

### 4.4 Options / accessibility
Settings panel (`game/ui/settings_panel.gd`) has only Graphics preset, volumes and Tips. Missing:
screen-shake toggle/scale, hit-stop toggle, flash intensity (full-white 0.12 s flash), damage-number density
(own / party / off), ally effect opacity, colour-blind mode for telegraphs (red damage vs gold split vs purple
control is a red/gold/purple hue code; the manual says identity is by shape, but the danger classes are only hue),
key rebinding.

### 4.5 Clutter with 5-player groups
- `_mine()` counts every party member and their summons: with 4 bots + summons, all their numbers show at full
  size (only the 48-label and 4-per-target caps hold it). Party skill FX are drawn like the player's (only the 58 m
  cull applies), so the player's own feedback competes with 4 others.
- WeaponArcs are already limited to player/party swings; there is no "allies at reduced opacity" tier.

### 4.6 Top-down readability
- 66% of class skills have startup <= 0.15 s: crisp for the caster but gives allies/AI almost no read, and the
  arc/anticipation rarely shows from the 52° camera.
- 25 skills > 0.3 s break the documented rule (1.6).
- Bosses' "frente" metric (unaimed boss hits on non-tanks) was 13% after the group AI pass (notes); no newer number.

---

## 5. Ranked list (player impact)

1. Channels cut by held LMB / chaining (4.1).
2. DPS spread at 45: Raio +156%, Fogo +96%, Gelo +66%, Inquisidor +58% vs Sacerdote -70%, Fera -35% (1.3).
3. No accessibility/feel options: shake, hit-stop, flash, numbers, colour-blind, rebinding (4.4).
4. Global hit-stop when the player is hit / non-arc hits freezes the whole world (4.3).
5. Party clutter: all party numbers + FX at full weight (4.5).
6. No boss HP/cast bar on the HUD (4.3).
7. Characters do not react to hits; no stun/root/slow body read (4.3).
8. Corsário kit: 5 unexplained WEAK skills; dps -20% at 45 (1.2, 1.3).
9. Sound: no per-target sound on magic hits, one `hit` pool for all weapons (4.3).
10. Anticipation: 193/294 skills at <= 0.15 s startup (1.6).
11. Startup rule broken by 25 skills, incl. nec_demon_form 0.45 s on a 6 s cd (1.6).
12. CC without diminishing returns; slows/roots stack as separate debuffs (2, CC).
13. Bot web path buys 0 notables for Cruzado/Templário (1.4).
14. Animation candidates still open: atk_charge, cast_channel, cast_shadow, buff_focus, unshielded block (3).
15. Boss humanoid `attack` 68-72°/frame peak shared by Durgash/Ghar/Warlord/Ghoul Giant/Troll Thrower (1.5).
