# Attack arcs, wave 6: druid animal forms (wolf + bear) - implementation spec (2026-11-15)

Author: technical-artist. Status: **spec only.** No code changed, no Godot run, no commit.
User decision (2026-11-15): forms get arcs, **wolf AND bear**, ground rake (option K).
Inputs (read-only): `production/qa/attack-arcs-rollout-plan.md` (forms row, shape K), `production/qa/attack-arc-colours.md`
(wolf #CFD1D6, bear #D1CCC4, floor-mark caps 6.5), `production/qa/evidence/attack-arcs/swing_table.{md,json}` (24 form
rows), `game/fx/weapon_arcs.gd`, `game/entities/entity_view.gd` (`IMPACT_FRAME`, `FORM_CLIP`, `FORM_SCALE`,
`clip_for_skill`, `ACTIVE_LOOP`), `tools/blender/druid_sets.py` (`form_clips`, `clear_form_ground`),
`data/catalog/skills_catalog.gd`, `data/catalog/classes_catalog.gd`, `data/balance.gd` (`FORM_REQUIRES`).
All file references are in the attack-arcs worktree unless stated.

## 0. Read first: which GLBs

- **The swing table's form rows are stale.** They were measured from master's `form_wolf.glb`/`form_bear.glb`
  (md5 `68eba79b...` / `bfb13c3c...`, same files in `wt/attack-arcs`), which still have the paws 0.15-0.25 m under the ground.
- The ground-clip rebuild (`clear_form_ground`, clips `maul pounce slam attack`) lives in **`wt/post-int`** (=`wt/ground-clip`):
  md5 `7218a64b...` (wolf) / `7b4bc2d2...` (bear). Every number in this spec was measured from those files (pure-Python
  glTF reader, rigid pieces on bone nodes, 24 fps, frames 1-based; same convention as the swing table: model space,
  x = +X of the model, y up, z forward; numbers are **before** `FORM_SCALE` wolf 1.15 / bear 1.4).
- **Wave 6 must run on the rebuilt GLBs.** Either wait for post-int to land on master and rebase `wt/attack-arcs`, or
  copy the two GLBs (+ `--import`) into the worktree. Do not tune rake positions on the old files.
- Measured paw clearance (rebuilt): paws never go below their idle height in `attack/maul/pounce/slam`
  (wolf idle min y -0.012, bear -0.049; worst in-clip -0.012 / -0.053). `roar`/`brace` sink on purpose (wolf brace -0.17):
  no arc on those clips, so it does not matter here.

## 1. Which clip each form skill plays (who triggers what)

Forms are not humanoid (`form_humanoid` false): `clip_for_skill(..., form=true)` returns `"attack"` for the basic and ignores
`SkillDef.clip`; skill clips go through the humanoid rules and `FORM_CLIP` maps them to the animal clip.
Hero builds (`classes_catalog.gd`): **Lobo = `fera`** (dual mace, `dru_wolf_form`), **Urso = `guardiao_verde`** (mace2h,
`dru_bear_form`). Form variants of the skills: `skills_catalog.gd` lines ~548-559.

| Skill (variant name) | Form | Target/kind | Humanoid clip (rule) | Form clip | IMPACT | Theme (VFX_RULES) | Arc |
|---|---|---|---|---|---|---|---|
| `basic_*` | both | CONE phys | `"attack"` (form basic) | `attack` | 5 | physical | **yes** |
| `dru_maul` (Patada do Urso, cone 140, radius x1.3) | bear | CONE phys | `atk_claw` ("maul" in CLAW_IDS) | `maul` | 7 | earth ("maul") | **yes** |
| `dru_earth_slam` (Pisão do Urso) | bear | SELF phys | `atk_spin` (SELF) | `slam` (ACTIVE_LOOP) | 8 | earth ("slam") | **yes** |
| `dru_stampede` (Investida do Urso, dash) | bear | DIRECTION phys | `atk_leap`/`atk_charge` (LEAP_IDS) | `pounce` | 9 | earth | **yes** (see gate, 6) |
| `dru_mountain` (Avalanche) | bear | GROUND phys | wave agent must confirm (no token; physical fall-through) | likely `maul` | 7? | earth | yes if CONE/GROUND gate passes; rocks FX already own the area |
| `dru_claw` (Mordida) | wolf | TARGET phys | `atk_claw` | `maul` | 7 | physical? (no VFX token seen) | **yes** |
| `dru_pounce` (Salto do Lobo, dash) | wolf | DIRECTION phys | `atk_leap`/`atk_charge` | `pounce` | 9 | earth ("pounce") | **yes** (gate, 6) |
| `dru_maim` (Dilacerar Feral) | wolf | TARGET phys | wave agent must confirm (likely fall-through -> `maul`) | `maul`? | 7 | confirm | yes |
| `dru_rampage` (Redemoinho de Presas) | wolf | SELF phys | `atk_spin` unless FLURRY_IDS has "rampage" (confirm) | `slam` (or `maul`) | 8 | blood ("rampage") | **yes** |
| `dru_savage` (Golpe da Matilha) | wolf | TARGET phys, hit_stop 6 | `atk_claw` ("savage" in CLAW_IDS) | `maul` | 7 | blood ("savage") | **yes** |
| `dru_bellow`, `dru_frenzy`, `dru_oak_skin`, `dru_prowl`, form toggles | - | BUFF | shout / buff_* | `roar` / `brace` | 7 / 6 | - | **no** (not a strike) |

"Confirm" rows: the wave agent prints `EntityView.clip_for_skill(s, w, off, 0, true, false)` and then `FORM_CLIP` for every
`fera`/`guardiao_verde` skill (with the form variant applied) and pastes the result into the check (section 7).
Ancestral forms (`alpha` -> wolf base, `ent` -> bear base, `ANC_FORM_BASE`) have their own GLBs (`form_alpha`, `form_ent`,
FORM_SCALE 1.4/1.2), **not measured here and not in the user's approval**: see decision D2.

## 2. Measured strike data (rebuilt GLBs, before FORM_SCALE)

`tip` = front-most vertex of the paw piece (`paw_leg_fr` / `paw_leg_fl`) or of `snout` in idle frame 1.
"Land" = first frame the paw is back at idle height after being lifted.

| Form / clip | frames | IMPACT | What hits | Path into impact | Land / contact (x, z) |
|---|---|---|---|---|---|
| wolf `attack` | 16 | 5 | **snout only** (paws stay planted, +-0.11 m) | snout 0.96 m (f3) -> 0.31 m (f5), forward 0.88 -> 1.20 | snout ground point (0.00, 1.20); holds 0.31-0.42 m until f9 |
| bear `attack` | 18 | 5 | **both paws**, +X paw leads | +X paw 0.82 m (f3) -> 0.11 (f4) -> ground f5, pulled BACK z 0.59 -> 0.30 (0.29 m drag); -X paw 0.59 m -> ground f5, z 0.66 -> 0.40; snout to 0.27 m f5 | +X (0.31, 0.30), -X (-0.31, 0.40), both at f5 = IMPACT |
| wolf `maul` | 16 | 7 | +X paw rakes, snout bites at the same frame; -X paw second | +X paw 0.77 m (f5) -> 0.07 (f7), z 0.59 -> 0.23 (back 0.36 m); snout 1.37 -> 0.25 m at f7; -X paw lands f9-10 | +X (0.09-0.15, 0.23-0.31) f7-9; -X (-0.14, 0.34) f10 |
| bear `maul` | 20 | 7 | +X paw rakes; -X paw second (3 frames later) | +X paw 1.04 m (f5) -> ground f7, z 0.45/0.68 -> 0.33; -X paw 0.82 m (f5) -> ground f10, z 0.62 -> 0.26 | +X (0.16, 0.33) f7; -X (-0.23, 0.26) f10-11 |
| wolf `pounce` | 18 | 9 | both paws together + snout | paws 1.22 m (f7) -> ground f9, forward z 1.05 -> 0.65; snout 1.82 -> 0.17 m | (+-0.19, 0.65) f9, skid back to z 0.37 by f14 |
| bear `pounce` | 21 | 9 | both paws together + snout | paws 1.29 m (f7) -> ground f9, z 1.10 -> 0.66 | (+-0.28, 0.66) f9, holds to f11 |
| wolf `slam` | 18 | 8 | both paws together (two-paw stomp) | paws 1.13 m (f5) -> 0.16 (f7) -> ground f8, z 0.58 -> 0.32 | (+-0.15, 0.32) f8, held to f13 |
| bear `slam` | 23 | 8 | both paws together | paws 1.34 m (f5) -> 0.42 (f7) -> ground f8, z 0.67 -> 0.29 | (+-0.23, 0.29) f8, held to f12 |
| `roar` / `brace` | 18-22 / 16-19 | 7 / 6 | - | no strike | - |

Every strike is **overhead** (lateral share 0-3 %, swing-table `sweep` 0): there is no left/right swipe to read a sign from.
The only "side" information is **which paw leads** (+X paw in `attack`(bear) and `maul`), which places the rake off-centre.

Paw-side naming caveat: the bone/piece called `leg_fr` sits at **model +X**. The project convention (`CLIP_ARC` comment,
swing table) says +X = the character's **left**. Either the mob_kit names are mirrored or the convention note is; the
rake only needs the model-space sign (+X), but the wave agent must confirm on screen once (one frame of bear `attack`
from the game camera: the lead rake must sit under the paw that came down) before naming anything "right paw" in code or docs.

## 3. Shape K: the ground rake

One new shape id (`K`, shader `shape 4` or a separate cached `ArrayMesh`, per the rollout plan) with **3 parallel claw
streaks** per paw (4 for the bear is acceptable if 3 reads thin at 24 m; start with 3). Lives on the floor, never stands.

Geometry (all metres in model space, multiply by `FORM_SCALE`):
- Placement: streaks run **along the facing**, centred on the paw's lateral x, from a far end at `land_z + k_len` to a near
  end at `land_z` (the paw drags back toward the body in every clip). Head (bright, opaque end) = **near** end at impact;
  erosion runs far -> near over the life, so the mark reads as "pulled in".
- Why forward of the paw: the measured land points sit at z 0.23-0.40 (under the chest). From the 52 deg camera the body
  covers them. Pushing the rake forward by `k_len` puts most of it in front of the muzzle, where the target is.
- Proposed knobs (new `FAMILIES` keys, one row per form, colour from the colours doc):
  `k_len` (streak length) wolf 0.75 / bear 0.95 · `k_gap` (spacing between streaks) wolf 0.09 / bear 0.13 ·
  `k_width` (each streak half-width at the head) wolf 0.035 / bear 0.05 · `k_y` floor offset 0.05 (above bear idle paw -0.049,
  no z-fight with zone planes, which sit at 0.8-6.0 mm) · `life` 0.18 (cap 0.2) · `alpha` 0.6 (cap) · `glow` 1.0.
  These are appearance values inside the art-director's caps; tune in the review loop and log them.
- Bite chevron (wolf `attack`, wolf `maul` snout): a **V of two short streaks** pointing forward, apex at the snout ground
  point (0, 1.20 x 1.15), arms 0.35 m at +-30 deg. Same material and caps. No chevron for the bear (its basic is a paw rake).
- **Never a ring or disc**, never filled. Each streak is a tapered strip; the gap between streaks must stay open at 24 m
  (if it closes into one band at 24 m, widen `k_gap`, do not thicken the strips).

Per clip:

| Clip | Mark | Spawn | Count |
|---|---|---|---|
| wolf `attack` | bite chevron at the snout point | damage tick (= IMPACT 5) | 1 |
| bear `attack` | rake under the +X paw (x +0.31) at impact; optional fainter (alpha x0.8) rake under the -X paw | damage tick | 1 (+1) |
| wolf/bear `maul` | rake under the +X paw at impact (+ wolf: chevron at the snout, same tick); **second rake under the -X paw** at clip frame 10 (wolf) / 11 (bear) | first at the damage tick; second from `EntityView` at the clip frame (same mechanism as `SLASH_FRAME` / `slash_hook`) | 2 |
| wolf/bear `pounce` | two short rakes (`k_len` x0.6), one per paw, at the landing (+-x, z 0.65), drawn as a skid (head = near end) | damage tick, **at the body's position at that tick** (dash: see risk R3) | 2 |
| wolf/bear `slam` | "stomp" mark: two paw rakes splayed outward +-20 deg from facing, `k_len` x0.7, at (+-x, z 0.3) | damage tick; when `slam` repeats in `ACTIVE_LOOP`, one pair per pass (like the R ring), never more than 2 pairs live | 2 per pass |

Notes:
- The slam area (`dru_earth_slam` radius 3.0 x1.25, `dru_rampage` radius 3.0 x1.2) is already shown by the skill's own FX.
  The stomp mark is local to the paws on purpose: an area-sized floor ring would read as a boss telegraph
  (colours doc 4/6.5, `FxManager.DANGER*` grammar).
- No standing crescent (S) on forms. The paws' path is vertical with no lateral component, and a standing crescent on a
  0.7 m-tall quadruped reads as a human swing.

## 4. Timing vs IMPACT, and hit-stop

- The sim's damage tick lands on the clip's IMPACT frame (the clip is retimed by `windup_timing` so `IMPACT_FRAME` meets
  `startup`). Spawn at the damage tick like every other arc (`FxManager` path); only the **second maul rake** is
  clip-frame driven from `EntityView` (the sim has one hit).
- Paw contact = IMPACT in `attack`(bear), `maul`(+X paw), `pounce`, `slam`. Wolf `attack` snout lowest = IMPACT. **No
  `peak_off`** needed: every form peak speed frame is IMPACT-1 or IMPACT (swing table `peak_speed_frame`, unchanged by the rebuild,
  which only lifted body/legs). The wave agent re-checks the peak frames on the rebuilt files if it changes timing.
- Held wolf basics: `fera` has +25 % attack speed in form; the rake life (0.18 s) may outlive the next swing. Pool slots recycle
  oldest first, so this is fine; confirm in `combat_probe` (0 FLAG) and by eye in the held-attack strip.
- Hit-stop (rollout plan): `stop_mult` **bear 1.5, wolf 1.0**. With `STOP_CAP_FRAMES` 8: `dru_savage` 6 x 1.0 = 6;
  `dru_mountain` 6 x 1.5 = 9 -> capped at 8; basic 2 x 1.5 = 3 for the bear. Push: wolf 0.12, bear 0.22 (appearance).

## 5. Colour

- Bands (colours doc, approved): **wolf `Color(0.81, 0.82, 0.84)` #CFD1D6**, **bear `Color(0.82, 0.80, 0.77)` #D1CCC4**,
  rim = `band.darkened(0.82)` (no `rim` key), glow 1.0, overall alpha <= 0.6, life <= 0.2 s.
- **Theme conflict (decision D1).** The pilot rule is "physical band unless the skill has a magic theme". The druid form
  skills are physical but carry **earth** (`maul`, `slam`, `pounce`, `stampede`, `mountain`) or **blood** (`rampage`,
  `savage`, `frenzy`) themes from `SkillsCatalog.VFX_RULES`, not nature. Today `_swing` treats any theme other than
  `""`/`physical` as magic, so as-is the rake would be earth brown #AD8A67 or blood #E94040 (x0.35 white) **on the floor**.
  Blood red on the floor is the danger hue (colours doc 6.5/6.6). Options:
  (a) **Recommended:** a K mark always uses the form band, whatever the theme; the theme stays in the skill's own FX. Rule:
  "floor marks are form colour". (b) Theme colour for earth, form band for blood. (c) The pilot rule unchanged (theme
  wins), accepting a red floor mark on `dru_rampage`/`dru_savage`.
  Implementation of (a): in the K path, ignore `theme_of(s)` for the band and use `FAMILIES["form_wolf"/"form_bear"]["band"]`.

## 6. Code changes the wave agent will make (summary, for the approval changeset)

`game/fx/weapon_arcs.gd`:
- `FAMILIES` rows `"form_wolf"` / `"form_bear"` (keys in section 3/4 + `band`, `stop_mult`, `push`), `K_KEYS` list.
- `family_of(e)`: `e.form in ["wolf", "bear"]` -> `"form_" + e.form` **before** the weapon lookup (today the form uses the
  mace/mace2h weapon type, so the bear would otherwise get the mace2h S crescent).
- `draws_arc`: replace the blanket `e.form != ""` exclusion with "form not in the K table -> false" (phantom, demon, lich,
  bird, ent, alpha stay excluded until D2). Add `SkillDef.Target.DIRECTION` **for forms only** (pounce/stampede are T_DIR;
  `ARC_TARGETS` has no DIRECTION today). Keep the `kind == PHYSICAL or basic` filter.
- `CLIP_ARC`-like table for forms, keyed by the **form clip** (after `FORM_CLIP`), e.g.
  `FORM_ARC := {"attack|form_wolf": "bite", "attack|form_bear": "rake_lead", "maul|*": "rake_lead+second",
  "pounce|*": "skid_pair", "slam|*": "stomp_pair"}` with the measured paw x/z per form (section 2) as data, not magic numbers
  scattered in code.
- Shape K spawn function (`_rake(...)`), one cached rake `ArrayMesh` (3 strips) or `shape 4` in `shaders/smear_arc.gdshader`;
  pool for K capped at 8 nodes.
`game/entities/entity_view.gd`: a `maul` second-rake hook at clip frame 10 (wolf) / 11 (bear), mirroring the
`atk_slash_shot` hook; `ribbon_off` already does nothing for forms (`kit.trail_on = false` in `_swap_form`).
No kit, GLB or Blender change. No sim change.

## 7. Checks to add (`_check_weapon_arcs`, `tools/tests/run_tests.gd`)

1. Every strike skill of `fera` (wolf variant) and `guardiao_verde` (bear variant), plus the basic, resolves through
   `clip_for_skill(..., form=true)` + `FORM_CLIP` to a clip present in `FORM_ARC`; every buff/shout resolves to `roar`/`brace`
   and `draws_arc` is false for it.
2. `draws_arc` is true for a wolf/bear entity on basic, `dru_maul`, `dru_claw`, `dru_savage`, `dru_pounce`, `dru_stampede`,
   `dru_earth_slam`, `dru_rampage`; false for phantom/demon/lich/bird (and alpha/ent unless D2 says yes).
3. `family_of` returns `form_wolf`/`form_bear` for a formed druid even with a mace / mace2h equipped.
4. K rows: `alpha <= 0.6`, `life <= 0.2`, `glow == 1.0`, `k_y > 0`; K spawn creates **no** node with `shape == R`/disc mesh.
5. Spawn count per clip: attack wolf 1, attack bear 1 (or 2 with the faint -X rake), maul 2 (one at tick + one at the frame hook),
   pounce 2, slam 2 per pass; K pool never exceeds 8 live nodes after 20 rapid basics.
6. `stop_mult x frames <= STOP_CAP_FRAMES` for every form skill (dru_mountain is the one that hits the cap).
7. `IMPACT_FRAME` for `attack maul pounce slam` equals the frame where the measured contact happens (data table in the check,
   copied from section 2): guards against a future `form_clips` retime moving the impact without the rake.
8. If D1 = (a): band of a K mark equals the form band for an earth and a blood skill.
9. Existing `_check_form_leg_twist` and "< 200 meshes per kit" stay green unchanged.

## 8. Evidence

`production/qa/evidence/attack-arcs/wave6/{before,after}/`, same harness and naming as waves 1-5:
- Heroes: Druid **`fera`** in wolf form, Druid **`guardiao_verde`** in bear form (`-- --autostart=druid --gear=<set_id> --form=<wolf|bear>`
  for the look; arcs filmed with the wave-1..5 strip tool).
- Strips at **9 m and 24 m**: wolf basic (bite), bear basic (lead rake), `dru_maul` bear (both rakes), `dru_claw` or
  `dru_savage` wolf (rake + bite), `dru_pounce` wolf, `dru_earth_slam` bear (stomp, two passes if it loops).
- Full frames at the impact frame and +1, and the maul second-rake frame.
- Grounds (colours doc 5): Aldara grass + dirt road, **steppe sand**, **fort_fire basalt**. Sand is where the light band fails:
  the rim must carry it; if the 0.6 alpha cap makes it invisible on sand, report it, do not raise the cap (D3).
- Held-attack strip for the wolf (attack-speed buff) to show rake overlap.
- Score with the `docs/skills_review.md` grid (pass >= 8). Smoke 0 `SCRIPT ERROR`, `combat_probe --class=druid` 0 FLAG,
  full suite 0 failed, `-- --perf` town fight A/B (no-regression budget, rollout plan 4).

## 9. Risks

- **R1 Stale GLBs** (section 0). Biggest one: tuning on master's forms puts rakes 0.15-0.25 m off and under paws that clip.
- **R2 Low silhouette / occlusion.** Wolf body ~0.7 m, bear ~0.9 m before scale; contact points sit under the chest. Rake
  pushed forward by `k_len` (section 3). Check the yaw-45 camera from all 4 facings: facing away from the camera hides more.
- **R3 Dash skills.** `dru_pounce`/`dru_stampede` move the body during the active phase (dash 5-7 m). The landing rake must
  use the entity position at the damage tick, and the wave agent must measure whether the paws visually land at that tick
  or after the dash ends (if after, fire the skid from the clip frame 9 hook instead, like the maul second rake).
- **R4 Camera roll is not an issue for K** (flat on the floor, no billboard), unlike S. It **is** an issue if anyone
  is tempted to reuse S for the slam: do not.
- **R5 FORM_CLIP mapping drift.** Everything above depends on `FORM_CLIP` + `clip_for_skill` + `CLAW_IDS/LEAP_IDS/FLURRY_IDS`
  tokens. A skill rename (e.g. losing "maul"/"savage") silently moves it to another clip: check 1 guards it.
- **R6 Paw-side naming** (`leg_fr` at +X = model left by the project convention): confirm on screen once (section 2).
- **R7 Floor-mark grammar.** Rakes are the only player FX on the floor besides the S mark: caps alpha 0.6 / life 0.2,
  never a ring, never saturated (D1). Blood theme on the floor is the main way to break this.
- **R8 Pool pressure.** Bear maul + slam loops + party druids: K needs its own pool (8) so it does not evict weapon arcs.
- **R9 Ancestral forms** (alpha/ent) share the base clips' names but are separate GLBs with other proportions and scale 1.4/1.2:
  not measured; leave them excluded unless D2 says otherwise.

## 10. Decisions for the user (before the wave agent writes code)

- **D1 Colour of floor rakes for earth/blood-themed form skills:** (a) always the form band (recommended), (b) earth = theme,
  blood = form band, (c) theme always (pilot rule as-is).
- **D2 Ancestral forms:** (a) wolf/bear only now (recommended; matches the approval), alpha/ent in a follow-up with their own
  measurements; (b) include alpha (as wolf) and ent (as bear) in wave 6, scaled by `FORM_SCALE`, after measuring their GLBs.
- **D3 Sand readability:** if the 0.6 alpha cap leaves the rake unreadable on sand: (a) accept it (rim only), (b) art-director
  raises the cap for K to 0.7, (c) 4 streaks instead of 3 for both forms.

## Minor decisions logged (agent's own, inside the approved scope)

- Rake head = near end, erosion far -> near (matches the measured backward paw drag in every strike clip).
- Rake pushed forward by `k_len` instead of centred on the paw contact (occlusion, R2).
- Wolf basic = bite chevron only (paws do not move in wolf `attack`), not a rake.
- Second maul rake from a clip-frame hook (the sim has a single hit).
- Slam = splayed paw-pair stomp, not an area mark.

## Formas ancestrais (medido)

Measurement only, 2026-11-15 (blender-modeler). No code, GLB or script changed; no Godot run; no commit.
Raw numbers (per frame + summary): `production/qa/attack-arcs-wave6-ancestral.json`.
Same method and conventions as section 2: pure-Python glTF reader, rigid pieces on bone nodes, 24 fps, frames 1-based,
model space (x = +X of the model, y up, z forward), metres **before** `FORM_SCALE` (**alpha 1.4, ent 1.2**).
Files: `assets/models/form_alpha.glb` (md5 `e5b97c66...`) and `form_ent.glb` (md5 `b0040693...`). **Both are byte-identical in
master and in `wt/post-int`: the ground-clip rebuild did not touch the ancestral forms.**

### A. How they are built (source: `tools/blender/druid_ancestral.py`, identical in master and post-int)

| Form | GLB | Body | Strike clips | Ground pass |
|---|---|---|---|---|
| `alpha` (Lobo Alfa, base wolf, build `fera`) | own file `form_alpha.glb` | `mob_kit.quadruped(..., "wolf")`: **the same wolf mesh** (paw, snout, belly bounding boxes equal to `form_wolf` to the mm) + mane, ruff, moon mark, 3 glowing claws per paw (`alpha_leg_*`, on the leg bones), tail tip | `druid_sets.form_clips(lp, arm, "wolf")`: **the wolf clips** | **none**: `druid_ancestral.build` never calls `clear_form_ground` (also not in post-int) |
| `ent` (Ent, base bear, build `guardiao_verde`) | own file `form_ent.glb` | **not a quadruped**: upright tree on `MOB_BONES` (trunk `body`, canopy `head`, two branch arms `arm_r`/`arm_l` with fist + 3 root fingers, four root feet `leg_*`); 2.82 m tall before scale | own `druid_ancestral.clips(..., "ent")` for `maul pounce slam roar brace`; `attack` is the generic `build_monsters.combat_actions` (golem/ent rig) | none |

Clip routing is the same as wolf/bear (`FORM_CLIP`, forms are not humanoid). Skill variants: `SkillsCatalog.FORM_MODS` gives
`ent` its own names for `dru_maul` (Golpe de Galho, cone 150), `dru_earth_slam` (Tremor de Raízes), `dru_stampede` (Marcha do Ent,
dash 6), `dru_mountain`, and `alpha` for `dru_claw`, `dru_pounce` (dash 7), `dru_maim`, `dru_rampage`, `dru_savage`. Form-only
ascension skills: **`dru_ent_roots`** (T_SELF physical, radius 6 m, hit_stop 5 -> `atk_spin` -> **`slam`**, a strike, theme `nature`);
`dru_ent_grove`, `dru_alpha_howl` (buffs -> `roar`/`brace`), `dru_alpha_pack` (summon -> `roar`): no strike.
IMPACT frames are the shared ones (`attack` 5, `maul` 7, `pounce` 9, `slam` 8). The skill -> clip rows were read from
`clip_for_skill`/`FORM_CLIP`, not printed from a run: the wave agent confirms them like the "confirm" rows of section 1.

### B. Lobo Alfa: it is the PRE-rebuild wolf

Animation keys compared channel by channel: `form_alpha` vs master `form_wolf` (old) = **max difference 0.0 in all 10 clips**;
vs the rebuilt wolf = differs in exactly `attack maul pounce slam` (the four clips `clear_form_ground` fixed). So every alpha
strike still has the paws under the ground, and x1.4 makes it worse than the old wolf ever was.

| Alpha clip | frames | IMPACT | What hits | Contact frame vs IMPACT | Side / sweep | Height at IMPACT (y; idle paw -0.012) | Path into impact / drag | Land (x, z) |
|---|---|---|---|---|---|---|---|---|
| `attack` | 16 | 5 | snout only | snout lowest f5 = IMPACT (peak speed f4) | centre, lateral 0 % | snout 0.31 (0.29 lowest vertex); **paws -0.03/-0.04**, sliding forward z 0.52 -> 0.81 | snout 0.96 (f3) -> 0.31 (f5), z 0.88 -> 1.20; holds 0.31-0.42 to f9 | snout ground point (0.00, 1.20) = rebuilt wolf |
| `maul` | 16 | 7 | +X paw rakes + snout bites, same frame; -X paw shifts later | +X paw at its lowest f7 = IMPACT (peak f6); -X paw also down at f7, moves in f10-11 | +X paw leads; lateral 5.5 % (x 0.14 -> 0.09, inward) | **+X paw -0.21, claws -0.23; -X paw -0.22; snout -0.02 (in the ground)**; belly 0.06 | +X paw 0.77 (f5) -> -0.20 (f7), z 0.58 -> 0.23 (back 0.35); stays under ground f7-f11 (-0.21..-0.16); snout 1.37 -> -0.01 | +X (0.09-0.15, 0.23-0.35) f7-9; -X (-0.14..-0.09, 0.34-0.24) f10-11 |
| `pounce` | 18 | 9 | both paws + snout | f9 = IMPACT (peak f9); also sinks in the crouch f3-f5 (-0.11..-0.19) | symmetric, lateral 0 % | **paws -0.17 / -0.16, claws -0.18**; snout 0.09; belly 0.13 | paws 1.22 (f7) -> -0.15 (f9), z 0.90 -> 1.05 (f8) -> 0.78; stays under ground to f14 | (+-0.19, 0.78) f9 (rebuilt wolf: z 0.65), back to z 0.66 by f14 |
| `slam` | 18 | 8 | both paws (+ snout hits the ground) | f8 = IMPACT (peak f7) | symmetric, lateral 2.7 % (x 0.19 -> 0.15) | **paws -0.26, claws -0.28; snout -0.05 (-0.07 lowest vertex); belly 0.01-0.04** | paws 1.13 (f5) -> 0.16 (f7) -> -0.25 (f8), z 0.36 -> 0.57 -> 0.37; under ground f8-f13 | (+-0.15, 0.37) f8, held to f13 (rebuilt wolf: z 0.32) |

In the game (x1.4): slam paws 0.36 m under the ground and the muzzle 0.10 m; maul paw 0.29 m; pounce 0.24 m.
x/z of the land points agree with the rebuilt wolf within 0.00-0.13 m (the rebuild opens the legs forward/back instead of sinking).

What this implies:
- **A rake cannot be tuned on the current `form_alpha.glb`**: a floor mark at `k_y` 0.05 would sit 0.3-0.4 m (scaled) *above* the
  paw that made it. Same risk R1 as the stale wolf, and no rebuilt file exists anywhere.
- The fix is a model rebuild, outside wave 6's "no kit, GLB or Blender change": add `ds.clear_form_ground(ck, arm)` after
  `ds.form_clips(lp, arm, "wolf")` in `druid_ancestral.build` and re-export `form_alpha` (needs the user's go-ahead; the claws
  are extra meshes on the leg bones, so the pass will clear them too and the result can differ from the wolf by a few cm).
- After that rebuild alpha should be able to **reuse the whole wolf K table** (same clips, same mesh): bite chevron for `attack`,
  lead +X rake + snout chevron + second -X rake at f10 for `maul`, skid pair for `pounce`, stomp pair for `slam`, positions x1.4
  instead of x1.15. This is an expectation, not a measurement: re-measure the rebuilt file once before tuning.
- The only alpha-specific questions are appearance: band (wolf #CFD1D6 vs something for the silver-blue alpha; its claws are
  `glow` cyan) and whether `aspd_pct` 28 makes held basics overlap more than the wolf's 25.

### C. Ent: an upright two-armed striker, not a pawed animal

`tip` = lowest vertex of the arm piece in idle (a root fingertip): idle at (+-0.97, 0.11, 0.49). `arm_r` sits at model **+X**
(same naming caveat as `leg_fr`, section 2). Idle lowest points: arms 0.11, root feet -0.029, trunk 0.37.

| Ent clip | frames | IMPACT | What hits | Contact frame vs IMPACT | Side / sweep | Height (y) | Path into impact / drag | Contact (x, z) |
|---|---|---|---|---|---|---|---|---|
| `attack` (generic mob clip) | 16 | 5 | both arms chop, **+X arm leads** (125 deg vs 90 deg wind-up) | **1 frame EARLY**: the hands pass the front at **f4** (+X z 1.17, y 0.72; -X z 1.02, y 0.50; peak speed f4, 2.03 m/frame) and at f5 they are already swung **behind** rest (+X z -0.18, -X z 0.01) | overhead, lateral 4-8 % (not a side swipe); +X arm higher and further | **never touches the ground at the front**: 0.64 / 0.47 lowest vertex at f4; at f5 0.15 / 0.05 but behind the body; -X arm dips to -0.06 at f7-8 on the way back | +X fingertip 2.44 (f3) -> 0.72 (f4) -> 0.16 (f5): 160 deg of arm in 2 frames, a full vertical arc through the front; no drag (it keeps swinging back, returns by f12) | front of the arc at f4: (+1.03, 1.17) and (-1.05, 1.02), 0.5-0.7 m up |
| `maul` (Golpe de Galho) | 20 | 7 | **+X arm**, overhead branch chop; -X arm low hook lands the same frame | **f7 = IMPACT** for both (peak speed +X f6, 1.93 m/frame; -X f7) | +X arm, crossing **inward**: x 0.97 -> 0.74 (-0.23), lateral 9 %; -X arm x -1.29 -> -1.08, lateral 16 % | +X fingertips stop at **0.14** (about idle height, no ground contact, no clipping); **-X arm -0.10..-0.12 (in the ground) f7-f10** | +X: 2.40 (f4, z 0.00) -> 2.36 (f5, z -0.73, behind the head) -> 1.82 (f6, z 1.12) -> 0.14 (f7, z 1.14): a 2.3 m drop in front; then held f7-f11, **dragged back** z 1.14 -> 0.96 (0.18 m) at y 0.09-0.11, home by f19 | +X (0.74, 1.14) f7; -X (-1.08, 0.96) f7 |
| `pounce` (Marcha do Ent) | 21 | 9 | **both arms, horizontal ram** (shoulder charge, arms thrust forward) | reach max f9 = IMPACT (peak speed f8, 1.28 m/frame) | symmetric, lateral 0 % | **0.98 fingertip, lowest vertex 0.82: nothing near the ground** | pulled back f6 (+-1.26, 0.16, z -0.35) -> f9 (+-1.09, 0.98, z 2.03): 2.4 m forward, 0.8 m up; held f9-f11, retracts by f20 | no ground contact; front of the ram (+-1.09, 2.03) at 0.98 m |
| `slam` (Tremor de Raízes, `dru_ent_roots`) | 23 | 8 | **both arms, double overhead smash** | **f8 = IMPACT**, exactly on the ground (peak speed f7, 2.2 m/frame) | symmetric, arms **open outward**: x +-0.60 (f5) -> +-0.94 (f8), lateral 10 % | **0.01 at f8-f9** (clean contact, no clipping) | 2.45 (f5, z -0.99 behind the canopy) -> 2.00 (f7, z 1.04) -> 0.01 (f8, z 1.31); stays down f8-f9, lifts to 0.18 by f12 while sliding back z 1.31 -> 1.17 (0.14 m) | (+-0.94, 1.31) f8 |

Root feet (ground clipping, same family as the old wolf): front roots sink to **-0.15/-0.17 in `attack`** (f5-f7), **-0.40 in `maul`**
(-X root, f7-f8), **-0.16/-0.19 in `pounce`** (f9-f12) and **-0.47 in `slam`** (both, f8; trunk bottom down to 0.11). x1.2 in game:
up to 0.56 m. Not a rake problem by itself (the roots are not the weapon) but a slam mark next to feet buried half a metre will show it.

What this implies:
- **None of the bear K rows transfers to the ent.** The bear's contacts are paw points at z 0.26-0.66, x +-0.16-0.31; the ent's
  are fingertips at z 1.14-2.03, x +-0.74-1.09 (x1.2: 1.4-2.4 m in front, 0.9-1.3 m to each side). "Ent as bear, scaled by
  FORM_SCALE" (D2 option b as written) would put the rakes under the trunk, about 1 m behind and 0.6 m inside the hands.
- Only **`slam`** is a real floor strike (two fists on the ground at IMPACT, well in front of the body): a K stomp pair at
  (+-0.94, 1.31) x1.2 fits the grammar. It is also the clip of `dru_ent_roots` (radius 6 m; area already shown by the skill FX)
  and loops in `ACTIVE_LOOP`.
- **`maul`** is a tall vertical chop that stops 0.14 m above the floor with a 0.18 m drag back: it reads as a weapon swing, not
  a claw rake. Options for the wave agent/user: one K streak under the +X hand at (0.74, 1.14), or a standing S crescent
  (section 3 forbids S on forms because wolf/bear are 0.7-0.9 m quadrupeds; the ent is 2.8 m and upright, so that reason does
  not hold here). The -X hook lands the same frame, 0.10 m under the ground: no second, later mark as in the bear `maul`.
- **`pounce`** has no ground contact at all (ram at 0.98 m): a skid pair under the hands would be invented, not measured. If a
  mark is wanted it would have to come from the root feet at the end of the dash, which are under the ground today.
- **`attack`**: the visual strike is at **f4, one frame before IMPACT** (`peak_off` -1 if anything is spawned from the hand
  path), and the hands never reach the floor in front. The clip is the shared golem/ent `combat_actions` attack: changing it
  changes other monsters.
- Arc colour: the ent has no approved band (bear #D1CCC4 is a fur tone; ent materials are bark brown / moss green / sap glow).
- Ent needs its own `FORM_ARC` rows and its own decisions; alpha needs a GLB rebuild first. Both go beyond what section 6 lists
  for wolf + bear (which says "no kit, GLB or Blender change"), so the user confirms the extra scope with these numbers in hand.

## Formas ancestrais (depois do rebuild, medido)

2026-11-15 (blender-modeler), user-approved rebuild of the two GLBs. Same reader and conventions as the section above (24 fps,
frames 1-based, x = +X of the model, y up, z forward, metres **before** `FORM_SCALE`: alpha 1.4, ent 1.2).
Raw per-frame numbers: `production/qa/attack-arcs-wave6-ancestral-after.json`.
**The rebuilt files exist only in the art worktree** `.claude/worktrees/shields-mount` (`wt/shields-mount`), not in master or
post-int (a copy of both files and of the script is also in `.claude/worktrees/attack-arcs`): `assets/models/form_alpha.glb` md5 `e2df2a85...` (was `e5b97c66...`), `form_ent.glb` md5 `5d76a2b9...` after round 6 (`4785054d...` after round 5, was `b0040693...`).
Source: `tools/blender/druid_ancestral.py` (`build` calls `ds.clear_form_ground` for alpha and the new `clear_ent_ground` for the ent).
Durations, IMPACT frames, node and mesh counts are unchanged; clips other than `attack maul pounce slam` are key-identical.
Evidence (low camera strips before/after, measurements, anim_probe rows): worktree `production/qa/evidence/art-branch-verify/ancestral/`.

### D. Lobo Alfa after the ground pass

Changed channels: leg rotations in the four strike clips and the body height in `maul pounce slam` (the wolf pass: body lifts,
legs open). Head untouched. The alpha-only claw meshes (`alpha_leg_*`) take part in the pass, so the keys are **not** identical to
the rebuilt `form_wolf` (without them the keys came out wolf-identical but the claws sat 24-30 mm under the ground).

Lowest point over the whole clip (y; idle: paw -0.012, claws 0.019, snout 0.591):

| Clip | Front paws before -> after | Claws before -> after | Snout before -> after | Hind paws before -> after |
|---|---|---|---|---|
| `attack` | -0.040 -> -0.012 | 0.003 -> 0.019 | 0.291 -> 0.291 (same) | -0.062 -> -0.016 |
| `maul` | -0.221 -> -0.012 | -0.231 -> 0.000 | **-0.023 -> 0.250** | -0.086 -> -0.015 |
| `pounce` | -0.190 -> -0.012 | -0.202 -> 0.000 | 0.076 -> 0.152 | -0.066 -> -0.013 |
| `slam` | -0.260 -> -0.012 | -0.279 -> 0.002 | **-0.066 -> 0.153** | -0.028 -> -0.012 |

Nothing goes under the ground any more (paws never below their idle height except 3-4 mm solver tolerance on the hind paws; claws
never below y 0, up to 19 mm under their own idle height while the paw is planted).

Contact points for the arcs (paw point = front-most vertex of the paw, as in section 2):

| Alpha clip | IMPACT | Contact frame | Height at IMPACT (y) | Land (x, z) | Path / drag |
|---|---|---|---|---|---|
| `attack` | 5 | snout lowest f5 (peak speed f4) | snout 0.31 (0.29 lowest vertex); paws on the ground, -0.011 | snout ground point (0.00, 1.20), unchanged; paws slide forward z 0.52 -> 0.85 (was 0.81) | snout 0.96 (f3) -> 0.31 (f5); holds 0.36-0.42 to f9 |
| `maul` | 7 | +X paw down f7 (peak speed **f5**, was f6); -X paw also down f7, shifts f10-11 | +X paw 0.07 (lowest vertex 0.067), claws 0.044; -X paw 0.05; **snout 0.25** (was -0.02) | +X (0.09, 0.23) f7 -> (0.10, 0.28) f8 -> (0.15, 0.28) f9; -X (-0.26, 0.52) f7 -> (-0.14, 0.30) f10 -> (-0.09, 0.24) f11 | +X paw 0.77 (f5, z 0.58) -> 0.27 (f6) -> 0.07 (f7, z 0.23): back 0.35; touches the ground at f9 (0.017), lifts from f11 |
| `pounce` | 9 | both paws f9 (peak speed **f7**, was f9: the legs now swing forward early and land flat) | paws 0.014, claws 0.008; snout 0.15 (was 0.08) | (+-0.19, **0.63**) f9 (was z 0.78; rebuilt wolf 0.65) | 1.22 (f7, z 0.90) -> 0.70 (f8, z 1.05) -> 0.01 (f9, z 0.63); skids back on the ground z 0.63 -> 0.55 (f11) -> 0.37 (f13) |
| `slam` | 8 | both paws f8 (peak speed f7) | paws 0.021, claws 0.005; **snout 0.15** (was -0.05); belly 0.22 | (+-0.15, **0.28**) f8 (was z 0.37; rebuilt wolf 0.32), held z 0.25-0.30 to f13 | 1.13 (f5, z 0.36) -> 0.97 (f6) -> 0.23 (f7, z 0.57) -> 0.02 (f8, z 0.28) |

- The wolf K table is expected to transfer with positions x1.4: land points are within 0.02-0.04 m of the rebuilt wolf in z
  (pounce 0.63 vs 0.65, slam 0.28 vs 0.32). A floor mark at `k_y` 0.05 now sits at paw height.
- In `maul` and `slam` the hind paws are in the air at IMPACT (0.23 / 0.21) because the body lifts instead of sinking, as in the wolf.
- Caveat (lead-in): the front legs are already pitched at frame 1 of `maul`/`pounce`/`slam` by **36-42 / 34 / 38 deg** (rebuilt
  wolf: 16-24 / 12 / 18), from the 40 deg/frame ramp of the pass. `attack` starts and all four clips end at the idle pose (0 deg).
  Visible as the front paws starting 0.16 m further back than in idle when the clip starts (paw point z 0.52 -> 0.33-0.37). Front-leg turn per 60 Hz step: 33-34 deg
  (wolf 26-32), under the 45 deg limit of post-int's `_check_form_leg_twist` (which today only loads wolf and bear).
- A separate margin for the claws (keep them at their 19 mm idle height) was tried and rejected: `pounce` then ended with the front
  legs 48 deg off the idle pose.

### E. Ent after the ground pass

Round 5 changed only the four `leg_*` rotation channels, in the four strike clips (round 6, below, adds the -X arm in `maul` and
`attack`). Trunk, canopy and the +X arm are identical to the measurement in section C: **maximum position change = 0.000 m**; the
-X arm is identical in `pounce` and `slam`. So every arm
contact in the table of section C still holds as written (slam (+-0.94, 1.31) y 0.01 at f8; maul +X (0.74, 1.14) y 0.14 at f7;
pounce ram (+-1.09, 2.03) y 0.98 at f9; attack front of the arc at f4).

Root feet, lowest point over the clip (y; idle -0.029):

| Clip | Front roots before -> after | Back roots before -> after | Front root tip at IMPACT (x, z), after |
|---|---|---|---|
| `attack` | -0.155 / -0.186 -> -0.029 | -0.160 -> -0.029 | (+-0.59, 0.80) on the ground (rest z 0.50) |
| `maul` | -0.059 / **-0.403** -> -0.032 / -0.029 | **-0.272** / -0.034 -> -0.033 / -0.032 | +X (0.67, 0.63); -X (-0.52, 0.86) |
| `pounce` | -0.166 / -0.188 -> -0.032 | -0.211 -> -0.029 | (+-0.59, 1.07), stays to f11, back to z 0.50 by f20 |
| `slam` | **-0.473** -> -0.030 | -0.147 -> -0.032 | toes at (+-0.49, 0.90) y 0.07 at f8, root pitched 75 deg forward; its lowest vertex is then the hip end, (+-0.19, 0.31) y 0.006 at f8-f9; toes back on the ground from f10 (z 0.83) |

- Roots never go below their idle height (-0.029) by more than 4 mm (solver tolerance). First and last frame of every clip are the
  idle pose (0 deg). Largest root turn: 43 deg per 24 fps frame in `slam` (about 17 deg per 60 Hz step).
- `pounce` (Marcha do Ent): the front roots now really are on the ground at the end of the charge, at (+-0.59, 1.07) from f9 to
  f11. If a mark is wanted there it is now measured, not invented (x1.2: +-0.71, 1.28).
- **Round 6 (same day): the -X arm no longer goes under the ground.** `clear_ent_ground` now also runs `arm_l` (only that bone,
  only `maul` and `attack`, X-axis pitch, smallest turn that clears). `form_ent.glb` md5 is now `5d76a2b9...` (the `4785054d...`
  above was the round-5 file). +X arm, trunk, head and roots: 0.000 m change in all four clips; `pounce` and `slam` are
  key-identical to round 5, so every +X and slam/pounce contact of section C still holds.
  - `maul` -X low hook, lowest y: -0.103 / -0.116 / -0.111 / -0.092 (f7-f10) -> **0.024 / 0.008 / 0.010 / 0.002**. **New contact
    point: (-1.08, 1.19) y 0.02 at f7 = IMPACT** (was (-1.08, 0.96) y -0.10; the arm pitches forward to clear, so the hook lands
    0.23 m further forward, x unchanged). It then drags back along the ground: (-1.06, 1.17) f8, (-1.05, 1.13) f9, (-1.05, 1.03)
    f10, (-1.06, 0.91) f11, (-1.07, 0.75) f12 (0.44 m at y 0.00-0.01), lifts from f13; f1-f6 and f13-f20 unchanged. Peak speed still f7.
  - `attack` -X arm, lowest y: -0.061 / -0.059 / -0.025 (f7-f9) -> 0.011 / 0.006 / 0.004 (lowest of the clip 0.000 at f6). The
    ramp also moves f4-f5 slightly: front of the arc at f4 is now (-1.05, 0.97) y 0.44 (was z 1.02, y 0.50); +X arm unchanged.
  - anim_probe: attack/maul seam, peak (arm_r 32 / 27), hand frame and hand peak unchanged; travel 842 -> 859 and 817 -> 841.
- `attack` is still the shared `combat_actions` clip with the visual strike at f4 (IMPACT 5); only the ent's own copy of the leg
  channels was corrected, other monsters are untouched.
