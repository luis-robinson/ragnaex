# Art review round 2: Act II / Kharzun (2026-11-13)

Read-only review. Paths are relative to `production/qa/evidence/`. The style bar is the same as round 1 (`art-review-2026-11-13.md`).
**Result:** 4 FIXED, 6 PARTIAL and 12 OPEN out of the 22 round-1 issues. Items 18 and 19 have no new shots, so they stay OPEN as unverified.

**Reviewed:** `final-qa/arena-fix/sig/*` (3), arena-fix `after_*_CAM_poi` for patio, wolf arena and gallery, arena-fix game shots for dg_slayers 01/03/04,
all 6 `telegraph-fix/*`, polish2 game shots for kharzun 00/03/04/06/08/09 and citadel 02/05/09, polish2 Blender shots for the flags and the hub,
after2 aldara 07/13/17, mount-ui keeper_2 and dire_wolf_mounted, roads kharzun/coast/steppe road_0-1,
`boss-models/mob_kragmar|troll_king|crossbow_master_after`, and the sig-props throneaxe, warbanner, shockring, floodring, vorgul_brand, wardrum and decoy_smoke.
**Not reviewed:** these were skipped because of the turn limit.
- `final-qa/field_coast/*` (coast 03 is only covered through `telegraph-fix/boss_tide_mother`).
- polish2 game shots for fort_trolls, fort_fire, field_steppe and dg_goblin, plus citadel 08 and 10-13.
- Most polish2 `CAMX` before/after shots, the arena-fix `*_arena_top` shots and the dg_goblin arena-fix shots.
- `ui-fix/after/*` (I used the later polish2 game shots instead), 15 of the 18 `roads/*` shots, and after2 aldara apart from 07/13/17.
- mount-ui keeper_1 and keeper_3, `boss-models/strips/**`, `roster-40/*`, and the sig-props ulgra_stampede, ghar_shieldwall, ghar_towershield, gorbash_shockshard and tide_island.
- `final-qa/tours2/` does not exist.

## Round-1 status

| # | Issue | Status | Evidence / note |
|---|---|---|---|
| 1 | Floor ornaments look like telegraphs | FIXED | `arena-fix/after_citadel_patio_CAM_poi.png`, `..._arena_lobo_...`, `..._dg_slayers_galeria_...`, `polish2/game/kharzun_citadel/..._02_patio.png`. The rings are now floor-tone. The wolf arena still has dashed concentric rings (low contrast); acceptable. |
| 2 | Lava reads as sand | FIXED | `polish2/game/field_kharzun/..._08_ponte_norte.png` and `arena-fix/sig/boss_kragmar.png`. The lava is saturated orange with a yellow vein. |
| 3 | Red arena floors | PARTIAL | Kragmar, Grukk and the fundição are now brown basalt (`arena-fix/sig/*`, `polish2/.../citadel_09_fundicao.png`). The Troll King arena is still a solid maroon-red floor (`telegraph-fix/boss_troll_king.png`), and the Durgash throne room is a dark red (`telegraph-fix/boss_durgash.png`). |
| 4 | "Esquiva!" stacking | PARTIAL | Repeats now merge into one "×N" (`polish2/.../citadel_09`: "×10"). There are still 2 stacks per target: a ghost "Esquiva!" sits under "Esquiva! ×2" (`arena-fix/game/dg_slayers/..._01_vestibulo.png`), and there are two "×2" stacks in `telegraph-fix/boss_troll_king.png`. |
| 5 | Pack nameplates | FIXED | `polish2/game/field_kharzun/..._03_canil.png`: only 2 names are left. |
| 6 | Telegraph grammar | PARTIAL | Gorbash is now an orange ring and Dire Mother an orange rect with a rim (`telegraph-fix/*`). Still off: the impaler line is pink with no rim (`polish2/.../04_minas.png`); Durgash uses a large yellow fill with green and white dashed rings (`telegraph-fix/boss_durgash.png`). |
| 7 | Always-on large red circles | OPEN | `polish2/.../04_minas.png` (a ring across the full screen) and `telegraph-fix/boss_troll_king.png` (a red arc at the top right). |
| 8 | Unshaded flags | PARTIAL | The Blender flags now have folds (`polish2/after_kharzun_flag_CAMX_bandeira_52.png`). In game they are still flat red quads with no outline (`polish2/.../03_canil.png`, `..._04_minas.png`, `roads/field_kharzun/road_0.png`, `telegraph-fix/boss_dire_mother.png`). |
| 9 | Pure-black basalt | FIXED | `polish2/.../08_ponte_norte.png` and `..._09_forja.png`: the basalt is slate-violet and shows its toon bands. |
| 10 | Shazka decoys look like smudges | PARTIAL | `telegraph-fix/boss_shazka.png`: one decoy is a translucent violet ghost, which reads well. The other is a black silhouette with red eyes, which still looks like a rendering hole. |
| 11 | Near props block the view | OPEN | The white tusk boulder and the palisade (`telegraph-fix/boss_dire_mother.png`), and the bone arches and white boulders (`telegraph-fix/boss_troll_king.png`). |
| 12 | Boss shout collides with nameplate | OPEN | The shout covers the boss name (`arena-fix/sig/boss_agitator_lord.png`, `telegraph-fix/boss_durgash.png`). The Tide Mother ghost duplicate is still there (`telegraph-fix/boss_tide_mother.png`). |
| 13 | Shrine z-fight and crack | PARTIAL | No stripes in `polish2/.../06_santuario_anoes.png`, but the thick black crack bar and a curved dark seam are still on the plaza. |
| 14 | Gorbash washed out | OPEN | `telegraph-fix/boss_gorbash.png`: a cream body with lime moss, low value contrast. |
| 15 | Bonfire placeholder | OPEN | `polish2/.../00_acampamento.png` and `polish2/after_kharzun_CAMX_hub_52.png`: a tan cone on a pale pedestal. It also covers the player. |
| 16 | World labels vs HUD | OPEN | `after2/city_aldara/..._17_portal_ruinas.png` (label behind the player panel). Labels also draw over the chat (`polish2/.../00_acampamento.png`) and below the hotbar (`after2/.../07_hub.png`). |
| 17 | Yellow hex blobs on the Aldara plaza | OPEN | `after2/city_aldara/..._07_hub.png` (2 blobs) and `mount-ui/keeper_2_unlocked.png`. |
| 18 | Ulgra pole clips the rider | OPEN (not re-shot) | No new evidence. |
| 19 | Clan guard standard | OPEN (not re-shot) | No new evidence. |
| 20 | Dark shards on the ground | OPEN | `polish2/.../03_canil.png`, right side. |
| 21 | Ally nameplate size varies | OPEN | Tiny in `telegraph-fix/boss_gorbash.png` and `boss_troll_king.png`, normal elsewhere. |
| 22 | Low FPS in shots | OPEN | 13 (`after2/.../13_castelo`), 24 (`polish2/.../04_minas`), 27-30 (Aldara hub), 28 (`telegraph-fix/boss_dire_mother`). This is perf, not art. |

## New issues

### HIGH
1. **Lava and damage telegraphs now share the same orange.** Lava was made orange, but the damage fill is also orange. In `polish2/.../citadel_09_fundicao.png` the player stands on an orange disc next to orange lava cracks, and you cannot tell which is the attack.
   The same happens next to the lava pool in `arena-fix/sig/boss_kragmar.png`.
   Fix: give telegraphs a separate cue: a bright cream/white rim, a fill that pulses and grows, and a red-orange hue (lean red). Keep lava orange with a dark crust and yellow veins, and never with a rim. **Layer: game view** (telegraph material).
2. **A red ring under every engaged mob.** In `polish2/.../04_minas.png` about 8 mobs each have a red ring, inside the large red leash ring and next to the impaler rect. Together they read as a dozen AoEs.
   Fix: show the ring only on the current target, as a thin neutral (cream) ring. Other aggro gets a small red pip on the nameplate instead. **Layer: game view.**
3. **Purple floor inlays in dg_slayers.** In `arena-fix/game/dg_slayers/..._01_vestibulo.png` there are 4 saturated violet rectangles, which is the control-telegraph colour (issue 6 grammar).
   Fix: drop them to a floor-tone violet, with value change ≤15% and low saturation. **Layer: Blender builder** (`build_dungeons` dressing).

### MEDIUM
4. **The Aldara welcome toast fires everywhere.** "Bem-vindo a Aldara… Fale com o Ancião Ravi" appears in Monte Kharzun (`telegraph-fix/boss_dire_mother.png`, stacked on the zone title and the boss line) and on a level-45 character in Aldara (`mount-ui/keeper_2_unlocked.png`).
   Fix: show it once, on the first Aldara visit of a new character. **Layer: game view / hud.**
5. **The mount keeper dialog is oversized.** About 70% of the panel is empty, world labels bleed through the translucent panel, and the item toasts overlap the Quests panel and the "Botica" label (`mount-ui/keeper_2_unlocked.png`).
   Fix: size the panel to its content, make the backdrop opaque (≥90%) or hide labels while a dialog is open, and stack toasts above the hotbar instead. **Layer: game view (UI).**
6. **Dire wolf mount is off-style.** It has glossy specular blobs, which break the matte 3-tone toon look. The rider sits on the neck and hides the wolf's head. At close zoom the nameplate covers the rider's head (`mount-ui/dire_wolf_mounted_kharzun.png`).
   Fix: set `spec_strength` to 0 on the wolf, move the saddle back, and use a constant pixel size for the nameplate (same fix as 21). **Layer: Blender builder + game view.**
7. **Troll King is washed out.** It is pale blue-grey with white armour and low value contrast, the same problem as Gorbash (`boss-models/mob_troll_king_after.png`).
   Fix: darker skin, darker iron, and a saturated accent for the crown and runes. **Layer: Blender builder.**
8. **Gorbash arena rings.** The green moss floor has about 6 dark concentric rings, which compete with his orange shockwave ring (`telegraph-fix/boss_gorbash.png`).
   Fix: lower their contrast the same way as issue 1, or break them into irregular cracks. **Layer: Blender builder.**
9. **Durgash telegraph off-grammar.** The large yellow filled disc, plus green and white dashed rings in the corners (`telegraph-fix/boss_durgash.png`). If the yellow means "stack here", document it as the one positive colour. Green and white must not be used for a hit. **Layer: game view / data.**

### LOW
10. **dg_slayers poison room.** The lime poison pools work as a hazard, but the blue discs with little figures are unexplained (`arena-fix/game/dg_slayers/..._03_venenos.png`). Fix: confirm what they are and add an icon or label. **Data / game view.**
11. **Crossbow master's crossbow.** The curved dark limbs read as spider legs, and the crossbow covers his face in the front view (`boss-models/mob_crossbow_master_after.png`). Fix: straighter limbs and a lighter stock. **Blender builder.**
12. **Kragmar's near-black body** loses its outline, and the hammer hides his head in the back view (`boss-models/mob_kragmar_after.png`). Fix: lift the black to the basalt value from issue 9. **Blender builder.**
13. **Boss shout with no boss on screen.** "Rei Javali: … (3 lutando: dano ×2.0)" shows with no boss in view, and the line includes the raw mechanic number. The `13_castelo` frame also does not show the castle (`after2/city_aldara/..._13_castelo.png`).
   Fix: limit shouts to players near the boss, and fix the tour framing. **Game view / tour data.**
14. **Shazka decoy smoke** uses the control colour, violet (`sig-props/prop_shazka_decoy_smoke_preview.png`). This is acceptable if decoys count as control; otherwise use a grey-violet smoke. **Blender builder.**

## Looks good
- The lava is now readable and on-GDD (`polish2/.../08_ponte_norte.png`). The basalt bands show, and the Kragmar arena fire cracks are striking (`arena-fix/sig/boss_kragmar.png`).
- Merged "Esquiva! ×N" and the hidden pack names make the Kharzun fights far cleaner (`polish2/.../03_canil.png`, `citadel_09`).
- The roads are a warm brown or tan in the open zones and stay distinct from the grass and water (`roads/field_coast/road_1.png`, `roads/field_steppe/road_0.png`).
- The sig-props `prop_horde_warbanner_sig` (shaded cloth and a skull emblem) and `prop_vorgul_brand` (a reticle with arrows) are on-style.
  The warbanner is the right model to replace the flat in-game flags (issue 8). Vorgul's brand is the best template so far for the telegraph rim.
