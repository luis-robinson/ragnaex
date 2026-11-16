# Attack arcs: swing table (2026-11-14)

Data only. Nothing was modified or exported. Measured headless in Blender 5.2 from `assets/models/kit_<class>_male.glb`
(8 kits) plus `form_wolf.glb` / `form_bear.glb`. Table: `swing_table.json` (all fields, tip path per frame, field
notes in `meta`) and `swing_table.csv` (same rows, no path).

- 392 rows: 368 kit rows (kit x weapon loadout x 16 clips x hand) and 24 form rows (2 forms x 4 clips x paw_r/paw_l/snout).
- 245 rows are clips the game actually plays for that weapon (`role` basic or skill); 147 are `other` (another family's
  clip, only reachable through `SkillDef.clip`), kept for completeness.
- Excluded: `atk_bow`, `atk_rifle`, `atk_pistol`, `atk_shoot_multi`, `atk_throw` (ranged). `atk_staff` is included
  although it is the caster basic.

## How it was measured

- Tip = weapon-piece vertex farthest from its hand bone (weapons are skinned 100% to `hand.R` / `hand.L`, not bone-parented).
  Base pieces `wpn_main_<type>` / `wpn_off_<type>`. Forms: front-most vertex of each front paw and of the snout.
- Frames: `IMPACT_FRAME` (1-based) from `entity_view.gd`. Path = IMPACT-4..IMPACT+2. Coordinates are Godot model space
  (x = character's left, y = up, z = forward).
- `sweep` = the pilot convention: sign of the tip's x travel from IMPACT-2 to IMPACT+1 (+1 = counter-clockwise from above).
  **Pilot check passes**: paladin sword `atk_1h_a` +1 (+1.90 m), `atk_1h_b` -1 (-1.86 m), `atk_sweep` +1 (+0.93 m).
- `type` comes from the fastest one-frame step of the tip inside IMPACT-2..IMPACT+1 (`strike_vec`): which component
  (lateral / vertical / forward) holds 50% or more; none = diagonal; body turn of 270 deg or more = spin; under 0.15 m/frame = static.
- `sweep_fast` is the sign of that fastest step; `sweep_ambiguous` marks rows where it disagrees with `sweep`.

## Kits do not differ from each other

The clips are the same in every kit: the same weapon family gives identical numbers in every kit that has it (284
clip x family x hand groups compared; the only groups that differ are wolf vs bear). **No kit has a sign different
from the paladin's for the same clip and the same weapon.** Every sign difference comes from the weapon family or
from the hand, so `CLIP_SWEEP` has to be keyed by clip + family (+ hand), not by clip alone.

## Type and sweep per clip x weapon (clips the game plays)

Cell = type (H horizontal, O overhead, T thrust, D diagonal, S spin, - static), sweep sign (+ / - / 0), tip going
down `v` or up `^`, `?` = sweep ambiguous. `imp` = IMPACT_FRAME.

| clip | imp | sword | mace | sword2h | mace2h | axe | axe off | axe2h | claw | claw off | scepter | mace off | staff | spear | dagger | dagger off | sword off | scythe | form paw_r | form paw_l | form snout |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| atk_1h_a | 7 | H+v | H+v |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| atk_1h_b | 7 | H-v | H-v |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| atk_thrust | 6 | D+ | H+v | D+v | D+v | H+v | O0? | D+ | H+v | T+v | T-v? | T-? | T0v? | D+v | H+v | D+v | T-? | T+ |  |  |  |
| atk_sweep | 8 | D+ | D+ | H+ | H+ | D+ | -0 | H+ | T0v? | D+v | T+v | H- | D+v | H+ | D+ | D+v | H-^ | H+v |  |  |  |
| atk_spin | 8 | S- | S- | S- | S- | S- | S- | S- | S- | S- | S- | S- | S- | S- | S- | S- | S- | S- |  |  |  |
| atk_finisher | 10 | O+v? | O+v? | O+v? | O+v? | O+v? | D-v | O+v? | H+ | O-v | O+v | T-v | O+v | O+v | O+v? | D-v | T-v | O+v? |  |  |  |
| atk_flurry | 5 | O+v | O+v | O+v | O+v | O+v | H0? | O+v | O+^? | H+v | O+v | -0 | O+v | O+v | O+v | H+v | -0 | O+v |  |  |  |
| atk_claw | 6 | H+v | O+v | H+v | H+v | H+v | H-v | O+v | H+^ | O-v | O+v? | H-v | O+v? | O+v? | H+v | H-v | H-v | O+v |  |  |  |
| atk_leap | 12 | O+v | O+v | H+v | H+v | O+v | O-v | O+v | O+v | O-v | O+v? | O-v | O+v | O+v | O+v | O-v | O-v | O+v |  |  |  |
| atk_charge | 5 | -0 | -0 | -0 | -0 | -0 | -0 | -0 | -0 | -0 | -0 | -0 | -0 | -0 | -0 | -0 | -0 | -0 |  |  |  |
| atk_2h | 10 |  |  | O+v | O+v |  |  |  |  |  |  |  |  |  |  |  |  | O+v |  |  |  |
| atk_dual_a | 5 | H0^? | H+ |  |  | H+ | D-^ |  | H+v | O+v |  | D-^ |  |  | D+v | -0 | H-^ |  |  |  |  |
| atk_dual_b | 5 | T+? | T+v? |  |  | D+v? | T0^? |  | D-v | D-v |  | T0^? |  |  | O-v | H- | T+^? |  |  |  |  |
| atk_staff | 7 |  |  |  |  |  |  |  |  |  | D0v? |  | D-v? |  |  |  |  | D-v? |  |  |  |
| atk_slash_shot | 9 | -0 |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| maul | 7 |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  | O0v | O0v | O0v? |
| pounce | 9 |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  | O0v | O0v | O0v |
| slam | 8 |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  | O0v | O0v | O0v |
| attack | 5 |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  | -0 | -0 | O0v |

## Clips that need a shape other than the flat crescent

**Overhead (vertical plane, crescent standing up, no left/right side):**
- `atk_2h` (basic of sword2h, mace2h, physical scythe): swing plane tilted 82 deg, tip from 2.18 m down to -0.15 m,
  reach 1.60 m, lateral travel only +0.33 m. Fastest at frame 9, one frame before IMPACT 10.
- `atk_finisher`: overhead for every main-hand weapon (tip 1.99 -> -0.18 m with the sword, 2.65 -> -0.78 m with the spear).
- `atk_leap`: both hands come down together (main +, off -, mirrored), tip from 2.2 m to the ground.
- `atk_flurry`: overhead chops, several in the window (shoulder arc over 700 deg in 7 frames).
- `atk_claw`: overhead or steep horizontal depending on weapon length (plane tilt 72-87 deg); off hand mirrored (-).
- Forms `maul`, `pounce`, `slam`: all overhead, sweep 0 in every paw and in the snout (lateral share 0-3%).
  They need a downward rake / ground impact, not a crescent.

**Thrust / lunge:**
- `atk_thrust` (spear basic, kick skills): not a clean line. The fastest step with the spear is 0.86 m left, 0.92 m
  down and 1.03 m forward (diagonal), reach 2.13 m, sweep +1. Sword / 2H weapons also diagonal; axe, dagger and claw
  read as horizontal +; scythe, staff and scepter as forward thrust. A forward streak with a slight right-to-left lean fits all.
- `atk_charge`: static. The weapon is already set 2 frames before IMPACT (tip moves under 0.05 m); the hit is the body lunge.
- `atk_dual_b`: the OFF hand does a forward jab (0.7-1.1 m forward with axe, mace, sword); the main hand barely moves.

**Spin:**
- `atk_spin`: body turns -360 deg, which is CLOCKWISE from above = sweep -1 for every weapon and both hands. Tip height
  is constant (1.60 m sword, 1.96 m sword2h, 2.34 m spear, 1.36 m axe) and the tip stays only 0.3-0.65 m from the axis
  (weapon held up), so the ring radius must come from the skill, not from the tip.

**Horizontal (the pilot crescent fits):**
- `atk_1h_a` / `atk_1h_b` with sword and mace: arc 162 / 133 deg about the body axis, plane tilt 18-20 deg, tip
  descending 0.7-0.8 m, reach 1.1-1.2 m, fastest exactly at IMPACT.
- `atk_sweep` (axe2h basic and cone skills): + for every main hand, but it is a high diagonal sweep (tip 0.8-1.7 m with
  the sword, 1.2-2.2 m with the spear; plane tilt 28-60 deg) that passes over the head with long weapons.

## Sign differs from the paladin sword for the same clip name

`ref` = paladin sword main hand; `got` = this weapon/hand; last column = x travel in the pilot window (m).

| clip | kits | weapon | hand | ref | got | type | dx |
|---|---|---|---|---|---|---|---|
| atk_dual_a | berserker | axe | main | +0 | +1 | horizontal | 0.19 |
| atk_dual_a | berserker | axe | off | +0 | -1 | diagonal | -0.27 |
| atk_dual_b | berserker | axe | off | +1 | +0 | thrust | -0.02 |
| atk_thrust | berserker | axe | off | +1 | +0 | overhead | 0.01 |
| atk_sweep | berserker | axe | off | +1 | +0 | static | -0.07 |
| atk_finisher | berserker | axe | off | +1 | -1 | diagonal | -0.60 |
| atk_flurry | berserker | axe | off | +1 | +0 | horizontal | 0.09 |
| atk_claw | berserker | axe | off | +1 | -1 | horizontal | -0.64 |
| atk_leap | berserker | axe | off | +1 | -1 | overhead | -0.42 |
| atk_dual_a | berserker | claw | main | +0 | +1 | horizontal | 0.61 |
| atk_dual_b | berserker | claw | main | +1 | -1 | diagonal | -0.76 |
| atk_sweep | berserker | claw | main | +1 | +0 | thrust | -0.01 |
| atk_dual_a | berserker | claw | off | +0 | +1 | overhead | 0.42 |
| atk_dual_b | berserker | claw | off | +1 | -1 | diagonal | -0.54 |
| atk_finisher | berserker | claw | off | +1 | -1 | overhead | -0.85 |
| atk_claw | berserker | claw | off | +1 | -1 | overhead | -0.79 |
| atk_leap | berserker | claw | off | +1 | -1 | overhead | -0.24 |
| atk_thrust | bishop | scepter | main | +1 | -1 | thrust | -0.11 |
| atk_dual_a | druid | mace | main | +0 | +1 | horizontal | 0.12 |
| atk_dual_a | druid | mace | off | +0 | -1 | diagonal | -0.38 |
| atk_dual_b | druid | mace | off | +1 | +0 | thrust | 0.07 |
| atk_thrust | druid | mace | off | +1 | -1 | thrust | -0.18 |
| atk_sweep | druid | mace | off | +1 | -1 | horizontal | -0.26 |
| atk_finisher | druid | mace | off | +1 | -1 | thrust | -0.51 |
| atk_flurry | druid | mace | off | +1 | +0 | static | -0.01 |
| atk_claw | druid | mace | off | +1 | -1 | horizontal | -0.58 |
| atk_leap | druid | mace | off | +1 | -1 | overhead | -0.47 |
| atk_thrust | druid/elementalist | staff | main | +1 | +0 | thrust | 0.03 |
| atk_staff | druid/elementalist | staff | main | +0 | -1 | diagonal | -0.11 |
| atk_dual_a | assassin | dagger | main | +0 | +1 | diagonal | 0.35 |
| atk_dual_b | assassin | dagger | main | +1 | -1 | overhead | -0.20 |
| atk_dual_b | assassin | dagger | off | +1 | -1 | horizontal | -0.21 |
| atk_finisher | assassin | dagger | off | +1 | -1 | diagonal | -0.74 |
| atk_claw | assassin | dagger | off | +1 | -1 | horizontal | -0.74 |
| atk_leap | assassin | dagger | off | +1 | -1 | overhead | -0.34 |
| atk_dual_a | assassin | sword | off | +0 | -1 | horizontal | -0.46 |
| atk_thrust | assassin | sword | off | +1 | -1 | thrust | -0.24 |
| atk_sweep | assassin | sword | off | +1 | -1 | horizontal | -0.33 |
| atk_finisher | assassin | sword | off | +1 | -1 | thrust | -0.52 |
| atk_flurry | assassin | sword | off | +1 | +0 | static | -0.06 |
| atk_claw | assassin | sword | off | +1 | -1 | horizontal | -0.60 |
| atk_leap | assassin | sword | off | +1 | -1 | overhead | -0.48 |
| atk_staff | necromancer | scythe | main | +0 | -1 | diagonal | -0.17 |

Reading it:
- Off hands are mirrored (-) in `atk_leap`, `atk_finisher`, `atk_claw`, `atk_sweep`, `atk_thrust`.
- Claws (berserker Punhos): `atk_dual_a` both hands +, `atk_dual_b` both hands - (the sword pair gives 0 / +).
- Daggers (assassin Laminas): `atk_dual_b` main and off both -.
- `atk_staff` with staff / scythe and `atk_thrust` with the scepter flip to -, but the lateral travel is only
  0.11-0.17 m: treat as no side.

## Surprises

1. **Dual-wield clips have almost no lateral travel in the pilot window.** `atk_dual_a/b` peak at frame 3 while IMPACT
   is 5; x travel over IMPACT-2..IMPACT+1 is 0.02-0.46 m for axe / mace / sword / dagger, so the pilot rule gives 0 or
   a sign that flips with the weapon. The fastest step is clearer: `atk_dual_a` main hand slashes left (+0.6 to +0.9 m
   in one frame), `atk_dual_b` is the off-hand forward jab. Use `sweep_fast` / `strike_vec` for the dual family.
2. **`atk_sweep` at IMPACT 8 has the tip almost over the body** (reach at impact 0.29 m sword, 0.21 m axe2h, 0.12 m
   scythe; max reach in the window 1.1-1.4 m). The fast part is frame 7 (frame 4 for axe2h, scythe, staff, scepter).
3. **`atk_slash_shot`: the sword is static at IMPACT 9** (that frame is the pistol shot; the slash peaks at frame 4
   and the tip rests at 0.13 m from the ground). An arc for the slash needs its own frame.
4. **`atk_flurry`, `atk_claw`, `atk_leap` peak far from IMPACT** (frame 12 vs 5, 3 vs 6, 6 vs 12). The tip is still
   moving fast into IMPACT in all three (1.5-1.8 m/frame with the sword), so the direction at IMPACT is valid.
5. **Tips go below the ground** in `atk_finisher`, `atk_leap`, `atk_claw`, `atk_2h`, `atk_flurry` (sword -0.2 m,
   sword2h -0.5 m, spear -0.9 m) and the form paws by 0.15-0.25 m. Clamp arc height at 0.
6. **`atk_spin` is clockwise (-1)** and is not in `CLIP_SWEEP`; the combo-parity fallback would mirror it every other cast.
7. **Sweep ambiguous in `atk_finisher`** (pilot dx +0.3 m but the fastest step is straight down): sign is meaningless there.
8. **Wolf vs bear `attack`**: the bear swipes with the right paw (0.82 m down to the ground); the wolf keeps its paws
   on the ground and only the snout drops (0.96 -> 0.31 m). Both forms share `IMPACT_FRAME` although the bear clips are
   2-5 frames longer; peak frames stay within 1-2 frames of IMPACT.
9. Claw tips extend along the forearm (0.46 m past the hand), so with claws most clips move the tip far less than a
   blade does (`atk_1h_a` with a claw: 0.07 m lateral vs 1.90 m with the sword).

## Limits

- Male kits only, base weapon pieces only (set variants `wpn_main_<type>_<style>` share the bone and grip; length may differ slightly).
- `type` is a classification of one fastest frame with fixed thresholds; `share_*`, `plane_tilt_deg` and `path` are in the table to re-judge.
- `arc_deg` uses two bases (`arc_basis`): yaw about the body for clean horizontal swings and spins, shoulder-subtended
  angle for the rest. The two are not comparable (the shoulder basis reads about 1.5x larger on the same swing).
- Read from the GLBs in Blender, not from the Godot runtime (no blend / retime of `windup_timing`).
