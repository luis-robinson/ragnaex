# Shields: close forearm mount for every shield — measurement, search, rollout

Date: 2026-11-15 · Branch `wt/shields-mount` (uncommitted) · Owner: blender-modeler
Trigger: shield-fix gave the starter shield `tabuas` a close mount; open question was whether the named shields should
follow. Started as a study; the user's decision (relayed by the coordinator) was **yes, all shields**, so sections 4-7
are the rollout as done. This worktree also carries the axes rollout (section 8).

## 1. What was wrong (measured)

The common mount put every shield 0.29 m outside the forearm axis and 0.32 m below it, held by two gold rods
(`wpn_off_grip`). The forearm with the plate gauntlet has a radius of 0.08 m, so there was **0.16-0.22 m of air** between
the arm and the back of the plate on 42 of the 43 styles (the starter shield was already close; column "Air before"). The shield is rigid on `forearm.L`, so that
gap is the same in idle, run and guard; what changes per clip is how far the shield is from the rest of the body
(column "Body clearance before").

That distance was not arbitrary: at 0.29 m the old mount had 0 contacts with set chest/skirt pieces on 34 of 43
styles and 0 with set helmets on 31. It was tuned to clear everything, and paid for it by floating.

## 2. Why a shield cannot simply be glued to the arm

- **Guard**: the forearm lies across the chest and the chibi head overhangs it. A plate 0.10 m from the arm, taller than
  ~1.2 m, runs into the chin or helmet. The arm is too short (0.31 m shoulder to wrist) to push the shield out instead,
  so the guard pose cannot buy the distance back. This is what keeps the big shields away.
- **Set armor**: with the arm on the chest, a close plate sits inside bulky set chest pieces. It is hidden behind the
  plate itself from the front and by the body from behind.
- **Sleeves**: wide set sleeves, couters and left pauldrons wrap the forearm; any close shield overlaps them (the starter
  shield already did: 7355 overlaps before this work).

## 3. Rule used by the search

`tools/blender/shield_mount_study.py`, per style, same rotation as the common mount (so icons and guard facing do not
change), searching gap / drop / shift along the forearm:

- **Rejects**: any contact with the common plate body on the male kit, in 15 frames (idle 3, run 8, guard 4). This is
  the `shield_mount.py --check` rule on a denser frame set; the check's own pass rules were not changed.
- **Prefers**: no contact on the female body either.
- **Weighs**: gap beyond touching (dominant: the gap is what reads as floating), contacts with set helmets, contacts
  with set chest/skirt, strap showing past the plate edge, drop away from 0.22.
- **Only counts**: overlaps with set pieces that belong to the left arm.

Contacts are polygon-pair overlaps summed over the frames of a clip and over every set of the class, worst clip shown;
they are a relative measure, not a count of visible defects.

## 4. Result per shield

Kit = where it was measured (common shields are in both kits and were tested against both). Heights and distances in
metres. "Air" = forearm skin to the back of the plate. "close" = air up to 0.06 m, "mid" = up to 0.12 m, "far" = more.

| Shield | Kit | Height | Gap before | Gap after | Drop after | Air before | Air after | Body clearance before (idle / run / guard) | --check (male) | Female contacts | Set helmets before -> after | Set chest/skirt before -> after | Left sleeve before -> after | Result |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `bastiao` | paladin | 1,17 | 0,290 | 0,127 | 0,34 | 0,193 | 0,031 | 0,13 / 0,13 / 0,14 | 0 | 0 | 12 -> 72 | 0 -> 674 | 0 -> 7579 | close |
| `juramento` | paladin | 1,25 | 0,290 | 0,122 | 0,34 | 0,199 | 0,032 | 0,18 / 0,17 / 0,21 | 0 | 0 | 0 -> 120 | 0 -> 1098 | 0 -> 4094 | close |
| `asa` | paladin | 1,07 | 0,290 | 0,163 | 0,34 | 0,197 | 0,073 | 0,13 / 0,09 / 0,26 | 0 | 0 | 0 -> 10 | 57 -> 501 | 0 -> 4850 | mid |
| `sol` | paladin | 1,53 | 0,290 | 0,138 | 0,34 | 0,201 | 0,051 | 0,14 / 0,14 / 0,13 | 0 | 0 | 0 -> 240 | 0 -> 598 | 0 -> 3527 | close |
| `presa` | paladin | 1,19 | 0,290 | 0,225 | 0,26 | 0,204 | 0,133 | 0,10 / 0,10 / 0,11 | 0 | 0 | 6 -> 48 | 0 -> 501 | 0 -> 1483 | far |
| `relicario` | paladin | 1,41 | 0,290 | 0,287 | 0,34 | 0,194 | 0,192 | 0,16 / 0,18 / 0,13 | 0 | 0 | 168 -> 110 | 0 -> 501 | 0 -> 224 | far |
| `prisma` | paladin | 1,39 | 0,290 | 0,141 | 0,34 | 0,157 | 0,012 | 0,11 / 0,14 / 0,15 | 0 | 0 | 0 -> 168 | 0 -> 501 | 0 -> 3875 | close |
| `gaia` | paladin | 1,16 | 0,290 | 0,108 | 0,30 | 0,195 | 0,011 | 0,19 / 0,20 / 0,24 | 0 | 0 | 0 -> 0 | 0 -> 1279 | 0 -> 1923 | close |
| `tabuas` | paladin | 0,95 | 0,120 | 0,120 | 0,22 | 0,032 | 0,032 | 0,06 / 0,05 / 0,07 | 0 | 0 | 438 -> 438 | 0 -> 546 | 7355 -> 7463 | close |
| `ferro` | paladin | 0,90 | 0,290 | 0,130 | 0,22 | 0,198 | 0,031 | 0,18 / 0,17 / 0,26 | 0 | 0 | 0 -> 0 | 0 -> 501 | 0 -> 5548 | close |
| `ossario` | paladin | 1,05 | 0,290 | 0,083 | 0,26 | 0,219 | 0,012 | 0,24 / 0,21 / 0,26 | 0 | 0 | 0 -> 24 | 0 -> 761 | 0 -> 4887 | close |
| `escama` | paladin | 1,32 | 0,290 | 0,178 | 0,34 | 0,203 | 0,091 | 0,10 / 0,12 / 0,16 | 0 | 0 | 13 -> 0 | 0 -> 501 | 0 -> 2984 | mid |
| `coluna` | paladin | 1,36 | 0,290 | 0,158 | 0,34 | 0,203 | 0,072 | 0,13 / 0,12 / 0,14 | 0 | 0 | 64 -> 264 | 0 -> 501 | 0 -> 7048 | mid |
| `perdao` | paladin | 1,43 | 0,290 | 0,229 | 0,34 | 0,192 | 0,132 | 0,16 / 0,08 / 0,19 | 0 | 0 | 0 -> 0 | 72 -> 501 | 0 -> 488 | far |
| `veredito` | paladin | 1,33 | 0,290 | 0,272 | 0,30 | 0,210 | 0,192 | 0,07 / 0,05 / 0,11 | 0 | 0 | 10 -> 12 | 12 -> 501 | 0 -> 224 | far |
| `serpente` | paladin | 1,33 | 0,290 | 0,224 | 0,34 | 0,197 | 0,132 | 0,10 / 0,06 / 0,19 | 0 | 0 | 0 -> 0 | 48 -> 501 | 0 -> 2984 | far |
| `cruel` | paladin | 1,50 | 0,290 | 0,156 | 0,34 | 0,205 | 0,072 | 0,13 / 0,13 / 0,14 | 0 | 0 | 4 -> 290 | 30 -> 501 | 0 -> 2160 | mid |
| `asa_negra` | paladin | 1,50 | 0,290 | 0,280 | 0,34 | 0,201 | 0,192 | 0,08 / 0,01 / 0,15 | 0 | 13 | 96 -> 138 | 84 -> 501 | 0 -> 224 | far |
| `suspiros` | paladin | 1,63 | 0,290 | 0,281 | 0,34 | 0,200 | 0,192 | 0,09 / 0,05 / 0,05 | 0 | 0 | 238 -> 214 | 36 -> 501 | 20 -> 224 | far |
| `pal1` | paladin | 0,90 | 0,290 | 0,132 | 0,22 | 0,199 | 0,032 | 0,18 / 0,17 / 0,26 | 0 | 0 | 0 -> 0 | 0 -> 26 | 0 -> 4913 | close |
| `pal_g10` | paladin | 0,93 | 0,290 | 0,132 | 0,22 | 0,199 | 0,032 | 0,18 / 0,17 / 0,26 | 0 | 0 | 0 -> 0 | 0 -> 26 | 0 -> 7492 | close |
| `pal_g15` | paladin | 0,97 | 0,290 | 0,108 | 0,30 | 0,195 | 0,012 | 0,18 / 0,18 / 0,25 | 0 | 0 | 0 -> 0 | 0 -> 26 | 0 -> 2582 | close |
| `pal_g20` | paladin | 0,93 | 0,290 | 0,108 | 0,30 | 0,196 | 0,012 | 0,18 / 0,19 / 0,26 | 0 | 0 | 0 -> 0 | 0 -> 26 | 0 -> 3865 | close |
| `pal_g25` | paladin | 1,09 | 0,290 | 0,181 | 0,34 | 0,200 | 0,092 | 0,11 / 0,12 / 0,26 | 0 | 0 | 0 -> 56 | 0 -> 26 | 0 -> 3479 | mid |
| `pal_g30` | paladin | 1,12 | 0,290 | 0,203 | 0,34 | 0,198 | 0,113 | 0,12 / 0,10 / 0,20 | 0 | 0 | 0 -> 88 | 0 -> 26 | 0 -> 3025 | mid |
| `pal_t5` | paladin | 0,90 | 0,290 | 0,132 | 0,22 | 0,199 | 0,032 | 0,18 / 0,17 / 0,26 | 0 | 0 | 0 -> 0 | 0 -> 26 | 0 -> 4913 | close |
| `pal_t10` | paladin | 0,90 | 0,290 | 0,132 | 0,22 | 0,199 | 0,032 | 0,18 / 0,17 / 0,26 | 0 | 0 | 0 -> 0 | 0 -> 26 | 0 -> 7273 | close |
| `pal_t15` | paladin | 1,18 | 0,290 | 0,104 | 0,34 | 0,196 | 0,012 | 0,16 / 0,19 / 0,17 | 0 | 0 | 0 -> 228 | 0 -> 26 | 0 -> 3900 | close |
| `pal_t20` | paladin | 1,13 | 0,290 | 0,225 | 0,34 | 0,196 | 0,132 | 0,13 / 0,14 / 0,16 | 0 | 0 | 12 -> 30 | 0 -> 26 | 0 -> 2061 | far |
| `pal_t25` | paladin | 1,18 | 0,290 | 0,104 | 0,34 | 0,196 | 0,012 | 0,16 / 0,19 / 0,17 | 0 | 0 | 0 -> 228 | 0 -> 26 | 0 -> 3900 | close |
| `pal_t30` | paladin | 1,19 | 0,290 | 0,255 | 0,34 | 0,195 | 0,161 | 0,13 / 0,16 / 0,14 | 0 | 0 | 8 -> 20 | 0 -> 26 | 0 -> 544 | far |
| `(no style)` | paladin | 1,25 | 0,290 | 0,122 | 0,34 | 0,199 | 0,032 | 0,18 / 0,17 / 0,21 | 0 | 0 | 0 -> 120 | 0 -> 1098 | 0 -> 4094 | close |
| `bis_s5` | bishop | 0,85 | 0,290 | 0,113 | 0,22 | 0,197 | 0,012 | 0,19 / 0,20 / 0,26 | 0 | 0 | 0 -> 0 | 0 -> 501 | 0 -> 1120 | close |
| `bis_s10` | bishop | 0,87 | 0,290 | 0,132 | 0,22 | 0,200 | 0,032 | 0,18 / 0,18 / 0,26 | 0 | 0 | 0 -> 0 | 0 -> 501 | 0 -> 2093 | close |
| `bis_s15` | bishop | 1,01 | 0,290 | 0,115 | 0,22 | 0,194 | 0,012 | 0,18 / 0,19 / 0,24 | 0 | 0 | 0 -> 0 | 0 -> 501 | 0 -> 2241 | close |
| `bis_s20` | bishop | 0,90 | 0,290 | 0,114 | 0,22 | 0,196 | 0,012 | 0,18 / 0,19 / 0,26 | 0 | 0 | 0 -> 0 | 0 -> 501 | 0 -> 990 | close |
| `bis_s25` | bishop | 0,90 | 0,290 | 0,124 | 0,30 | 0,199 | 0,032 | 0,21 / 0,14 / 0,26 | 0 | 0 | 0 -> 0 | 0 -> 501 | 0 -> 372 | close |
| `bis_s30` | bishop | 1,11 | 0,290 | 0,229 | 0,26 | 0,198 | 0,131 | 0,12 / 0,10 / 0,21 | 0 | 0 | 0 -> 0 | 9 -> 501 | 0 -> 444 | far |
| `bis_b5` | bishop | 0,92 | 0,290 | 0,114 | 0,22 | 0,196 | 0,012 | 0,18 / 0,19 / 0,26 | 0 | 0 | 0 -> 0 | 0 -> 501 | 0 -> 1360 | close |
| `bis_b10` | bishop | 0,88 | 0,290 | 0,132 | 0,22 | 0,199 | 0,032 | 0,18 / 0,18 / 0,26 | 0 | 0 | 0 -> 0 | 0 -> 501 | 0 -> 2130 | close |
| `bis_b15` | bishop | 0,95 | 0,290 | 0,208 | 0,30 | 0,196 | 0,113 | 0,18 / 0,10 / 0,26 | 0 | 0 | 0 -> 0 | 36 -> 501 | 0 -> 226 | mid |
| `bis_b20` | bishop | 0,97 | 0,290 | 0,135 | 0,22 | 0,195 | 0,033 | 0,17 / 0,15 / 0,25 | 0 | 0 | 0 -> 0 | 0 -> 501 | 0 -> 2612 | close |
| `bis_b25` | bishop | 0,90 | 0,290 | 0,105 | 0,30 | 0,199 | 0,012 | 0,18 / 0,14 / 0,26 | 0 | 0 | 0 -> 0 | 0 -> 991 | 0 -> 1553 | close |
| `bis_b30` | bishop | 1,11 | 0,290 | 0,126 | 0,34 | 0,195 | 0,032 | 0,15 / 0,14 / 0,20 | 0 | 0 | 0 -> 0 | 0 -> 704 | 0 -> 1396 | close |

Reading the table:

- **26 close** (air 0.01-0.05 m; 27 rows with the no-style shield): every shield up to about 1.2 m tall, the small set shields, and
  three big ones whose bulk sits below the arm (`juramento`, `sol`, `prisma`).
- **7 mid** (0.07-0.11 m): `asa`, `escama`, `coluna`, `cruel`, `pal_g25`, `pal_g30`, `bis_b15`.
- **10 far** (0.13-0.19 m): `presa`, `perdao`, `serpente`, `pal_t20`, `bis_s30` (0.13), `pal_t30` (0.16), and four that
  barely moved: `relicario`, `veredito`, `asa_negra`, `suspiros` (0.19). These are the 1.3-1.6 m shields with spikes or
  wings on the arm side; anything closer puts them into the head in guard or the legs in run. They still lost the gold
  rods and got the strap, but their two steel spacers are long and they read as before.
- `shield_mount.py --check` is 0 on every clip for both kits (rule unchanged). On the denser frame set the male body is
  also 0 everywhere. The female body is 0 except `asa_negra` in run (13; it was 5 with the old mount).
- **Cost of going close**: set helmets are touched more on 17 styles (worst `pal_t15`/`pal_t25` 228, `cruel` 290,
  `coluna` 264: a tip grazing a crest or horn in guard); set chest/skirt overlaps appear on all (the constant 501 on
  common shields and 26 on paladin set shields is the strap alone, lying on the chest in guard). 23 styles touch no set
  helmet at all.
- "Body clearance" after the change is not listed: the strap is part of the shield mesh now and sits on the arm, so the
  number collapses to 0.01-0.06 m for every style and says nothing about the plate.

## 5. What changed

- `tools/blender/chibi_kit.py`: `SHIELD_MOUNTS` has an entry for all 43 styles (generated block). `kit_shield` joins the
  strap (`kit_shield_strap`: leather band + two steel spacers) into the shield mesh before the welded outline;
  `kit_shield_grip` and the separate `wpn_off_grip` / `wpn_off_grip_tabuas` nodes are gone. The no-style shield of the
  player kits uses the `juramento` mount. Humanoid monsters keep the old far mount with no strap
  (`kit_shield(..., close=False)`), so no monster model changes on a rebuild.
- `game/entities/kit_model.gd`: the two lines that switched the grip node on are removed (3 lines net).
- `tools/blender/shield_mount_study.py` (new): measures, searches, renders before/after; rebuilds the old mount itself
  for the "before" side, so it stays re-runnable. `tools/blender/shield_mount_apply.py` (new): writes the search result
  into `chibi_kit.py`. `shield_mount.py`: docstring only.
- `.claude/docs/ragnaex/conteudo.md`: shield entry explains the close mount and the two commands.
- Rebuilt: all 18 `kit_*.glb`. Regenerated: 43 shield icons.

## 6. Mesh budget

| Kit | master | shield-fix base | now |
|---|---|---|---|
| `kit_paladin_<sex>` | 196 | 197 | **195** |
| `kit_bishop_<sex>` | 176 | 177 | **175** |
| others | unchanged | unchanged | unchanged |

Zero meshes added; two removed (the common grip and the `tabuas` grip). Shield vertices went from 21 744 to 25 528 over
the 43 styles (+88 per shield for the strap). Draw calls are unchanged: the worn pieces were already merged per
character.

## 7. Verification

- `shield_mount.py -- --check`: 0 / 0 / 0 for paladin and bishop.
- Godot `--import` clean; full suite **78491 passed, 0 failed** (an earlier run in this session, before the last mount pass, gave 78494 / 0; the 3-check difference was not traced); smokes paladin, bishop, berserker: `SMOKE OK`, 0 `SCRIPT ERROR`.
- `--block_shot` ran for `shield_iron`, `shield_deus_guerra`, `shield_muro_suspiros`, `shield_defensor_castelo` with 0
  script errors (`game_block_*.png`). These shots are taken from the game camera in the crowded plaza and during the
  hit flash, so they prove the kits load and block in game but are too far to judge the mount; judge it on the sheets
  and on `lineup_*.png`.
- Icons: `icons_antes_depois.png` (top row of each pair = before). The art is the same; the strap is hidden behind the
  plate on all but a faint edge on the spiky ones listed below.

Evidence in `production/qa/evidence/shields-mount/`:
`shields_01.png` .. `shields_08.png` (per shield: idle front / side / game camera, guard front / side, each before and
after; rendered in Blender with flat materials, not the game's toon shader), `lineup_idle_pN.png` and
`lineup_guard_pN.png` (game shader), `icons_antes_depois.png`, `game_block_*.png`, `study_final.json` (all numbers),
`study_search.json` (the search result that was applied).

## 8. Axes rollout merged here

At the coordinator's request this worktree took the axes work from `../axes` so one branch carries both:
copied as-is `tools/blender/{axe_kit,berserker_sets,mob_kit,act2_bosses,kharzun_mobs}.py`, `tools/icons/item_icons.gd`,
`tools/lineup/lineup.gd`, the 8 rebuilt monster GLBs and the changed icons; `chibi_kit.py` was merged three-way against
`../ground-clip` with no conflicts. The kits were then rebuilt here: `kit_berserker_*` has the same 158 meshes, with the
same names, as the axes worktree. Not taken: the axes QA doc and evidence folder (still only in `../axes`).

## 9. Open items

1. ~~Strap visible past the plate edge~~ fixed in section 10.
2. **The ten "far" shields** need a different answer if they must hug the arm: a lower, wider guard pose for tall
   shields, or trimming the arm-side spikes (`shield_kit.INNER`). Both change the look and were out of scope.
3. **Set helmets**: the 17 styles with more helmet contact were not reviewed set by set in game.
4. **Monsters with shields** (`mob_loyal_paladin`, `mob_skel_guard`, one more humanoid, and the Kharzun tower shield)
   still float at the old distance with no strap; they were measured on no body here.
5. `asa_negra` on the female body in run (13 overlaps, was 5).
6. ~~`docs/shields_review.md` still describes the old `wpn_off_grip` support~~ updated (section 10).

## 10. Round 2: strap trimmed to the plate, docs, combined-branch verification

**Strap trim.** `chibi_kit.kit_shield_strap(base, style, mats, plate)` now clips each strap part (leather band, two
spacers) to the silhouette of the plate seen along the face normal, which is the icon view: 6 mm grid, largest covered
rectangle of the part's own box, cut 12 mm inside the edge (`STRAP_MARGIN`), cut faces closed. A part that is already
behind the plate is not touched. Holes inside the plate count as covered, except for the styles in `STRAP_HOLES`
(`pal_g30`: the strap showed through the gold ring). `STRAP_CLIP = False` rebuilds the whole strap for comparison.

Strap vertices outside the plate silhouette, front view (of 44), before -> after:

| Style | Before | After | What was cut |
|---|---|---|---|
| `asa` | 4 | 0 | band, one side |
| `presa` | 13 | 0 | band one side, elbow spacer shortened |
| `escama` | 6 | 0 | band, one side |
| `cruel` | 13 | 0 | band (most of it), both spacers |
| `pal_g25` | 20 | 0 | band and both spacers, one side |
| `pal_g30` | 3 | 0 | band, inside the ring opening |
| `bis_s25` | 10 | 0 | band and elbow spacer, one side |
| `bis_b25` | 2 | 0 | band, one side |
| `sol` (not on the list) | 8 | 0 | both spacers |
| `prisma` (not on the list) | 1 | 0 | wrist spacer |
| `veredito` | 1 | 0 | wrist spacer |

`serpente` had no strap vertex outside the plate and was not changed. `juramento` (2) and `tabuas` (1) show a strap
vertex through a small gap inside the plate, not past the edge; left as they are. The other 30 styles have 0.
From above and from behind the arm and what is left of the strap are still in view; only the front silhouette was the
target.

- Meshes: `kit_paladin_<sex>` 195, `kit_bishop_<sex>` 175 (unchanged). Only these four kits were rebuilt; the
  generic kits carry the no-style shield (`juramento` mount), which did not change.
- `shield_mount.py -- --check`: 0 / 0 / 0 for both kits.
- Icons: `tools/icons/shield_icons.gd` gained `-- --only=<style>,...`; the 11 styles were re-photographed and 10 files
  changed (`shield_luz_cristal`, the `prisma` icon, came out byte-identical).
- Not redone: `shields_01..08.png` and `study_final.json` still show the whole strap on these 11 styles.

Evidence in `production/qa/evidence/shields-mount/straps/`: `alca_icone_jogo_guarda_01..03.png` and
`alca_frente_corrida_guardajogo_01..03.png` (whole vs trimmed per style; Blender flat materials),
`icones_antes_depois.png` (top row before), `strap_vertices_fora.json`.

**Docs.** `docs/shields_review.md` has a new section "Montagem rente" and marks the old grip text as history;
`.claude/docs/ragnaex/modelos.md` has the `axe_kit.py` line and the shield mount lines.

**Verification of the combined branch** (ground-clip + axes + shield mounts + strap trim, after the last rebuild):

| Check | Result |
|---|---|
| `--import` | clean, 0 errors |
| Full suite | 78536 passed, 0 failed (one run) |
| `combat_probe` | `flags=0` |
| `anim_probe`, default models (1327 rows) | 0 rows differ from the ground-clip run on the 124 rows both cover |
| `anim_probe`, the 10 kits/forms of the ground-clip run + 3 more kits | 417 of 436 rows identical; the 19 that differ are all `kit_berserker_male` (new axes) |
| Smokes berserker, paladin, bishop, druid | `SMOKE OK`, 0 `SCRIPT ERROR` each |
| Lineup strips, Durgash signature shot | 14 shots, 0 script errors |

Berserker rows that changed: largest turn per 60 Hz step did not rise on any clip (kit maximum still 64, `atk_finisher`,
same as the other kits). One thing to look at: in `dash` the right hand now ends 171 degrees from where it starts (was
99); the axe swings round behind the body during the dash (`berserker_dash_male.png`). The step peak there is 18, so
it is a pose question, not a pop.

Evidence in `production/qa/evidence/art-branch-verify/`: `berserker_<carniceiro|executor>_tiers_<male|female>.png`,
`berserker_atk_2h_<male|female>.png`, `berserker_dash_male.png`, `paladin_shields_<guard|idle>_p<0|1>.png`,
`paladin_block_shield_strip_front.png`, `durgash_attack_strip.png`, `durgash_sig/boss_durgash.png` (Machado do Trono
in the fight), `anim_probe_vs_ground_clip.txt`, `anim_probe_kits_vs_ground_clip.txt`.
