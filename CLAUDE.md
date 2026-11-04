# RagnaEx — guia para o Claude Code

Protótipo de "MMO" 2.5D single-player com bots. **Godot 4.7.2 + GDScript**, sem addons.
Arte: Tree of Savior (chibi, pastel, toon 3 tons + outline) · **layout de mundo estilo Erenshor** (zonas orgânicas:
vale fechado, vila murada como hub, estradas curvas, rio com pontes, POIs com marcos — ver "Layout de zonas") ·
câmera Ragnarok (52°, yaw em 45°, a mesma perspectiva de sempre) · combate Drakantos (encara o cursor, LMB básico,
skills com mira MOBA). Leia `README.md` e `docs/DESIGN.md`.

## Comandos

```powershell
# Windows (use o wrapper; ele acha o Godot em Program Files / Downloads / $env:GODOT)
.\tools\godot.ps1 --headless --path . --import                    # (re)gera cache de classes — rode após criar scripts com class_name
.\tools\godot.ps1 --headless --path . tools/tests/tests.tscn      # testes (8000+ checks) — OBRIGATÓRIO antes de terminar uma tarefa
.\tools\godot.ps1 --headless --path . -- --autostart=berserker    # smoke test: joga sozinho e sai; 0 "SCRIPT ERROR" é o critério
.\tools\godot.ps1 --path .                                        # abre o jogo com janela
```
Linux/mac: troque `.\tools\godot.ps1` por `godot` (binário 4.7.2 no PATH).

Scripts novos com `class_name` só são vistos pelos outros scripts depois de `--import`.

## Arquitetura (regra de ouro)

- `core/` = **simulação**. Nunca importe/instancie `Node3D`, `Control`, câmera, shaders ou `Input` aqui.
  Tudo que acontece no jogo passa por `core/sim/world_sim.gd` (autoload `Sim`) via `InputCommand`.
  Jogador e bots são a mesma coisa para a sim (só muda quem gera o comando). Isso é o futuro servidor.
- `game/` = **apresentação**. Lê o estado da sim, nunca muda HP/posição/inventário diretamente;
  chama métodos públicos de `Sim` (`equip`, `use_potion`, `upgrade_mastery`, `try_cast`…) ou os
  sistemas estáticos (`QuestSystem`, `CraftSystem`). Reage aos sinais de `core/events.gd` (autoload `Events`).
- `data/` = conteúdo. Schemas (Resources) em `data/schemas/`, dados em `data/catalog/*_catalog.gd`
  (dicionários → Resources em `GameData._ready`). Constantes de balanceamento SÓ em `data/balance.gd`.
- Autoloads (ordem): `Events`, `Balance`, `GameData`, `Sim`, `SaveSystem`.

## Como adicionar conteúdo

- **Skill**: `data/catalog/skills_catalog.gd` → `_more()` com `_s(...)`/`_buff(...)` (20+ por classe; nível, build e
  arma exigida em cada uma; o jogador aprende com pontos e equipa 6). `ClassDef.skill_ids` é preenchido sozinho.
  Campos em `data/schemas/skill_def.gd`; efeitos suportados por `WorldSim._apply_effects`
  (`dot, slow, stun, root, buff, shield, dash, summon, heal_pct_of_dmg, taunt, boss_summon, wither`); `dot` de skill de fogo vira queimadura sozinho e gelo estilhaça alvo retardado (`Combat.frost_mult`). Mira: SELF/DIRECTION/GROUND/CONE/TARGET.
  A skill entra sozinha na árvore de pontos (`data/catalog/tree_catalog.gd`, ramo da build dela); nada a editar lá. Na janela K as linhas têm altura fixa (`TREE_ROW_PX`) e o painel rola; há check de folga entre nós.
  Talentos de escolha (aba Talentos): `TreeCatalog.PICK_ROWS` + `PICK_FLAVOR` por classe (um por linha, `WorldSim.pick_sibling`); revisar `--bag_shot=<png> --wins=skills --level=20 --picks`.
  Ícone: adicione o id em `GLYPHS` (`tools/icons/make_icons.gd`) e rode `.\tools\godot.ps1 --path . tools/icons/make_icons.tscn` + `--import`.
  Fundo vem do tema, marcas (área, cone, avanço) finas ATRÁS do símbolo e selos (buff, dano no tempo, dreno) em discos nos cantos de baixo,
  todos dos dados; símbolo fino/cheio se equilibra em `GLYPH_WEIGHT`. Sombreado toon (`_toon`) e sombra projetada (`_flush` desenha as sombras de todos os símbolos antes) saem sozinhos de `_p`/`_c`/`_l`;
  anel desenhado à mão dentro de um símbolo usa `_garc` (respeita a sombra). `DUP` no log = ícone igual a outro da classe. Revisar com `--sheet=<png> --only=<classe>`.
  Visual: tema (`SkillDef.vfx`, por palavra no id em `SkillsCatalog.VFX_RULES`) → cor/partículas/forma em `game/fx/skill_fx.gd`;
  clipe pela forma da skill em `EntityView._action_clip`. Revisar em loop na **bancada**:
  `.\tools\godot.ps1 --path . -- --showcase=<classe> [--skill=<id>] --out=<pasta>` (folha de 8 quadros por skill + páginas-resumo
  `<classe>_pagina_N.png`; quadro do impacto em amarelo) e `--headless ... --showcase=all --check` (lança as 174 sem erro).
  Notas em `docs/skills_review.md` (pose, tempo, forma, identidade, retorno — 0-2 cada, passa com ≥ 8).
  Clipe por família em `EntityView._action_clip`; poses em `chibi_kit._family_clips`. A cabeça é enorme: `_tame` limita tronco e cabeça dos golpes.
  Filme o clipe de perto (`lineup --strip`, de lado e `--front`): a bancada mostra tempo e efeito, não a pose.
- **Escudo**: linha em `GearCatalog.SHIELDS` (modelo próprio em `tools/blender/shield_kit.py`, um por escudo; afinidade em `GearCatalog.SHIELD_AFFINITY` dá Juramento/Graça; ícone é foto do modelo: `tools/icons/shield_icons.tscn`; `shield_effect` = reação ao bloquear).
  Rode `build_kits` e `tools/icons/shield_icons.tscn` (com janela) + `--import`. Revisar: `-- --autostart=paladin --block_shot=<png> [--shield=<id>]`, `lineup.tscn -- --shields [--page=N] --anim=block_shield`, `--block_film`; montagem e guarda: `tools/blender/shield_mount.py` (sem args resolve `SHIELD_*` no idle; `-- --guard` acha o braço do
  `block_shield`; `-- --check` conta toques fora do braço esquerdo em idle/corrida/guarda, os 18 escudos). Mudou montagem ou pose: rode `--check`.
- **Build**: `ClassDef.builds` em `classes_catalog.gd` (armas, armadura, atributos, skills em prioridade). Uma build nova
  ganha conjuntos lendários sozinha (`gear_catalog.gd`; adicione o nome em `BUILD_OF`).
- **Evolução** (skill ou dash): `data/catalog/talents_catalog.gd` (`TalentDef`; dash = `skill_id: "dash"`).
- **Item/equipamento**: `items_catalog.gd` (atributos FOR/AGI/VIT/WILL/INT vêm SÓ de equipamento). Ícone: sem `icon` próprio, arte pintada
  `art_<id>.png` por `tools/icons/item_icons.gd` (laço sobre todos os itens; forma por `ItemIcons.art_key`: tipo de arma, slot + `armor_style`,
  palavra no id do material; cor principal = `icon_color`, acabamento/gema/brilho pela raridade) sobre a moldura `slot_r<raridade>.png`
  (fotos de conjunto/escudo também vão na moldura, recuadas 10%).
  Forma nova = `_a_<chave>` em `item_icons.gd` (há check). Rodar `item_icons.tscn [-- --only=<id> --sheet=<png>]` (com janela) e `--import`.
  Loja do mercador (`npc_ui._shop`): grade da mercadoria e da bolsa, abas, clique/Shift, "vender materiais" (`junk_of`); revisar `--bag_shot=<png> --wins= --shop`.
  Bolsa ↔ boneco por arrastar e soltar (`windows._drag_from_bag/_drop_on_slot/_drop_on_bag`; clique = soltar sem arrastar); conferir com `--bag_shot=<png> --dnd_check`.
  Barra de buffs/debuffs do HUD: ícone da skill/item que deu (`hud._buff_source`) ou `status_<estado>.png` (`make_icons.tscn -- --only=status`),
  tempo embaixo; revisar com `--bag_shot=<png> --status_demo --wins=`.
  A mesma arte boia sobre o baú no chão (`LootChest`) e aparece no aviso de item pego (`hud._on_item_gained`); revisar com `-- --loot_demo --screenshot=<png>`.
  Revisar: `-- --autostart=<classe> --bag_shot=<png>`. Armas novas por tier e
  lendários/conjuntos são gerados por loops em `gear_catalog.gd` (números em `Balance.GEAR_*`/`SET_*`/`LEGENDARY_*`).
- **Forja/alquimia**: não fazem armas nem armaduras (essas caem de monstro: `WorldSim.gear_pool` por tier, filtradas pela classe; nível 1 na loja).
  Fazem joias e capas por tier x tema (`RecipesCatalog.gear_recipes`, laço) e Bolsas Ampliadas (`bag_t0..3`, `Balance.BAG_*`; bolsa tem limite de pilhas).
  Aprimoramento no ferreiro: `WorldSim.enhance`/`enhance_cost` (+1..+9, nunca quebra; `Balance.PLUS_*`), por CÓPIA: a peça aprimorada vira a versão `<id>+N` (`GameData.plus_item`, stats da base com o bônus; `ItemDef.base_id/plus`; saves voltam por `GameData.resolve_item`);
  brilho `plus_glow` no toon (`KitModel.plus_glow_color`). Revisar: `lineup.tscn -- --plus_demo --strip=<classe>` e `--bag_shot=<png> --wins= --enhance`.
- **Monstro**: `monsters_catalog.gd` + loot table + spawner em `maps_catalog.gd` (+ modelo `mob_<id>` no Blender).
- **Lugar** (cabana com NPC, acampamento, santuário, entrada de dungeon): uma linha em `PLACES` no `build_<zona>.py`; a forma
  vem de `tools/blender/zones/places.py`. NPC novo vai em `MapsCatalog.PLACE_NPCS` e toda cabana dá quest (lateral, em `quests_catalog.gd`).
  `_check_places` exige os 4 tipos por zona e prova que tudo é alcançável a pé. `PLACE_CONFLICT` no build = lugar colado em estrada/rio.
- **Casa que abre** (interior): entrada em `MapsCatalog.INTERIORS` (casa do JSON mais perto de `house`, sala, móveis, NPCs); porta só do jogador
  (`player_only`), saída volta para a frente da casa; `MapDef.interior`. Móvel novo = função em `prop_kit.py` (+ `BUILDERS`) e `build_all(only=[...])`.
  Revisar: `-- --tour=<pasta> --tour_map=<in_id>`. Morador que passeia: `MapsCatalog.VILLAGERS` (`wander`/`route`).
- **Dungeon**: entrada em `places.DUNGEONS` + `MapsCatalog.DUNGEON_DEFS`; o mapa sai de `build_dungeons.py` (forma única por loop).
  É mapa compartilhado (`MapDef.parent_map`), não instância; bots não caçam lá sozinhos.
  Dungeon ramificada: `layout` em `places.DUNGEONS` (salões + ligações, `build_dungeons.build_graph`; rocha sólida sela as alas). `door` = selo para outro mapa
  (`parent_map` em cadeia, que bots seguem). `bosses` no `DUNGEON_DEFS` se houver mais de um; NPCs de dentro em `PLACE_NPCS[<dungeon>]`.
- **Chefe com mecânica**: `MonsterDef.phases` (`hp`, `say`, `skills`, `summon`, `enrage`) em `_update_boss`; lacaios com 0 XP via `summon` ou efeito `boss_summon` (nunca o `summon` de jogador).
  Chefe sem alvo reseta (`reset_boss`). Calibre rodando a luta com bots: eles têm ATK de equipamento do nível, bem acima do inicial.
  Sonda: `--headless --path . tools/tests/boss_probe.tscn -- [--party=1,3] [--trials=20] [--boss=<id>,...]` (vitórias, tempo, mortes).
  Use 20+ lutas: com 14 a variação passa de ±2 vitórias.
- **Colheita**: ponto em `MapsCatalog.GATHER[<mapa>]` (item, forma `herb|herb_blue|ore|star|shell|mushroom|relic|crate`, centro, raio, quantos); a sim espalha
  (`WorldSim._spread_gather`), F colhe (`_start_gather/_update_gather`), visual em `game/world/gather_view.gd`. Item novo precisa de arte (`item_icons`).
- **Entrega**: quest COLLECT com `give_items` (o pacote) e `turnin_npc` diferente do `giver_npc`. XP de quest é escalada por faixa (`QuestsCatalog.scale_xp`):
  o número escrito vale como peso; o teste confere 40-50% da faixa e 10+ quests por faixa.
- **Portão de progressão**: `MapsCatalog.PORTAL_GATES` (id do portal → `level`, `quest`, `bosses`, `text`); vale só para o jogador. Save sem `save_version` passa por `grandfather_gates`.
- **Grupo (party)**: regras na sim (`WorldSim.party_*`, `kill_sharers`; aliado = `SimEntity.is_friend`), números em `Balance.PARTY_*`,
  bots em `BotBrain._follow/_gather_party/wants_party`; UI em `hud.gd` (quadros/convite/comandos de chat) e janela `party` (P).
- **Quest**: `quests_catalog.gd` (KILL/COLLECT/TALK/CRAFT/REACH; NPC giver precisa existir em algum `MapDef.npcs`). `prereq_all` junta ramos, `reward_gear_tier` dá peça vestível, `repeatable` é recompensa de quadro.
- **Mapa/zona**: siga "Layout de zonas" abaixo (`/layout-zone`). O `MapDef` continua sendo a verdade da sim
  (obstáculos = colisão, portais, spawners, NPCs); o visual da zona vem do Blender (`map_<zona>.glb`).
- Sempre adicione um `check(...)` em `tools/tests/run_tests.gd` para conteúdo/regra nova.

## Layout de zonas (estilo Erenshor, câmera de cima)

Referência: `C:\Users\luisf\Desktop\projects\erenpg` (`blender/scripts/build_vale_inicial.py`,
`godot/assets/maps/vale_inicial.png`, `ERENSHOR_LIKE_PROJECT.md`). Nada de mapa quadrado com caminhos em cruz/grade.

**Estrutura de toda zona** (1 unidade = 1 m; personagem ≈ 1.7 m; corrida ≈ 5.5 m/s):
- **Vale fechado** de ~240 × 240 m: borda natural (anel de penhascos/montanhas facetadas, floresta densa ou mar) —
  nunca uma borda reta visível. Portais para outras zonas ficam em gargantas/passagens na borda.
- **Hub no centro**: vila murada circular (raio ~25–30 m) com praça radial (chafariz/marco), mercado, NPCs de
  serviço (ferreiro, alquimista, mercador, quest), portões nas direções das estradas. Cabe 10+ bots sem travar.
- **3–5 POIs** a 60–120 m do hub (1–2 min de caminhada): floresta, ruínas com monumento, lago, acampamento,
  boca de caverna/dungeon. Cada POI tem identidade visual própria (cor do chão, props, marco) e seus spawners.
- **Estradas curvas** (catmull-rom, 4 m de largura) ligando hub↔POI e POI↔POI; nunca linha reta, sem becos
  sem saída acidentais. Rio/lago com **pontes** como únicos cruzamentos.
- **Landmark** visível de qualquer ponto (castelo na colina, torre em ruínas, árvore gigante) — fora das rotas
  principais para não esconder o jogador.
- **Leitura de cima** (a câmera é alta, 52°): o que define a zona é o que se vê no chão — estradas de terra,
  muros, telhados, manchas de cor por região (floresta escura, campo claro, pedra da vila, água). Nada alto
  (> 6 m) colado nas estradas perto do hub; o fade de oclusão existe, mas o layout não deve depender dele.
- **Altura**: a sim é plana (andável = plano y = 0). Verticalidade é visual: penhascos da borda, colinas e
  patamares como obstáculos sólidos (não andáveis), muros, castelo sobre base sólida. Rampas/colinas andáveis
  exigem altura na sim (heightmap) — ainda não existe; não prometa isso no layout.

**Pipeline** (Blender = fonte do layout; a sim continua 100% dados):
- `tools/blender/zones/build_<zona>.py` (usando `zone_lib.Zone`: estradas, rio, pontes, penhascos, paliçadas, morros,
  dispersão; e `nature.py`: `scatter`, `shore`, `fix_trees`, `woodland_floor`, `mountain_ring`) constrói a zona inteira por
  loops (nada objeto a objeto) dentro da Collection `Z_<zona>` e exporta o visual para `assets/models/map_<zona>.glb`
  (`MapDef.model = "map_<zona>"`). Sem janela: `blender -b --factory-startup --python <script>` chamando `build(export=True)`.
- A dispersão de uma zona muda quando lugares/trilhas mudam: chegadas de portal precisam estar reservadas (`block`/`spots`).
- Água e morros colidem na sim (`WorldSim._build_collider_grid`): o rio só tem vão nas pontes, que nascem onde uma estrada
  (`kind: "road"`) cruza o rio. Bots usam `water_path`; mudou rio/ponte, rode os testes de travessia (`_cross_river`).
  Toda zona chama `nature.clear_banks` depois de espalhar a vegetação: corredor de 2 m livre nas margens (sem bolsões; há check).
- Marcadores no Blender viram dados da sim (exportados para `data/zones/<zona>.json` e lidos pelo `maps_catalog.gd`):
  `OB_box_<nome>` / `OB_circle_<nome>` (colisão: tamanho/rotação do objeto), `SPAWN_player_01`,
  `SPAWN_mob_<monster_id>_NN` (raio no nome ou custom prop `radius`), `SPAWN_npc_<npc_id>`,
  `SPAWN_hangout_NN` (pontos de bot), `TRIG_portal_<zona_destino>` (+ `SPAWN_chegada_<zona_origem>` no destino).
- Nomes do visual: `Z_<zona>_<tipo>_<nome>` (`terreno`, `estrada`, `agua`, `ponte`, `muro`, `casa`, `prop`,
  `arvore`, `penhasco`). Materiais `tint`/`roof` funcionam como nos props (cor vinda dos dados).
- Nunca apague objetos fora de `Z_<zona_atual>`, `OB_*`, `SPAWN_*`, `TRIG_*` da zona atual. Não salve `.blend`
  de outro projeto aberto no Blender do usuário — confira `bpy.data.filepath` antes.

**Loop de layout** (`/layout-zone <zona — descrição>`, `/layout-check`): blocagem primeiro (cores lisas), depois
detalhe. A cada iteração tire 3 screenshots — `CAM_top` (ortográfica sobre a zona), `CAM_game` (a câmera do jogo:
52°, distância 24 m, olhando o hub) e `CAM_poi` (câmera do jogo num POI) — e dê nota 0–2 em:
legibilidade (acho o hub de qualquer ponto?), fluxo (estradas curvas, sem becos), ritmo (hub→POI 60–120 m),
borda/altura (borda natural, landmark, patamares visuais), multidão (hub comporta 10+ bots). Corrija só os pontos
fracos e repita; pare com nota ≥ 8 (máx 6 iterações). Depois valide no jogo (tour de screenshots pela zona) e rode
testes + smoke (tour: `-- --tour=<pasta> [--tour_map=<zona>]` salva screenshots dos POIs).

## Desempenho

- `KitModel`: peça que não aparece sai da árvore (`_show`) e só ganha material toon ao aparecer; procure peças com `kit.pieces("<glob>")`,
  não com `find_children` (só acha as ligadas). Mapas sem o jogador simulam a cada `Balance.AWAY_MAP_EVERY` ticks (`Sim.away_every`).
- Draw calls: peças ligadas do kit viram 1 malha (`KitModel._remerge`) e monstros/cavalo de peças rígidas também (`RigidMerge`, malha guardada por modelo);
  bonecos a mais de 58 m somem e param de processar (`main._cull_views`), props têm distância de desenho (`MapBuilder.set_vis_range`).
  Ação de 1 vez no `InputCommand` (montar, voltar) precisa ser zerada no comando repetido entre pensamentos (`WorldSim.tick`).
- Lentidão que só aparece jogando: `main._perf_watch` grava em `user://perf_log.txt` (AppData/Roaming/Godot/app_userdata/RagnaEx) cada trecho < 25 FPS com
  mapa, monstros acordados, draws, GPU e as fases da sim; reproduzir com `-- --soak=<s> [--soak_map=<dungeon>]` (joga sozinho e imprime FPS a cada 5 s).
- Medir: `.\tools\godot.ps1 --path . -- --perf [--perf_at=x,z] [--no_merge] [--cull_test=hide|noproc] [--no_prune] [--no_away]` (cidade cheia ~8 s: FPS, draw calls, nós, memória, custo do tick).

## Estilo GDScript

- Tipagem estática; `var x := ...` só quando o tipo é inferível (valores vindos de `Array`/`Dictionary`
  untyped precisam de tipo explícito: `var d: float = e.position.distance_to(...)`).
- Lambdas de uma linha podem ter `a(); b()`, mas não `if`. Use métodos nomeados para sinais com lógica.
- `lerp`/`lerpf` em `_process`: sempre `minf(1.0, delta * k)` como peso.
- Texto do jogo em pt-BR; comentários curtos em pt-BR; nomes de código em inglês.
- Nada de `.tscn` grandes editados à mão: UI e mundo são construídos em código.

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
`RAN_BOWS` na mão esquerda; `RAN_RIFLES` e `rifle_parts`, que também desenha o mosquete comum). Lince: `mob_kit.quadruped(kind="lynx")`.
Conjuntos do Assassino: `tools/blender/assassin_sets.py` (`ASS_SETS` Lâminas: capuz + máscara de pano, frascos de veneno, capa rasgada; Duelista:
chapéu de pluma/máscara de baile, casaca de abas, meia-capa; `ASS_WEAPONS` gera o par `wpn_main_`/`wpn_off_<dagger|sword>_<estilo>`).
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
`ItemDef.legend_effect` próprio da build (`GearCatalog.LEGEND_EFFECTS`, tipos em `WorldSim._legend_on_hit/_legend_weapon/_legend_on_kill`; build nova precisa de entrada lá). Atributos das peças, da arma, da mão secundária
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
Revisão em loop: `.\tools\godot.ps1 --path . tools/lineup/lineup.tscn -- --shot=<png> --anim=<clipe>` (todas as classes,
equipamento inicial + lendários de cada build).

## Save

`SaveSystem` (autoload): espaços `user://save_<n>.json` (`SLOTS`), `SaveSystem.slot` = personagem em jogo. `--autostart` usa `slot = -1` (não grava)
e os testes usam `TEST_SLOT` (90): nunca apague/grave `save_0..4` em teste ou revisão. Esc → `hud.open_game_menu`; voltar ao menu = `main.return_to_menu`
(`Sim.reset_world` + recarregar a cena; `--autostart=<c> --return_check [--menu_shot=<png> --return_shot=<png>]` confere).

## Definition of done

1. `--import` + testes passam (0 failed) + smoke sem `SCRIPT ERROR`.
2. Nenhum `Node`/`Input` dentro de `core/`.
3. Conteúdo novo tem check nos testes e está no README/`docs/DESIGN.md` se mudar regra.
