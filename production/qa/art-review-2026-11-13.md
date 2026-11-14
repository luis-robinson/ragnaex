# Art review: Act II / Kharzun final QA (2026-11-13)

Read-only review of the screenshots in `production/qa/evidence/`. Evidence paths below are relative to that folder.
Style bar: Tree of Savior chibi, pastel, 3-tone toon + outline, 52° camera (`estilo.md`, `modelos.md`, `zonas.md`);
Kharzun intent from GDD `ato2-horda.md` §757: "rocha escura e basalto, rios de lava **laranja**".
Ignored (known): Durgash throne empty, Aldara portal road pale band, `toon_side__*` / `*__toon.png`.

**Coverage:** I looked at all 11 `boss-signatures/boss_*.png`, the 3 `glow__*__after`, the `mob_ghar|dire_mother|ulgra_after`,
3 of 5 `roster-40/*_after`, 3 `sig-props`, and the `final-qa` tours. Tours covered: kharzun after 00/01/03/04/06/08/09/11,
citadel 00/02/05/07/09, dg_slayers 00/02/04, aldara after 07/17, coast after 08, and the artifacts (santuario/portao/floresta).
**Not reviewed:** the other aldara/coast tour frames (including coast 03 mae_das_mares), kharzun 02/05/07/10, citadel 01/03/04/06/08/10-13,
dg_slayers 01/03, `boss-models/strips/*` (other than glow), `mob_kragmar|troll_king|crossbow_master_after`,
`roster-40` dire_wolf/troll_thrower, and 10 of the 13 sig-props.

## HIGH

1. **Arena floor art uses the telegraph vocabulary.** The arenas have permanent rings, dashes and arcs painted on the floor:
   red/yellow slashes in the citadel patio, cream/dark rings in the wolf arena, a purple/cream spiral in Shazka's hall, and dashed rings in the
   dg_slayers gallery. These show up even with no attack in progress, so the player cannot tell the real warning from the decoration.
   In `boss_shazka.png` the signature attack is lost in the floor spiral.
   Evidence: `final-qa/kharzun_citadel/tour_kharzun_citadel_02_patio.png`, `..._05_arena_lobo.png`, `final-qa/dg_slayers/tour_dg_slayers_04_mestre.png`, `..._02_galeria.png`.
   Fix: decoration on the floor should use only low-contrast, low-saturation tones close to the floor colour (value change ≤15%), with no red, purple or yellow.
   Keep saturated rings, arcs and fills for telegraphs only. **Layer: Blender builder** (`act2_dress`/arena dressing in the citadel and dungeon builders).
2. **Lava reads as sand or a safe zone.** Lava rivers and pools are pale cream/yellow with no glow. They look the same as Kharzun roads,
   and the same as the *safe* sand islands of the Tide Mother fight. In `boss_kragmar.png` the lava pool is a cream disc that a player
   would step onto as if it were safe. This also contradicts the GDD's "orange lava".
   Evidence: `final-qa/after/field_kharzun/tour_field_kharzun_08_ponte_norte.png`, `..._09_forja.png`, `boss-signatures/boss_kragmar.png`, `sig-props/prop_kragmar_lavapool_preview.png`.
   Fix: make lava a saturated orange → red-orange core with an emissive `glow_*` material and a bright yellow rim only at the banks.
   Roads and paths must never use that hue. **Layer: Blender builder** (zone lava material + `prop_kragmar_lavapool`).
3. **The whole screen is red in some fights, so there is no safe colour.** The Agitator (Grukk) and Kragmar arenas have red floors,
   with red/orange telegraphs on top of them. The forge (fundição) floor is also red-orange. Danger then covers 100% of the view.
   Evidence: `boss-signatures/boss_agitator_lord.png`, `boss_kragmar.png`, `final-qa/kharzun_citadel/tour_kharzun_citadel_09_fundicao.png`.
   Fix: put the arena floors back on desaturated basalt (grey-brown) so red stays reserved for danger. If the drum aura needs an area,
   draw it as an outline ring rather than a fill. **Layer: Blender builder** (floors) and **game view** (aura fill alpha).
4. **Floating combat text stacks into an unreadable block.** Repeated "Esquiva!" pops land on the same spot and cover the player's
   name, the HP bar and the boss name.
   Evidence: `boss-signatures/boss_crossbow_master.png`, `final-qa/after/field_kharzun/tour_field_kharzun_09_forja.png`, `final-qa/dg_slayers/tour_dg_slayers_02_galeria.png`, `boss_troll_king.png`.
   Fix: scatter the pops vertically and sideways, merge repeats into one "Esquiva! x5", cap visible pops at 3 per target, and drift them up and out.
   **Layer: game view** (fx/hud damage numbers).
5. **Pack nameplates overlap at mob packs.** At the wolf kennel (canil), about 15 nameplates sit on top of each other, so you cannot tell
   which mob is which role. Evidence: `final-qa/after/field_kharzun/tour_field_kharzun_03_canil.png`, `..._04_minas.png`.
   Fix: hide names on non-targeted trash when more than N mobs are within a small radius (keep the HP bar), and stagger the label height.
   **Layer: game view.**

## MEDIUM

6. **Telegraph styles are inconsistent.** Ghar uses a hollow red ring next to a filled orange cone; Dire Mother uses a solid opaque red rectangle with no rim;
   Gorbash uses *green* arcs for the expanding shockwave (green means safe or heal); clan guards use a pale white fan.
   Evidence: `boss_ghar.png`, `boss_dire_mother.png`, `boss_gorbash.png`, `tour_kharzun_citadel_02_patio.png`.
   Fix: use one grammar for every telegraph, with a semi-transparent fill (about 35%), a bright rim and a fill that grows as the hit approaches. Use red-orange for damage, purple for control,
   and never green or white for a hit. **Layer: game view / data** (skill vfx theme).
7. **Large always-on red circles** (aura or leash radius) cross the field. They read as AoE warnings. Evidence: `final-qa/after/field_coast/tour_field_coast_08_palafitas.png`, `..._field_kharzun_04_minas.png`.
   Fix: thin dashed rim at low alpha, or show only while the player is inside or approaching. **Layer: game view.**
8. **Unshaded flags and banners.** These are flat red or yellow quads with no toon shading and no outline, and they look like placeholders.
   Evidence: `boss_dire_mother.png` (red board lower left), `tour_field_kharzun_03_canil.png`, `tour_field_coast_08_palafitas.png`.
   Fix: assign the toon `tint` material and add an outline, a cloth fold or a hem. **Layer: Blender builder.**
9. **Pure-black basalt rocks** lose all form. With no toon bands visible they read as holes in the ground.
   Evidence: `tour_field_kharzun_08_ponte_norte.png`, `..._09_forja.png`.
   Fix: raise the lowest value to about 15-20% grey-violet so all 3 toon bands show. **Layer: Blender builder** (material colour).
10. **Shazka decoys render as blurry black smudges** rather than readable copies. Evidence: `boss_shazka.png`.
   If the decoys are meant to be convincing, use the real model with a subtle tell (a smoke wisp at the feet). If they are meant to be obvious, use a clean purple silhouette.
   Today they read as a rendering bug. **Layer: game view.**
11. **Large objects near the camera block the view.** These include a giant tan cone (crossbow master), a huge white boulder with tusks (Dire Mother) and the white bone arches by the Troll King.
   Each covers 20-30% of the frame. Evidence: `boss_crossbow_master.png`, `boss_dire_mother.png`, `boss_troll_king.png`.
   Fix: give them occlusion fade, or move them out of the boss approach path. They also look oversized next to the 1.7 m chibi.
   **Layer: Blender builder** (placement/scale), **game view** (fade).
12. **Boss name and shout text collide.** Boss lines are drawn over the boss nameplate and its status icons (Ghar, Grukk), and the Tide Mother line is drawn twice
   (one ghost copy). Evidence: `boss_ghar.png`, `boss_agitator_lord.png`, `boss_tide_mother.png`.
   Fix: move shouts to a fixed band under the top of the screen and de-duplicate them. **Layer: game view (hud).**
13. **Z-fighting band at the dwarf shrine is still present after the fix.** Evidence: `final-qa/artifacts/after_field_kharzun_santuario_anoes_52.png` (striped band below the shrine,
   the same as in `before_`). A thick black crack bar on the plaza also reads as a gap: `final-qa/after/field_kharzun/tour_field_kharzun_06_santuario_anoes.png`.
   Fix: separate the overlapping patches with `Zone.patch(y=)`, and make the crack thinner or drop it to the floor value. **Layer: Blender builder.**
14. **Gorbash looks washed out.** The grey body with grey moss has low value contrast and a faint outline, so the boss reads as a grey blob
   (`boss-models/strips/godot/glow__act2_bosses__after.png`, `boss_gorbash.png`). Fix: darker rock base and brighter moss/rune accents. **Layer: Blender builder.**

## LOW

15. **The camp bonfire is untextured.** The tan cone on a grey pedestal reads as a placeholder (`tour_field_kharzun_00_acampamento.png`). Fix: add a flame material plus ember particles. **Blender + game view.**
16. **The Aldara portal label renders behind the HUD player panel** ("…(Lv 20-30)") in `final-qa/after/city_aldara/tour_city_aldara_17_portal_ruinas.png`. Fix: clamp world labels out of HUD rects. **Game view.**
17. **Translucent yellow hex blobs on the Aldara plaza** look unfinished (`tour_city_aldara_07_hub.png`). Fix: confirm what they are; if they are gather or light spots, give them an outline or icon. **Game view / data.**
18. **Ulgra's banner pole and spear cut through the rider's arm and helmet** in the back and side views (`boss-models/mob_ulgra_after.png`). **Blender builder.**
19. **The clan guard's back standard reads as a floating head** above the crest (`roster-40/mob_clan_guard_after.png`, front view). Fix: thicken the pole or lower it. **Blender builder.**
20. **Stray dark triangle shards on open ground** (`tour_field_kharzun_00_acampamento.png`, `..._04_minas.png`). Check whether they are intended scatter. **Blender builder.**
21. **Ally and NPC nameplate size varies a lot between shots**: tiny in `boss_ulgra.png` and `boss_gorbash.png`, normal in the others. Fix: use a pixel size that does not depend on distance. **Game view.**
22. **Low FPS seen in the shots:** 23 at the citadel gate, 25 in the Aldara hub, 30 at the north bridge (perf, not art; flagged only because it is visible in the evidence).

## Looks good

- **Mob roles read well at 52°.** Clan guards (tan helmet, red crest, tower shield), fire archers (yellow flame mohawk), crossbowmen (wide grey hat),
  assassins (purple hood with green ears) and recruits vs warriors (green vs dark helmet) are all separable in `tour_kharzun_citadel_02_patio.png` and `tour_dg_slayers_02_galeria.png`.
- **Boss silhouettes are strong and on-style.** Ghar (horned helm, raven shield, skulls), Dire Mother (spears stuck in the back, white spiky mane), Ulgra's wolf-skull helm and Kragmar's glowing hammer
  tell their stories (`boss-models/*_after.png`, `glow__runes_reticle_hammer__after.png`).
- **The best telegraphs:** Ulgra's three chevron stampede lanes (`boss_ulgra.png`), the Tide Mother sand islands as safe spots (`boss_tide_mother.png`),
  and the crossbow master's reticles over the allies (`boss_crossbow_master.png`). Use these as the template for issue 6.
- **The Kharzun field palette** (dusty mauve ground, pale roads, palisades) stays pastel and coherent with Acts I and II.
  The citadel arrival and the poison pools (`tour_kharzun_citadel_00_chegada.png`, `..._07_pocas.png`) are clean and readable.
- **The HUD frame** (action bar, minimap, chat, quest panel) is consistent across every shot, and the hotbar stays legible over red floors.
