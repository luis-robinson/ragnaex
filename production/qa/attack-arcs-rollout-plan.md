# Attack arcs: rollout plan to every melee family (2026-11-14)

Author: technical-artist. Status: **plan only, waiting for the user's 3 decisions (section 6).** No code changed, no Godot run.
Inputs: `production/qa/attack-anim-audit-2026-11-14.md` (option B), the pilot (`game/fx/weapon_arcs.gd`,
`shaders/smear_arc.gdshader`, 1H sword, scores basic physical 3->9, holy 5->9, `pal_holy_strike` 6->8) and
`production/qa/evidence/attack-arcs/swing_table.{json,csv,md}` (392 measured clips, kits identical per weapon family).

## 1. Family table

Shapes: **F** flat crescent (pilot, tilted to the camera) · **S** standing crescent (vertical plane, axial-billboarded
toward the camera, head ends at the ground) · **W** narrow wedge (thrust spike + speed-line fringe) · **R** ring (spin)
· **K** ground rake (3 claw streaks / bite chevron on the floor). Band colours are **placeholders for the art-director**
(I pick no palette): only the pilot sword value is real. `stop_mult` multiplies the sim's hit-stop frames
(basic = `Balance.HIT_STOP_FRAMES_BASIC` 2), from the audit's dagger 1 / sword 2 / axe-2h 4 frames.

| Family (`weapon_type`) | Basic clip (shape) | Skill clips (shape) | Band (placeholder) | stop_mult |
|---|---|---|---|---|
| sword (pilot) | `atk_1h_a` F+ / `atk_1h_b` F- (110 deg cone) | `atk_sweep` F+, `atk_finisher`/`atk_leap`/`atk_flurry` S, `atk_spin` R, `atk_thrust` W | cool steel `(0.72,0.86,1.0)` (pilot) | 1.0 |
| mace | `atk_1h_a` F+ / `atk_1h_b` F- (same signs as sword) | as sword; `atk_claw` S (mace is overhead there, sword is H) | warm steel | 1.25 |
| sword2h, mace2h | `atk_2h` **S** (plane tilt 82 deg, tip 2.2 -> -0.15 m, 150 deg cone x1.4 reach) | `atk_sweep` F+ (H), `atk_leap` F+ (H with 2h!), `atk_finisher` S, `atk_spin` R | heavy steel, thicker band | 2.0 |
| axe (1h, paired) | see dual | `atk_claw` F+, `atk_finisher`/`atk_leap` S | see dual | 1.5 |
| axe2h (+ Titan pair) | `atk_sweep` F+ (150 deg, peak at frame 4 not IMPACT 8) | `atk_2h`/`atk_leap`/`atk_finisher` S, `atk_spin` R | heavy, ember-edged | 2.0 |
| spear | `atk_thrust` **W** (40 deg, 3.3 m; tip dx +0.86, slight right-to-left lean) | `atk_sweep` F+ (H), `atk_leap`/`atk_finisher` S, `atk_spin` R | pale, long fringe | 1.0 |
| dual (sword/axe/mace/dagger/claw pairs) | `atk_dual_a` / `atk_dual_b` **2 slivers** (short F, 70-90 deg) or F + W (see 2) | off hand mirrors main in `atk_claw`/`atk_finisher`/`atk_leap` | per main weapon, slimmer | dagger 0.5, others 0.75 |
| dagger (single, `atk_dagger`) | F short (measured only as `other`, no build plays it today) | - | as dual | 0.5 |
| claws | via dual: `atk_dual_a` both +, `atk_dual_b` both - | `atk_claw` F+ (H main, O- off), `atk_finisher` F+ | as dual | 0.75 |
| scythe | physical: `atk_2h` S; magic basic `atk_staff` keeps the ribbon | `atk_sweep` F+ (H+v), `atk_finisher`/`atk_leap` S, `atk_spin` R (tip 0.31 m from axis) | dark, hooked tail | 1.5 |
| scepter / staff | **keep the tinted ribbon** (`atk_staff` lateral travel 0.11-0.17 m = no side) | physical scepter skills only: `atk_thrust` W (no side) | theme colour | - |
| druid forms wolf/bear | `attack`: bear = right-paw swipe **K**, wolf = snout drop (bite chevron **K**) | `maul`/`pounce`/`slam` K (overhead, sweep 0 on every paw) | form colour | bear 1.5, wolf 1.0 |

Out of scope (unchanged): `atk_charge` (static weapon, the hit is the body lunge), bow/rifle/pistol/throw/shoot_multi.

## 2. How `CLIP_SWEEP` must change

Today: `{clip: sign}` with combo-parity fallback. The table shows every sign difference comes from family or hand,
never from the kit, so:

- **Key = `clip|family|hand`** (`hand` = `main`/`off`), value = `{sweep, shape, peak_off}`; fallback order
  `clip|family|main` -> `clip|*|main` -> parity. Generated once from `swing_table.json` (rows with `role` basic/skill,
  245 rows) by a small script, pasted as a const; a check re-reads the JSON and asserts the signs (section 4).
- **Dual wield = 2 slivers.** `atk_dual_a`/`b` peak at frame 3, IMPACT is 5, so the pilot window gives 0 or a sign that
  flips with the weapon: use `sweep_fast`. Spawn both slivers at the damage tick with `progress` pre-advanced by
  `peak_off` (2 frames / clip fps, about 0.25 of life) so the head is already past the peak. Pairs: `atk_dual_a`
  main +, off - (axe/mace/sword), off static (dagger, 1 sliver), off + (claw); `atk_dual_b` claw and dagger both -,
  axe/mace/sword = off-hand **forward jab** (W) with main at 0 (no main sliver).
- **`atk_spin` = -1 (clockwise from above) for every family and hand.** Today it is missing and parity mirrors it every
  other cast. Ring radius comes from `SkillDef.radius`, not the tip (tip stays 0.3-0.65 m from the axis).
- **`atk_slash_shot` uses its own frame.** IMPACT 9 is the pistol shot (blade static, 0.13 m off the ground); the slash
  peaks at frame 4. Its arc must be fired from `EntityView` at clip frame 4, not from the sim's damage tick.
- **Overheads have no side** (`atk_2h`, `atk_finisher`, `atk_leap`, `atk_flurry`, `atk_claw` when O, forms):
  `sweep = 0`, shape S/K. Ambiguous rows (`sweep_ambiguous`, e.g. `atk_finisher` dx +0.3 m but fastest step straight
  down; scepter `atk_thrust` -0.11 m) are written as 0, never trusted as a side.
- Clamp every arc height at >= 0: tips go 0.2-0.9 m under the ground in finisher/leap/claw/2h/flurry.

## 3. New shapes (shader + `weapon_arcs.gd`)

All shapes reuse the one cached grid `ArrayMesh` (shape chosen in the vertex shader) and the one shared material;
only the rake needs a new cached mesh. Effort: S < 0.5 day, M 1 day, L 2+ days.

| Shape | Shader | `weapon_arcs.gd` | Effort |
|---|---|---|---|
| F short sliver (dual) | none (params) | 2 spawns per swing, `peak_off`, off-hand sign; pool 6 -> 8 | S |
| S standing crescent | `sweep == 0` branch: head at the bottom, top-to-bottom erosion | vertical plane along facing, rotated about the facing axis toward the camera (else edge-on when facing to/away from the camera); ground slash mark at the landing point | M |
| W thrust wedge | new `shape 3`: u along reach, v across, sharp tip, 3-4 fringe lines | length = `s.radius`, width from `cone_angle_deg`; small lean from the table | S |
| R ring | `arc_deg = 360`, high `inner_r`, travelling head (`progress` drives head angle) | trigger from SELF skills; one ring per `ACTIVE_LOOP` pass | M |
| K ground rake | new `shape 4` + cached 3-strip mesh | on the floor (y 0.05), along facing; bear 3 streaks, wolf chevron | M |
| Triggers beyond CONE | - | `FxManager._on_skill_effect` SELF (spin) and GROUND (leap) branches; `atk_slash_shot` frame-4 hook in `EntityView` | M |

Total about 4-5 days of Godot work, no Blender.

## 4. Order of work, evidence, checks, perf

**Waves (each is one pilot = one family row + its evidence, reviewed before the next):**
1. mace (rows only, F, same clips as sword) + sword2h/mace2h (S shape). Hero: Paladin.
2. axe2h + Titan pair (F wide, peak frame 4 vs IMPACT 8). Hero: Berserker executor.
3. spear (W). Hero: Ranger lanceiro.
4. dual (slivers, jab) for sword/axe/mace/dagger/claw pairs. Heroes: Assassin lâminas, Berserker punhos, Druid maces.
5. cross-family skill clips: R (spin), S on leap/finisher/flurry, `atk_slash_shot` hook. Scythe rides on this wave.
6. forms (only if decision 3 says yes).

**Evidence per family**, same as the pilot, in `production/qa/evidence/attack-arcs/<family>/{before,after}/`:
strips at 9 m and 24 m for basic A, basic B (or the dual pair) and one skill; full frames at the impact frame and
+1 (`f10/f11`); scored with the `docs/skills_review.md` grid (pass >= 8). Plus smoke 0 `SCRIPT ERROR`,
`combat_probe` 0 FLAG, full suite 0 failed.

**Checks to add** (in `_check_weapon_arcs`):
- every `clip|family|hand` the game plays (swing table `role` basic/skill) has an entry or a documented fallback, and its
  sign equals the table (ambiguous rows = 0); `atk_spin` is -1 everywhere; overheads are 0.
- every `FAMILIES` key is in `ItemDef.MELEE_TYPES`; `family_of` returns `dual` for two `ONE_HANDED_MELEE`, `""` for
  bow/rifle/pistol/staff/wand/orb; a monster with empty `weapon_type` gets no arc.
- dual spawns exactly 2 arc nodes (1 for the dagger off-hand static and for the `atk_dual_b` jab); pool stays capped.
- `stop_mult x frames` capped (proposal: 8 frames) for every catalog skill; shapes 0-4 load in the shader.
- the existing "< 200 meshes per kit" check stays green unchanged (proves no kit was touched).

**Perf budget.** The project states no FX draw or particle budget, so the budget is **no regression vs before**
(`-- --perf` town fight, interleaved A/B; pilot: draws 1548-1761 both sides = noise) and a hard ceiling from the pool:
1 draw per live node, today 18 max (6 x 3 shapes); with dual and rake, proposed 8 per type = 40 max worst case,
typically under 10. Melee ribbons off saves one `ImmediateMesh` rebuild per swinging character. Sim cost: none.

## 5. Risks

- **Mesh budget: not affected.** No new meshes in any kit, no `build_kits`; everything is one procedural grid + one rake
  mesh at runtime. Option C's `smear_*` kit pieces stay out.
- **Hit-stop stacking.** `hit_react` takes the max, so one view never stacks. But: (a) `stop_mult` x big skills
  (`ber_overhead` 7 x 2.0 = 14 frames = 0.23 s) leaves the clip behind the sim: needs the cap; (b) the `hit_stop` event
  carries only frames, so in a frame with an arc hit **and** a non-arc hit on the player (projectile, magic) the local
  handler can swallow the global stop or both fire; (c) `combat_probe` runs without FxManager, so it cannot see any of
  this: the cap check is the guard.
- **Ranged stays as is:** bow/rifle/pistol/throw/multi-shot, projectile trails, and the staff/wand/orb ribbon.
- **Mobs and NPC guards.** `family_of` reads `stats.weapon_type`, so guards, sentinels and bots with gear already get
  arcs (the pilot does this for swords); monsters have `""` and get none, even orcs that hold an axe model. Arcs
  everywhere in a raid/siege will recycle the pool and cut arcs short; sparks/star are already player/party only. Proposal:
  arcs for player, party and anyone hitting or hit by them; others keep the ribbon.
- Pose disagreement on clips where weapon length changes the type (claw vs sword `atk_claw`, 2h `atk_leap` is H):
  this is why the key includes family. Set variants `wpn_main_<type>_<style>` were not measured (same bone, lengths differ slightly).

## 6. Recommendation and decisions

**Recommend: roll out per family in the 5 waves above (forms last, optional), physical = family band, magic = theme
colour (the pilot rule), arcs limited to player/party-involved swings.** Each wave is independently revertible
and the pilot showed the review loop is about half a day per family.

Decisions for the user:
1. **All at once vs per family.** All at once: one review, about 4-5 days, one big diff. Per family (recommended): 5 small
   changesets, each with its own before/after strips and a stop point.
2. **Colour per family vs per theme.** (a) family band for physical + theme for magic (pilot rule, recommended);
   (b) always the build's signature `look`/theme; (c) one neutral band for everything. Exact colours go to the art-director.
3. **Do the druid forms get arcs?** (a) ground rake K for wolf and bear; (b) bear only (wolf `attack` has the paws on the
   ground, only the snout drops 0.96 -> 0.31 m); (c) no, keep today's look.
   (Related, smaller: should armed mobs and guards outside the player's fights get arcs? see section 5.)
