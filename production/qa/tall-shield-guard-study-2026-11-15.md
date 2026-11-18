# Tall shields: lower guard pose vs spike trim (study)

Date: 2026-11-15 · Study only: no asset, tool or game file changed, no commits · Owner: blender-modeler
Follows `production/qa/shields-mount-2026-11-15.md` (worktree `wt/shields-mount`), open item 2: the 10 "far" and 7 "mid"
shields. Measured on scratch kits built from that worktree's `tools/blender` (paladin and bishop, both sexes), with the
same search rule and weights as `shield_mount_study.search`.

## 1. Outcome

- **The premise was only partly right.** The guard is what keeps the plate away on 5 of the 17 shields (`pal_t20`,
  `pal_t30`, `relicario`, `suspiros`, `cruel`). On 10 it is the **run** clip, and on `veredito` it is idle. `coluna` is
  not bound by any single clip.
- **In the run, the contact is the head, not the legs.** The shield arm swings 46 degrees each way; on the forward
  swing the elbow-side top corner of the plate goes into the plate helmet.
- **In the guard, the contact is set helmets (crests, horns), not the chin.** With the plate touching the arm, the
  common body is clear in guard on 15 of 17 (`suspiros` and `cruel` touch the bare head with a centre spike).
- **A, guard variant alone: 4 close, 4 mid, 9 far.** It fixes the guard-bound ones and nothing else.
- **A+, guard variant plus a run variant with a quieter shield arm: 12 close, 3 mid, 2 far.** No mesh changes.
- **B, trim: 15 close, 1 mid, 1 far**, losing 2-11% of the front silhouette (17% on `asa_negra`). The side to trim is
  the elbow side (`+X`), the opposite of what `shield_kit.INNER` shortens today.
- **Recommendation:** A+ first (two clips, 14 KB per kit, 0 meshes), then a trim only on the 3-5 shields A+ leaves
  mid or far. Details in section 6.

Today (shipped mounts): 0 close, 7 mid, 10 far.

## 2. What was built

| Option | What changes | How it was found |
|---|---|---|
| A | Clip `block_shield_tall`: `upper_arm.L` (-45, 22.5, -37.5) instead of (-60, 22.5, -37.5), forearm roll -30 instead of -15. Arm 15 degrees lower, plate leans 16 degrees off vertical, face turns 27 degrees outward (was 17) and 12 degrees down. | 273 upright, forward-facing arm poses scored on all 17 shields at a close mount against the common body and the 18 paladin set helmets. Base pose: 16 body and 4250 helmet contacts. Chosen pose: 0 and 36. |
| A+ | A, plus clip `run_shield_tall`: shield arm swing 15 degrees instead of 46, carried 24 degrees further forward. | 432 run arm poses, same scoring over 4 phases. Base: 774 body and 12874 helmet contacts. Chosen: 0 and 0. |
| B | Plate trimmed in model space, shipped clips. `canto` pulls the elbow-side top corner towards the elbow; `topo` lowers everything above the arm line. Factors 0.70, 0.40, 0.15 (share kept). | 6 trims per shield, mount searched for each; the lightest one that reaches close is shown, or the closest if none does. |

For every option the mount (gap, drop, along) was searched again with the unchanged rule: no contact with the common
male body on 15 frames, female body preferred, set helmets and set chest weighted.

Six poses reached 0 helmet contacts but move the arm two to four times as far; the one used (36) is the smallest change from the current pose. Head or torso
changes were not needed.

## 3. Results

"Air" = forearm skin to the back of the plate, metres. close = up to 0.06, mid = up to 0.12, far = more.
"Floor by clip alone" = the air the search reaches when only that clip is checked; the highest one is what binds.
"Control" = the same search on the shipped clips and shipped plate, run today.

| Shield | Was | Height | Floor by clip alone (guard / run / idle) | Binds | Now | Control | A | A+ | B | B trim | B area lost | B height |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `presa` | far | 1.20 | 0.01 / 0.11 / 0.03 | run | 0.133 | 0.162 | 0.162 far | 0.052 close | 0.052 close | topo 0.40 | 6% | 1.04 |
| `perdao` | far | 1.43 | 0.01 / 0.13 / 0.01 | run | 0.132 | 0.132 | 0.132 far | 0.033 close | 0.032 close | canto 0.40 | 2% | 1.42 |
| `serpente` | far | 1.33 | 0.01 / 0.13 / 0.05 | run | 0.132 | 0.132 | 0.132 far | 0.052 close | 0.052 close | canto 0.40 | 8% | 1.32 |
| `pal_t20` | far | 1.13 | 0.13 / 0.01 / 0.01 | guard | 0.132 | 0.132 | 0.013 close | 0.012 close | 0.051 close | topo 0.70 | 2% | 1.06 |
| `bis_s30` | far | 1.11 | 0.01 / 0.11 / 0.05 | run | 0.131 | 0.131 | 0.131 far | 0.052 close | 0.012 close | canto 0.40 | 7% | 1.11 |
| `pal_t30` | far | 1.19 | 0.16 / 0.01 / 0.01 | guard | 0.161 | 0.161 | 0.012 close | 0.012 close | 0.052 close | topo 0.70 | 4% | 1.12 |
| `relicario` | far | 1.42 | 0.19 / 0.03 / 0.01 | guard | 0.192 | 0.192 | 0.033 close | 0.033 close | 0.012 close | topo 0.40 | 7% | 1.27 |
| `veredito` | far | 1.34 | 0.05 / 0.16 / 0.19 | idle | 0.192 | 0.192 | 0.192 far | 0.192 far | 0.052 close | canto 0.40 | 9% | 1.34 |
| `asa_negra` | far | 1.50 | 0.01 / 0.19 / 0.13 | run | 0.192 | 0.192 | 0.192 far | 0.132 far | 0.032 close | canto 0.15 | 17% | 1.50 |
| `suspiros` | far | 1.63 | 0.19 / 0.16 / 0.07 | guard | 0.192 | 0.192 | 0.161 far | 0.072 mid | 0.132 far | topo 0.40 | 7% | 1.43 |
| `asa` | mid | 1.08 | 0.01 / 0.13 / 0.03 | run | 0.073 | 0.132 | 0.132 far | 0.092 mid | 0.012 close | canto 0.40 | 11% | 1.00 |
| `escama` | mid | 1.32 | 0.01 / 0.11 / 0.05 | run | 0.091 | 0.091 | 0.091 mid | 0.052 close | 0.052 close | canto 0.70 | 2% | 1.32 |
| `coluna` | mid | 1.37 | 0.01 / 0.03 / 0.03 | none | 0.072 | 0.072 | 0.052 close | 0.052 close | 0.051 close | canto 0.70 | 3% | 1.36 |
| `cruel` | mid | 1.50 | 0.19 / 0.09 / 0.01 | guard | 0.072 | 0.192 | 0.093 mid | 0.053 close | 0.093 mid | topo 0.70 | 2% | 1.41 |
| `pal_g25` | mid | 1.10 | 0.01 / 0.09 / 0.07 | run/idle | 0.092 | 0.092 | 0.092 mid | 0.072 mid | 0.032 close | canto 0.70 | 3% | 1.10 |
| `pal_g30` | mid | 1.12 | 0.05 / 0.11 / 0.05 | run | 0.113 | 0.162 | 0.131 far | 0.052 close | 0.051 close | canto 0.40 | 4% | 1.12 |
| `bis_b15` | mid | 0.95 | 0.01 / 0.11 / 0.03 | run | 0.113 | 0.113 | 0.113 mid | 0.032 close | 0.052 close | canto 0.70 | 2% | 0.95 |

Counts (close / mid / far): antes 0 / 7 / 10; controle 0 / 4 / 13; A 4 / 4 / 9; A+ 12 / 3 / 2; B 15 / 1 / 1

| Shield | Body contacts m+f (now / A / A+ / B) | Set helmets, worst clip (now / A / A+ / B) | Set chest and skirt, worst clip (now / A / A+ / B) | Lowest point in guard, m (now / A / B) | Lowest point in run, m (now / A+) |
|---|---|---|---|---|---|
| `presa` | 0 / 0 / 0 / 0 | 48 / 48 / 144 / 0 | 0 / 0 / 16 / 56 | -0.20 / -0.20 / -0.20 | -0.22 / -0.20 |
| `perdao` | 0 / 0 / 0 / 0 | 0 / 0 / 0 / 24 | 132 / 132 / 210 / 840 | -0.51 / -0.54 / -0.51 | -0.49 / -0.51 |
| `serpente` | 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 | 54 / 54 / 196 / 422 | -0.47 / -0.55 / -0.47 | -0.51 / -0.50 |
| `pal_t20` | 0 / 0 / 0 / 0 | 30 / 72 / 48 / 24 | 0 / 33 / 0 / 0 | -0.18 / -0.22 / -0.18 | -0.18 / -0.14 |
| `bis_s30` | 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 | 0 / 0 / 290 / 478 | -0.14 / -0.19 / -0.14 | -0.14 / -0.21 |
| `pal_t30` | 0 / 0 / 0 / 0 | 20 / 0 / 0 / 112 | 0 / 33 / 33 / 0 | -0.23 / -0.25 / -0.23 | -0.23 / -0.22 |
| `relicario` | 0 / 0 / 0 / 0 | 110 / 0 / 0 / 16 | 0 / 774 / 162 / 1503 | -0.45 / -0.45 / -0.45 | -0.43 / -0.44 |
| `veredito` | 0 / 0 / 0 / 0 | 12 / 0 / 0 / 160 | 0 / 0 / 0 / 106 | -0.36 / -0.48 / -0.36 | -0.42 / -0.43 |
| `asa_negra` | 13 / 13 / 0 / 0 | 138 / 138 / 0 / 168 | 84 / 84 / 66 / 934 | -0.61 / -0.65 / -0.61 | -0.61 / -0.62 |
| `suspiros` | 0 / 0 / 0 / 0 | 214 / 36 / 96 / 20 | 48 / 78 / 48 / 114 | -0.58 / -0.64 / -0.58 | -0.59 / -0.58 |
| `asa` | 0 / 0 / 0 / 0 | 10 / 42 / 24 / 0 | 225 / 138 / 30 / 531 | -0.23 / -0.17 / -0.11 | -0.23 / -0.15 |
| `escama` | 0 / 0 / 0 / 0 | 0 / 0 / 0 / 72 | 0 / 0 / 194 / 62 | -0.43 / -0.50 / -0.35 | -0.47 / -0.46 |
| `coluna` | 0 / 0 / 0 / 0 | 264 / 36 / 0 / 228 | 134 / 163 / 36 / 468 | -0.44 / -0.46 / -0.44 | -0.46 / -0.41 |
| `cruel` | 0 / 0 / 0 / 0 | 290 / 72 / 96 / 140 | 188 / 102 / 94 / 102 | -0.49 / -0.49 / -0.45 | -0.51 / -0.41 |
| `pal_g25` | 0 / 0 / 0 / 0 | 56 / 56 / 0 / 0 | 0 / 0 / 0 / 0 | -0.24 / -0.28 / -0.24 | -0.24 / -0.23 |
| `pal_g30` | 0 / 0 / 0 / 0 | 88 / 0 / 0 / 144 | 0 / 0 / 0 / 0 | -0.22 / -0.19 / -0.22 | -0.22 / -0.21 |
| `bis_b15` | 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 | 72 / 72 / 826 / 156 | -0.15 / -0.21 / -0.15 | -0.16 / -0.14 |

| Shield | Trim ladder: air (area lost) for canto 0.70 / 0.40 / 0.15 and topo 0.70 / 0.40 / 0.15 |
|---|---|
| `presa` | 0.112 (3%) ; 0.112 (6%) ; 0.112 (8%) ; 0.072 (3%) ; 0.052 (6%) ; 0.032 (8%) |
| `perdao` | 0.072 (1%) ; 0.032 (2%) ; 0.032 (3%) ; 0.131 (3%) ; 0.133 (6%) ; 0.133 (8%) |
| `serpente` | 0.073 (4%) ; 0.052 (8%) ; 0.033 (11%) ; 0.162 (4%) ; 0.132 (7%) ; 0.132 (10%) |
| `pal_t20` | 0.132 (2%) ; 0.132 (4%) ; 0.132 (5%) ; 0.051 (2%) ; 0.012 (5%) ; 0.012 (7%) |
| `bis_s30` | 0.072 (4%) ; 0.012 (7%) ; 0.013 (9%) ; 0.112 (5%) ; 0.072 (10%) ; 0.092 (14%) |
| `pal_t30` | 0.161 (4%) ; 0.161 (7%) ; 0.161 (10%) ; 0.052 (4%) ; 0.011 (8%) ; 0.012 (11%) |
| `relicario` | 0.192 (2%) ; 0.192 (3%) ; 0.192 (4%) ; 0.092 (4%) ; 0.012 (7%) ; 0.012 (9%) |
| `veredito` | 0.112 (5%) ; 0.052 (9%) ; 0.052 (11%) ; 0.191 (4%) ; 0.162 (8%) ; 0.132 (11%) |
| `asa_negra` | 0.191 (7%) ; 0.112 (13%) ; 0.032 (17%) ; 0.192 (3%) ; 0.192 (5%) ; 0.162 (7%) |
| `suspiros` | 0.192 (5%) ; 0.192 (10%) ; 0.192 (14%) ; 0.162 (3%) ; 0.132 (7%) ; 0.132 (10%) |
| `asa` | 0.092 (6%) ; 0.012 (11%) ; 0.012 (14%) ; 0.132 (2%) ; 0.132 (4%) ; 0.132 (6%) |
| `escama` | 0.052 (2%) ; 0.012 (4%) ; 0.012 (6%) ; 0.112 (2%) ; 0.092 (3%) ; 0.072 (5%) |
| `coluna` | 0.051 (3%) ; 0.051 (6%) ; 0.032 (8%) ; 0.031 (4%) ; 0.031 (7%) ; 0.032 (10%) |
| `cruel` | 0.192 (1%) ; 0.192 (3%) ; 0.192 (4%) ; 0.093 (2%) ; 0.093 (4%) ; 0.112 (6%) |
| `pal_g25` | 0.032 (3%) ; 0.012 (5%) ; 0.012 (7%) ; 0.072 (1%) ; 0.091 (2%) ; 0.032 (3%) |
| `pal_g30` | 0.091 (2%) ; 0.051 (4%) ; 0.051 (6%) ; 0.132 (2%) ; 0.112 (4%) ; 0.071 (6%) |
| `bis_b15` | 0.052 (2%) ; 0.012 (3%) ; 0.012 (4%) ; 0.112 (1%) ; 0.112 (3%) ; 0.092 (4%) |

Reading the tables:

- **Control differs from shipped on 4 shields** (`presa`, `asa`, `cruel`, `pal_g30`): today's search lands 0.03-0.12 m
  further out than the mount that shipped (the shipped table was a merge of two search rounds). On those four, compare
  A, A+ and B with Control, not with Now; `asa` under A+ (0.092) is still worse than what ships (0.073).
- **Body contacts** are 0 for every option on both sexes. `asa_negra` on the female body in run (13 today) goes to 0
  with A+ and with B.
- **Set helmets** drop or stay level under A and A+ on most shields; they rise on `presa` under A+ (48 to 144) and on
  `pal_t20` under A (30 to 72).
- **Set chest and skirt overlaps rise with every closer mount**, most under B (`relicario` 1503, `asa_negra` 934,
  `perdao` 840) and on `bis_b15`, `bis_s30` under A+. As in the mount study, these sit behind the plate.
- **A on the guard-bound five**: `pal_t20`, `pal_t30`, `relicario` reach close; `cruel` reaches mid (close with A+);
  `suspiros` stays far at 0.161 because the run binds it too (A+ gets 0.072).
- **A+ leaves** `veredito` (idle-bound, unchanged at 0.192), `asa_negra` (0.132), and mid on `suspiros`, `asa`, `pal_g25`.
- **B leaves** `suspiros` far (0.132) and `cruel` mid; both are guard-bound by a centre spike that neither trim removes
  at these factors.
- **Ground**: these shields already end 0.14-0.61 m below the ground plane in guard and run with the shipped mounts
  (a 1.1-1.6 m plate hung 0.26-0.34 m below a forearm at 0.63 m). The guard variant adds up to 0.12 m (`veredito`),
  typically 0.02-0.08. Not caused by this study; listed because a lower guard was expected to make it worse, and does,
  slightly.

## 4. Cost

| | A | A+ | B |
|---|---|---|---|
| Meshes per kit | 0 | 0 | 0 |
| Kit size (`kit_paladin_male.glb`, 9 621 396 bytes) | about +7 KB | +14 356 bytes for both clips (0.15%) | unchanged |
| Look change | Guard only: plate leans 16 degrees, arm lower | Guard as A; in the run the shield is carried steady instead of pumping | Permanent: silhouette 2-11% smaller (`asa_negra` 17%); `topo` lowers height 0.07-0.20 m and squashes round crowns (`relicario` ring becomes an ellipse) |
| Mounts to regenerate | the shields that move (5) | the shields that move (about 14) | 15 shields |
| Icons to redo | none (rotation unchanged) | none | 15 (plate shape changes) |
| Game code | clip choice | clip choice in two places | none |

The A clip alone was not exported separately; 7 KB is half of the measured pair.

## 5. How the game would choose the pose (read only)

- `EntityView` picks the guard at `game/entities/entity_view.gd:1832`:
  `base = "block_shield" if entity.stats.has_shield and _clip("block_shield") != "" else "block"`, and the run two
  lines above (`SimEntity.State.MOVING: base = "run"`). Both would ask the kit for the variant.
- `KitModel` already knows the off-hand item when it shows the shield (`off_node_of`, `kit_model.gd:518`, from
  `ItemDef.shield_style`). It can keep a flag such as `tall_shield` set there, from a constant list of styles or a
  new `ItemDef` field filled in `GearCatalog`; `EntityView` then asks `kit.guard_clip()` / `kit.run_clip()`.
- Simpler alternative: no per-shield choice. Play the variants for **every** shield (`has_shield`), replacing
  `block_shield` and adding one `run_shield`. This needs the 26 close shields re-checked against the new clips
  (not measured here) and changes the guard look of all shields.
- Places that name the clips and would need the new names: `KitModel.LOOPS`, `RidePose.ensure_guard_clip` (builds
  `block_ride` from `block_shield`), the run speed scale at `entity_view.gd:1854` (`base == "run"`), the mounted
  strike at `:1728`, `tools/tests/run_tests.gd:186` and `:1706`, `tools/tests/anim_probe.gd:64`,
  `tools/lineup/lineup.gd` (`--block_film`), and `shield_mount.py --check` (must check each shield on the clips it
  will play).
- The guard variant is a constant arm offset, so it could be made at load like `RidePose.GUARD_DELTA` with no kit
  bytes. The run variant changes the swing amplitude and needs a real clip.
- The mount is baked into the shield mesh per style, so a shield mounted for the variants must always play them.

## 6. Recommendation and effort

1. **A+ for the tall shields** (Blender: 2 pose functions and the two `_cycle` calls in `chibi_kit.animate_v3`, the
   study search taught which clips each style plays, mounts regenerated, paladin and bishop kits rebuilt; Godot: clip
   choice, the list above, one check). About 1 day including `--check`, suite, smoke and lineup strips.
   Gets 12 close, 3 mid, 2 far with no change to any shield's shape.
2. **Then a light trim on what is left**: `veredito` and `asa_negra` (far), optionally `suspiros`, `asa`, `pal_g25`
   (mid). As a per-style value next to `shield_kit.INNER` for the elbow side. About half a day with icons. Trim on
   top of A+ was not measured; the B column is trim alone.
3. **B alone is the stronger result on paper (15 close) but is not recommended first**: it changes 15 shield shapes
   and icons for good, and the art decision is per shield.
4. **A alone is not worth shipping**: 4 shields.

Decisions for the user: per-shield choice or variants for all shields; whether a steadier shield arm in the run is
acceptable for the look; which of the leftover shields may be trimmed.

## 7. Limits of this study

- Rendered in Blender with flat materials, not the game's toon shader; "game camera" cells are orthographic at 52/45
  degrees. No Godot run was made.
- The guard variant was picked on the male paladin kit against paladin set helmets; the final numbers include both
  kits and both sexes. Whether the shield arm sinks into the torso in the variant was not measured (the contact rule
  ignores the left arm); the sheets show no obvious case.
- The trims are generic deformations, not art: a real trim would be per family in `shield_kit.py`.
- The run variant was not checked for the shield covering the face from the game camera, nor against `block_ride`.
- The 26 close shields were not measured on the new clips.

## 8. Evidence

`production/qa/evidence/tall-shield-guard/`:

- `guarda_01.png` .. `guarda_03.png`: per shield, guard front / side / game camera, each as ANTES, A, A+, B (air printed
  in each cell). Order: the 10 far, then the 7 mid.
- `corrida_idle_01.png` .. `corrida_idle_03.png`: run side / run game camera (frame 5, arm forward) / idle game camera.
- `study.json` (all numbers), `binding_by_clip.json`, `pose_search_guard.json`, `pose_search_run.json`.
- `scripts/`: the scratch scripts (`run1.py` binding clip, `run1b.py` what touches what, `run2.py`/`run2g.py` pose
  searches, `run3.py` measurement and sheets). They import the worktree's `tools/blender` and write only to the
  folder given in `--out` / `--evid`.
