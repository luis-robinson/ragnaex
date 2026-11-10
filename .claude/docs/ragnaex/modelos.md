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
Conjuntos do Elementalista: `tools/blender/elementalist_sets.py` (`ELE_SETS` gerados por elemento × nível: o 1º elemento dá chapéu/coroa, barra
e cor; o 2º (`SECOND`, igual ao `favor` do `SET_VISUALS`) dá ombros, orbes e a gema do cajado). Elementais: `mob_kit.elemental(cid, kind)`;
revisar monstros: `lineup.tscn -- --mobs=<modelo>,<modelo> [--anim=idle]`.
Conjuntos do Necromancer: `tools/blender/necromancer_sets.py` (`NEC_SETS` por foco × nível: Invocador ossos/caveiras, Ceifador capuz rasgado/manto/cravos,
Sombras capuz alto/olho/aletas; `build_scythe`). Cão de ossos, Rei Esqueleto e a forma demoníaca (`form_demon`) saem de `mob_kit.build_all`.
Conjuntos do Druida: `tools/blender/druid_sets.py` (`DRU_SETS` humano; `DRU_STAFFS`, `DRU_MACES` com a 2ª maça na esquerda; formas: `build_forms`
gera `form_wolf.glb`/`form_bear.glb` com `frm_<estilo>_<slot>_<osso>`, lidos por `FormModel`). Revisar formas: `lineup.tscn -- --strip=druid --set=<build> --form=<wolf|bear>`
e no jogo `-- --autostart=druid --gear=<set_id> --form=<wolf|bear>`. Mudou um conjunto do Lobo/Urso: refaça o kit E as formas.
Conjuntos do Bispo: `tools/blender/bishop_sets.py` (`BIS_SETS` túnicas, véu/touca/mitra/coroa, halo, asas; `BIS_MACES` via `paladin_sets.build_mace`;
`BIS_SHIELDS` em `shield_kit.FAMILIES`; `BIS_SCEPTERS` e `scepter_parts`, que também desenha o cetro comum do kit).
Conjuntos do Berserker: `tools/blender/berserker_sets.py` (`BER_SETS` armadura bárbara: capuz/elmo, chifres, pele, tiras, saiote; `BER_AXES`
machados, o 2º machado dos Gêmeos vira `wpn_off_axe_<estilo>` via `KitModel.off_node_of`). Build pode ter `passives` (árvore) e `set_extra` (bônus).
Conjuntos do Paladino (menos pal1): uma linha em `PAL_SETS` (`tools/blender/paladin_sets.py`, construtor paramétrico: elmo, enfeites,
ombreiras em camadas, tabardo, emblema, elmos fechados `closed` com fenda/grade/bico) + entrada em `GearCatalog.SET_VISUALS`.
Ícones: `"icon"` = estilo e `tools/icons/set_icons.tscn` (com janela) fotografa cada peça do kit; sem `icon` = símbolo do tipo.
Arma própria de conjunto: linha em `paladin_sets.PAL_WEAPONS` (lâmina em losango, guarda cross/down/sun/horn/wing, pomo, gema, halo,
filete brilhante) → malha `wpn_main_<tipo>_<estilo>`; a arma do conjunto ganha `ItemDef.weapon_style` e `KitModel.main_node` escolhe a malha.
Conjunto lendário = 5 peças de armadura (`SetDef.armor`: cabeça, peito, calça, luvas, botas; bônus 2-5); arma/mão secundária não contam e a arma tem
`ItemDef.legend_effect` próprio da build (`legend` da build em `classes_catalog.gd` + números em `Balance.LEGEND_NUMBERS`, tipos em `LegendEffects.legend_on_hit/legend_weapon/legend_on_kill`). Atributos das peças, da arma, da mão secundária
e dos escudos nomeados (por `SHIELD_AFFINITY`) vêm da build/classe (há check de coerência).
Maça de conjunto: build com 2 armas principais ganha a 2ª como `SetDef.alt_pieces` (mesmo efeito lendário da arma, não conta nas peças, cai como
lendário); modelo em `paladin_sets.PAL_MACES`. Revisar: `-- --autostart=paladin --gear=<set_id> --mace`.
Escudo de conjunto: família em `paladin_sets.SET_SHIELDS` (entra em `shield_kit.FAMILIES`; `shield_style` = estilo do conjunto, afinidade em
`SHIELD_AFFINITY`); ícone por `shield_icons.tscn`, contato por `shield_mount.py -- --check`.
Kits por classe: `build_kits` gera `kit_<classe>_<male|female>.glb` (os dois sexos: criação de personagem) (corpo + peças comuns + SÓ os conjuntos/armas/escudos dela, pelo prefixo em
`chibi_kit.CLASS_PREFIX`; escudos só em `SHIELD_CLASSES`) e `kit_<male|female>` genéricos para NPCs; `KitModel.create(..., class_id)`.
Classe nova com conjuntos: adicione o prefixo em `CLASS_PREFIX`.
Criação de personagem: `tools/blender/looks.py` põe em todo kit cabelos `base_hair_<estilo>`, barbas `base_beard_<estilo>` e olhos `base_eyes_<estilo>`
(uma malha cada; materiais `hair`/`beard`/`iris`); os nomes batem com `data/catalog/looks_catalog.gd`. Estilo novo = função em `looks.py` + entrada no
catálogo + refazer os kits. `SimEntity.look` (salvo no save; bots sorteiam) → `KitModel.apply_look`. Cada boneco instancia o kit inteiro, então peças de conjunto passam
por `paladin_sets.join_slots` (1 malha por slot) e há check de < 200 malhas por kit (o smoke headless não pega o estouro da GPU).
Lendário com visual próprio: referência em `reference/<classe>/set_N/` → função `kit_set_<estilo>` em `chibi_kit.SET_STYLES`
(revisar em loop com `look` frente/costas contra a referência), entrada em `GearCatalog.SET_VISUALS` (estilo, cor, nomes, ícone)
e ícones 128 px em `assets/icons/<icone>_<peça>.png`. Revisar no jogo: `lineup.tscn -- --strip=<classe> --set=<build> --level=<lv>`
e `-- --autostart=<classe> --gear=<set_id> --screenshot=<png>` (janela C com ícones).
Auditoria de clipes: `tools/lineup/film_all.sh` filma tudo e `--headless --path . tools/tests/anim_probe.tscn` mede emenda do laço, giro por quadro,
quadros parados e cabeça no chão (notas em `docs/animations_review.md`). Força das skills: `--headless --path . tools/tests/skill_audit.tscn` (`WEAK` < 60% da mediana).
Revisão em loop: `.\tools\godot.ps1 --path . tools/lineup/lineup.tscn -- --shot=<png> --anim=<clipe>` (todas as classes,
equipamento inicial + lendários de cada build).
