# Axe redesign — diagnosis, construction, old vs new, rollout

Date: 2026-11-15 · Branch `wt/axes` (uncommitted) · Owner: blender-modeler
Trigger (user): "precisamos refatorar os machados, parecem mais porretes, olha os machados de priston".
Scope decided by the user (relayed by the coordinator): **option A, all axes**. Sections 1-6 are the phase 1 record
(prototype, nothing in `assets/models/` touched); **section 7 is the rollout as done** after the user approved the sheets.

Inspiration only (broad flared crescent, thin cheek, bright edge, beard / double bit, back spike, banded haft).
No Priston Tale model was copied or referenced; the family below is ours.

## 1. Diagnosis: why the current axes read as clubs

Game camera: 52° pitch, 24 m, fov 35 → about **71 px per metre** at 1080p. A one-hand axe head is ~21 px, the
outline (inverted hull, 2.5 cm) adds ~2 px per side. Only silhouette and two-tone contrast survive.

| # | Cause | Where | Effect |
|---|---|---|---|
| 1 | Common axe head is a **flattened sphere** (`ball("axehead", 0.13, …, (0.18, 0.8, 0.7))`), no haft detail | `chibi_kit.kit_weapon` `axe`/`axe2h` (also every monster that calls `kit_weapon`) | literally a lollipop/club from any angle |
| 2 | Set heads are a prism over a **nearly convex outline** (`HEADS`), no narrow neck: the head is as tall at the haft as at the edge | `berserker_sets.HEADS` / `_prism` | paddle or shield shape, not eye → flare |
| 3 | **No edge contrast**: the "edge" strip uses the same `m_metal` as the blade (only `glow` styles differ), and it is a 1.8 cm sliver | `build_axe`, `edge` | head is one flat white blob in the toon shader |
| 4 | Blade is `m_metal` (0.78–0.86, spec 0.9): the brightest thing on the character, uniform | materials | white slab; nothing says "steel face + ground edge" |
| 5 | Constant 3.2–4 cm thickness to the rim + smooth shading + 2.5 cm outline per side | `_prism`, `ck._smooth` | from above (the usual view) the head is a ~9 cm dark-rimmed bar: a mallet |
| 6 | Socket tube (r 4.5 cm × S) + fur ring + skull + gems stacked at the same point | `build_axe` | lump at the top of the haft |
| 7 | Haft is bare wood with 3–4 loose discs and a ball pommel | `build_axe` | reads as a club handle |

Evidence: top row of `blender_closeup_side.png`, top row of `blender_game_cam_3x.png` (white lumps and bars from
above) and `godot_old_tiers_*.png` (real toon + outline: white paddles).

## 2. New construction (`tools/blender/axe_kit.py`, prototype, not wired yet)

One parametric builder shared by the common axe, every `BER_AXES` style (main and Gêmeos off-hand) and, through
`kit_weapon`, the monsters.

Blade (`blade_parts`), in the plane u = along the haft, v = outwards, w = thickness:

- **Eye → flare**: the blade starts `2 × eye` tall at the haft and opens to `up` (toe) and `dn` (heel/beard) at the
  edge. `flare_up` / `flare_dn` are exponents: 1 = straight wedge, 2–3 = stays narrow, opens at the end (concave
  neck, pointed toes).
- **Edge arc**: from `-dn` to `+up`, apex at `apex` (0–1), toes pulled back by `sag_up` / `sag_dn` (large = crescent
  horns). Optional `teeth` + `tooth` scallop the edge (fang).
- **Thin cheek**: `thick` (6.2 cm × S) at the eye tapering to `thick_bev` (2.6 cm × S) at the bevel line, then to zero
  at the edge; toe and heel are 45% thinner than the middle.
- **Bevel strip**: the last `bevel` = 24% of the reach is a separate strip in `m_metal` (bright, spec 0.9 in
  `KitModel._prepare`); the cheek is the new matte `m_axe_cheek` (0.38, 0.41, 0.52) or `m_axe_cheek_dark` for `dark`
  styles; `glow` styles light the bevel. 24% is ~7 cm on a one-hand axe = 5 px in game (a strip under 4 cm vanishes).
- Blade faces are **flat shaded**; round parts stay smooth. No Godot change is needed (same node names, existing
  material names plus two plain ones).
- Grid: 9 rows × 5 columns (13 rows with teeth). 1 mesh per weapon as today.

Rest of the axe (`axe_parts`): slightly tapered haft, butt cap (`trim`), **one leather grip sleeve + two `tint2`
rings**, wedge-shaped **eye box in `tint`** (item colour), two `trim` collars, **langets** (metal strips down the
haft), short nape, optional `back` (4-sided war spike), `poll` (hammer back), `spike` (4-sided top spike), `fur`,
`skull` (moved to the back of the eye, off the blade), `gem`, `tassel`, `dark`, `glow`. `double` mirrors the blade.

Head shapes (`axe_kit.HEADS`, metres at S = 1; S = 0.78 one-hand, 1.4 two-hand, common two-hand 1.2):

| head | eye | reach | up | dn | apex | sag up/dn | flare up/dn | used by |
|---|---|---|---|---|---|---|---|---|
| broad | 0.085 | 0.40 | 0.25 | 0.29 | 0.52 | 0.07 / 0.08 | 2.0 / 2.2 | common `axe`, common `axe2h` (+ back spike) |
| bearded | 0.085 | 0.41 | 0.17 | 0.43 | 0.72 | 0.04 / 0.13 | 1.5 / 3.0 | ber_g5, g10, e5 |
| crescent | 0.07 | 0.42 | 0.38 | 0.38 | 0.50 | 0.20 / 0.20 | 2.6 / 2.6 | ber_g20, g30, e20 |
| cleaver | 0.15 | 0.36 | 0.36 | 0.36 | 0.60 | 0.00 / 0.05 | 1.25 / 1.6 | ber_e15 |
| fang | 0.08 | 0.42 | 0.33 | 0.35 | 0.50 | 0.14 / 0.15 | 2.3 / 2.5, teeth 3 × 0.075 | ber_g15, g25 |
| double | 0.075 | 0.38 | 0.31 | 0.31 | 0.50 | 0.13 / 0.13 | 2.3 / 2.3 | ber_e10, e25, e30 |

`BER_AXES` keeps its keys (`head`, `spike`, `back`, `fur`, `skull`, `gem`, `glow`, `dark`), so the 12 styles map
without data changes. Old `tomahawk` / `francisca` outlines are unused in the catalog today.

Cost (measured in the prototype): 400–560 tris per axe against 130–440 before; the scratch Berserker kit has
**158 meshes** (159 today, limit 200); `clear_weapons` ran clean on it. Envelope stays close to the old one
(reach up to 0.33 m one-hand and 0.59 m two-hand, against 0.35 / 0.67; bounding boxes within about 5 cm of the old ones, the cleaver 3-7 cm larger), so ground clearance did not get harder.

## 3. Sheets (`production/qa/evidence/axes/`)

| File | What |
|---|---|
| `blender_closeup_side.png` | close-up, side: common 1h, common 2h, ber_g5, ber_g20, ber_e10, ber_e15; old on top, new below |
| `blender_closeup_34.png` | same, 3/4 from above (thickness and bevel) |
| `blender_game_cam_1x.png`, `_3x.png` | 52°, 24 m, fov 35 (1x = game pixels, 3x = enlarged); old row behind, new in front |
| `godot_old_tiers_carniceiro.png` / `godot_new_…` | real toon + outline, lineup `--strip=berserker --set=carniceiro --tiers` (6 one-hand pairs) |
| `godot_old_tiers_executor.png` / `godot_new_…` | same for the 6 two-hand axes |
| `godot_old_strip_e10_sweep.png` / `godot_new_…` | `atk_sweep` film with ber_e10 |

The Godot shots came from a scratch copy of the project with a scratch-built `kit_berserker_male.glb`; the worktree's
`assets/models` is untouched. The Blender sheets use a bare body in rest pose. In-game `--autostart` screenshots were
taken but discarded: they land mid-fight and show neither version clearly.

Not verified in this phase: female kit, off-hand axes up close, monsters, icons, `shield_mount`-style contact checks,
the test suite.

## 4. Rollout plan (option A, all axes)

1. Wire `axe_kit` in: `berserker_sets.build_axe` → `axe_kit.build` (drop `HEADS`/`_prism` there);
   `chibi_kit.kit_weapon` `axe`/`axe2h` → `axe_kit.COMMON`; legacy `chibi_kit.weapon()` `axe2h` likewise.
2. Monsters: `mob_zombie`, `mob_orc_recruit`, `mob_orc_warrior`, `mob_ghoul_giant`, the two `kharzun_mobs`
   humanoids with `axe`/`axe2h` inherit the common axe through `kit_weapon`. Two bosses draw their own head over the
   kit axe and need a decision each: `mob_ghar` (`act2_bosses.py` ~580, two `ck.blade` plates) and `mob_durgash`
   (`kharzun_mobs.durgash_axe`, a ball head). `prop_durgash_throneaxe` (`sig_props_b._axe_blade`) is separate.
3. Rebuild: `kit_berserker_male/female`, `kit_male/female`, the monsters above (`mob_kit.build_all(only=[…])`).
   `mob_ghar` has solved poses (`ghar_wall_solve.py`, `GHAR_SOLVED`) tied to the axe geometry: re-check `guard_wall`,
   `wall_counter` and `clear_ground` there.
4. Icons: Berserker set weapon icons are photos of the kit (`tools/icons/set_icons.tscn`, windowed) → re-run;
   painted item art `_a_axe` / `_a_axe2h` in `tools/icons/item_icons.gd` already draws a wedge blade but should get the
   flared profile and a wider edge mark (`item_icons.tscn` + `--import`). Skill glyph `axe` in `make_icons.gd` is
   optional.
5. Checks: `--import`, full tests (mesh count < 200, hand twist, ground checks, model leaks), lineup
   `--strip=berserker --set=<build> --tiers [--front]` for both builds and both sexes, `anim_probe`, smoke
   `--autostart=berserker`, `lineup --mobs=` for the monsters, evidence screenshots.

Effort: wiring + Berserker and generic kits + lineup review about half a session; monsters + two bosses + icons +
tests the other half. One session in total if the bosses take the common family; more if Ghar/Durgash get bespoke
heads.

## 5. Risks

- **Mesh count**: unchanged (1 mesh per weapon); measured 158 for the Berserker kit.
- **Ground clip**: blades are not longer than before, but the silhouette is different (beard hangs lower, top spike);
  `clear_weapons` recomputes on build, and `_check_hand_twist` (< 112°) is the check that can trip. Monster axes are
  outside `clear_weapons` unless the model calls `act2_bosses.clear_ground`.
- **Uncommitted kit work**: all 20 kit GLBs in this worktree are already modified (ground-clip pass). The rollout
  rebuilds 4 of them on top of that; do it after that work is settled, or in the same commit.
- **Flat shading + inverted-hull outline**: no cracks visible in the lineup shots, but only one sex and one camera
  were checked.
- **Glow edges** (g20, g30, e20, e30) wash out to pale peach, same as before; a more saturated colour is a small
  follow-up if wanted.
- **Two-hand idle pose** still puts the head in front of the face from the lineup angle (pose, not model; unchanged).
- **Icons** drift from the models until step 4 runs.

## 6. Open decisions for the user

1. Approve the family as shown, or ask for changes (the knobs are in the table in section 2).
2. One-hand scale: 0.78 keeps today's footprint; 0.86 is chunkier (more "MMO"), slightly more overlap with the body.
3. Common two-hand axe: single broad head + back spike (prototype) or double-bit.
4. Ghar and Durgash: take heads from the new family (which shapes) or keep their bespoke blades.
5. Cheek colour: fixed dark steel (prototype) or a hint of the item colour on higher tiers.

## 7. Rollout as done (2026-11-15, uncommitted in `wt/axes`)

User decisions applied: shapes as shown; one-hand scale **0.86**; common two-hand = single broad head + back spike;
Ghar and Durgash moved to the new family; cheek = fixed dark steel.

Code
- `tools/blender/axe_kit.py`: the builder. `kit_axe` (common axe), `build`, `axe_parts`, `blade_parts`, `HEADS`,
  `COMMON`. New cfg keys: `S`, `shaft`, `butt`, `back_scale` (second blade of a double), `colors`
  (`trim` / `tint` / `tint2` for one axe).
- `berserker_sets.build_axe` now calls `axe_kit.build`; the old `HEADS` / `_prism` are gone.
- `chibi_kit.kit_weapon(base, wtype, hand, mats, cfg=None)` sends `axe` / `axe2h` to `axe_kit.kit_axe`; the legacy
  `weapon()` `axe2h` uses the same parts.
- `mob_kit.humanoid(..., axe=None)` passes a head cfg to the kit axe. `act2_bosses.GHAR_AXE` (double, back blade
  70%, top spike, red band; the overlay blades were removed) and `kharzun_mobs.DURGASH_AXE` (double, spike, gold
  trim, gems; `durgash_axe` removed).
- Ghar: head stays 0.66 m from the hand and the edge 0.44 m from the haft, so `GHAR_SOLVED` was **not** re-solved.
  The new blade is about 3 cm taller, so `ghar_wall_clips` now ends with
  `clear_ground(rig, {"wall_counter": 0.0}, "hand.R", ("wpn_main_",))`: it turned the hand 3° on frames 10, 12, 13.
- `tools/icons/item_icons.gd`: `_axe_blade` (same eye → flare → bevel recipe) used by `_a_axe` and `_a_axe2h`.
- `tools/lineup/lineup.gd`: review option `--body=<male|female>`.

Rebuilt (Blender batch): `kit_berserker_male/female`, `kit_male/female`, `mob_zombie`, `mob_orc_recruit`,
`mob_orc_warrior`, `mob_ghoul_giant`, `mob_orc_warlord`, `mob_clan_guard`, `mob_ghar`, `mob_durgash`.
Icons regenerated: 12 `art_axe*`, 12 `ber_*_weapon`, 6 `ber_g*_offhand`. `set_icons` also re-photographed the Berserker
armour pieces; those were restored to the committed files (out of scope).

Verification (in the worktree)

| Check | Result |
|---|---|
| `--import` | clean |
| Full suite | 3 full runs: 78502 passed / 0 failed (after the rebuild), 78489 / 1 failed, 78491 / 0 failed (both on the final state). The one failure was `_check_mounted_charge` "Carga anda 11,2 m (10.72)", a sim check that did not repeat; the check count itself varies between runs |
| `combat_probe` (all classes) | `flags=0` |
| `anim_probe` before vs after | identical output; note it covers `kit_paladin_male`, `kit_bishop_female`, forms and monsters, **not** the Berserker kits |
| Smoke `--autostart=berserker` | `SMOKE OK`, 0 `SCRIPT ERROR` |
| Kit ground clearance | `clear_weapons` ran on all four kits during the build; the suite's kit checks pass |

Evidence in `production/qa/evidence/axes/rollout/`: `tiers_carniceiro[_front|_female].png`,
`tiers_executor[_front|_female].png`, `strip_e10_atk_sweep.png`, `strip_e30_atk_2h[_female].png`,
`strip_g20_atk_dual_a.png`, `strip_common_idle.png`, `strip_e20_titan_front.png`, `ghar_guard_wall[_low].png`,
`ghar_wall_counter[_low].png`, `ghar_attack.png`, `durgash_attack.png`, `mobs_axes.png`, `mobs_axes_bosses.png`,
`icons_axe_sheet.png`.

Left as is
- Glow edges still wash out to pale peach.
- `.claude/docs/ragnaex/modelos.md` does not mention `axe_kit.py` yet (manual is outside this agent's files).

## 8. Follow-ups (2026-11-15, uncommitted)

Not touched in this round, on request (the shields worktree is merging them): `axe_kit.py`, `chibi_kit.py`,
`berserker_sets.py`, kit GLBs.

**Machado do Trono** (`prop_durgash_throneaxe`, `tools/blender/sig_props_b.py`): `_axe_blade` now calls
`axe_kit.blade_parts` with the `double` head (the one `DURGASH_AXE` uses) at scale 3.03, 6 rows. Everything else in the
prop is unchanged (spike, head box, gold `glow_trono` runes and skull eyes, tusks, haft, pennants). Same material list
in the same order, origin still at the tip on the ground, bounding box ±1.14 × ±0.37 × 0..3.25 m (was ±1.15, same Y and
Z), 665 tris (was 549, limit 700). Before/after: `evidence/axes/followup/throneaxe_before.png`, `throneaxe_after.png`.
Not re-filmed in the boss fight (`BossSigView`); size and pivot did not change.

**Skill glyph `axe`** (`tools/icons/make_icons.gd` `_g_axe`): flared blade in the darker symbol tone, wide bevel in the
light tone, back spike, collar. Regenerated with `--only=berserker`; the files that changed are the 10 axe skills
(`ber_cleave`, `ber_leap`, `ber_execute`, `ber_hack`, `ber_axe_storm`, `ber_throw_axe`, `ber_butcher`,
`ber_crimson_flurry`, `ber_whirlwind`, `ber_glad_finale`) and `class_berserker.png`. No `DUP` line in the log.
Sheet: `evidence/axes/followup/skill_icons_berserker_sheet.png`; old `ber_cleave` for comparison:
`skill_ber_cleave_before.png`.

**Proposal: glow-edge washout (g20, g30, e20, e30). No change made.**

What happens: the glowing bevel is `m_axe_edge_glow`, base (1.0, 0.25, 0.15), emission 2.4. `KitModel._prepare` caps
`emission_amount` at 2.0 and the toon shader adds `EMISSION = base * emission_amount` on top of the lit colour, so the
strip is around (3.0, 0.75, 0.45) before tonemapping. My reading (from the shader and environment code, not measured)
is that filmic tonemapping plus the scene glow compress that to the pale peach seen in the lineup shots. The old axes did the same, but the strip was 1.8 cm; the new bevel is 24% of the reach, so the washed colour
is now a large area. All four styles also share one red-orange, including `ber_e20` ("Gigante do Inverno", an
ice-blue set).

Options
1. **Lower the energy, deepen the colour** (recommended first step). Emission 1.0 (a 0.25 step, as `RigidMerge`
   wants) and base about (1.0, 0.16, 0.06). The strip then stays a saturated orange-red instead of clipping. Two
   constants in `axe_kit.py`.
2. **Glow colour per set** (recommended with 1). `glow` in `BER_AXES` becomes a colour instead of `True`:
   g20 violet-crimson for the dark reaper, g30 blood red, e20 ice blue (0.45, 0.8, 1.0), e30 scarlet-gold. A few
   lines in `axe_kit.axe_parts` (material name per colour) plus four entries in `berserker_sets.BER_AXES`.
3. **Steel bevel + glowing inner line** (optional, changes the look). Keep the bevel in bright steel like the other
   axes and put the glow in a narrow band along the bevel line (the paladin weapons' glowing fillet idea). Reads as
   "steel edge, lit rune" and cannot wash out the whole edge; costs about 16 quads per blade and a new strip in
   `blade_parts`.

Cost of 1 + 2: rebuild `kit_berserker_male/female`, re-photograph 4 weapon icons and 2 off-hand icons
(`set_icons --only=ber_g20,ber_g30,ber_e20,ber_e30`, then restore the armour icons), lineup `--tiers` for both builds
with and without `--no_glow`, suite. It has to wait for the shields merge because it edits `axe_kit.py` and
`berserker_sets.py`. The exact colours are a look decision for the user; the numbers above are starting points and
have not been rendered.
