<!-- RagnaEx manual (pt-BR) — Modelos (Blender). Moved VERBATIM from the old CLAUDE.md on 2026-11-08 (CCGS adoption); imported by CLAUDE.md. Edit here. -->

## Modelos (Blender)

`tools/blender/` gera personagens/monstros/props low-poly com rig e animações e exporta GLB para
`assets/models/`. O jogo usa placeholders até o `.glb` existir. Com o Blender MCP conectado
(`.mcp.json` → `uvx blender-mcp` + addon ligado no Blender), use `execute_blender_code`:
```python
import sys; sys.path.append(r"C:/Users/luisf/Desktop/projects/ragnaex/tools/blender")
import build_all; build_all.run(r"C:/Users/luisf/Desktop/projects/ragnaex/assets/models")
```
Nomes: `kit_male.glb`/`kit_female.glb` (personagens e NPCs: corpo + TODAS as armaduras/armas, o jogo liga as do
equipamento e pinta pela cor do item — `chibi_kit.build_kits`), `mob_<id>.glb`, `prop_<kind>.glb`.
Animações: `idle run block hit die jump fall land dash` + golpes `atk_*`/`cast*` (`chibi_kit.animate_v3`: idle/corrida
procedurais, pulo, dash, golpes com antecipação e acomodação; IMPACT não muda). Filme de um clipe para revisar:
`tools/lineup/lineup.tscn -- --strip=<classe> --anim=<clipe> [--front] --shot=<png>`.
Peça nova no kit: nome `arm_<plate|leather|cloth>_<head|body|legs|gloves|boots>_<parte>` (capa: `arm_cape_cape_cape`, igual para todos) ou `wpn_<main|off>_<tipo>`;
material `tint` recebe a cor do item, `tint2` a cor de destaque derivada dela (`KitModel.accent`), `hair` a cor da classe.
De cima a cabeça é o que mais aparece: detalhe novo vai primeiro no elmo/capuz e nos ombros. Item de armadura precisa de `armor_style`.
Conjuntos do Ranger: `tools/blender/ranger_sets.py` (`RAN_SETS` couro leve, chapéu de pena/capuz/tricórnio/óculos, aljava ou bandoleira;
`LAN_SETS`/`build_lancer` Lanceiro `ran_l*`: cabeça de bicho, gola de pelo, troféu no ombro esquerdo, dardos nas costas; `RAN_SPEARS`/`spear_parts` lanças, que também desenham a lança comum;
`RAN_BOWS` na mão esquerda; `RAN_RIFLES` e `rifle_parts`, que também desenha o mosquete comum). Lince: `mob_kit.quadruped(kind="lynx")`.
Conjuntos do Assassino: `tools/blender/assassin_sets.py` (`ASS_SETS` Lâminas: capuz + máscara de pano, frascos de veneno, capa rasgada; Duelista:
chapéu de pluma/máscara de baile, casaca de abas, meia-capa; `ASS_WEAPONS` gera o par `wpn_main_`/`wpn_off_<dagger|sword>_<estilo>`; Corsário `CORSAIR_SETS`: tricórnio/bicorne, casaca de abas, faixa; sabres e pistolas `pistol_parts`, `wpn_off_pistol`).
Revisar conjuntos de uma build lado a lado: `lineup.tscn -- --strip=<classe> --set=<build> --tiers [--front]` (de costas com `--front`).
Conjuntos do Ato II (35/40/45 + Ápice): UM visual novo por build, a mesma malha nos três níveis. Malhas: `ACT2_SETS` no `<classe>_sets.py` (estilo `<pre>_<b>35`, ex. `ber_e35`, `ass_l35`; função própria por build, 4 malhas por `join_slots`) + arma com `"glow": "tint"`. Materiais: `tint` (cor do item), `tint2` (destaque: pano, pena, crina, estandarte) e `tint_glow`/`tint_glow_edge` (peças acesas; `berserker_sets._tint_glow`). Dados: uma linha em `GearCatalog.ACT2_VISUALS["<classe>_<build>"]` = `style`, `colors`/`accents`/`glows` (uma cor por nível, ordem de `Balance.HYBRID_LEVELS`; escada: 35 ferro de Kharzun, 40 cor de guerra, 45 apogeu), `name` + `suffix` (+ `nouns`) = nome próprio ("Elmo do Quebra-Hordas do Triunfo": sufixo + `TIER_EPITHETS`), `icon` = estilo. `visual_of` devolve tudo; `KitModel` pinta `tint2` com `GearCatalog.set_accent` (sem `accents` vale `ItemDef.accent`) e as acesas com `set_glow`. Ápice = mesmo visual (`apex_color`), híbrido = malha da 1ª build na cor/destaque da 2ª. Passos de uma build nova: função + `ACT2_SETS`/arma no `_sets.py`; prévia sem janela (`blender -b --factory-startup`, `SET_STYLES[estilo](base, mats)` num `build_base`); `chibi_kit.build_kits(out, only=["<classe>"])` (< 200 malhas); linha em `ACT2_VISUALS`; `tools/icons/set_icons.tscn -- --only=<estilo>` (com janela; UMA foto por build, na cor do 40, `ACT2_ICON_LEVEL`) + `--import`; `lineup.tscn -- --strip=<classe> --set=<build> --tiers --levels=30,35,40,45 [--front] [--view=game]`. Check `_check_act2_visuals` (+ `_check_act2_extras`). Feitos: as 8 classes (Paladino num kit à parte, `_a2`); folha de desenho, nomes, cores e revisão animada em `production/qa/act2-set-visuals.md`.
Ato II do Necromancer: `necromancer_sets.ACT2_SETS` (`nec_i35` Ossuário de Guerra `build_ossuary`, `nec_c35` Ceifeiro do Campo `build_field_reaper`, `nec_s35` Sol Negro `build_eclipse`; foices `build_scythe2`).
Ato II do Bispo: `bishop_sets.ACT2_SETS` (`bis_s35` Capelã de Campanha `build_chaplain`, `bis_i35` Farol da Aurora `build_beacon`, `bis_b35` Martelo da Vanguarda `build_vanguard`; maças `ACT2_MACES`/`build_mace2`, cetro `build_scepter2`; os ESCUDOS continuam os do 30).
Ato II do Paladino (kit extra): `paladin_sets.ACT2_SETS` (`pal_g35` Baluarte de Kharzun `build_bulwark`, `pal_c35` Lança da Aurora `build_dawn_lance`, `pal_t35` Chama de Guerra `build_war_flame`; só ARMADURA: espadas, maças e escudos continuam os do 30 pela chave `"wpn"` de `ACT2_VISUALS`). As malhas NÃO entram no kit principal (195 malhas, teto de 200): `register_a2` põe os estilos em `chibi_kit.A2_STYLES` e `build_kit_a2`/`build_kits_a2(out, only=["paladin"])` (chamado no fim do `build_kits`) exporta `kit_paladin_<male|female>_a2.glb` (só as 12 malhas `arm_pal_*35_<slot>_all` + o MESMO esqueleto de 19 ossos, sem corpo/armas/clipes). No jogo: `KitModel.load_addon` (caminho = o do kit + `_a2`, `addon_path_for`) lê o arquivo na 1ª vez que uma peça dele é vestida (`apply_equipment`), guarda a cena por caminho e anexa as malhas ao esqueleto do kit com o skin do kit principal; elas entram em `_nodes` como as outras (fusão, cor, brilho, flash). Sem o arquivo o boneco veste o estilo do 30 (`GearCatalog.act2_fallback_style`). Outra classe que estourar o teto: registre os estilos em `A2_STYLES` (o prefixo de `CLASS_PREFIX` decide a classe). Ícones: `set_icons.tscn -- --only=pal_g35,pal_c35,pal_t35` e `shield_icons.tscn -- --only=pal_g30,pal_t30` (o escudo do Ato II é fotografado só no conjunto do nível 40). Custo: `tools/tests/addon_probe.tscn` (com janela). Check `_check_kit_addon`.
Filme das peças de costas/ombro num clipe: `lineup.tscn -- --strip=<classe> --set=<build> --level=35 --anim=<clipe> --frames=6 [--yaw=205] [--crop=0.22,0.70]` (`--frames` = quantos instantes, câmera mais perto; `--yaw` = giro, 90 perfil, 205 de costas em 3/4).
Conjuntos do Elementalista: `tools/blender/elementalist_sets.py` (`ELE_SETS` gerados por elemento × nível: o 1º elemento dá chapéu/coroa, barra
e cor; o 2º (`SECOND`, igual ao `favor` do `SET_VISUALS`) dá ombros, orbes e a gema do cajado). Elementais: `mob_kit.elemental(cid, kind)`;
revisar monstros: `lineup.tscn -- --mobs=<modelo>,<modelo> [--anim=idle]`.
Conjuntos do Necromancer: `tools/blender/necromancer_sets.py` (`NEC_SETS` por foco × nível: Invocador ossos/caveiras, Ceifador capuz rasgado/manto/cravos,
Sombras capuz alto/olho/aletas; `build_scythe`). Cão de ossos, Rei Esqueleto e a forma demoníaca (`form_demon`) saem de `mob_kit.build_all`.
Casulo de Seda (lacaio da Rainha Aranha, monstro `web_cocoon`): `mob_kit.web_cocoon` gera `mob_web_cocoon.glb` (peças rígidas nos ossos `body`/`core`/`head`/`arm_r`/`arm_l`;
clipes `idle run attack hit die`, no `die` as metades da casca tombam e o miolo some); refazer só ele: `mob_kit.build_all(out, only=["mob_web_cocoon"])`.
Muralha de Escudos do Ghar: `act2_bosses.ghar_wall_clips` soma ao `mob_ghar` os clipes `guard_wall` (laço, escudo-torre fincado à frente) e `wall_counter` (pancada de escudo + machado, impacto em `GHAR_COUNTER_IMPACT`); poses em `GHAR_TORSO` + `GHAR_SOLVED`, este achado por `tools/blender/ghar_wall_solve.py -- solve`. Refazer: `mob_kit.build_all(out, only=["mob_ghar"])`.
No jogo: `guard_wall` em laço durante a muralha e `wall_counter` no contragolpe (`EntityView.IMPACT_FRAME` 10 = `Balance.GHAR_COUNTER_DELAY` 0,375 s; clipes só de monstro em `EntityView.MOB_ONLY_CLIPS`).
Chefes e monstros do Ato II: corpo/peças em `act2_bosses.py` (Troll Rei, Besteiro, Ghar) e `kharzun_mobs.py` (Ulgra, Kragmar, Mãe-Loba, assassino, atirador de pedra, guarda de clã).
Arma/escudo que fura o chão num clipe: `act2_bosses.clear_ground(rig, clip, bone, prefixes, front=True)` depois de `mob_clips`/`posture` (gira o osso pela frente; `"*"` = todos os clipes; no `die` margem -0,2).
Conferir rente ao chão: `lineup.tscn -- --mob_strip=<modelo> --anim=<clipe> [--gap=3] [--cam_h=0.12] [--toon] [--no_glow]` (`--toon` = material do jogo; `--no_glow` = sem emissão).
Modelos das assinaturas dos chefes: `tools/blender/sig_props_a.py`/`_b.py`/`_c.py` → `prop_<chefe>_<peça>.glb` (peças `glow_*` brilham; ligados em `BossSigView._sig_model`).
Conjuntos do Druida: `tools/blender/druid_sets.py` (`DRU_SETS` humano; `DRU_STAFFS`, `DRU_MACES` com a 2ª maça na esquerda; formas: `build_forms`
gera `form_wolf.glb`/`form_bear.glb` com `frm_<estilo>_<slot>_<osso>`, lidos por `FormModel`). Revisar formas: `lineup.tscn -- --strip=druid --set=<build> --form=<wolf|bear>`
e no jogo `-- --autostart=druid --gear=<set_id> --form=<wolf|bear>`. Mudou um conjunto do Lobo/Urso: refaça o kit E as formas.
Ato II do Druida: `druid_sets.ACT2_SETS` (`dru_x35`/`dru_w35`/`dru_b35`, fora de `DRU_SETS` porque as formas ancestrais percorrem `DRU_SETS`) e `ACT2_FORM` + `form_armor2`
(`frm_dru_w35_*` no lobo, `frm_dru_b35_*` no urso; o `FormModel` pinta `tint`, `tint2` = `GearCatalog.set_accent` e `tint_glow` = `set_glow` do nível). Refazer só lobo/urso:
`druid_sets.build_forms(out, only=["wolf", "bear"])`. Formas ancestrais: `druid_ancestral.ACT2_STYLE` (Alfa = `form_armor2` do lobo, Ent `ent_armor2`, Pássaro `bird_armor2`; `frm_<estilo>_*`), FORA da conta de chão (`skip=` em `clear_form_ground`/`clear_ent_ground`): os clipes saem byte a byte iguais; refazer: `druid_ancestral.build(out, only=["alpha"|"ent"|"bird"])`. Folha: `lineup.tscn -- --strip=druid --set=<build> --form=<wolf|bear|alpha|ent|bird> --levels=30,35,40,45`.
Conjuntos do Bispo: `tools/blender/bishop_sets.py` (`BIS_SETS` túnicas, véu/touca/mitra/coroa, halo, asas; `BIS_MACES` via `paladin_sets.build_mace`;
`BIS_SHIELDS` em `shield_kit.FAMILIES`; `BIS_SCEPTERS` e `scepter_parts`, que também desenha o cetro comum do kit).
Conjuntos do Berserker: `tools/blender/berserker_sets.py` (`BER_SETS` armadura bárbara: capuz/elmo, chifres, pele, tiras, saiote; `BER_AXES`
machados, o 2º machado dos Gêmeos vira `wpn_off_axe_<estilo>` via `KitModel.off_node_of`). Build pode ter `passives` (árvore) e `set_extra` (bônus).
Machados: `tools/blender/axe_kit.py` (`HEADS`, `COMMON`, `kit_axe`); chefes passam a cabeça por `mob_kit.humanoid(axe=...)`.
Fio aceso do machado: `glow` = cor em `berserker_sets.AXE_GLOW`, emissão `axe_kit.EDGE_GLOW_ENERGY`; fim do dash: `chibi_kit.GROUND_EASE_*` (saída da correção de chão).
Conjuntos do Paladino (menos pal1): uma linha em `PAL_SETS` (`tools/blender/paladin_sets.py`, construtor paramétrico: elmo, enfeites,
ombreiras em camadas, tabardo, emblema, elmos fechados `closed` com fenda/grade/bico) + entrada em `GearCatalog.SET_VISUALS`.
Ícones: `"icon"` = estilo e `tools/icons/set_icons.tscn` (com janela) fotografa cada peça do kit; sem `icon` = símbolo do tipo.
Arma própria de conjunto: linha em `paladin_sets.PAL_WEAPONS` (lâmina em losango, guarda cross/down/sun/horn/wing, pomo, gema, halo,
filete brilhante) → malha `wpn_main_<tipo>_<estilo>`; a arma do conjunto ganha `ItemDef.weapon_style` e `KitModel.main_node` escolhe a malha.
Conjunto lendário = 5 peças de armadura (`SetDef.armor`: cabeça, peito, calça, luvas, botas; bônus 2-5); arma/mão secundária não contam e a arma tem
`ItemDef.legend_effect` próprio da build (`legend` da build em `classes_catalog.gd` + números em `Balance.LEGEND_NUMBERS`, tipos em `LegendEffects.legend_on_hit/legend_weapon/legend_on_kill`). Atributos das peças, da arma, da mão secundária
e dos escudos nomeados (por `SHIELD_AFFINITY`) vêm da build/classe (há check de coerência).
Maça de conjunto: build com 2 armas principais ganha a 2ª como `SetDef.alt_pieces` (não conta nas peças, cai como lendário; no Paladino
a espada ataca e a maça defende com Baluarte, `GearCatalog.WEAPON_ROLES`); modelo em `paladin_sets.PAL_MACES`. Revisar: `-- --autostart=paladin --gear=<set_id> --mace`.
Escudo de conjunto: família em `paladin_sets.SET_SHIELDS` (entra em `shield_kit.FAMILIES`; `shield_style` = estilo do conjunto, afinidade em
`SHIELD_AFFINITY`); ícone por `shield_icons.tscn`, contato por `shield_mount.py -- --check`.
Montagem dos escudos: rente ao antebraço, uma entrada por estilo em `chibi_kit.SHIELD_MOUNTS` (todos os estilos; achada por `shield_mount_study.py`, gravada por
`shield_mount_apply.py`); a alça vai soldada na malha do escudo (`kit_shield_strap`, 0 malhas a mais) e é aparada na silhueta da placa (`STRAP_CLIP`; `STRAP_HOLES` =
escudos em que um vão da placa também apara). Monstros com escudo ficam na montagem afastada, sem alça (`kit_shield(close=False)`). Ícone de alguns estilos: `shield_icons.tscn -- --only=<estilo>,...`.
Escudos altos (`shield_kit.TALL`, 17 estilos; espelho em `KitModel.TALL_SHIELDS`): clipes próprios `run_shield_tall` e `block_shield_tall` (`chibi_kit.animate_tall_shield`, só o braço
esquerdo muda; só nos kits de `SHIELD_CLASSES`, fora do `animate_v3`, então os outros kits e os monstros não mudam) e montagem medida neles (`ck.shield_clip`, usado pelo estudo e pelo
`shield_mount.py -- --check`). `shield_kit.ELBOW` = canto de cima do lado do cotovelo aparado por estilo (k, x0, z0; `--trim=` do estudo experimenta sem editar); vale só com
`kit_shield(close=True)` e também no `shield_mount_study.legacy_shield`. `shield_mount_apply.py` mantém as entradas dos estilos que o json não traz.
Guarda montada do escudo alto: clipe `block_ride_tall` do kit (`chibi_kit._shield_ride_tall_pose` + `SHIELD_RIDE_TALL`, em `animate_tall_shield`); o braço sai de `tools/blender/shield_ride_solve.py`
(`-- solve` procura, `-- check [--old] [--mount=a,b]` conta cruzamentos com a montaria e toques no cavaleiro, nos dois sexos). Ponta que não fura o chão: `chibi_kit.add_shield_tip` (osso `shield_tip.L`,
só nos kits de `SHIELD_CLASSES`) + `skin_shield_tip` (rampa de pesos abaixo do antebraço, `SHIELD_TIP_PIVOT`), lidos por `ShieldGround` no jogo; mexeu em um dos dois: refaça os 4 kits e rode `tools/tests/shield_probe.tscn`.
Kits por classe: `build_kits` gera `kit_<classe>_<male|female>.glb` (os dois sexos: criação de personagem) (corpo + peças comuns + SÓ os conjuntos/armas/escudos dela, pelo prefixo em
`chibi_kit.CLASS_PREFIX`; escudos só em `SHIELD_CLASSES`) e `kit_<male|female>` genéricos para NPCs; `KitModel.create(..., class_id)`.
Classe nova com conjuntos: adicione o prefixo em `CLASS_PREFIX`.
Criação de personagem: `tools/blender/looks.py` põe em todo kit cabelos `base_hair_<estilo>`, barbas `base_beard_<estilo>` e olhos `base_eyes_<estilo>`
(uma malha cada; materiais `hair`/`beard`/`iris`); os nomes batem com `data/catalog/looks_catalog.gd`. Estilo novo = função em `looks.py` + entrada no
catálogo + refazer os kits. `SimEntity.look` (salvo no save; bots sorteiam) → `KitModel.apply_look`. Cada boneco instancia o kit inteiro, então peças de conjunto passam
por `paladin_sets.join_slots` (1 malha por slot) e há check de < 200 malhas por kit (o smoke headless não pega o estouro da GPU).
Lendário com visual próprio: referência em `reference/<classe>/set_N/` → função `kit_set_<estilo>` em `chibi_kit.SET_STYLES`
(revisar em loop com `look` frente/costas contra a referência), entrada em `GearCatalog.SET_VISUALS` (estilo, cor, `suffix`/`adj` do nome, ícone; substantivos da build em `PIECE_NOUNS`)
e ícones 128 px em `assets/icons/<icone>_<peça>.png`. Revisar no jogo: `lineup.tscn -- --strip=<classe> --set=<build> --level=<lv>`
e `-- --autostart=<classe> --gear=<set_id> --screenshot=<png>` (janela C com ícones).
Carga dos NPCs que trabalham (`carry` em `MapsCatalog.LIVING_NPCS`, só visual): `tools/blender/life_props.py` → `prop_<carry>.glb` em tamanho real
(`carry_crate|carry_sack|carry_log|carry_rock` no ombro, `cart` puxada à mão, `cart_draft` puxada por animal); pose dos braços e ajustes em `CarryPose`
(`game/entities/carry_pose.gd`). `CarryPose.DRAFT` = animal de tiro: `EntityView._attach_draft` põe o `mob_horse` entre os varais sem a sela (`strip`, fusão
própria no `RigidMerge`) e `_animate_draft` atrasa o nó `cart` na curva (peça com `node`/`pivot`/`under` sai em nó à parte: `prop_kit.export_scene`).
Rodas: o nó `wheels` (origem no eixo) gira pela distância andada nas duas carroças (`EntityView._animate_wheels`; raio em `CarryPose.WHEELS` / `DRAFT.wheel_r`).
Refazer: `prop_kit.build_all(out, only=["cart", "cart_draft"])`; revisar: `-- --autostart=paladin --carry_shot=<png> [--carry=cart|cart_draft]`.
Costas/lado de um monstro: `lineup.tscn -- --mobs=<m>,<m>,<m> --yaws=180,115,270 [--cam_dist=5.6]` (peça nas costas tem de passar por fora da cabeça chibi).
Auditoria de clipes: `tools/lineup/film_all.sh` filma tudo e `--headless --path . tools/tests/anim_probe.tscn` mede emenda do laço, giro por quadro,
quadros parados e cabeça no chão (notas em `docs/animations_review.md`). Força das skills: `--headless --path . tools/tests/skill_audit.tscn` (`WEAK` < 60% da mediana).
Revisão em loop: `.\tools\godot.ps1 --path . tools/lineup/lineup.tscn -- --shot=<png> --anim=<clipe>` (todas as classes,
equipamento inicial + lendários de cada build).
