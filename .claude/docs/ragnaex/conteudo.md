<!-- RagnaEx manual (pt-BR) — Como adicionar conteúdo. Moved VERBATIM from the old CLAUDE.md on 2026-11-08 (CCGS adoption); imported by CLAUDE.md. Edit here. -->

## Como adicionar conteúdo

- **Skill**: `data/catalog/skills_catalog.gd` → `_more()` com `_s(...)`/`_buff(...)` (20+ por classe; nível, build e
  arma exigida em cada uma; o jogador aprende com pontos e equipa 6). `ClassDef.skill_ids` é preenchido sozinho.
  Campos em `data/schemas/skill_def.gd`; efeitos suportados por `WorldSim._apply_effects`
  (`dot, slow, stun, root, buff, shield, dash, summon, heal_pct_of_dmg, taunt, boss_summon, wither, mend_pct_of_dmg, combust, bounce, aura`; aura = liga/desliga em `AuraSystem`, `bounce` = projétil que ricocheteia; `SkillDef.clip`/`vfx` forçam clipe e tema); `dot` de skill de fogo vira queimadura sozinho e gelo estilhaça alvo retardado (`Combat.frost_mult`). Mira: SELF/DIRECTION/GROUND/CONE/TARGET.
  A skill entra sozinha na **teia** (estilo Path of Exile, `data/catalog/tree_catalog.gd`): malha de junções e estradas (grade `CELL` irregular,
  sorteio fixo por classe, parte das estradas sai = escolha de rota) com círculos nas casas: de skill (maestria/evoluções/passivos em volta) e de
  notável (`ARM_NOTABLES`/`RING_NOTABLES`, duas entradas). Setores por ramo; skill de nível alto mais longe. Há check de folga (`windows.NODE_PX`/`WEB_UNIT`). 8 pontos por nível (`Balance.points_at`); estradas/junções só caminho. Quanto a teia dá: `--headless --path . tools/tests/web_probe.tscn -- [--level=30]` (alvo ~x1,4 ATK, ~x1,2 HP no 30). Bots compram
  caminho na teia (`ProgressionSystem.bot_spend`). Revisar: `--bag_shot=<png> --wins=skills --level=<n> [--build_i=N]` (arrastar/zoom/busca na janela K).
  **Talentos de classe** (aba Talentos): `data/catalog/class_talents_catalog.gd`, 6 linhas (5..30) × 3 por classe, um por linha (nós `pick` `<classe>_c_<id>`,
  `WorldSim.pick_sibling`, troca na cidade). Ganchos: `permanent`/`aura` (buff da skill sempre ativo / em você e no grupo), `summon_permanent`/`summon_extra`,
  `skill_mods`, `stats`, `form_mult`/`form_time`, `cheat_death`, `ally_save`, `on_kill`, `low_hp`, `execute`, `regen`, `mana_shield`, `ambush_mult`, `trap_max`, `oath_max`;
  regras em `core/sim/systems/class_talent_system.gd` (há check que todo gancho/skill citado existe). Revisar `--bag_shot=<png> --wins=skills --picks --level=30`.
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
- **Item/equipamento**: `items_catalog.gd` (atributos FOR/AGI/VIT/WILL/INT vêm de equipamento e dos nós de atributo da teia). Ícone: sem `icon` próprio, arte pintada
  `art_<id>.png` por `tools/icons/item_icons.gd` (laço sobre todos os itens; forma por `ItemIcons.art_key`: tipo de arma, slot + `armor_style`,
  palavra no id do material; cor principal = `icon_color`, acabamento/gema/brilho pela raridade) sobre a moldura `slot_r<raridade>.png`
  (fotos de conjunto/escudo também vão na moldura, recuadas 10%).
  Forma nova = `_a_<chave>` em `item_icons.gd` (há check). Rodar `item_icons.tscn [-- --only=<id> --sheet=<png>]` (com janela) e `--import`.
  Loja do mercador (`npc_ui._shop`): grade da mercadoria e da bolsa, abas, clique/Shift, "vender materiais" (`junk_of`); revisar `--bag_shot=<png> --wins= --shop`.
  Bolsa ↔ boneco por arrastar e soltar (`windows._drag_from_bag/_drop_on_slot/_drop_on_bag`; clique = soltar sem arrastar); conferir com `--bag_shot=<png> --dnd_check`.
  Barra do HUD: poção da bolsa → F1-F3 e skill da janela K → 1-6 por arrastar (`hud._drop_potion_slot/_drop_skill_slot`, botão direito esvazia); mouse simulado: `--bag_shot=<png> --wins= --hotbar_drag_check`. A barra (moldura, recarga em leque, atalhos, XP em 20 gomos) é `game/ui/action_bar.gd`; revisar com `-- --autostart=<c> [--preset=20] --screenshot=<png>`.
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
- **Faixa de nível (teste de jogo)**: `--headless --path . tools/tests/band_probe.tscn -- [--from=10] [--to=20] [--trials=16] [--only=audit|duel] [--mob=<id>] [--why]`
  (auditoria das quests + caçada de 4 monstros seguidos por bot do nível; `travou` com `--why` mostra por quê). Mexeu em monstro da faixa: rode.
- **Chefe com mecânica**: `MonsterDef.phases` (`hp`, `say`, `skills`, `summon` [+`pick`], `enrage`, `ward` = corte de dano enquanto um lacaio vive) em `MobSystem.update_boss`;
  `berserk_after` (s de luta → dano × `Balance.BOSS_BERSERK_MULT`); `SkillDef.mob_pick` (`far`/`random`/`soft`: num CHEFE a skill mira outra vítima, o aggro fica no tanque;
  `SkillsCatalog.BOSS_PICK` liga em skills já existentes); efeitos `barrage` (círculos avisados que caem depois, `m["hazards"]`, `MobSystem.place_barrage/update_hazards`; bots fogem)
  e `pull` (gancho). Skill de invocar (`boss_summon`) ou BUFF de chefe vale a qualquer distância (`MonsterBrain._skill_reach`): lacaios no ritmo da recarga.
  Grupos e faixas (campo/elite/grupo) em `boss_probe.GROUPS/BANDS`; `--bands` imprime `OUT_OF_BAND`, `--kite` testa atirador a 9,5 m+, `--why` mostra dano por fonte e estado do chefe. `intro`/`last_words` = falas de abertura/queda; lacaios com 0 XP via `summon` ou efeito `boss_summon` (nunca o `summon` de jogador).
  Chefe sem alvo reseta (`reset_boss`). Calibre rodando a luta com bots: eles têm ATK de equipamento do nível, bem acima do inicial.
  Sonda: `--headless --path . tools/tests/boss_probe.tscn -- [--party=1,3] [--trials=20] [--boss=<id>,...]` (vitórias, tempo, mortes).
  Use 20+ lutas (solo oscila ±10 pontos com 20; confirme com 40). Tabela calibrada em `docs/DESIGN.md` (Chefes).
- **Resposta/fluidez do combate**: `--headless --path . tools/tests/combat_probe.tscn -- [--class=<id>,...] [--verbose]` (nível 30, cada build, bonecos parados):
  latência do comando, trava, encadear no básico, buffer, dash cancela, impacto do clipe no tick do dano, golpe que para antes da fase ativa
  e quanto o boneco fica parado entre básicos segurados. `FLAG` = problema; mexeu em timing de skill ou clipe, rode e deixe em 0 (o Cruzado tem 0,16 s de ritmo de arma pesada, aceito).
  Formas de bicho: `EntityView.FORM_CLIP` manda o gesto humano para `maul/pounce/slam/roar/brace` (`druid_sets.form_clips`); gesto longo repete na fase ativa (`ACTIVE_LOOP`).
  Filme de clipe de monstro/forma: `lineup.tscn -- --mob_strip=<modelo> --anim=<clipe>`.
- **Colheita**: ponto em `MapsCatalog.GATHER[<mapa>]` (item, forma `herb|herb_blue|ore|star|shell|mushroom|relic|crate`, centro, raio, quantos); a sim espalha
  (`GatherSystem.spread_gather`), F colhe (`GatherSystem.start_gather/update_gather`), visual em `game/world/gather_view.gd`. Item novo precisa de arte (`item_icons`).
- **Entrega**: quest COLLECT com `give_items` (o pacote) e `turnin_npc` diferente do `giver_npc`. XP de quest é escalada por faixa (`QuestsCatalog.scale_xp`):
  o número escrito vale como peso; o teste confere 40-50% da faixa e 10+ quests por faixa.
- **Portão de progressão**: `MapsCatalog.PORTAL_GATES` (id do portal → `level`, `quest`, `bosses`, `text`); vale só para o jogador. Save sem `save_version` passa por `grandfather_gates`.
- **Investida / sentinela**: rota em `z.data["raid"]` no `build_<zona>.py` (from, route, target, radius) + levas/ritmo/falas em `MapsCatalog.RAIDS`;
  `RaidSystem` (relógio só com o jogador no mapa) e a marcha em `MonsterBrain._march`. Sentinela = NPC com `fighter` (monstro `guard_*` dá
  atributos), `gear` e `route`, em `MapsCatalog.FOREST_NPCS`; `GuardBrain`. Calibrar: `--headless --path . tools/tests/raid_probe.tscn -- [--trials=20] [--bots=0,1,3]`
  (repelidas, chegada, mortes, `presos` = FLAG). Filmar: `-- --autostart=<classe> --raid_shot=<png>`.
- **Grupo (party)**: regras na sim (`PartySystem`, via `Sim.party_*`, `kill_sharers`; aliado = `SimEntity.is_friend`), números em `Balance.PARTY_*`,
  bots em `BotBrain._follow/_gather_party/wants_party`; UI em `hud.gd` (quadros/convite/comandos de chat) e janela `party` (P).
- **Quest**: `quests_catalog.gd` (KILL/COLLECT/TALK/CRAFT/REACH; NPC giver precisa existir em algum `MapDef.npcs`). `prereq_all` junta ramos, `reward_gear_tier` dá peça vestível, `repeatable` é recompensa de quadro.
- **Mapa/zona**: siga "Layout de zonas" abaixo (`/layout-zone`). O `MapDef` continua sendo a verdade da sim
  (obstáculos = colisão, portais, spawners, NPCs); o visual da zona vem do Blender (`map_<zona>.glb`).
- Sempre adicione um `check(...)` em `tools/tests/run_tests.gd` para conteúdo/regra nova.
