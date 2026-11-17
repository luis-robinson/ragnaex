# Act II set visuals (levels 35/40/45 + Ápice) — phase 1

Date: 2026-11-17. Status: all 8 classes built (sections 7-9; Paladin in the on-demand `_a2` kit). Sections 1-6 are the phase-1 record; where they differ, the later sections win.

User decision: one new visual per build for Act II; the Ápice set of the build shares it; 35/40/45 differ by
colour, trim and glow only (no new meshes per level). Theme: the Horde war on Monte Kharzun.

## 1. Inventory (before the pilot)

`GearCatalog.visual_of(sid)` returns the level-30 visual (flag `reuse`) for every level above
`OWN_VISUALS_UNTIL` (30); Ápice and hybrid sets asked for the level-30 visual directly.

| Class | Build (id) | 30 style | Sets that reuse it |
|---|---|---|---|
| Paladin | Guardião (guardiao) | pal_g30 | 35, 40, 45; hybrid armour of templario+guardiao takes templario's |
| Paladin | Cruzado (cruzado) | pal_c30 | 35, 40, 45; Ápice 35/40/45 |
| Paladin | Templário (templario) | pal_t30 | 35, 40, 45; hybrid templario+guardiao 35/40/45 (armour) |
| Berserker | Machados Gêmeos (carniceiro) | ber_g30 | 35, 40, 45; Ápice x3 |
| Berserker | Executor (executor) | ber_e30 | 35, 40, 45; Ápice x3 |
| Berserker | Punhos de Fúria (punhos) | ber_m30 | 35, 40, 45; Ápice x3 |
| Bishop | Sacerdote (sacerdote) | bis_s30 | 35, 40, 45 |
| Bishop | Iluminado (inquisidor) | bis_i30 | 35, 40, 45; Ápice x3 |
| Bishop | Clérigo de Batalha (batalha) | bis_b30 | 35, 40, 45; hybrid batalha+sacerdote x3 (armour) |
| Druid | Urso (guardiao_verde) | dru_b30 | 35, 40, 45; Ápice x3 (+ bear form armour) |
| Druid | Lobo (fera) | dru_w30 | 35, 40, 45; Ápice x3 (+ wolf form armour) |
| Druid | Xamã (xama) | dru_x30 | 35, 40, 45; Ápice x3 |
| Ranger | Caçador (cacador) | ran_c30 | 35, 40, 45; Ápice x3 |
| Ranger | Atirador (atirador) | ran_a30 | 35, 40, 45; Ápice x3 |
| Ranger | Lanceiro (lanceiro) | ran_l30 | 35, 40, 45; Ápice x3 |
| Assassin | Lâminas (laminas) | ass_l30 | 35, 40, 45; Ápice x3 |
| Assassin | Duelista (duelista) | ass_d30 | 35, 40, 45; Ápice x3 |
| Assassin | Corsário (corsario) | ass_c30 | 35, 40, 45; Ápice x3 |
| Elementalist | Fogo (fogo) | ele_f30 | 35, 40, 45; hybrid fogo+gelo x3 (armour) |
| Elementalist | Gelo (gelo) | ele_g30 | 35, 40, 45; hybrid gelo+raio x3 (armour) |
| Elementalist | Raio (raio) | ele_r30 | 35, 40, 45; hybrid raio+fogo x3 (armour) |
| Necromancer | Invocador (invocador) | nec_i30 | 35, 40, 45; hybrid invocador+ceifador x3 (armour) |
| Necromancer | Ceifador (ceifador) | nec_c30 | 35, 40, 45; hybrid ceifador+pestilento x3 (armour) |
| Necromancer | Sombras (pestilento) | nec_s30 | 35, 40, 45; hybrid pestilento+invocador x3 (armour) |

Totals: 24 builds (8 classes x 3; the brief said ~27), 72 build sets, 42 Ápice sets (14 builds), 24 hybrid sets (8 pairs).
Hybrid rule today: armour = build A's style in build B's colour; each weapon keeps its own build's style.

## 2. Mesh budget (limit: < 200 meshes per kit, `_check_character_models`)

Each set style costs 4 meshes (head, body, gloves, boots, joined by `paladin_sets.join_slots`); a set weapon is 1 mesh
per hand; a set shield is 1.

| Kit | Today | + armour (3 builds) | + weapons / shields if all new | Total | Fits |
|---|---|---|---|---|---|
| paladin | 195 | +12 | +6 (sword + mace per build) +2 shields | 215 | NO |
| bishop | 175 | +12 | +3 (2 maces, 1 sceptre) +2 shields | 192 | yes, tight |
| druid | 169 | +12 | +4 (staff, mace pair, maul) | 185 | yes |
| assassin | 164 | +12 | +7 (dagger pair, sword pair, sabre + pistol) | 183 | yes |
| elementalist | 163 | +12 | +3 staffs | 178 | yes |
| necromancer | 163 | +12 | +3 scythes | 178 | yes |
| berserker | 158 | +12 | +5 (axe pair, great axe, claw pair) | 175 | done (pilot) |
| ranger | 144 | +12 | +3 (bow, rifle, spear) | 159 | yes |

Proposal (nothing done yet):
1. Seven classes: build in-kit, exactly as the pilot.
2. Paladin (over by 16): `ACT2_VISUALS` already supports `"wpn"` and `"shield"` overrides, so the Act II sets can keep
   the level-30 swords, maces and shields. That gives 207, still over by 8. To close the gap, pick one:
   a. drop the common leather and cloth armour from the paladin kit (about 10 meshes) if the Paladin can never wear them — to be confirmed in `ItemSystem`;
   b. an on-demand add-on kit (`kit_paladin_<sex>_a2.glb`, attached to the same skeleton only when an Act II piece is worn). Costs KitModel work, but removes the ceiling for every later tier;
   c. Act II paladin sets as "armour only, 3 meshes": gloves joined into the body mesh (the gloves slot then shows nothing of its own).
   Recommended: (a) if the rule allows, else (b).
3. Druid Lobo/Urso also need form armour (`druid_sets.build_forms`, `form_wolf.glb` / `form_bear.glb`): +1 style each in the form files.
4. Kit file size grows about 1 MB per class (berserker 6.0 -> 7.1 MB).

## 3. How the per-level variation works (implemented in the pilot)

- `GearCatalog.ACT2_VISUALS["<class>_<build>"] = {style, colors[3], glows[3], (wpn), (shield)}`, indexed by `Balance.HYBRID_LEVELS` (35, 40, 45).
- `colors[i]` is the item colour (`tint`); the accent (`tint2`) is derived from it as always (`ItemDef.accent`).
- `glows[i]` paints the materials named `tint_glow` (emission 2.0) and `tint_glow_edge` (axe edge, emission 1.0) of the kit:
  `KitModel` keeps them in `_glows` and reads `GearCatalog.set_glow(item.set_id)`. No schema change, no new ItemDef field.
- Ápice: same meshes; colour = `apex_color(colors[i])` (25% darker + 20% gold, rule R-AP5 unchanged); same glow as the level.
- Hybrid: armour = build A's Act II style in build B's level colour (same rule as before, now per level).
- Names and icons still follow the "reused" rule (generic names; level-30 icons).

Colour ladder (rule for every class): 35 = "iron of Kharzun" (earthy, low saturation, warm glow);
40 = "war banner" (the build's saturated war colour, cold or gold glow); 45 = "apogee" (very dark or very pale plate, strongest glow).

## 4. Design sheet

Head and shoulders first (52 degree camera). Every look has one back/top piece that the 30 set does not have.

### Berserker (PILOT, built)

| Build | Style | Head | Shoulders | Body | Back piece | Weapon | 35 / 40 / 45 colour (glow) |
|---|---|---|---|---|---|---|---|
| Machados Gêmeos | ber_g35 "Montador de Warg" | warg skull over a leather hood, glowing sockets, dyed mane crest (tint2) from brow to nape | boar tusks on BOTH shoulders over fur and an iron plate | wide bandolier, iron chest disc with lit rune, fang necklace, hip skull trophies | grey wolf pelt half-cape with tail | dark cleaver axes, lit edge, back spike, tassel | rust ochre (ember) / steel blue (frost) / obsidian (blood) |
| Executor | ber_e35 "Quebra-Hordas" | bucket helm, lit cross visor, wide bull horns with gold rings, iron crest with three spikes, jaw tusks | three stacked plates with spike towers, fur trim, lit rune | high gorget, furnace grille with three lit slits, plate tassets | war banner on a tilted pole above the head (tint2 cloth, skull finial) | dark bearded great axe with hammer poll, lit edge | gunmetal (furnace orange) / bronze (pale gold) / bone white (crimson) |
| Punhos de Fúria | ber_m35 "Tambor do Trovão" | iron circlet with short gold horns and lit gem, tall horsetail (tint2), iron ridge | iron caps with gold spike on BOTH sides | vest, short rosary, champion belt with lit gold buckle | arc of five war drums behind the shoulders, lit marks | four long dark claws, lit knuckle bar; oversized iron gauntlets | storm indigo (lightning) / jade (gold) / vermilion (white gold) |

### Paladin (30: closed/open/great helm with crown, wings or flame + halo, wing pauldrons, sun emblem)

| Build | Style | Head | Shoulders | Body | Back piece | Weapon accent |
|---|---|---|---|---|---|---|
| Guardião | pal_g35 "Baluarte de Kharzun" | flat-top siege helm, transverse fan crest (tint2) | square tower pauldrons with merlons | fur collar, riveted belly plates | none (the tower shield is the back read) | keep 30 sword/mace/shield (budget) |
| Cruzado | pal_c35 "Lança da Aurora" | beaked sallet, long horsehair plume falling back | one giant right pauldron with spike, small left | long split tabard | fur-trimmed half cape over the left shoulder | lit fuller (tint_glow) if budget allows |
| Templário | pal_t35 "Chama de Guerra" | crowned great helm carrying a lit brazier | chain-draped shoulders with hanging lit censers | scale skirt | none | keep 30 |

### Bishop (30: crown / mitre / winged helm, wing shoulders, capelet, sun emblem)

| Build | Style | Head | Shoulders | Body | Back piece |
|---|---|---|---|---|---|
| Sacerdote | bis_s35 "Capelã de Campanha" | wide pilgrim hat with tassels | rolled blanket and bandage rolls | field robe, satchel belt | portable shrine backpack with lit candles |
| Iluminado | bis_i35 "Farol da Aurora" | open cage tiara with a lit orb floating above | long layered sleeves | plain tall robe | flat sun-ray collar behind the shoulders |
| Clérigo de Batalha | bis_b35 "Martelo da Vanguarda" | bascinet with chain aventail, swept side wings | single heavy plate mantle | armoured half-skirt, chained book on the hip | none |

### Druid (30: leaf crown / wolf hood / bear skull, leaf mantle, antlers)

| Build | Style | Head | Shoulders | Body | Back piece |
|---|---|---|---|---|---|
| Xamã | dru_x35 "Xamã da Estepe" | ram-skull mask, long feather war bonnet (tint2) down the back | bone talisman bundles | painted hide robe | the bonnet trail |
| Lobo | dru_w35 "Matilha de Guerra" | full wolf-head helm, face inside the open jaws | clawed pauldrons, spiked collar | studded leather | none (+ wolf form armour) |
| Urso | dru_b35 "Montanha Viva" | stone helm with moss ridge | stone slab pauldrons with lit crystals | bark and rock plates | stone shell with moss (+ bear form armour) |

### Ranger (30: circlet / tricorn / beast head, cape, quiver or bandolier)

| Build | Style | Head | Shoulders | Body | Back piece |
|---|---|---|---|---|---|
| Caçador | ran_c35 "Batedor da Estepe" | fur cap with hawk wings | hawk-feather mantle | light leather, twin quivers | steppe-grass ghillie cape |
| Atirador | ran_a35 "Artilheiro de Cerco" | pilot cap, goggles, brass scope monocle | crossed ammo belts | long coat | powder keg backpack with lit fuse |
| Lanceiro | ran_l35 "Caça-Trolls" | helm with two huge troll tusks rising from the jaw guards | troll-hide collar | hide vest | spined troll-hide cloak, javelin fan |

### Assassin (30: horned hood / plume hat / captain hat, torn cape or coat)

| Build | Style | Head | Shoulders | Body | Back piece |
|---|---|---|---|---|---|
| Lâminas | ass_l35 "Sombra da Horda" | wide war hat over a bone half-mask | none (slim) | wrapped leather, lit poison censer at the belt | two long scarf tails (tint2) |
| Duelista | ass_d35 "Lâmina de Gala" | cavalier hat, one huge feather | armoured left arm (manica), high collar | fitted coat | two spare blades crossed on the back |
| Corsário | ass_c35 "Costa de Ferro" | bicorne with skull badge | fur-collar greatcoat | anchor-chain belt | none |

### Elementalist (30: element hat/crown + second-element shoulders and orbs)

| Build | Style | Head | Shoulders | Body | Back piece |
|---|---|---|---|---|---|
| Fogo | ele_f35 "Forja Viva" | brazier crown with flame-shaped horns | magma-crack mantle (lit lines) | forge apron robe | floating ember ring |
| Gelo | ele_g35 "Geleira" | tall asymmetric ice-crystal crown | glacier shard pauldrons | layered frost robe | cape of ice shards |
| Raio | ele_r35 "Para-raios" | hat with a tall ringed rod | rod spires on both shoulders | banded robe | coil pack with lit arcs |

### Necromancer (30: bone crown / torn hood / tall hood with eye)

| Build | Style | Head | Shoulders | Body | Back piece |
|---|---|---|---|---|---|
| Invocador | nec_i35 "Ossuário de Guerra" | crown of finger bones | orc skull on each shoulder | rib-cage breastplate | spine-and-ribs frame rising behind the shoulders |
| Ceifador | nec_c35 "Ceifeiro do Campo" | tall pointed executioner hood | chains with lit lanterns | torn leather | strips of fallen banners as a cape |
| Sombras | nec_s35 "Eclipse" | veil mask | floating shards | plain dark robe | black sun disc with lit rim behind the head |

## 5. Pilot evidence

`production/qa/evidence/act2-sets/pilot/`: `<build>_30_35_40_45.png` (3/4 front), `..._back.png`, `..._gamecam.png`
(game camera, 52 degrees at 24 m), for carniceiro, executor and punhos. Left to right: 30, 35, 40, 45.

## 6. Follow-ups (not done)

- Icons: the Act II items still show the level-30 icons (`set_icons.tscn` needs a pass that reads `ACT2_VISUALS`, 3 colours per build).
- Names: Act II sets keep the generic tier names ("... da Ascensão"); proper set names per build are a writing task.
- `modelos.md` / `DESIGN.md` not updated yet (waiting for the look approval).
- In-game review with animation (run, dash, attacks) for the back pieces (banner, drum arc, pelt): only idle was photographed.

## 7. Wave 1A (2026-11-17): infra for all classes + Berserker update + Assassin

User approved the pilot look and the rollout. Changes to the rules in section 3:

- **Accent per level**: `ACT2_VISUALS[...]["accents"]` (3 colours) paints `tint2` (`GearCatalog.set_accent`, `KitModel`); without the key the old derived accent applies.
  Fixes the blue banner on the bronze Executor (now crimson). Hybrid: armour takes build B's colour AND accent.
- **Names**: `"name"` + `"suffix"` (+ `"nouns"`): pieces are `<noun> <suffix> <TIER_EPITHETS>` ("Elmo do Quebra-Hordas do Triunfo"), set is `Conjunto <name> <epithet>`
  (35 "da Ascensão", 40 "do Triunfo", 45 "do Apogeu": the same tier words the generic names already used). Apex and hybrid names unchanged.
- **Icons**: `"icon"` = style; `tools/icons/set_icons.tscn` photographs ONE set per build (level 40 colours) and all three levels, the Apex and the hybrid armour use it.

| Build | Name | 35 colour / accent / glow | 40 | 45 |
|---|---|---|---|---|
| Berserker Machados Gêmeos | Montador de Warg | rust ochre / dark red / ember | steel blue / pale bone / frost | obsidian / crimson / blood |
| Berserker Executor | Quebra-Hordas | gunmetal / dark red / furnace orange | bronze / crimson / pale gold | bone white / black / crimson |
| Berserker Punhos | Tambor do Trovão (head: Diadema) | storm indigo / pale blue-white / lightning | jade / gold ochre / gold | vermilion / black / white gold |
| Assassin Lâminas | Sombra da Horda (head: Chapéu) | ash leather / rust red / sickly yellow-green | toxic teal / pale straw / acid green | near black / bone white / magenta |
| Assassin Duelista | Lâmina de Gala | slate / burgundy / amber | crimson / ivory / pale gold | ivory / royal blue / ice blue |
| Assassin Corsário | Costa de Ferro (head: Bicorne, body: Sobretudo) | weathered brown / faded navy / lantern orange | navy / crimson / gold | black iron / bone white / ghost teal |

Assassin as built (`assassin_sets.py` `ACT2_SETS`): `ass_l35` wide conical war hat (accent band, lit ring, iron tip, bone talismans) over a bone half-mask with tusks,
kunai bandolier, lit poison censer + vials at the belt, two long scarf tails; daggers = dark kris with ring pommel and lit core. `ass_d35` cavalier hat pinned on the left with
one huge feather, high collar, plastron, armoured left arm (manica with neck guard), two spare swords crossed on the back with lit pommels; swords = leaf blade, swept + cup
guard, lit core. `ass_c35` large iron-trimmed bicorne with skull and crossbones (lit eyes), closed greatcoat with pale fur collar and shoulder capelets, anchor chain belt with
hanging anchor; sabre = dark cutlass with skull pommel, pistol = dark double-barrel blunderbuss with lit rune.

Mesh counts: kit_assassin 164 -> 182; kit_berserker 175 (unchanged). Evidence: `production/qa/evidence/act2-sets/assassin/` and `.../berserker/` (re-photo with the new accents).

## 8. Wave 3 (2026-11-17): Druid (with form armour) + names/icons for Ranger and Elementalist

| Build | Name (piece nouns) | 35 colour / accent / glow | 40 | 45 |
|---|---|---|---|---|
| Druid Xamã | Xamã da Estepe (head: Cocar) | hide tan / rust red / amber | teal / orange / spirit green | bone pale / deep violet / violet |
| Druid Lobo | Matilha de Guerra (head: Elmo, body: Couro) | gunmetal / dark red / ember | blood crimson / pale bone / gold | near black / ice white / ice blue |
| Druid Urso | Montanha Viva (head: Elmo, body: Casco) | granite / moss green / amber crystals | slate teal / gold lichen / cyan | obsidian / pale lichen / amethyst |
| Ranger Caçador | Batedor da Estepe | (colours of wave 1B) | | |
| Ranger Atirador | Artilheiro de Cerco (head: Touca, body: Casaco) | | | |
| Ranger Lanceiro | Caça-Trolls (head: Elmo) | | | |
| Elementalist Fogo | Forja Viva (head: Braseiro) | | | |
| Elementalist Gelo | Geleira | | | |
| Elementalist Raio | Para-raios | | | |

Druid as built (`druid_sets.py` `ACT2_SETS`, kept out of `DRU_SETS`): `dru_x35` hide hood under a ram skull (muzzle over the brow, lit sockets, curled horns with gold rings),
feather war bonnet from ear to ear (accent, white tips, lit centre bead) whose trail runs down the back to the hips, fur collar, tooth necklace, painted sun on the chest with a lit eye,
bone talisman bundles + small skull + feathers on both shoulders, painted hem (accent teeth, fringe); staff = ram skull with curled horns, lit eyes and crystal, hanging feathers.
`dru_w35` full wolf-head helm (upper jaw over the brow, lower jaw bars closing at the chin, fangs, lit eyes, tall ears, accent mane crest brow to nape), clawed pauldrons on both
shoulders, spiked collar with lit tag, crossed studded straps with a wolf skull, fur kilt, tail, knuckle claws; maces (both hands) = dark iron head inside six curved fangs, lit band.
`dru_b35` stone helm in slabs (brow, cheeks, cap) with an accent moss ridge and three lit crystals, stacked stone slabs on both shoulders with crystals and moss, bark torso with rock
plates and a lit crystal heart, stone shell on the back (slabs, moss, crystals), stone gauntlets and boots; maul = bound boulder with crystals on both faces and on top, moss patch.

Form armour (`druid_sets.ACT2_FORM` + `form_armor2`, same piece names/bones as the old sets): wolf `frm_dru_w35_*` = studded barding, accent mane crest on head and spine,
spiked collar with lit tag, brow plate with lit gem and bone spikes, clawed shoulder pads, spiked leg bands; bear `frm_dru_b35_*` = stone shell in slabs with three lit crystals and
moss, stone helm with crystals and moss ridge, rock collar, slab + crystal on the front shoulders, stone leg bands with moss rims. `FormModel` now paints `tint2` with the level accent
and `tint_glow` with the level glow. The ancestral forms got their Act II armour in the final pass (section 9.2).

Mesh counts: kit_druid 169 -> 185. form_wolf / form_bear: +6 meshes each. Evidence: `production/qa/evidence/act2-sets/druid/`.
Icons photographed (level 40): `dru_x35/w35/b35`, `ran_c35/a35/l35`, `ele_f35/g35/r35` (46 PNG in `assets/icons/`).

## 9. Wave 4 (2026-11-17): Paladin armour in an on-demand add-on kit

User decision: new Act II ARMOUR per build; the level-30 swords, maces and shields stay (`ACT2_VISUALS` `"wpn"`; the shield
already defaults to the 30 style); the armour meshes live in `kit_paladin_<male|female>_a2.glb`, loaded only when worn.

| Build | Name | 35 colour / accent / glow | 40 | 45 |
|---|---|---|---|---|
| Paladin Guardião | Baluarte de Kharzun | basalt grey / dark red / amber | royal blue / ivory / pale gold | obsidian / gold / ice blue |
| Paladin Cruzado | Lança da Aurora | weathered steel / rust / warm orange | crimson / ivory / gold | pearl white / royal blue / dawn rose |
| Paladin Templário | Chama de Guerra | dark bronze / near black / ember | orange gold / dark red / yellow flame | ash black / bone white / white-hot |

As built (`paladin_sets.py` `ACT2_SETS`): `pal_g35` flat-top siege helm (drum with iron band and rivets, lit eye slit, nasal bar, breath holes) under a transverse fan crest
(accent) from ear to ear, pale fur collar, high gorget, lit portcullis on the chest, riveted belly lames, back plate with a lit diamond, square tower pauldrons with merlons and a lit
arrow slit, square tassets, block gauntlets and knee plates with lit slits. `pal_c35` beaked sallet (pyramid snout, gold brow and comb, slanted lit eyes, side fins, neck tail) with a
long horsehair plume (accent) arcing back down to the waist, ONE giant four-lame right pauldron with a gold spike, fins and a lit gem, fur-collared half cape (accent) over the left
shoulder with a lit clasp, lit rising sun on the chest, long split white tabard (four panels, accent stripes), finned gauntlets, winged greaves. `pal_t35` crowned bucket helm with a lit
cross visor and an iron brazier on top (ember + six flames, all lit), white surcoat with the cross in the accent colour front and back, chains from shoulder to shoulder, lit censers
hanging from both pauldrons and on the back, three-row scale skirt, lit wrist rings and knee embers.

Add-on kit: `chibi_kit.A2_STYLES` / `build_kit_a2` (12 meshes, 0.8 MB per sex, same 19-bone skeleton, no clips); `KitModel.load_addon` (lazy, scene cached per path, meshes
attached to the kit skeleton with the main kit skin; fallback to the 30 style when the file is missing). Mesh counts: kit_paladin 195 (unchanged, not rebuilt); a character wearing an
Act II set carries 195 + 12. First-equip cost (`tools/tests/addon_probe.tscn`, windowed): 6.3-8.0 ms the first time per sex (read + attach), 0.2-0.3 ms for every later character.
Icons (level 40): `pal_g35/c35/t35_<head|body|gloves|boots|weapon|mace|mace2h>` + `pal_g35_offhand`, `pal_t35_offhand` (20 PNG).
Evidence: `production/qa/evidence/act2-sets/paladin/` (`<build>_30_35_40_45[_back|_gamecam].png`, `game_<build>_<lv>[_char...].png`).

## 9. Final pass (2026-11-17): names/icons Necromancer + Bishop, ancestral forms, animated review, colour nits

### 9.1 Names and icons (all 24 builds now have a proper name and their own icons)

| Build | Name (piece nouns) | Icon prefix |
|---|---|---|
| Necromancer Invocador | Ossuário de Guerra (head: Coroa, body: Couraça) | nec_i35 |
| Necromancer Ceifador | Ceifeiro do Campo | nec_c35 |
| Necromancer Sombras | Sol Negro (the sheet said "Eclipse": `Conjunto Eclipse` already exists at level 25) | nec_s35 |
| Bishop Sacerdote | Capelã de Campanha (head: Chapéu) | bis_s35 |
| Bishop Iluminado | Farol da Aurora (head: Tiara) | bis_i35 |
| Bishop Clérigo de Batalha | Martelo da Vanguarda | bis_b35 |

Bishop shields stay the level-30 meshes; their Act II items have their own icon files (`bis_s35_offhand.png`, `bis_b35_offhand.png`,
photographed by `shield_icons.tscn -- --only=bis_s30,bis_b30`; the two level-30 offhand icons were restored from backup after that run).

### 9.2 Ancestral forms (`druid_ancestral.ACT2_STYLE`)

| Form | Style | Armour |
|---|---|---|
| Lobo Alfa (`form_alpha`) | dru_w35 | the wolf's `form_armor2`: studded barding, accent mane crest, spiked collar with lit tag, clawed shoulder pads, spiked leg bands |
| Ent (`form_ent`) | dru_b35 | `ent_armor2`: ring of stone slabs round the canopy, three lit crystals, moss ridge, stone belt with lit buckle, rock collar, slab shell with crystals on the back, stone bracers + shoulder slab with crystal, stone rings on the roots |
| Pássaro Arcano (`form_bird`) | dru_x35 | `bird_armor2`: ram-skull cap with curled horns, feather bonnet (accent) with its trail down the back, tooth necklace, lit bead, wing bands with hanging feathers and a bone talisman, anklets |

The Act II meshes are left OUT of the ground passes (`skip=` in `clear_form_ground` / `clear_ent_ground`): all animation channels of the three GLBs are
byte-identical to the files before the rebuild (300 / 270 / 300 channels compared), so the ground fixes and the contact numbers of
`attack-arcs-wave6-spec.md` D/E are unchanged. Meshes: alpha 65 -> 71, ent 56 -> 64, bird 43 -> 49. Check: Act II block in `_check_ancestral_forms`.

### 9.3 Animated review of the back / shoulder pieces (level 35; run, dash, attack, cast, hit; side + 3/4 back, 6 frames each)

Films: `production/qa/evidence/act2-sets/final/anim/<class>_<build>_A.png` (side: dash, attack, cast, hit) and `_B.png` (back: run, attack, cast).
`hit` = the head tips far back for about 0.1 s; every chest-mounted piece that stands behind the head touches it there. That is left as is for all builds
(moving the pieces to the head bone would make them swing with every nod).

| Class / build | Piece | run | dash | attack | cast | hit | Verdict |
|---|---|---|---|---|---|---|---|
| Berserker Machados Gêmeos | wolf pelt half-cape | ok | ok | ok | ok | ok | ok |
| Berserker Executor | banner on tilted pole | ok | ok | ok | ok | touches head | left (hit only) |
| Berserker Punhos | drum arc | ok | ok | ok | ok | touches head | left (hit only) |
| Assassin Lâminas | scarf tails | ok | ok | ok | ok | ok | ok |
| Assassin Duelista | spare swords, feather | ok | ok | ok | ok | ok | ok |
| Assassin Corsário | greatcoat, fur collar | ok | ok | ok | ok | ok | ok |
| Ranger Caçador | ghillie cape, quivers | ok | ok | ok | ok | ok | ok |
| Ranger Atirador | powder keg | ok | ok | ok | ok | ok | ok |
| Ranger Lanceiro | javelin fan, troll cloak | ok | ok | ok | ok | touches head | left (hit only; the fan lies on the back of the head, no cut in the other clips) |
| Elementalist Fogo | ember ring | ok | ok | ok | ok | touches head | left (hit only) |
| Elementalist Gelo | ice-shard cape | ok | ok | ok | ok | ok | ok |
| Elementalist Raio | coil pack + arc | ok | ok | ok | ok | hat brim dips into the coils | left (hit only) |
| Druid Xamã | bonnet trail | ok | ok | ok | ok | ok | ok |
| Druid Lobo | tail, mane crest | ok | ok | ok | ok | ok | ok |
| Druid Urso | stone shell | ok | ok | ok | ok | ok | ok |
| Necromancer Invocador | spine-and-ribs frame | ok | ok | ok | ok | touches head | left (hit only; the ribs hug the head closely) |
| Necromancer Ceifador | banner strips, lanterns | ok | ok | ok | ok | ok | ok |
| Necromancer Sombras | black sun disc (head bone) | ok | ok | ok | ok | rim dips into the shoulders | left (hit only) |
| Bishop Sacerdote | portable shrine | posts through the hat brim | same | same | same | same | FIXED: shrine moved behind the brim on L-shaped posts (`build_chaplain`); only `hit` still touches |
| Bishop Iluminado | sun-ray collar | ok | ok | ok | ok | ok | ok |
| Bishop Batalha | (no back piece) wings on the helm | ok | ok | ok | ok | ok | ok |
| Paladin Guardião | fan crest (head) | ok | ok | ok | ok | ok | ok |
| Paladin Cruzado | plume (head) + half cape | ok | ok | ok | ok | ok | ok |
| Paladin Templário | brazier crown, censers, scale skirt | ok | ok | ok | ok | ok | ok |

Limit of this review: frames were judged by eye at about 200 px per figure; small overlaps (a few centimetres) cannot be seen at that size.

### 9.4 Colour changes (`ACT2_VISUALS` only, no mesh)

| Build / level | Before | After |
|---|---|---|
| Druid Xamã 45 | bone pale / deep violet accent (low contrast with the skull) | dark violet (0.22, 0.16, 0.34) / bright violet feathers (0.56, 0.26, 0.82) |
| Elementalist Gelo 35 | pale grey-blue (too close to the 45) | dark teal-slate (0.2, 0.3, 0.36) / accent (0.62, 0.78, 0.82); 45 accent now (0.32, 0.3, 0.72) |
| Ranger Atirador 35 | cold gunmetal (read as navy) | warm gunmetal (0.44, 0.39, 0.33) |
| Ranger Caçador 40 | saturated red (0.72, 0.26, 0.16) | muted brick (0.58, 0.3, 0.22) |
| Bishop Sacerdote 45 | navy (too close to Batalha's black iron) | ivory (0.9, 0.87, 0.8) / gold accent (0.8, 0.58, 0.2) |

Sheets: `production/qa/evidence/act2-sets/final/colour_<class>_<build>_30_35_40_45.png`; forms: `final/form_<alpha|ent|bird>_30_35_40_45[front].png`.
