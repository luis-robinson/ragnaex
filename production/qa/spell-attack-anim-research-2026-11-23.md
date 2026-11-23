# Spell, attack and animation research + review (2026-11-23)

Author: art-director (research + review only; no code, asset or data changed).
Request: "search for attack and animations for spells, abilities for games like ours, and improve it".
Inputs read (by section): `docs/skills_review.md` (rubric + audit), `docs/animations_review.md` (incl. "Pacote C9"),
`production/qa/combat-audit-2026-11-23.md` (§1.5-1.6, §2 hit-stop/numbers/sound, §3-5),
`production/qa/attack-anim-audit-2026-11-14.md` §2, `production/qa/attack-arc-colours.md` §1-2,
`game/fx/skill_fx.gd` (`PALETTE`, `PARTS`, function list), `data/catalog/skills_catalog.gd` (`VFX_RULES`, `vfx_theme`),
`game/entities/entity_view.gd` (`clip_for_skill`, token lists, `CAST_BY_THEME`, `_buff_clip`),
`tools/blender/chibi_kit.py` (`_family_clips`), and bench sheets in `production/qa/evidence/`
(`skills-fill/*`, `cruzado-skills/*`, `ultimates/{berserker,druid,bishop}/*`).
Not done here: no new showcase run (sheets are from earlier passes; a fresh `--showcase=all` is step 0 of the plan).

Confidence marks: **[S]** = stated by a primary/developer source, **[2]** = secondary write-up, **[R]** = rule of thumb
from craft practice (not a single citable source; treat numbers as starting ranges), **[?]** = uncertain / not verified.

---

## (a) Principles from comparable games

### a.1 What the references actually say

| # | Principle | Who / source | What it means for a 52° / 24 m chibi camera |
|---|---|---|---|
| P1 | **Legibility is the first art principle** of an overhead ARPG; the fixed camera is exploited (assets built for one angle) | Diablo III, Lichtner GDC 2012 [S/2] ([Game Developer](https://gamedeveloper.com/design/gdc-2012-diablo-iii-s-art-director-shows-off-design-process), [80.lv](https://80.lv/articles/blizzard-art-philosophy-in-diablo-iii/), [GDC Vault](https://gdcvault.com/play/1015306/The-Art-of-Diablo)) | Poses and VFX are authored for the game camera, not for a side view. Our `lineup --yaw=35 --high` is the right review angle; side films are secondary. |
| P2 | **Visual impact = gameplay impact**: a basic must not look like an ultimate; VFX show the spell's *space, power and function* without muddling the action | Riot VFX style guide [S] ([Nexus post](https://nexus.leagueoflegends.com/en-us/2017/10/dev-leagues-vfx-style-guide/), [PDF](https://nexus.leagueoflegends.com/wp-content/uploads/2017/10/VFX_Styleguide_final_public_hidpjqwx7lqyx0pjj3ss.pdf)) | We need an explicit **size/value tier** per skill class (basic < skill < heavy < Suprema). Today some Supremas are smaller than skills and others white out the screen (b.1). |
| P3 | **One colour drives the theme**, the complement is desaturated and confined to small accents; saturation and contrast create focus; avoid pure white / pure black | Riot guide [S] + summary [2] ([VFX Apprentice](https://www.vfxapprentice.com/blog/10-league-of-legends-vfx-design-tips)) | Matches our "identity by form, hue is spoken for" rule (`attack-arc-colours.md` §1). The near-white washes (Juízo do Sol, Oferenda Sombria) break it. |
| P4 | **Gameplay readability wins over theme**; emphasise the part the enemy must avoid (missile tip, edge) | Riot [S] ([Clarity in League](https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/), [VFX updates](https://www.leagueoflegends.com/en-pl/news/dev/dev-behind-the-scenes-of-vfx-updates/)) | Bright leading edge on projectiles and arcs; dim interiors. Already done for arcs (`smear_arc`), not for spell sectors/circles. |
| P5 | **Never rely on colour alone** (colour-blind); red-green is the common case | Riot Illaoi post [S] ([Nexus](https://nexus.leagueoflegends.com/en-us/2018/02/resistance-illaoi-the-final-update/)); VFX artist [2] ([Mighty Bear](https://medium.com/mighty-bear-games/how-ux-design-can-help-with-vfx-a0925f80e0f0)) | Element identity must also come from **particle shape and motion** (our `PARTS` already differ by mesh/gravity: keep pushing that). |
| P6 | **Huge effects cannot be spammable**; many casters of the same class cause readability problems, so some effects play **locally for the caster only / reduced for others** | Diablo III Necromancer VFX panel [2] ([BlizzPro](https://blizzpro.com/?p=69359), [Diablofans](https://static.diablofans.com/news/48954-visual-effects-of-the-necromancer-panel-overview)) | Directly our 5-member party problem (combat audit §4.5). Ally tier at reduced opacity/size. |
| P7 | Players of party ARPGs ask for **per-source opacity** and a layer order **enemy telegraph > own > ally** | PoE / PoE2 forum requests [2, player opinion] ([party effects](https://www.pathofexile.com/forum/view-thread/3660138), [opacity slider](https://www.pathofexile.com/forum/view-thread/3868713), [ground effects](https://pathofexile.com/forum/view-thread/3626389)) | Our telegraph grammar is already the top layer; add the ally tier and an option. |
| P8 | **Anticipation conveys power**; designers want few anticipation frames, animators want more; strong key poses carry a 6-frame attack | Skullgirls GDC 2014 [S] ([GDC Vault](https://gdcvault.com/play/1020575/Animation-Bootcamp-Fluid-and-Powerful), [80.lv](https://80.lv/articles/tips-on-making-fluid-and-powerful-animations)); Sakurai/Smash [2]; [Anticipation in games](https://gamedeveloper.com/design/anticipation-in-games) | Our latency-first rule (66% of skills ≤ 0.15 s startup) is a legitimate design choice; the read must then come from **key-pose snap + VFX gather**, not from more frames (a.2 T3). |
| P9 | Attack = **anticipation / active / recovery**; enemy attacks are read by the anticipation | Dark Souls 3 anatomy [2] ([Game Developer](https://www.gamedeveloper.com/game-platforms/anatomy-of-an-enemy-attack-in-dark-souls-3)); [12 principles in games](https://www.gamedeveloper.com/production/the-12-principles-of-animation-in-video-games) | Already the sim model (startup/active/recovery). Bosses: long anticipation (done via telegraphs). Players: short. |
| P10 | **Hit-stop scales with weight** (light ≈ 2 frames, heavy/parry ≈ 8-12); being hit should freeze less so the player keeps control | game-feel write-up [2] ([gamejuice](https://gamejuice.pages.dev/articles/hit-stop-frame-trick)); Smash hitlag scales with damage [2] ([SmashWiki](https://ssbwiki.com/Hitlag)); impact-feel study [S, academic] ([Lin et al. 2022](https://arxiv.org/abs/2208.06155)); [critpoints](https://critpoints.net/2017/05/17/hitstophitfreezehitlaghitpausehitshit/) | Matches our local hit-stop for arcs (basic 2, cap 8). Gap: global freeze when the player is hit (audit §4.3) contradicts "freeze less when hit". |
| P11 | **Impact feel = hit-stop + sound coherence + camera**; missing any one makes impact unsatisfying | Lin et al. 2022 [S] ([arXiv](https://arxiv.org/abs/2208.06155)) | Our weakest leg is **sound**: magic hits have no per-target sound, one `hit` pool for all weapons (audit §2). |
| P12 | **Smear / anticipation / easing** are the three tools of a fast swing; smears belong to stylised fixed-camera games | GDQuest [2] ([juicy attack](https://gdquest.com/library/juicy_attack)); [Smear frame](https://www.wikipedia.org/wiki/Smear_frame) | Done for melee families (`WeaponArcs`). Missing for staff/scythe/spell gestures and ranged release. |
| P13 | **Kill feedback** is what made Tree of Savior's combat feel meaty; players still ask for stronger per-skill feedback | PC Gamer [2] ([article](https://pcgamer.com/what-other-mmos-need-to-learn-from-tree-of-saviors-dramatic-combat)); ToS forum [player] ([thread](https://forum.treeofsavior.com/t/serious-skills-need-to-give-much-better-visual-feedback/322199)) | A distinct **kill punctuation** (launch/knock-back pop, burst, sound) separate from the hit. [?] Need to film what our death read is today beyond the `die` clip. |
| P14 | Readability through **pose, timing and silhouette, not micro-detail**; restraint in clutter | Hades commentary [2, low authority] ([geekchamp](https://geekchamp.com/the-art-of-hades-showcases-the-talent-that-went-into-this-beautifully-vibrant-game/), [80.lv Hades FX](https://80.lv/articles/a-behind-the-scenes-look-at-the-effects-in-hades)); counterpoint: reviews flag Hades readability in crowded rooms [2] | For chibi: the **weapon and arms must leave the head's silhouette** at the key pose; torso detail is invisible from above. |
| P15 | When camera shake can be disabled, power must also come from other channels (pose, ground) | Guild Wars 2 artists [2] ([Creative Bloq](https://www.creativebloq.com/3d/video-game-design/youre-not-supposed-to-notice-it-inside-the-hidden-art-of-animation-and-vfx-in-guild-wars-2)); Mistfall Hunter: tight control of VFX size/colour/brightness so they never block the camera [2] ([80.lv](https://80.lv/articles/interview-how-mistfall-hunter-blends-soulslike-combat-with-dark-fantasy-rpg-extraction-mechanics)) | Ground decals and residue (cracks, scorch, frost) carry weight when shake is off (accessibility option pending, audit §4.4). |
| P16 | Element colour coding extends to **damage numbers** (Genshin: anemo teal numbers, etc.) | [2] ([Mighty Bear UX/VFX](https://medium.com/mighty-bear-games/how-ux-design-can-help-with-vfx-a0925f80e0f0)) | [?] Our `FxManager._on_damage` colours by kind/glyph; element tint on numbers would tie hit to skill cheaply. |
| P17 | Diablo IV: precise frame-by-frame combat, stop animations and blending for "grounded" weight | Blizzard quarterly update / IGN via Wowhead [2] ([Wowhead](https://www.wowhead.com/diablo-4/de/news/diablo-iv-ign-interview-combat-design-and-visuals-information-versus-immersion-329803), [GamingBolt](https://gamingbolt.com/?p=424066)) | Supports our "impact on the damage tick" rule (`combat_probe` 0 FLAG). |

Not found (searched, no developer source): Lost Ark, Albion, MapleStory 2, Torchlight, Drakantos, Ragnarok 2 skill-VFX
breakdowns; Lost Ark only has class "behind the scenes" posts about design/sound
([Valkyrie](https://www.playlostark.com/en-gb/news/articles/behind-the-scenes-valkyrie-class)). Anything below attributed
to those games is **[R]** (observation of genre practice), not a citation.

### a.2 Working numbers (60 Hz frames; starting ranges, tune by eye at the game camera)

| Tier | Anticipation (startup) | Active | Recovery (cancel window) | Hit-stop | VFX footprint / value | Ours today |
|---|---|---|---|---|---|---|
| T1 Basic (LMB) | 0.08-0.15 s (5-9 f) [R]; Skullgirls-style 6-frame punch works with a strong key pose [S] | 1-4 f | 0.15-0.3 s, chainable early | 2 f local [2] | ≤ weapon reach; band alpha ≤ 0.85; no ground decal | startup 0.12, active 0.06, hit-stop 2: **in range** |
| T2 Skill, light | 0.1-0.2 s, but with a **pose snap on frame 1** and a VFX gather [R] | 2-6 f | 0.2-0.35 s | 2-4 f | real hitbox outline + edge; residue ≤ 1 s | 193/294 at ≤ 0.15 s; most show impact on the 2nd sheet frame, **no gather** |
| T3 Skill, heavy (finisher, slam, leap, big spell) | 0.25-0.45 s [R] (Diablo/Lost Ark heavies feel ~0.3-0.5 s) | 3-8 f | 0.3-0.5 s | 4-8 f + small shake | ground decal (crack/scorch/sigil) 2-4 s, fading | 76 at 0.2-0.3 s; decals only for some (`decal_sector/line`) |
| T4 Channel | entry 0.15-0.25 s, then a **loop with a pulse every tick** | per tick | release pose | 1-2 f per tick (or none) | beam/cone at steady alpha; pulse flash per tick | `cast_channel` now has two pulses (C9); channels cut by LMB (audit §4.1) |
| T5 Summon / big AoE | 0.4-0.6 s acceptable if telegraphed to the caster (ground brand during startup) [R] | — | 0.3 s | 0 | the summon's own entrance (rise from ground) is the payoff | 25 skills > 0.3 s; rule needs an exception (audit §1.6) |
| T6 Suprema | 0.2-0.3 s (our rule ≤ 0.3 s) + **one held key pose 4-8 f** [R] | — | — | 6-10 f, local | biggest footprint on screen **but capped value** (no full-screen white); distinct colour moment | inconsistent: some invisible, some white-out (b.1) |
| Being hit (player) | — | — | — | ≤ 1-2 f, never global [2] | small directional flinch, red rim | global freeze 2-6 f when hit (audit §4.3), no player flinch |

Other numbers [R]:
- **Chibi exaggeration**: anticipation and follow-through must be ~1.5-2x a realistic-proportion pose to read from above (the
  head covers the torso; `attack-anim-audit` §2.8). Arms/weapon must clear the head disc at the key pose.
- **Smear/arc life**: 0.08-0.2 s; leading edge brightest, tail fades; width ≥ 0.4 m to survive 24 m (our arcs: yes).
- **Ground residue**: 1.5-4 s, alpha ≤ 0.5, in the ground's own tones or the element tone desaturated (never saturated red:
  that is the boss danger code).
- **Particle count per cast** for a 5-member party: own 100%, allies ~50-60% size/alpha (D3 local-only tech, PoE requests).
- **Sound sync**: whoosh at anticipation end (≈ impact − 60-100 ms), impact sound on the damage tick, tail on recovery; per
  material (blade/blunt/pierce/magic element) [R].

### a.3 Archetype casting poses (what reads from a high camera) [R, from genre practice]

| Archetype (ours) | Key pose that reads from above | Ground / world carrier | Our clip today |
|---|---|---|---|
| Staff caster (Elementalista) | staff thrust **forward** past the head at impact; free hand opens to the side; fire = throw, ice = plant, storm = staff up then point | element-shaped ground mark (flame petals / frost star / rune ring) | `cast_fire/ice/bolt` good; wind shares `cast_ice` |
| Holy (Bispo/Paladino) | arms **up and open** (V), then down to the target; scepter/mace raised | sigil circle, light shaft, falling hammer | `cast_holy` shared by both classes AND all heals |
| Necro (scythe) | scythe drawn **behind** and swept low; or hand claw pulling up from the ground | ground cracks, dark hands, rising bones | `cast_shadow` shared with poison/bone (Assassino venoms too) |
| Nature / shapeshift (Druida) | hands to the ground then up (growth); forms: whole-body lunge, rear, stomp | roots, petals, claw rakes | `cast_nature` shared with earth and lunar; forms have 5 gestures (`maul/pounce/slam/roar/brace`) |
| Archer (Ranger bow) | full draw: elbow back past the head, release snap; charged shots hold the draw | arrow streak, impact feathers | `atk_bow`, `atk_shoot_multi` only |
| Gunner (rifle, Corsário pistols) | recoil kick + muzzle flash + smoke; pistol pair alternates | tracer, puff (`gunshot`, `puff`) | `atk_rifle` (fixed in review); pistol skills [?] route through dual/throw clips |
| Dual wield (Assassino) | alternating crossing slashes, low crouch, dash-through | X slash (`slash_x`), afterimage | `atk_dual_a/b`, `atk_flurry` |
| Heavy melee (Berserker, Paladino 2h) | big coil (spine twist 50°+), overhead crash, ground crack | crack decal, debris (earth theme) | `atk_sweep`, `atk_finisher`, `atk_leap`; good |

---

## (b) Review: gaps per class / archetype

### b.1 Evidence from the bench sheets (sample read this session)

| Sheet | What reads | What fails (rubric) |
|---|---|---|
| `skills-fill/necromancer_000_nec_dark_offering.png` (Oferenda Sombria) | pose shows a scythe raise | impact = **four pale mint/white concentric rings + white box confetti** covering the frame: reads holy/frost, not "dark sacrifice" (identity 0); white near-pure value (P3); rings overlap per summon. |
| `cruzado-skills/paladin_000_pal_crusader_strike.png` | arc band, cone shape, yellow crit numbers: good shape/timing | white hit flash on every body + numbers dominate the impact frame; holy tint barely visible on the band (identity 1). |
| `skills-fill/elementalist_pagina_0.png` (Semente de Brasa) | brand on target during startup: good | the payoff burst is small next to a slime; seed→bloom lacks a second beat (feedback 1). |
| `ultimates/berserker/ber_ult_seven_winds` (Suprema) | — | frames 1-2 identical (no visible anticipation), impact = a few sparks + numbers: **a Suprema smaller than a basic arc** (P2 broken). |
| `ultimates/druid/dru_ult_blood_moon` (Suprema, wolf) | wolf pose | one thin white circle, no red/moon motif; "Lua de Sangue" has no blood or moon (identity 0). |
| `ultimates/bishop/bis_ult_judgement_sun` (Suprema) | huge, unmistakably holy | **white-out**: the whole frame turns cream, enemies and the caster lose contrast (P3/P7). |

Pattern: no shared **scale/value ceiling** per tier. White is used as the "power" colour (hit flash, physical theme
`PALETTE["physical"]` near-white, ring colours), so strong effects converge to white and weak effects to "thin white circle".

### b.2 Systemic gaps (from the code read)

1. **Clip routing is token-driven and coarse.** `clip_for_skill` sends: every physical GROUND skill with a 1h weapon to
   `cast_ground` (a caster gesture on a warrior); every magical DIRECTION skill to the basic `atk_staff/atk_1h_a/atk_2h`
   swing (the spell looks like a basic); every MOVEMENT skill to `cast_buff`; every heal to `cast_holy` via
   `CAST_BY_THEME["heal"]` (Druida and Necromante heals look like the Bispo); `wind` to `cast_ice`; `bone`/`poison`/`shadow`
   to one `cast_shadow` (necro curses and assassin venoms share a gesture); `earth`/`lunar`/`nature` to one `cast_nature`.
   211 skills already override with `"clip"`, so the routing mostly governs the remaining ~80 + every new skill.
2. **Theme set is 15 elements for 24 builds.** `VFX_RULES` + `VFX_CLASS` give a class default, so within a class the
   builds share the palette (Paladino and Bispo are both `holy` gold; Necro Invocador/Ceifador/Sombras all `shadow`).
   250 skills set `vfx`, but no **build accent** exists.
3. **Physical = white.** `PALETTE["physical"]` is near-white with additive particles; non-arc physical skills (ranged
   physical, kicks, throws) read as "light magic" (also noted in `skills_review.md` "Pendências": arrows).
4. **No anticipation layer for fast skills.** 66% of skills at ≤ 0.15 s; only TARGET magic gets `SkillFx.brand` during
   startup. Melee skills, cones and directions get nothing before impact (combat audit #10).
5. **Impact layer is one-size.** White hit flash for all, generic `hit` sound pool for all physical, no per-target sound for
   magic, no element tint on numbers [?], no residue decal on most AoEs, no kill punctuation distinct from the hit [?].
6. **Status reads missing.** Stun = `hit` clip, no stars; root/slow have no `BuffLooks` entry (audit §2 CC).
7. **Reactions.** Players/bots never flinch; bosses flinch on every hit (jitter risk); global hit-stop when the player is hit.
8. **Ally clutter.** Party FX at full weight (audit §4.5); no local-vs-others tier (P6/P7).
9. **Ultimate inconsistency** (b.1): no rule for footprint, value cap, or a held key pose.

### b.3 Per class

| Class | Reads well | Weak / generic | Lacks identity |
|---|---|---|---|
| Paladino | arc families, Cruzado 2h chain, falling/orbit hammers, shield throw | holy gold shared with Bispo; Guardião buffs share `buff_guard`; Suprema Bastião/Juízo [?] scale | build accent (Guardião steel-blue? Templário flame-gold?) |
| Berserker | axes inverted black-iron band, sweep/finisher/leap, blood theme | Sete Ventos (Suprema) almost invisible; `shout` single clip for all cries; blood red sits next to danger red (`THEME_WHITE_BY` blood 0.35 mitigates arcs only) | Gêmeos vs Executor vs Carniceiro differ little in VFX |
| Bispo | heal/holy columns, falling hammer | Juízo do Sol white-out; every heal = `cast_holy`; Sacerdote buffs share `cast_holy`/`buff_*` | Inquisidor vs Sacerdote vs Vanguarda same gold |
| Druida | form clips, K ground marks for forms, entangle | Lua de Sangue invisible; 5 form gestures for all form skills; human heals use `cast_holy`; earth/lunar/nature one gesture; `dru_moonfire` small hit (known) | wolf vs bear vs Ent skills colour-identical (nature green) |
| Ranger | lynx, traps, rifle recoil (after fix) | bow skills all `atk_bow` except multi; no charged-draw pose; physical arrows white trail (known); Lanceiro throw/thrust only | Caçador vs Atirador vs Lanceiro: no accent |
| Assassino | dual clips, `slash_x`, shadowstep | venoms share `cast_shadow`; Corsário pistols: weakest kit (5 WEAK skills, audit §1.2) and [?] pistol skills routed through generic clips | Lâminas poison / Duelista rapier / Corsário gunpowder not distinct beyond palette |
| Elementalista | best kit: per-element gestures, meteor, chain bolt, combust brand | wind uses ice gesture; seed bloom small | fine; ensure Raio's many bolts don't dominate a party screen |
| Necromante | summons, channels, scythe sets | Oferenda Sombria pale rings; curses all `cast_shadow`; `summon` one clip for bones/army/king/lich; heals/drain via holy routes [?] | Invocador/Ceifador/Sombras all `shadow` purple |

---

## (c) Improvement plan (packages, prioritised)

Effort: **P** ≤ 1 day, **M** 2-4 days, **G** 1-2 weeks. All packages are presentation (`game/`, `tools/blender/`,
`tools/audio/`); none touches `core/` timings unless marked "timing".
Shared verification: fresh `--showcase=<classe> --out=<pasta>` pages before/after per class (rubric ≥ 8 in
`docs/skills_review.md`), `combat_probe` 0 FLAG, `--showcase=all --check` (all skills cast without error), tests 0 failed.
Evidence goes to `production/qa/evidence/spell-anim/<package>/`.

| Pri | Package | What | Effort | Impact | Verify |
|---|---|---|---|---|---|
| 1 | **V1 Tier ceilings (value/scale)** | Define T1-T6 caps in one table (`SkillFx` constants via `Balance`? no: presentation constants in `skill_fx.gd`): max footprint, max alpha, **white budget** (no fill above L 0.9 over > 15% of the screen), residue life. Rework the out-of-band Supremas first: Sete Ventos (add 7 wind arcs + ground spiral), Lua de Sangue (red-violet moon disc on the ground + claw marks), Juízo do Sol (gold rim + rays, translucent interior, no cream fill), Oferenda Sombria (dark violet implosion, one ring not four). | M | High: fixes the most visible failures and sets the rule for all future skills | ultimate sheets (24) + skills-fill sheets; a screenshot-luminance probe [optional, P] reporting % of frame above L 0.9 at the impact frame |
| 2 | **V2 Anticipation without latency** | For startup ≤ 0.15 s: (a) **pose snap**: start the clip at the coil key (skip the first ~20% of windup) so frame 1 is already the extreme; (b) **gather VFX** on the weapon/hand during startup (glint on the edge for physical, element mote for magic: extend `SkillFx.gather`/`brand` to DIRECTION/CONE/SELF); (c) **pre-impact whoosh** 60-100 ms before the tick. No change to sim startup. | M | High: addresses audit #10 (193 skills) and party read | showcase sheets: frame 1-2 must differ and show the gather; `combat_probe` 0 FLAG (impact still on the tick) |
| 3 | **S1 Impact sound split** | `Sfx`: per-target magic impact per theme (fire whump, ice shatter, bolt crack, holy chime, shadow thud, poison hiss), physical split blade/blunt/pierce/arrow/bullet by weapon family; crit layer stays. Generated in `build_sfx.py` (SYNTH or CC0). | M | High (P11: sound is the missing leg of impact) | smoke `SMOKE SOM:` lists the new names; `_check` that every theme/family has a sound; listening pass |
| 4 | **V3 Impact layer per material** | Replace the uniform white hit flash with a **tinted rim flash** (element colour for magic, steel for physical, white only on crits); per-family hit sparks (blunt = dust ring + debris, blade = thin slash spark, pierce = straight spark line, bullet = puff); **residue decals** for T3+ (crack, scorch, frost star, holy sigil) in desaturated element tones 1.5-4 s; element tint on damage numbers [decision 3]. | M | High | showcase impact frame; `--loot_demo`-style screenshot of a group fight for clutter |
| 5 | **R1 Reactions + status bodies** | Player/bot additive upper-body flinch (no lock, 0.15 s, direction from the hit); boss flinch only on crits/staggers (no jitter); stun stars, root (vines/ice by source), slow (frost crawl / mud) entries in `BuffLooks`; global hit-stop removed when the player is the target (local 1 f instead). Overlaps audit #4 and #7. | M | High (feel + clarity) | `--buff_shot` for stun/root/slow; film a 5-mob pack hitting the player; `combat_probe` 0 FLAG |
| 6 | **A1 Ally tier** | Party members' skill FX at ~55% alpha and 85% size, arcs at 50%, their numbers smaller (own full); option slider later. Layer order: boss telegraph > own > ally. | P-M | Medium-high in groups (the game is group-first) | `boss_probe --comp=...` filmed run, before/after screenshot with 5 members |
| 7 | **C1 Clip routing fixes (no new clips)** | `clip_for_skill`: physical GROUND + 1h → `atk_leap`/`atk_finisher` instead of `cast_ground`; magical DIRECTION → the theme cast (`CAST_BY_THEME`) instead of the basic swing; heal by class theme (druid → `cast_nature`, necro → `cast_shadow`); MOVEMENT → `dash`/`jump`. Add a `_check` that no physical skill resolves to a `cast_*` clip unless `clip` is explicit. | P | Medium: removes the "warrior casting" and "spell = basic" reads at once | test check; showcase for affected skills (list printed by a one-off routing dump) |
| 8 | **C2 New archetype clips (Blender)** | ~10 clips in `chibi_kit` (kits only where needed via `CLASS_ONLY_CLIPS`): `cast_heal_nature`, `cast_curse` (claw pull from ground), `cast_wind` (spiral), `summon_rise` (necro, hands up from ground) vs `summon_call` (druid/ranger, whistle/arm sweep), `atk_bow_charge` (held draw), `atk_pistol_pair` (alternating shots), `atk_pistol_fan`, `atk_scythe_reap` (low 270° sweep), `shout_rally` (ally buff cry vs `shout` threat). Each authored at the game camera, arms clear of the head at the key pose, `_tame` limits respected. | G | High for identity of Necro, Ranger, Corsário, Druida | `lineup --strip=<c> --anim=<clip> --yaw=35 --high`; `anim_probe` (no peak > 60°, no dead frames); kit mesh budget unchanged (clips only); `combat_probe` 0 FLAG |
| 9 | **V4 Build accents** | Second colour + particle shape per build (`VFX_BUILD_ACCENT[<class>_<build>]`) mixed into the theme as the small-accent colour (P3): e.g. Guardião steel-blue sparks, Templário ember-gold, Inquisidor white-violet, Corsário gunpowder orange-smoke, Lâminas venom green drips, Duelista rose-silver, Invocador bone-mint, Ceifador ash-grey, Sombras deep violet. Pending decision 3. | M | Medium-high (24 builds read apart) | showcase pages per build side by side; colour table reviewed against `attack-arc-colours.md` §1 (no hue that collides with danger red / safe mint) |
| 10 | **V5 Smears for casters and ranged** | Extend `WeaponArcs` to staff/scythe/scepter spell gestures (thin element-tinted arc on the cast swing, not on the basic) and a **release flash** for bow/pistol (bowstring snap glint, muzzle cone); arrow trail physical = no additive glow (known pending). | M | Medium | `arc_film.sh --class=<c> --skill=<id>` strips; showcase |
| 11 | **T1 Timing doc + exceptions (timing)** | Write the tier table (a.2) into `docs/skills_review.md`; accept the summon/big-AoE exception (T5) in the manual; trim `nec_demon_form` 0.45 s on a 6 s cd to ≤ 0.3 s or raise its cd. Each Suprema gets a 4-8 f held key pose inside its ≤ 0.3 s startup. | P (doc) + P (data) | Medium: removes the rule conflict (audit #11) | `combat_probe`; existing `_check` on Suprema startup |
| 12 | **K1 Kill punctuation** [?] | After filming the current death read: knock-back pop proportional to overkill (presentation only, view offset), short burst + a distinct kill sound; elites/bosses bigger. | P-M | Medium (P13, ToS lesson) | film a pack kill; listening pass |

Suggested order: V1 → C1 → V2 → S1 → V3 → R1 → A1 → V4 → C2 → V5 → T1 → K1 (C1 and T1 are cheap and can ride along
with any package). V1-V3 + S1 + C1 is about 2 weeks of work and covers the bulk of the visible gap.

---

## (d) Decisions for the user

**D1. How fast skills get their "weight" (anticipation strategy)**
- **A. Keep the latency, add pose snap + gather VFX + pre-impact whoosh (Recommended).** Keeps the Drakantos responsiveness
  that `combat_probe` protects; the read moves into the first frame and the sound. Trade-off: heavy skills still feel
  lighter than in Lost Ark.
- **B. Raise skill startup to a floor of 0.2 s (basics unchanged).** More natural anticipation and better ally/AI read;
  costs responsiveness and touches balance (DPS, chaining, bots).
- **C. Per-tier: light skills stay fast, heavies (finishers/leaps/big AoEs) go to 0.25-0.4 s.** Best of both, but needs a
  per-skill pass over ~80 skills and a balance check.

**D2. How Supremas present themselves**
- **A. World-only, biggest footprint under a value cap, with a held key pose (Recommended).** Fits the camera and the
  group screen; no new UI.
- **B. Add a 0.3-0.5 s screen-space flourish** (portrait slash/cut-in across the screen, Lost Ark/Genshin-burst style
  [R]). Strong fantasy; risks clutter with 5 members and needs its own option.
- **C. Camera punch** (short zoom-in toward the caster). Cinematic; conflicts with boss lock and readability, motion
  sensitivity.

**D3. Colour identity depth**
- **A. Element only (today).** Simplest; builds of one class look the same.
- **B. Element + build accent (Recommended).** One accent per build in small particles/edges (P3); 24 readable builds
  without new hues.
- **C. Class signature palette** (Paladino gold-steel vs Bispo white-sky, etc.) overriding element. Strong class read;
  collides with element meaning for hybrids and with the reserved hues.
- Sub-question: element-tinted damage numbers? (yes / only crits / no).

**D4. Allies' effects**
- **A. Allies at reduced opacity/size by default + slider in Configurações (Recommended).**
- **B. Full weight for everyone** (today).
- **C. Own effects only + allies as outlines/arcs only.** Cleanest; allies' contributions stop being visible.

**D5. Hit flash**
- **A. Tinted rim flash by damage type, white only on crits (Recommended).**
- **B. Keep the white full-body flash** (strong but uniform, part of the white-out problem).
- **C. No flash; sparks and numbers only.** Cleanest, weakest confirmation on small mobs.

---

## Sources

- Game Developer, GDC 2012 Diablo III art direction: https://gamedeveloper.com/design/gdc-2012-diablo-iii-s-art-director-shows-off-design-process
- 80.lv, Blizzard art philosophy in Diablo III: https://80.lv/articles/blizzard-art-philosophy-in-diablo-iii/
- GDC Vault, The Art of Diablo 3: https://gdcvault.com/play/1015306/The-Art-of-Diablo
- BlizzPro, Diablo 3 Necromancer VFX panel: https://blizzpro.com/?p=69359
- Diablofans, Necromancer VFX panel overview: https://static.diablofans.com/news/48954-visual-effects-of-the-necromancer-panel-overview
- Riot, VFX style guide post: https://nexus.leagueoflegends.com/en-us/2017/10/dev-leagues-vfx-style-guide/
- Riot, VFX style guide PDF: https://nexus.leagueoflegends.com/wp-content/uploads/2017/10/VFX_Styleguide_final_public_hidpjqwx7lqyx0pjj3ss.pdf
- Riot, Clarity in League: https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/
- Riot, behind the scenes of VFX updates: https://www.leagueoflegends.com/en-pl/news/dev/dev-behind-the-scenes-of-vfx-updates/
- Riot, Resistance Illaoi (colour-blindness): https://nexus.leagueoflegends.com/en-us/2018/02/resistance-illaoi-the-final-update/
- VFX Apprentice, 10 tips from the LoL VFX guide: https://www.vfxapprentice.com/blog/10-league-of-legends-vfx-design-tips
- Mighty Bear Games, How UX design can help with VFX: https://medium.com/mighty-bear-games/how-ux-design-can-help-with-vfx-a0925f80e0f0
- GDC Vault, Skullgirls Animation Bootcamp: https://gdcvault.com/play/1020575/Animation-Bootcamp-Fluid-and-Powerful
- 80.lv, tips on fluid and powerful animations: https://80.lv/articles/tips-on-making-fluid-and-powerful-animations
- Game Developer, Anticipation in games: https://gamedeveloper.com/design/anticipation-in-games
- Game Developer, Anatomy of an enemy attack in Dark Souls 3: https://www.gamedeveloper.com/game-platforms/anatomy-of-an-enemy-attack-in-dark-souls-3
- Game Developer, 12 principles of animation in video games: https://www.gamedeveloper.com/production/the-12-principles-of-animation-in-video-games
- gamejuice, hit-stop frame trick: https://gamejuice.pages.dev/articles/hit-stop-frame-trick
- SmashWiki, Hitlag: https://ssbwiki.com/Hitlag
- critpoints, hitstop: https://critpoints.net/2017/05/17/hitstophitfreezehitlaghitpausehitshit/
- Lin et al. 2022, What features influence impact feel: https://arxiv.org/abs/2208.06155
- GDQuest, juicy attack: https://gdquest.com/library/juicy_attack
- Wikipedia, Smear frame: https://www.wikipedia.org/wiki/Smear_frame
- PC Gamer, Tree of Savior combat: https://pcgamer.com/what-other-mmos-need-to-learn-from-tree-of-saviors-dramatic-combat
- Tree of Savior forum, skills need better feedback: https://forum.treeofsavior.com/t/serious-skills-need-to-give-much-better-visual-feedback/322199
- 80.lv, behind the scenes of Hades effects: https://80.lv/articles/a-behind-the-scenes-look-at-the-effects-in-hades
- geekchamp, art of Hades (low authority): https://geekchamp.com/the-art-of-hades-showcases-the-talent-that-went-into-this-beautifully-vibrant-game/
- Creative Bloq, Guild Wars 2 animation and VFX: https://www.creativebloq.com/3d/video-game-design/youre-not-supposed-to-notice-it-inside-the-hidden-art-of-animation-and-vfx-in-guild-wars-2
- 80.lv, Mistfall Hunter interview: https://80.lv/articles/interview-how-mistfall-hunter-blends-soulslike-combat-with-dark-fantasy-rpg-extraction-mechanics
- Path of Exile forum, party effects: https://www.pathofexile.com/forum/view-thread/3660138
- Path of Exile forum, skill opacity: https://www.pathofexile.com/forum/view-thread/3868713
- Path of Exile forum, ground effects visibility: https://pathofexile.com/forum/view-thread/3626389
- Wowhead, Diablo IV IGN interview: https://www.wowhead.com/diablo-4/de/news/diablo-iv-ign-interview-combat-design-and-visuals-information-versus-immersion-329803
- GamingBolt, Diablo 4 animation technology: https://gamingbolt.com/?p=424066
- Lost Ark, Valkyrie behind the scenes (design/sound only): https://www.playlostark.com/en-gb/news/articles/behind-the-scenes-valkyrie-class
