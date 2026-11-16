# Attack arcs: colour bands per weapon family (2026-11-15)

Author: art-director. Status: **proposal for the implementer + 3 user decisions (section 6).** No code changed, no Godot run.
Inputs: `game/fx/weapon_arcs.gd` (`FAMILIES`, `_swing`: `band` for theme `""`/`physical`, else
`SkillFx.col(theme, 0).lerp(WHITE, 0.15)`; `rim = band.darkened(0.82)`), `shaders/smear_arc.gdshader` (unshaded,
premultiplied **mix**, not additive: the colour on screen is the colour written here), `game/fx/skill_fx.gd` `PALETTE`,
`game/fx/fx_manager.gd` `DANGER*`, `game/fx/boss_sig_view.gd` (danger grammar), `production/qa/attack-arcs-rollout-plan.md`,
evidence `production/qa/evidence/attack-arcs/{after,wave1/after}/` (pilot sword, wave-1 mace / mace2h / sword2h strips at 24 m).

## 1. The rule behind the palette

The hue wheel is already spoken for: red/carmine = danger, orange = fire/lava, gold/yellow = holy and split, purple =
shadow/control (and lunar lavender), green/mint = poison/nature/heal/wind/summon and the SAFE colour, saturated sky blue =
ice/lightning, sand/cream = safe ground and the danger rim. A physical swing cannot own a hue without stepping on one of them.

So physical bands live in **metal space**: low chroma (HSV saturation <= 0.25; every magic theme arc is >= 0.34 after the
15% white lerp, except bone 0.11, see 4) and **light value** (relative luminance >= 0.6) with the dark toon rim doing the
outline. Family identity comes from three things, in this order: **shape** (F/S/W/R/K, already per family), **thickness**
(inner radius, already per family), and **temperature inside the metal range** (cool steel / white glint / warm pewter /
rose iron / black iron). This is the same "identity by form, never by contrary colour" rule the boss telegraphs follow.

Why light + dark rim: mid-value bands vanish on mid-value ground. Measured on approximate ground tones from the evidence
frames (grass L 0.37, dirt road 0.29, stone 0.33, sand 0.59, basalt 0.04), a mid slate band (L 0.32-0.40) scores contrast
1.0-1.2 against grass, dirt and stone: invisible except for its rim. A light band scores 1.6-2.0 on grass/dirt/stone and
8+ on basalt; on sand (the one light ground) the near-black rim carries it (ratio ~9). One exception family is
**inverted** (black-iron band, light rim, section 3) so it reads on everything but basalt, where its rim and white core carry it.

## 2. Band table

`band` = the `FAMILIES[...]["band"]` value. `edge` = the rim the shader draws. For normal families keep today's
`band.darkened(0.82)` (it is a toon outline, ~18% of the band; listed for the record). **Inverted families need a rim
override** (new optional `rim` key; today the rim is hard-coded in `_swing`). `glow` = core multiplier (existing key).

| Family | Band (sRGB hex) | Band `Color()` | Edge / rim | glow | Alpha / intensity notes |
|---|---|---|---|---|---|
| sword (pilot) | **#BDD4F2** cool steel (pilot was #B8DBFF, see 6.1) | `Color(0.74, 0.83, 0.95)` | darkened 0.82 = #22262B | 1.25 | as pilot; band_a 0.85 x tail unchanged |
| sword2h | **#D6E3F5** polished white steel | `Color(0.84, 0.89, 0.96)` | #26292C | 1.35 | thicker (inner 0.22) does the "heavy"; whiter than the 1h sword so the step reads |
| mace | **#D1CCC4** warm pewter | `Color(0.82, 0.80, 0.77)` | #262523 | 1.25 | replaces the amber placeholder (6.2) |
| mace2h | **#D9D4CC** light pewter | `Color(0.85, 0.83, 0.80)` | #272625 | 1.35 | same hue as mace; inner 0.20 + S shape separate it |
| axe (1h, dual slivers) | **#453F3D** black iron, INVERTED | `Color(0.27, 0.25, 0.24)` | **override #E0E6F0** `Color(0.88, 0.90, 0.94)` | 1.5 | core must punch through the dark band; off-hand sliver alpha x0.8 |
| axe2h (+ Titan pair) | **#453F3D** black iron, INVERTED | `Color(0.27, 0.25, 0.24)` | **override #E0E6F0** | 1.5 | no "ember edge" (6.3); weight from size, inner 0.20, stop_mult |
| spear | **#E6EBF2** pale ash steel | `Color(0.90, 0.92, 0.95)` | #292A2B | 1.25 | W wedge: fringe lines in band at 0.6 alpha, tip in core |
| dagger (single + dual) | **#EDF2FF** glint | `Color(0.93, 0.95, 1.0)` | #2B2B2E | 1.3 | thin fast slivers read by brightness; off-hand alpha x0.8 |
| claw (dual) | **#DBC9CF** rose iron | `Color(0.86, 0.79, 0.81)` | #282425 | 1.3 | sat 0.08 only; fallback = dagger glint (6.4) |
| scythe (physical only) | **#3A4150** blue-black steel, INVERTED | `Color(0.23, 0.25, 0.31)` | **override #E0E6F0** | 1.5 | Necromancer builds are all MATK: most scythe swings take the theme colour; this band is rare |
| dual variants | each sliver uses **its own hand's family band** (main for jab/main, off for off) | - | per family | per family | off-hand sliver alpha x0.8 so the pair reads as one swing, main hand leading |
| druid wolf (rake K) | **#CFD1D6** neutral grey | `Color(0.81, 0.82, 0.84)` | #252626 | 1.0 | FLOOR mark: overall alpha <= 0.6, life <= 0.2 s, never a ring/disc (6.5) |
| druid bear (rake K) | **#D1CCC4** pewter (= mace) | `Color(0.82, 0.80, 0.77)` | #262523 | 1.0 | as wolf; bear form needs mace2h, wolf needs dual mace, so the pewter family carries over |
| fists | **not present** | - | - | - | no fist type in `ItemDef.MELEE_TYPES` (`sword sword2h mace mace2h axe axe2h dagger spear claw`) |

Ground slash mark of the S shape (`mark`, `MARK_*`): same band, but treat it as a floor mark: alpha <= 0.6, glow 1.0.

### Relative luminance and contrast (approximate, from the evidence ground tones)

| Family | Band L | vs grass | vs dirt | vs stone | vs sand | vs basalt |
|---|---|---|---|---|---|---|
| sword #BDD4F2 | 0.65 | 1.67 | 2.05 | 1.85 | 1.10 (rim) | 8.0 |
| sword2h #D6E3F5 | 0.77 | 1.96 | 2.40 | 2.17 | 1.29 (rim) | 9.4 |
| mace #D1CCC4 | 0.62 | 1.59 | 1.95 | 1.77 | 1.05 (rim) | 7.7 |
| mace2h #D9D4CC | 0.67 | 1.72 | 2.11 | 1.91 | 1.13 (rim) | 8.3 |
| axe / axe2h #453F3D | 0.05 | 4.0 | 3.4 | 3.8 | 6.4 | 1.0 (rim + core) |
| spear #E6EBF2 | 0.83 | 2.10 | 2.58 | 2.33 | 1.39 | 10.1 |
| dagger #EDF2FF | 0.89 | 2.25 | 2.76 | 2.49 | 1.48 | 10.9 |
| claw #DBC9CF | 0.62 | 1.61 | 1.98 | 1.79 | 1.06 (rim) | 7.8 |
| scythe #3A4150 | 0.05 | 4.0 | 3.4 | 3.8 | 6.4 | 1.0 (rim + core) |
| wolf #CFD1D6 | 0.65 | 1.66 | 2.03 | 1.84 | 1.09 (rim) | 7.9 |

"(rim)" = the band alone is weak there and the dark outline (contrast ~9 on sand) does the reading. **Do not lower the rim
alpha** (shader `mix(0.35, 0.85, u)`) for any light family; it is what makes them read on the steppe/coast sand.

## 3. Why each family

- **Blades = cool steel ramp** (sword < sword2h < spear < dagger in whiteness). The cool hue ties the edged weapons
  together; whiteness rises with "polish/speed". The 1h sword keeps the pilot's identity (blue steel) but drops chroma.
- **Blunt = warm pewter** (mace, mace2h, druid bear). The tech artist's "warm steel" intent was right; the placeholder was
  just 5x too saturated. Pewter keeps the warmth at saturation 0.06, far from holy/gold/sand/fire.
- **Axes = black iron, inverted.** "Heavy" and "brutal" without a heat colour. It is the one family whose silhouette flips
  (dark crescent, light outline, white core), which is the strongest family read in the set and suits the Berserker.
- **Claw = rose iron.** Pink against green grass is complementary, so the thin slivers pop on the commonest ground. Chroma is
  0.08, an order of magnitude under danger carmine (0.91) and blood (0.72). Kept as an option because it is the only band in
  the red hue family (6.4).
- **Scythe = blue-black, inverted.** Rare as a physical band; when the Necromancer swings with magic it is shadow purple /
  bone / poison from the theme, and the cool black makes a physical reap clearly not-shadow (hue 225 vs 269, sat 0.26 vs 0.37).
- **Forms = the druid's own mace pewter** (wolf neutral, bear warm). Forms are tied to mace kits in `Balance.FORM_REQUIRES`,
  so the colour carries across the transformation; wolf vs bear is told by the rake shape (chevron vs 3 streaks).

## 4. Contrast check against danger and theme colours

Theme arcs as the game draws them (`PALETTE[theme][0].lerp(WHITE, 0.15)`), HSV hue / saturation:

| Theme | Arc colour | H / S | Nearest physical band | Verdict |
|---|---|---|---|---|
| fire | #FF8840 | 22 / 0.75 | none (no warm band above sat 0.06) | clear |
| ice | #9ED8FF | 204 / 0.38 | sword: proposed #BDD4F2 (214/0.22); **pilot #B8DBFF (210/0.28)** | proposed clear; **pilot CONFLICT** (6.1) |
| lightning | #9EBEFF | 220 / 0.38 | sword #BDD4F2 (214/0.22) | clear (chroma gap 0.16) |
| holy | #FFDE7D | 44 / 0.51 | mace #D1CCC4 (36/0.06); **placeholder #FAD69E (37/0.37)** | proposed clear; **placeholder CONFLICT** (6.2) |
| lunar | #BEA8FF | 252 / 0.34 | sword2h #D6E3F5 (215/0.13) | clear |
| shadow | #8856BE | 269 / 0.55 | scythe #3A4150 (225/0.26) | clear (hue 44 apart, value and chroma apart) |
| poison | #88E95C | 101 / 0.61 | none | clear |
| bone | #F4EED8 | 47 / 0.11 | mace2h #D9D4CC (39/0.06) | **closest pair in the set**: watch. Bone is Necromancer (scythe), never on a mace, so they do not meet on one character |
| nature | #88DE67 | 104 / 0.54 | none | clear |
| earth | #AD8A67 | 30 / 0.40 | mace #D1CCC4 (36/0.06) | clear (chroma and value) |
| blood | #E94040 | 0 / 0.72 | claw #DBC9CF (343/0.08) | clear by chroma; same hue family (6.4) |
| wind | #C9FFEE | 160 / 0.21 | spear #E6EBF2 (216/0.05) | clear |
| heal | #88FF9E | 129 / 0.47 | none | clear |
| summon | #88F4C9 | 157 / 0.44 | none | clear |
| physical | uses the family band | - | - | - |

Danger / mechanic grammar (`FxManager.DANGER*`, `BossSigView`):

| Signal | Colour | Nearest band | Verdict |
|---|---|---|---|
| damage fill | carmine #E61429 | claw (rose iron) | clear (sat 0.08 vs 0.91); shape + plane differ |
| damage rim (pulsing) | cream #FFF2CC | mace2h #D9D4CC | clear (sat 0.06 vs 0.20, and the rim is a pulsing ground ring) |
| lava / shard glow / hot dust | #FF801F / #FF7326 / #FF9E40 | none | clear (was at risk with the amber placeholders and the planned "ember edge") |
| split (gold) | #FFC738 rim, #FFD64D lit | none | clear (was at risk with the amber placeholders) |
| shadow / control | VENOM #8042B8 | scythe | clear |
| safe (cold / sand) | #CCFFEB / #FAEBB3 | spear, mace | clear (sand was at risk with the amber placeholders) |

Shape also separates arcs from telegraphs: arcs are crescents tilted toward the camera or standing, living 0.16-0.18 s;
telegraphs are flat ground areas that persist and fill. The only arcs that touch the floor are the S-shape mark and the
druid rake, hence their alpha/life caps.

## 5. Notes for the implementer

- Add an optional `"rim"` key to `FAMILIES`; `_swing` uses it when present, else `band.darkened(0.82)` (axe, axe2h, scythe).
  For a magic theme on an inverted family, use the normal theme band + darkened rim (the theme rule wins).
- Dual: pass the off-hand family's band to the off-hand sliver; off sliver alpha x0.8.
- Floor marks (S mark, K rake): overall alpha <= 0.6, glow 1.0, life <= 0.2 s.
- `scythe` is not in `ItemDef.MELEE_TYPES`; the plan's check "every `FAMILIES` key is in `MELEE_TYPES`" will fail when
  scythe lands. Either add it there or exempt it in the check (gameplay owner's call, not art).
- Review evidence per family should include one frame on **sand** (steppe/coast) and one on **basalt** (fort_fire), not
  only Aldara grass/road: those are where a band fails.

## 6. Conflicts found and decisions for the user

1. **Pilot sword band vs ice theme.** #B8DBFF and the ice arc #9ED8FF are 6 degrees and 0.10 saturation apart: a
   frost-themed cone skill on a sword reads the same as a plain swing. The pilot was approved, so this is the user's call.
   Options: (a) shift to #BDD4F2 (Recommended): same blue steel, chroma below every magic theme; (b) keep the pilot and
   accept the overlap.
2. **Wave-1 warm placeholders (mace #FAD69E, mace2h #FFD194).** Saturation 0.37-0.42 in the 34-37 degree range sits
   between holy (#FFDE7D, the Paladin's own theme, so a mace basic and a holy strike look alike), split gold, sand-safe and
   the cream danger rim; in `wave1/after/strip_cam24_mace_basicPhys.png` the band reads orange on the dirt road. Replace with
   pewter #D1CCC4 / #D9D4CC. Sword2h placeholder #CCE0FF is acceptable; #D6E3F5 is a cleaner step from the 1h sword.
3. **The plan's "ember-edged" axe2h** would put orange on a player swing: fire / lava / hot dust / danger family. Replaced
   by inverted black iron. Options: (a) black iron, inverted (Recommended): strongest family read, needs the rim key;
   (b) axes share the pewter band: no code change, but axe and mace become one colour.
4. **Claw rose iron** is the only band in the red hue family. Options: (a) rose iron #DBC9CF (Recommended): best pop on
   grass, chroma 0.08; (b) claws take the dagger glint #EDF2FF: zero risk, assassin pairs look alike.
5. **Floor marks** (S mark, druid rake K) touch the "only telegraphs are saturated on the floor" rule: capped as above.
   Not a decision, a constraint for wave 6.
6. **Theme side (outside this brief, flagged only):** player arcs with theme `blood` (#E94040) share the danger carmine
   hue, and `fire` arcs (#FF8840) match lava (#FF801F). Shape and timing separate them today. If playtest shows confusion,
   the cheap fix is a larger white lerp (0.35) for those two themes in arcs only. Holy (#FFDE7D) vs split gold (#FFD64D) is
   close too, already accepted with the pilot.

Swatch PNG: not produced (no script runner in this session). The hex values above are the source of truth.

## Ent e formas (revisão 2026-11-15)

Author: art-director. Read-only review of wave 6 (`game/fx/weapon_arcs.gd` `FAMILIES["form_*"]`, `_form_standing`,
`_form_marks`, `FORM_ARC`) and the evidence in `production/qa/evidence/attack-arcs/wave6/after/`. No code changed, no Godot run.

### 7.1 Ent band: #C7CCBF -> **#D4D8CC** (pale lichen bark)

The implementer's idea is right (a near-neutral bark/moss so the Ent owns its own step in the form family), the value is not.

| Candidate | H / S (HSV) | Band L | vs grass | vs dirt | vs stone | vs sand | vs basalt |
|---|---|---|---|---|---|---|---|
| #C7CCBF (wave-6 default) | 83 / 0.06 | 0.59 | **1.52** | 1.88 | 1.68 | 1.00 (rim) | 7.1 |
| **#D4D8CC** `Color(0.83, 0.85, 0.80)` | 80 / 0.06 | 0.68 | 1.73 | 2.13 | 1.91 | 1.13 (rim) | 8.1 |

- #C7CCBF is the only physical band under the section-1 floor (L >= 0.6) and the weakest on grass (1.52, every other light
  band is 1.59+). Its slight green cast also leans *toward* the commonest ground and toward the Ent's own pale-green crown,
  which is the wrong direction (the claw got rose iron precisely because the complement pops on grass). In
  `full_cam24_ent_maul_imp.png` the crescent reads as a dull tan-grey smear on the road, close to the dirt itself.
- #D4D8CC keeps the same hue and chroma (the identity), lifts value to the mace2h/wolf level. Rim stays
  `band.darkened(0.82)` = **#262725**; glow, alpha, life unchanged.
- The form family now reads as a temperature ramp at equal value: **wolf cool** (#CFD1D6, hue ~223) / **bear warm**
  (#D1CCC4, 36) / **Ent lichen** (#D4D8CC, 80). At S 0.06 the three are near-identical on screen; that is intended.
  Identity comes from shape (bite V / 3 rakes / standing crescent + stomps) and size (`FORM_SCALE`), as for weapons.

Theme / danger check of #D4D8CC: nature #88DE67 (104/0.54), poison #88E95C (101/0.61), heal #88FF9E, summon #88F4C9,
wind #C9FFEE (160/0.21), safe cold #CCFFEB (155/0.20): all clear by chroma (0.06 vs 0.20+). Cream danger rim #FFF2CC
(44/0.20), bone #F4EED8, safe sand #FAEBB3: clear (hue 80 vs 44-47, chroma 3x lower). mace2h #D9D4CC is the same value
and the same S shape, different hue; a form overrides the weapon (`family_of`), so they never meet on one body, and the
Ent crescent is ~2x the size. No conflict. If the Ent's skills carry a magic theme (nature), the theme colour wins as for
any weapon (`band_rim`): the band only shows on physical swings.

### 7.2 Readability of the form rakes in the evidence

| Ground | Frames | Verdict |
|---|---|---|
| Grass / dirt (Aldara) | wolf, alpha, bear, Ent at cam 9 and 24 | **Reads.** Light rakes over grass and road at 0.6 alpha, short life, no ring. Ent stomps (`full_cam9_ent_slam_imp.png`) are the clearest marks in the set. |
| Basalt / ash (`fort_fire`, "Estepes de Cinza") | `full_cam24_fort_fire_bear_maul_imp.png` | **Reads well**, as predicted: light streaks on dark ground (~7-8x). |
| Sand (`field_coast`) | `full_cam24_field_coast_bear_maul_imp.png`, `strip_cam24_field_coast_wolf_claw.png` | **Not verified.** The bear stands in a shallow water pool (rake lands on water), and the wolf strip crop is empty sand: the druid is out of frame. |
| Steppe (`field_steppe`) | `full/strip_cam24_field_steppe_*` | **Not verified.** The wolf frames show no druid in combat (camera on a mounted group by a cart; the red rectangle is someone else's telegraph); the bear frame is a crowd where the rake cannot be picked out. |
| Ent on sand / basalt | none | **Missing.** The Ent was filmed only on Aldara grass/dirt. |

Sand is the one ground where the light bands rely on the dark rim (contrast ~1.0-1.1 for the band alone, section 2),
so it is the case that most needs a frame, and it is the one the evidence misses.

### 7.3 Ent-specific shape notes

- **Standing crescent (galho, `maul|ent`)**: visible at cam 24 (`strip_cam24_ent_maul.png`, row 2) as a thin arc
  upper-left of the crown, but for much of its life it passes **behind the Ent's own crown** at the 52° camera (2.8 m
  form, `s_pivot` 1.1 x scale). The new band value helps where it shows; the occlusion is geometry, not colour. Advisory
  for the technical-artist: try a larger `s_roll` or a pivot slightly in front of the trunk so the head of the arc clears
  the crown. Not a colour must-fix.
- **Stomps (`slam|ent`)**: at the impact frame (`full_cam9_ent_slam_imp.png`) the two marks sit ~1 body-width toward the
  camera from where the fists are, and the fists are still at hip height. `FORM_ARC` puts them at frame 0 while the code
  comment says the fists land at frame 8. A mark that appears where nothing touched reads as an independent ground effect
  (the telegraph's job), not as the Ent's blow. Advisory: check the frame (0 vs a hook at 8) and the contact x/z on the
  rebuilt GLB.

### 7.4 Art-bible / danger grammar

- Wave-6 marks respect the floor caps in code: `MARK_ALPHA` 0.6 (arm drag 0.6 x 0.8 = 0.48), `MARK_LIFE_MAX` 0.2 s,
  `MARK_GLOW` on every floor mark, K meshes are streaks only (stomp = rake x0.7 opened 20°), never ring/disc. The
  standing crescent's ground nick uses the same caps. No conflict with "Cor do chão" (zonas.md) or the danger grammar
  (conteudo.md, `FxManager.DANGER*`): no form colour is saturated, red, gold or purple.
- **Flag, outside wave 6** (`full_cam24_ent_slam_imp.png`, `full_cam9_ent_slam_imp.png`): the slam skill's own AoE FX
  draws a **filled translucent disc plus a cream ring** on the floor around the player. A filled floor area with a
  cream rim is the damage-telegraph vocabulary (`DANGER` fill + cream rim). It is short and centred on an ally, so
  probably harmless, but it is the same words. Escalate to the creative-director as a trade-off (skill feedback vs
  "only telegraphs fill the floor"), not a wave-6 fix.

### 7.5 Summary

- Final Ent band: **#D4D8CC** `Color(0.83, 0.85, 0.80)`, rim darkened 0.82, other keys unchanged.
- **Must-fix before wave 6 closes:** (1) set the Ent band to #D4D8CC; (2) re-shoot sand (`field_coast` on dry sand, not
  the pool) and steppe frames with the druid actually in the crop and fighting, for wolf, bear **and Ent**, plus one Ent
  frame on `fort_fire` basalt. The sand case is the one section 2 flagged as rim-dependent and it has no valid frame.
- Advisory: crescent occluded by the crown (7.3); stomp marks ahead of fist contact (7.3); slam AoE disc + cream ring (7.4).
