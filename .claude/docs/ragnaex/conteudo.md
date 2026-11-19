<!-- RagnaEx manual (pt-BR) — Como adicionar conteúdo. Moved VERBATIM from the old CLAUDE.md on 2026-11-08 (CCGS adoption); imported by CLAUDE.md. Edit here. -->

## Como adicionar conteúdo

- **Skill**: `data/catalog/skills_catalog.gd` → `_more()` com `_s(...)`/`_buff(...)` (20+ por classe; nível, build e
  arma exigida em cada uma; chega sozinha no nível dela, `ProgressionSystem.grant_level_skills`, e o jogador equipa 6).
  **Rank 1-5** (`e.mastery`, efeitos de `SkillDef.mastery`) sobe no Mestre de Skills (NPC de papel `Balance.SKILL_TRAINER_ROLES`) com ouro +
  materiais da faixa da skill (`Balance.SKILL_RANK_*`; `ProgressionSystem.rank_cost/rank_error/rank_up`, `Sim.skill_rank_*`; bots: `bot_rank`);
  check `_check_skill_ranks`. Na teia o círculo da skill tem "<Skill> Aprimorada" (`_s_`, kind `skill_up`, `Balance.SKILL_UP_POWER`) e
  "<Skill> Ágil" (`_m_`, kind `skill_quick`, `SKILL_QUICK_PCT`), aplicados em `ProgressionSystem._web_upgrades` (check `_check_skill_upgrade_nodes`). `ClassDef.skill_ids` é preenchido sozinho.
  Campos em `data/schemas/skill_def.gd`; efeitos suportados por `WorldSim._apply_effects`
  (`dot, slow, stun, root, buff, shield, dash, summon, heal_pct_of_dmg, taunt, boss_summon, wither, mend_pct_of_dmg, combust, bounce, aura, orbit, zone, sunder, sunder_consume, seed, sacrifice, wound_heal, wound_extend, riposte, momentum_spend`; `combust` com `kind: "poison"` = Eviscerar consome os venenos (`WoundSystem`); `riposte` = janela de aparar do Duelista e `momentum_spend` gasta o Ímpeto (`RiposteSystem`; checks `_check_eviscerate_poison`, `_check_bleed_whirl`, `_check_riposte`); `orbit` = martelos que giram e batem de novo com o poder do lançamento (`AuraSystem.start_orbit/orbit_tick`, Martelos Abençoados); aura = liga/desliga em `AuraSystem`, `bounce` = projétil que ricocheteia; `strikes` = sequência de golpes de personagem: N golpes nos tempos `at`, partes `weights` do power, `crit_last` = último crítico garantido, `clips` = um clipe por golpe na `EntityView`; encadear só depois do último; check `_check_crusader_skills`; `SkillDef.clip`/`vfx` forçam clipe e tema); `dot` de skill de fogo vira queimadura sozinho e gelo estilhaça alvo retardado (`Combat.frost_mult`). Mira: SELF/DIRECTION/GROUND/CONE/TARGET.
  A skill entra sozinha na **teia** (estilo Path of Exile, `data/catalog/tree_catalog.gd`): malha de junções e estradas (grade `CELL` irregular,
  sorteio fixo por classe, parte das estradas sai = escolha de rota) com círculos nas casas: de skill (Aprimorada no centro; Ágil/evoluções/passivos em volta) e de
  notável (`ARM_NOTABLES`/`RING_NOTABLES`, duas entradas). Setores por ramo; skill de nível alto mais longe. Há check de folga (`windows.NODE_PX`/`WEB_UNIT`). 7 pontos por nível (`Balance.points_at`); estradas/junções só caminho. Quanto a teia dá: `--headless --path . tools/tests/web_probe.tscn -- [--level=30]` (alvo: média das builds ATK x1,3-1,5 e HP x1,1-1,3, cada build ATK×HP x1,2-2,3; `Balance.WEB_GAIN_*`, check `_check_web_strength`). Bots compram
  caminho na teia (`ProgressionSystem.bot_spend`). Revisar: `--bag_shot=<png> --wins=skills --level=<n> [--build_i=N]` (arrastar/zoom/busca na janela K).
  **Talentos de classe** (aba Talentos): `data/catalog/class_talents_catalog.gd`, 9 linhas (`ROW_LEVELS` 5..45) × 3 por classe, um por linha (nós `pick` `<classe>_c_<id>`;
  35/40/45 têm uma opção por build com a chave `build`, sem trava: só diz qual o bot da build escolhe (nas outras linhas o bot fica com a de maior `ClassTalentSystem.bot_score`: cita skill da build > gancho que serve > números; sem sorteio; exceção por build x linha em `ClassTalentsCatalog.BOT_PREFER`, vence a nota; check `_check_bot_talent_prefs`); os refinos de ascensão viraram portões na teia de ascensão (`AscensionCatalog.NODES`),
  `WorldSim.pick_sibling`, troca na cidade). Ganchos: `permanent`/`aura` (buff da skill sempre ativo / em você e no grupo), `summon_permanent`/`summon_extra`,
  `skill_mods`, `stats`, `form_mult`/`form_time`/`form_stats` (bônus só na forma), `cheat_death`, `ally_save`, `on_kill`, `low_hp`, `execute`, `regen`, `mana_shield`, `ambush_mult`, `trap_max`, `oath_max`, `summon_time` (invocação com tempo dura ×N), `dot_boost` (dano no tempo mágico: duração/dps);
  regras em `core/sim/systems/class_talent_system.gd` (há check que todo gancho/skill citado existe e que toda opção da linha N cita skill aberta até N, `_check_talent_unlock_levels`; gancho genérico conta pela skill do tipo em `ClassTalentSystem._hook_fits`; números novos em `Balance.CT_*`; talento que muda de linha passa por `sanitize_picks` no save). Revisar `--bag_shot=<png> --wins=skills --picks --level=30`.
  **Ascensão** (35/40/45, missão `hx_asc_<classe>`; GDD `ato2-horda` R6): skill com `SkillDef.ascension` entra sozinha na **teia de ascensão** da classe
  (`data/catalog/ascension_catalog.gd`: `NODES[<classe>]` passivos/portões por ramo de build, ids `<classe>_a_*`, `flag` lido pela regra via
  `ProgressionSystem.asc_flag`; pontos próprios `Balance.ASC_POINTS_PER_LEVEL`/`ASC_QUEST_POINTS` = 6/21/36). A barra ganha `Balance.ASC_SLOTS` vagas
  (7, 8, 9, 0) só para skills de ascensão; 1-6 recusam ascensão. Bots: `AscensionCatalog.BOT_ORDER` (+ `BOT_NO_SLOT`), `ProgressionSystem.bot_spend_asc`.
  Peso F5 por build em `Balance.ASC_BUILD_POWER`. Checks `_check_ascensions`, `_check_asc_web_fill`, `_check_ascension_bots`. Revisar: `-- --autostart=<c> --ascend --level=40`
  e `--bag_shot=<png> --wins=skills --asc_tab --ascend --level=45`.
  **Suprema do 40** (tecla R, GDD `design/gdd/ultimates-lv40.md`): uma por build em `SkillsCatalog._ultimates()` com `_s(...)` +
  `"ultimate": true`, `"ult_bot": "boss"|"save"|"self"`, nível `Balance.ULT_LEVEL`, custo 0, recarga 0, startup ≤ 0,3 s e id
  `<prefixo>_ult_<nome>`; números SÓ em `Balance.ULT_NUMBERS[<id>]` (o texto lê de lá). Ela não entra na teia, na barra nem em
  `ClassDef.skill_ids` (`GameData.ultimates[classe][build]`; a janela J mostra no fim da aba da build). Mecânicas próprias:
  `storm`, `hop_strikes`, `intercept`, `dot_amp`, `curse_spread`, `pet_revive`, `barrage` de personagem, `summon.ignore_max`,
  buff `end_cast`/`oath_lock` (contratos no `skill_def.gd`; regras em `StormSystem`, `HopSystem`, `InterceptSystem`, `UltEffects`).
  Carga Suprema e o R: `UltimateSystem` (números `Balance.ULT_*`/`BOT_ULT_*`). Ícone: id em `GLYPHS` + `make_icons.tscn -- --only=<skill_id>`
  (a Suprema ganha filete dourado sozinha). Checks `--only=ultimate`; ritmo da carga: `boss_probe.tscn -- --lvl=40 --asc --ult --comp=...`
  (linha `ULT`: s até a 1ª cheia, `luta` = s desde que a carga saiu do zero, pts/s por membro; `--ult_trace` = carga a cada 5 s; alvo 45-60 s); foto da moldura: `-- --autostart=elementalist --ascend --level=40 --build_i=0 --ult_shot=<pasta>`.
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
- **Mecânicas do preenchimento de skills** (2026-11-19, GDD `skills-fill-2026-11-19`; números em `Balance.HALLOWED_ZONE/FAITH_BANNER_ZONE/SUNDER*/EMBER_SEED/DARK_OFFERING`):
  `zone` = chão que fica e pulsa (`TrapSystem.place_zone`, kind `zone` em `m["traps"]`; desenho `FxManager._zone_fx`; `ally_buff` entra em `BuffLooks.sources`);
  `sunder`/`sunder_consume` = cargas no debuff `sunder` (marca) que o finalizador gasta (`SunderSystem`); `seed` = semente que estoura no fim ou na morte do alvo e
  espalha o `dot` (`SeedSystem`, gancho no fim do debuff e em `_kill`); `sacrifice` = oferece as próprias invocações (`SummonRites`; `try_cast` recusa sem nenhuma).
  Condições de bot em `BotBrain._fill_ok`. Checks `_check_skill_fill` (≥ 8 por build, ≥ 4 gerais), `_check_zone_pulse`, `_check_sunder`, `_check_seed`, `_check_sacrifice`.
- **Escudo**: linha em `GearCatalog.SHIELDS` (modelo próprio em `tools/blender/shield_kit.py`, um por escudo; afinidade em `GearCatalog.SHIELD_AFFINITY` dá Juramento/Graça; ícone é foto do modelo: `tools/icons/shield_icons.tscn`; `shield_effect` = reação ao bloquear).
  Rode `build_kits` e `tools/icons/shield_icons.tscn` (com janela) + `--import`. Revisar: `-- --autostart=paladin --block_shot=<png> [--shield=<id>]`, `lineup.tscn -- --shields [--page=N] --anim=block_shield`, `--block_film`; montagem e guarda: `tools/blender/shield_mount.py` (sem args resolve `SHIELD_*` no idle; `-- --guard` acha o braço do
  `block_shield`; `-- --check` conta toques fora do braço esquerdo em idle/corrida/guarda, cada escudo nos clipes que ele toca). Mudou montagem ou pose: rode `--check`.
  Montagem rente (2026-11-15): todo escudo do jogador tem entrada em `chibi_kit.SHIELD_MOUNTS` (placa encostada no antebraço até onde o tamanho deixa)
  e a alça vai soldada na malha dele (não existe mais `wpn_off_grip`). Escudo novo ou pose de guarda/corrida mudada:
  `blender -b --factory-startup --python tools/blender/shield_mount_study.py -- --out=<pasta> [--only=<estilo>]` (procura, mede, fotografa antes/depois;
  `--kit_mounts` só confere as do kit, `--wear=<estilo de conjunto>` veste um conjunto na foto) e `python tools/blender/shield_mount_apply.py <pasta>/study.json`
  (o apply troca só os estilos do json; os outros ficam como estão).
  Escudos altos (2026-11-16): os 17 estilos de `shield_kit.TALL` (= `KitModel.TALL_SHIELDS`, mantenha os dois iguais) correm em `run_shield_tall` (braço do escudo quieto)
  e bloqueiam em `block_shield_tall` (braço mais baixo); montados, `block_ride_tall` (clipe do kit: braço aberto para a esquerda, placa de pé por fora do ombro da montaria; `chibi_kit.SHIELD_RIDE_TALL`, achado e conferido por `tools/blender/shield_ride_solve.py -- solve|check --mount=mob_horse,mob_dire_wolf_mount`). Os clipes só existem nos kits de `SHIELD_CLASSES`
  (`chibi_kit.animate_tall_shield`) e quem escolhe é `KitModel.tall_clip/run_clip/guard_clip` (`tall_shield`, ligado no `apply_equipment`); a montagem deles é medida nesses
  clipes (`ck.shield_clip`). Cinco têm o canto do cotovelo aparado (`shield_kit.ELBOW`, só no kit do jogador): mexeu lá = estudo `--only=<estilo>`, apply, kits e ícone.
  Escudo alto novo: entra em `TALL` e em `TALL_SHIELDS` antes do estudo. Revisar: `lineup.tscn -- --shields --styles=<estilo>,... --anim=run|block_shield [--phase=0.25]
  [--shield_view=game|side] [--plain]`, `--strip=<classe> --shield=<item>`, `--mounted --guard=<item>,... [--shield_side]`. Check `_check_tall_shields`.
  Escudo e chão (2026-11-17): o chibi tem o cotovelo a ~0,55 m do chão, então TODO escudo passava do chão (até 0,8 m). Nos kits de `SHIELD_CLASSES` o rig tem o osso
  `shield_tip.L` e a parte da placa abaixo do braço pesa nele em rampa (`chibi_kit.skin_shield_tip`); no jogo `ShieldGround` (`game/entities/shield_ground.gd`, criado pelo
  `KitModel`) sobe o osso só o que falta para a ponta ficar no chão do pai do kit (na sela e no pulo a placa volta inteira). Com o osso em repouso a malha é a de sempre
  (montagem, ícones, monstros). Medir: `--headless --path . tools/tests/shield_probe.tscn -- [--kits=paladin_male] [--all]` (ponto mais baixo por clipe antes/depois e
  arestas do escudo que cruzam a montaria na guarda montada); o check `_check_shield_ground_and_ride` exige 0 em todo clipe de pé (fora `die`/`gather_*`; até 8 cm em
  `cast_nature`/`atk_finisher`/`atk_leap`/`attack`) e 0 cruzamentos com cavalo e lobo. Escudo novo ganha a rampa sozinho; montaria nova: rode o `shield_ride_solve.py -- check`.
- **Build**: uma entrada `_b(...)` em `classes_catalog.gd` diz tudo da build: armas, armadura, atributos, skills em prioridade,
  `passives`/`set_extra`, `of` ("do X" das peças), `signature` (magia-assinatura + `look` do básico), `legend` (kind/name/skill
  da arma lendária; build com papel por arma em `GearCatalog.WEAPON_ROLES`: espada ataca com o `legend`, maça defende com Baluarte,
  escudo do conjunto em `DETERMINATION_SHIELDS` ganha Determinação) e, no Elementalista, `element`. Números por build ficam em `Balance` (`BUILD_POWER`, `SIGNATURE_BUILD_POWER`,
  `LEGEND_NUMBERS`; check `_check_build_entries`). Uma build nova ganha conjuntos lendários sozinha (`gear_catalog.gd`) e um
  **Ápice** (35/40/45, `design/gdd/apice-sets.md`) com uma linha em `GearCatalog.APEX` + números em `Balance.APEX_NUMBERS`; a regra do
  5 peças mora em `FusionEffects` (id `apice_<build>`; checks `_check_apex_sets`/`_check_apex_rules`/`_check_apex_save`, `--only=apex`).
  Acessórios lendários (Manto/Medalhão/Anel/Sinete 35/40/45, `GearCatalog.legendary_accessories`) também saem sozinhos, mas a build nova
  precisa de entrada em `Balance.LEG_ACC_BUILDS` (stat de cada peça, de `LEG_ACC_STEP`) e da arte (`item_icons.tscn -- --only=leg_acc_`); check `_check_legendary_accessories`.
- **Evolução** (skill ou dash): `data/catalog/talents_catalog.gd` (`TalentDef`; dash = `skill_id: "dash"`).
- **Item/equipamento**: `items_catalog.gd` (atributos FOR/AGI/VIT/WILL/INT vêm de equipamento e dos nós de atributo da teia). Ícone: sem `icon` próprio, arte pintada
  `art_<id>.png` por `tools/icons/item_icons.gd` (laço sobre todos os itens; forma por `ItemIcons.art_key`: tipo de arma, slot + `armor_style`,
  palavra no id do material; cor principal = `icon_color`, acabamento/gema/brilho pela raridade) sobre a moldura `slot_r<raridade>.png`
  (fotos de conjunto/escudo também vão na moldura, recuadas 10%).
  Forma nova = `_a_<chave>` em `item_icons.gd` (há check). Rodar `item_icons.tscn [-- --only=<id> --sheet=<png>]` (com janela) e `--import`.
  Loja do mercador (`npc_ui._shop`): grade da mercadoria e da bolsa, abas, clique/Shift, "vender materiais" (`junk_of`); revisar `--bag_shot=<png> --wins= --shop`.
  Bolsa ↔ boneco por arrastar e soltar (`windows._drag_from_bag/_drop_on_slot/_drop_on_bag`; clique = soltar sem arrastar); conferir com `--bag_shot=<png> --dnd_check`.
  Barra do HUD: poção da bolsa → F1-F3 e skill da janela K → 1-6 por arrastar (`hud._drop_potion_slot/_drop_skill_slot`, botão direito esvazia); mouse simulado: `--bag_shot=<png> --wins= --hotbar_drag_check`. Clique em janela não ataca/bloqueia (o segurar só vale se o clique começou no mundo, `player_controller.attack_down/block_down`): `-- --autostart=<c> --bag_shot=<png> --wins= --ui_click_check` (check `_check_ui_click_gate`). A barra (moldura, recarga em leque, atalhos, XP em 20 gomos) é `game/ui/action_bar.gd`; revisar com `-- --autostart=<c> [--preset=20] --screenshot=<png>`.
  Montaria (H): o ícone segue o tipo escolhido (`ActionBar.mount_icon/set_mount_kind`, `action_mount_<kind>.png`, fallback cavalo); tipo novo =
  entrada `mount_<kind>` em `ACTION_ICONS` do `make_icons.gd` (+ glifo, ex. `_g_wolf`) e `make_icons.tscn -- --only=action` + `--import` (check em `_check_action_bar`).
  Cuidador de montarias (`npc_ui.mount_options/pick_mount`, estáticos; botões "Em uso / Trocar para / (travado)" + linha com a quest que destrava;
  check `_check_mount_keeper_ui`): revisar `--bag_shot=<png> --wins= --mount_keeper [--quests=hx_ov_hatch | --mount_kind=dire_wolf]`.
  Barra de buffs/debuffs do HUD: ícone da skill/item que deu (`hud._buff_source`) ou `status_<estado>.png` (`make_icons.tscn -- --only=status`),
  tempo embaixo; revisar com `--bag_shot=<png> --status_demo --wins=`.
  A mesma arte boia sobre o baú no chão (`LootChest`) e aparece no aviso de item pego (`hud._on_item_gained`); revisar com `-- --loot_demo --screenshot=<png>`.
  Revisar: `-- --autostart=<classe> --bag_shot=<png>`. Armas novas por tier e
  lendários/conjuntos são gerados por loops em `gear_catalog.gd` (números em `Balance.GEAR_*`/`SET_*`/`LEGENDARY_*`).
- **Forja/alquimia**: não fazem armas nem armaduras (essas caem de monstro: `WorldSim.gear_pool` por tier, filtradas pela classe; nível 1 na loja).
  Fazem joias e capas por tier x tema (`RecipesCatalog.gear_recipes`, laço) e Bolsas Ampliadas (`bag_t0..3`, `Balance.BAG_*`; bolsa tem limite de pilhas).
  Aprimoramento no ferreiro: `WorldSim.enhance`/`enhance_cost` (+1..+9, nunca quebra; `Balance.PLUS_*`), por CÓPIA: a peça aprimorada vira a versão `<id>+N` (`GameData.plus_item`, stats da base com o bônus; `ItemDef.base_id/plus`; saves voltam por `GameData.resolve_item`);
  brilho `plus_glow` no toon (`KitModel.plus_glow_color`). Revisar: `lineup.tscn -- --plus_demo --strip=<classe>` e `--bag_shot=<png> --wins= --enhance`.
- **Boneco de treino** (2026-11-19): monstro `training_dummy` (`MonsterDef.dummy`, modelo `mob_training_dummy`, `mob_kit`), 99999 de vida, DEF/MDEF 0, nunca cai de 1 HP (`_deal_damage`/`_kill`),
  parado `Balance.DUMMY_REGEN_DELAY` s se recompõe e volta ao lugar (`MobSystem.update_dummy`); só o jogador e invocações dele (`SimEntity.player_owned`) o acertam (`is_hostile_to`),
  sem aggro/XP/saque; bots não o caçam nem ajudam nele. Lugares em `MapsCatalog.TRAINING_DUMMIES` (Aldara: entre o portão oeste e o rio). Check `_check_training_dummy` (`--only=training_dummy`).
- **Janela de Skills (J)** (2026-11-19): `windows._book` (abas = builds da classe + "Gerais" (build "") + "Ascensão" a partir de `ASC_LEVEL`; bloqueadas em cinza),
  ficha de números de agora em `game/ui/skill_sheet.gd` (`SkillSheet`: `ProgressionSystem.resolve_skill` + Stats, mesmas contas de `_apply_skill`/`_apply_effects`/`calc_damage` sem sorteio).
  Efeito novo que deve aparecer na ficha: linha em `SkillSheet._effect_rows`. A janela K perdeu a lista de skills (ficou a barra + botão para a J). Check `_check_skill_book`;
  revisar `-- --autostart=<c> --bag_shot=<png> --wins=book [--book_tab=<build>|geral|asc] --level=<n>`.
- **Buffs longos** (2026-11-19): buffs de "ligar e esquecer" (armaduras de Gelo/Ossos/Abençoada, Casca, Carvalho, Bênção, Égide, Hino, Bênção do Bosque, Pacto Sombrio,
  Matilha, Lâmina Pestilenta) duram `Balance.BUFF_KEEP_S` (60 s; texto via `SkillsCatalog._keep_s()`); escudo absorvente e buffs de explosão (Fúria, Ira, Muralha...) seguem curtos.
  Buff novo desse tipo: entra em `run_tests.KEEP_BUFFS` (check `_check_keep_buffs`). Lentidão de gelo: `slow.frost` marcado em `GameData.load_all` (elemento frost ou tema ice) → `Combat.frost_attack_mult` (check `_check_frost_aspd`).
- **Monstro**: `monsters_catalog.gd` + loot table + spawner em `maps_catalog.gd` (+ modelo `mob_<id>` no Blender).
  **Metamorfose** (xamã que vira bicho; `core/sim/systems/shift_system.gd`, contrato no topo do arquivo): `MonsterDef.shift_forms = [{"form": <id>, "weight": n}]` (+ `shift_cast` s, 0 = `Balance.SHIFT_CAST_S`); a forma é outro MonsterDef completo (modelo, vida, skills, alcance, `ranged`, aggro/leash, nome curto "Urso" → placa "Xamã (Urso)"), `shift_stealth` = entra furtiva e o 1º golpe é emboscada × `SHIFT_AMBUSH_MULT`, `kite` = atirador que recua a menos de `SHIFT_KITE_DIST`. Sorteia 1 forma por luta (rng da sim) ao ganhar alvo, conjura, troca guardando o % da vida/aggro/buffs; volta no leash, `reset_boss` ou `SHIFT_REVERT_S` s fora de combate. Morre como a forma, mas XP/saque/quest KILL/Rei contam pela BASE (quest mira o id da base; forma com `xp: 0` e sem loot). Desenho: `EntityView._swap_monster_model` (troca o modelo quando `monster_def` muda) + `FxManager._on_monster_shift` (`Events.monster_shift`, tema nature). Check `_check_monster_shift` (`--only=shift`).
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
- **Chefe com mecânica**: dano escala com quem luta contra ele (`Balance.BOSS_CROWD_MULT`, `MobSystem.crowd_of`; check `_check_boss_crowd`);
  `MonsterDef.phases` (`hp`, `say`, `skills`, `summon` [+`pick`], `enrage`, `ward` = corte de dano enquanto um lacaio vive) em `MobSystem.update_boss`;
  `berserk_after` (s de luta → dano × `Balance.BOSS_BERSERK_MULT`); `SkillDef.mob_pick` (`far`/`random`/`soft`: num CHEFE a skill mira outra vítima, o aggro fica no tanque;
  `SkillsCatalog.BOSS_PICK` liga em skills já existentes); efeitos `barrage` (círculos avisados que caem depois, `m["hazards"]`, `MobSystem.place_barrage/update_hazards`; bots fogem)
  e `pull` (gancho). Skill de invocar (`boss_summon`) ou BUFF de chefe vale a qualquer distância (`MonsterBrain._skill_reach`): lacaios no ritmo da recarga.
  Grupos e faixas (campo/elite/grupo) em `boss_probe.GROUPS/BANDS`; `--bands` imprime `OUT_OF_BAND`, `--kite` testa atirador a 9,5 m+, `--why` mostra dano por fonte e estado do chefe. `intro`/`last_words` = falas de abertura/queda; lacaios com 0 XP via `summon` ou efeito `boss_summon` (nunca o `summon` de jogador).
  Chefe sem alvo reseta (`reset_boss`). Calibre rodando a luta com bots: eles têm ATK de equipamento do nível, bem acima do inicial.
  Sonda: `--headless --path . tools/tests/boss_probe.tscn -- [--party=1,3] [--trials=20] [--boss=<id>,...]` (vitórias, tempo, mortes).
  Use 20+ lutas (solo oscila ±10 pontos com 20; confirme com 40). Tabela calibrada em `docs/DESIGN.md` (Chefes).
  Aviso de skill nova de chefe segue a gramática de cor (`FxManager.DANGER*`, cabeçalho do `BossSigView`): dano = vermelho-laranja (área fraca
  + borda + miolo que cresce), seguro = frio/areia, dividir = dourado, sombra/controle = roxo; identidade do chefe pela FORMA, nunca por cor
  contrária (`glow_*` verde/ciano de prop de aviso vira quente, ex. `SHARD_GLOW`). Golpe físico de monstro = tema `blood`, não `physical`.
  Dano de zona avisada no chão (assinatura/perigo de chefe) NÃO é esquivado pela AGI (decisão 2026-11-13): passa por `BossSignatures._hit` →
  `_deal_damage(..., dodgeable=false)`; só sair da zona salva. Mecânica nova de chão de chefe usa o mesmo caminho (check em `_check_boss_sig_rules`).
- **Resposta/fluidez do combate**: `--headless --path . tools/tests/combat_probe.tscn -- [--class=<id>,...] [--verbose]` (nível 30, cada build, bonecos parados):
  latência do comando, trava, encadear no básico, buffer, dash cancela, impacto do clipe no tick do dano, golpe que para antes da fase ativa
  e quanto o boneco fica parado entre básicos segurados. `FLAG` = problema; mexeu em timing de skill ou clipe, rode e deixe em 0 (o Cruzado tem 0,16 s de ritmo de arma pesada, aceito).
  Formas de bicho: `EntityView.FORM_CLIP` manda o gesto humano para `maul/pounce/slam/roar/brace` (`druid_sets.form_clips`); gesto longo repete na fase ativa (`ACTIVE_LOOP`).
  Filme de clipe de monstro/forma: `lineup.tscn -- --mob_strip=<modelo> --anim=<clipe>`.
- **Trava no chefe (Tab, 2026-11-18)**: só apresentação, `game/player/boss_lock.gd` (`BossLock`, funções puras) + `PlayerController` (ação `lock_target` no InputMap).
  Só chefe de verdade (`is_boss`, sem `elite_of`, sem `decoy`) até `Balance.BOSS_LOCK_RANGE`; o sob o cursor vence o mais perto; sem chefe = aviso "Nenhum chefe por perto".
  Travado: W/S = raio, A/D = órbita no raio guardado (persegue um ponto `BOSS_LOCK_ORBIT_AHEAD` à frente no círculo: não espirala), mira de TUDO = chefe (a sim limita GROUND ao alcance).
  Solta: Tab, chefe morto/sumido/resetado (`adds_epoch`), troca de mapa, além de `BOSS_LOCK_RELEASE`, jogador morto; montar NÃO solta. Marca: `LockMarker` (mira dourada nos pés + seta branca), etiqueta "Travado" no HUD.
  Check `_check_boss_lock`; revisar: `-- --autostart=<c> --lock_shot=<pasta> [--boss=<id>]` (imprime `LOCK_SHOT` com o raio antes/depois do D).
- **Arco de golpe por família de arma** (`game/fx/weapon_arcs.gd`, `WeaponArcs`; só apresentação, nunca muda tempo nem dano): no tick do dano de golpe
  físico em cone (básico e skills de leque) desenha um crescente do tamanho do cone REAL da `SkillDef`, faíscas/estrela no alvo e hit-stop LOCAL (só quem bate e quem apanha).
  `FAMILIES[<tipo de arma>]` = aparência: `band` (cor da faixa no tema físico; tema mágico usa a cor do tema puxada para o branco, `THEME_WHITE`, e `THEME_WHITE_BY`
  por tema, ex. `blood` 0,35: o vermelho cheio é do aviso de golpe), `rim` (contorno; família invertida = faixa escura e contorno claro, os machados), `glow`, `stop_mult`
  (× quadros de parada da sim, teto `STOP_CAP_FRAMES`), `angle_pad/inner/tilt/height/life/push`; arco em pé exige `S_KEYS`, cunha de estocada `W_KEYS`; `"on": false` = só cor decidida.
  Cores: `production/qa/attack-arc-colours.md`. `CLIP_ARC["clipe|família"]` (ou `"clipe|*"`) = `[lado, forma, início]`: lado +1/-1/0 (para onde a lâmina corre no impacto;
  0 = de cima), forma `F` crescente deitado / `S` em pé / `W` cunha, 3º número opcional = progresso com que o arco nasce (golpe já passou do pico). Os lados saem da tabela de
  golpes medida nos kits, `production/qa/evidence/attack-arcs/swing_table.json` (evidência; os checks `_check_weapon_arcs*` a releem). Família nova: linha em `FAMILIES`
  (cor aprovada no doc de cores) + linhas `CLIP_ARC` dos clipes dela conferidas na tabela + check; sem linha a arma fica no rastro antigo.
  **Formas de bicho do Druida** (onda 6): `FORM_FAMILY` (lobo/Alfa = `form_wolf`, urso = `form_bear`, Ent = `form_ent`) vence a arma; marcas no CHÃO (forma K, riscos de garra,
  `K_KEYS`, nunca aro/disco (`QUIET_FORMS` = Ent, urso, lobo, Alfa: o pisão sai sem o aro do golpe em volta de si), alfa ≤ 0,6, vida ≤ 0,2 s, sempre a cor da forma, nunca a do tema: vermelho no chão é aviso de chefe) por `FORM_ARC["clipe do bicho|forma"]` = `[tipo rake/skid/stomp/bite, x, z, quadro(, alfa)]`
  (contato medido no modelo; quadro > 0 = gancho da `EntityView`, a 2ª garra do maul); `FORM_STANDING` = crescente em pé (galho do Ent). Pool próprio `K_POOL`.
  Medir ossos de um GLB por quadro: `--headless --path . -s tools/lineup/arc_measure.gd -- --model=<glb> --clip=<clipe> [--bones=hand.R,hand.L] [--from=N --to=N]`.
  Revisar: `tools/lineup/arc_film.sh --class=<c> [--build=<b>] [--main=<item|tipo>] [--off=<item|tipo|none>] [--skill=<id|basic|basic_phys>] [--name=<rótulo>] [--cams=9,24]
  [--map=<id> [--at=x,z]] --out=<pasta>` (várias tomadas: `--take=<rótulo>:<skill>:<main>:<off>[:<build>[:<forma>]]` repetido, `--form=<wolf|bear|alpha|ent>`; um Godot por câmera, janela fora da tela, sem som):
  `strip_cam<C>_<rótulo>.png` (18 quadros a 60 Hz, impacto em amarelo) + `.txt` (tempo/clipe por quadro) e `full_cam<C>_<rótulo>_imp.png` (tela inteira logo depois do dano).
- **Colheita**: ponto em `MapsCatalog.GATHER[<mapa>]` (item, forma `herb|herb_blue|ore|star|shell|mushroom|relic|crate`, centro, raio, quantos); a sim espalha
  (`GatherSystem.spread_gather`), F colhe (`GatherSystem.start_gather/update_gather`), visual em `game/world/gather_view.gd`. Item novo precisa de arte (`item_icons`).
- **Entrega**: quest COLLECT com `give_items` (o pacote) e `turnin_npc` diferente do `giver_npc`. XP de quest é escalada por faixa (`QuestsCatalog.scale_xp`):
  o número escrito vale como peso; o teste confere 40-50% da faixa e 10+ quests por faixa.
- **Portão de progressão**: `MapsCatalog.PORTAL_GATES` (id do portal → `level`, `quest`, `quests` = várias, todas exigidas, `bosses`, `text`); vale só para o jogador. Save sem `save_version` passa por `grandfather_gates`.
- **Cidade com identidade / evento de estrada** (GDD `living-towns`): centro e quadrantes de cidade em `tools/blender/zones/town_dress.py` (lotes `Dress`;
  zona antiga sem `Zone` usa `town_dress.shim`; resumo em `data["town"]["centerpiece"]`, check `_check_town_identity`). Rotina de NPC = linha em
  `MapsCatalog.LIVING_NPCS[<mapa>]` (`flow` = não para nos pontos da rota, ponto `[x, z, s]` = parada; check `_check_living_routes`, mapa novo entra em `TOWN_LIVING`).
  Evento de estrada: ponto em `EVENT_POINTS` do `build_<zona>.py` (vira `SPAWN_event_<tipo>_NN` e `events` no JSON → `MapDef.road_events`; `EVENT_CONFLICT` = ponto fora das regras)
  + regras em `MapsCatalog.ROAD_EVENTS[<mapa>][<tipo>]` (monstro, vítima, falas, prêmio consumível) + números `Balance.EVENT_*`; sim em `RoadEventSystem`
  (`Sim.road_event_status/road_event_start`). Filmar: `-- --autostart=<classe> --event_shot=<png> [--event_point=N]`. Check `_check_road_events`.
- **Investida / sentinela**: rota em `z.data["raid"]` no `build_<zona>.py` (from, route, target, radius) + levas/ritmo/falas em `MapsCatalog.RAIDS`;
  `RaidSystem` (relógio só com o jogador no mapa) e a marcha em `MonsterBrain._march`. Sentinela = NPC com `fighter` (monstro `guard_*` dá
  atributos), `gear` e `route`, em `MapsCatalog.FOREST_NPCS`; `GuardBrain`. Calibrar: `--headless --path . tools/tests/raid_probe.tscn -- [--trials=20] [--bots=0,1,3]`
  (repelidas, chegada, mortes, `presos` = FLAG). Filmar: `-- --autostart=<classe> --raid_shot=<png>`.
- **Cerco Vivo** (GDD `design/gdd/act2-siege-life.md`; P1 = Porto Esperança): `MapsCatalog.SIEGE[<mapa>]` (→ `MapDef.siege`) liga o relógio do
  `SiegeSystem` (core/sim/systems/siege_system.gd) no lugar do relógio de cada rota: uma leva por vez, revezando os `segments` (trechos da
  paliçada: `{id, quest, label, route}`). Trecho aberto = rota `cerco_<id>` (`unless "quest|close_all"`; no WorldState um id `"a|b"` vale com
  qualquer uma das duas) e a Horda entra pela brecha; fechado = a leva daquele lado vai ao `gate_route`. `pressure` (1ª linha que vale: 3 Fúria,
  2 Cerco, 1 Fustigar = só `low_route`, 0 Paz) escala frequência/tamanho/leva grande (`Balance.SIEGE_EVERY_MULT/SIZE_MULT/BIG_NTH`). Assédio =
  rota `kind: "harass"` (`harass_route`, `harass_mob`): atiradores no `from`, salva de círculos avisados em % da vida (não esquivável, só
  jogador/bots, fora de `SiegeSystem.safe_points`). Batedores = `MOB_PATROLS` com extras `{"horn": true}` (não contam em `MapDef.has_hunting`).
  Reserva = sentinela com `responder` (prefixo `port_r_`). Repelida = buff `colonia_de_pe` + conta quest `DEFEND` (tipo novo: `target_id` = mapa);
  chegou e não foi repelida = Chamas (só visual: marcadores `fire` de `z.data["fx"]`, `game/world/siege_fx.gd`, que também faz a fumaça
  `smoke`/`smoke_low` com `if`/`unless`). No Blender: `build_city_port.SEGMENTS` (espelho dos `segments`; há check), peças `pal_<id>_obra_*` /
  `pal_<id>_pronta_*` e lotes com `tag` em `act2_dress.port_siege` (casas queimadas/novas, refugiados, torre, enfermaria). Números só em
  `Balance.SIEGE_*` (cadência "Intenso": leva a cada 90 s). Checks `--only=siege`; medir: `raid_probe.tscn -- --map=city_port --side=cerco_ne --bots=0`
  (uma rota) e `-- --map=city_port --siege_run=1800 --bots=0 --level=32 [--quests=...]` (relógio de verdade: repelidas, intervalo entre eventos,
  XP/min); fotos: `-- --autostart=paladin --siege_shot=<pasta> [--quests=hx_palisade]`.
- **Grupo (party)**: regras na sim (`PartySystem`, via `Sim.party_*`, `kill_sharers`; aliado = `SimEntity.is_friend`), números em `Balance.PARTY_*`,
  bots em `BotBrain._follow/_gather_party/wants_party`; UI em `hud.gd` (quadros/convite/comandos de chat) e janela `party` (P).
  IA de grupo por papel da build (posição contra chefe, ameaça, cura no tanque, tirar lacaio; `Balance.BOT_*`, check `_check_bot_group`; tanque seguidor abre sozinho no chefe a até `BOT_TANK_PULL_BOSS` m do líder, `BotBrain._tank_pull`, check `_check_tank_pull`). Medir:
  `boss_probe.tscn -- --party=5 --comp=paladin:guardiao,bishop:sacerdote,... [--why]` (aggro no tanque, `frente` = dano no lugar errado, `ritmo`, `cura_tq`).
  Sob pressão: `--dmg=6` (ATK/MATK do chefe ×6; grupo de 4 vence ~80%) ou `--under=N` (bots N níveis abaixo); `baixa`/`baixa_tq`/`pocoes`/`mortes` medem a cura.
  **Bots presos** (2026-11-17): povoado murado (`town_radius` + portões no JSON, com ou sem `is_town`) passa por `BotBrain._route` (portão com histerese, anel em volta
  do muro `_ring`); monstro calmo com a linha bloqueada não é escolhido (`MapGeometry.line_walkable`); sem chegar perto em `BOT_CHASE_STALL` s larga e ignora (`_stalled`/`_drop`);
  ponta de rio a ≤ 3 m de lago fecha (`MapGeometry.river_lake_joins`); seguidor espera na porta só do jogador (`_wait_at_door`; catchup e portal do grupo não entram em casa).
  Medir: `tools/tests/stuck_probe.tscn -- --minutes=30 --seed=<n> --out=<json>` + `python tools/tests/stuck_cluster.py <jsons>`; checks `_check_bot_unstuck`, `_check_water_lines_walk`.
  **Faixa dos bots** (2026-11-18, `BotBandSystem`): cidade nasce na faixa dela (`spawn_levels`, `BOT_BAND_SLACK`) e espalhada (`spawn_spots`: no máx. `BOT_SQUARE_CAP` na praça);
  bot sem cristal volta/renasce no povoado com cristal da faixa (`home_map`, `BOT_HOME_STEP_UP`; no grupo do jogador = casa do jogador, via `PortalSystem.home_of(e, sim)`);
  à toa em povoado de faixa baixa sai para caçar (`below_band`); ponto de encontro com menos gente (`BotBrain._pick_hangout`). Medir: `sim_probe.tscn -- --ticks=18000 --census` (`BAND`/`BANDAVG`); check `_check_bot_band`.
- **Quest**: `quests_catalog.gd` (KILL/COLLECT/TALK/CRAFT/REACH; NPC giver precisa existir em algum `MapDef.npcs`). `prereq_all` junta ramos, `reward_gear_tier` dá peça vestível, `repeatable` é recompensa de quadro.
- **Mapa/zona**: siga "Layout de zonas" abaixo (`/layout-zone`). O `MapDef` continua sendo a verdade da sim
  (obstáculos = colisão, portais, spawners, NPCs); o visual da zona vem do Blender (`map_<zona>.glb`).
- **Som**: banco em `assets/audio/sfx/<nome>_<n>.<ogg|wav>`, todo gerado por `python tools/audio/build_sfx.py [--only=<nome>,...]` (+ `--import`; `--only` refaz só esses nomes): `CC0` = arquivos dos pacotes
  do OpenGameArt (baixados para `.godot/sfx_cache`), `SYNTH` = funções `s_<nome>` (biblioteca padrão, semente fixa). Nome novo precisa de volume em `Sfx.VOL`
  (`game/audio/sfx.gd`; há check) e de um gancho em evento lá. Tema de skill novo = entrada em `Sfx.THEME_SOUND`. Monstros: `Sfx.MOB_VOICE` (id ou prefixo → [entrar em luta, lançar skill, morrer]),
  `CAST_SOUND` (skill com som próprio na fase ativa), `EFFECT_SOUND` (no impacto), `AURA_SOUND` (aura de `MonsterDef.aura` em laço, ex. tambor do Agitador), `BUFF_SOUND` (buff de monstro que pulsa enquanto dura, ex. regeneração do troll).
  Assinaturas de chefe: `SIG_WARN` (skill `boss_signature` → [fase em que o desenho aparece, sons]; toda assinatura precisa, há check) e `SIG_EFFECT`
  (impacto/quebra, inclusive ids que não são skill: `BossSignatures.*_FX`).
  O smoke imprime `SMOKE SOM:` (o que tocou).
- **Música**: `game/audio/music.gd` (`Music`, criado no `main`, barramento `Music`): tema do lugar (`Music.MAP_THEME` / `theme_for`: masmorras,
  fortalezas, interiores por família), por cima "chefe" (chefe de verdade em luta a 32 m) e "investida" (leva no mapa). Faixas CC0 do OpenGameArt
  em `assets/audio/music/<tema>.<ogg|mp3>`, geradas por `python tools/audio/build_music.py` (licença conferida na página de cada faixa; créditos
  em `CREDITS.md`). Mapa ou tema novo = entrada aqui e lá (check `_check_music`). O smoke imprime `SMOKE MUSICA:`.
- Sempre adicione um `check(...)` em `tools/tests/run_tests.gd` para conteúdo/regra nova.
- **Chaves dos catálogos** (check `_check_catalog_keys`): os `_mk` passam por `CatalogUtil.fill` (chave que o Resource não tem
  = falha no teste, não some mais em silêncio). Stat de passivo/`set_extra`/bônus/buff só de `Stats.STAT_KEYS` (stat novo = ler
  em `Stats.compute` E pôr na lista); efeito de skill só de `SkillDef.EFFECT_KEYS` (efeito novo = entra na lista e o `_s` o manda para `effects`).
- **Refatorar catálogo sem mudar dado**: `--headless --path . tools/tests/catalog_dump.tscn -- --out=<arquivo>` antes e depois
  (skills, itens, conjuntos, classes, monstros, quests, receitas, mapas, evoluções; dicionários em ordem) e `diff` vazio.

- **Arte do início** (tela inicial; spec `design/ux/start-flow.md`): cenário 3D `tools/blender/menu_set.py` → `assets/models/menu_set.glb` (acampamento de Aldara ao entardecer; vazios `SPOT_pedestal`, `CAM_title/list/create`, `LIGHT_fire`, `LIGHT_lantern`,
  `MS_flames`, `MS_sparks`; cores em `menu_set.DUSK`; revisar com `tools/menu_set_view.tscn -- --menu_set_shot=<png>`); `tools/blender/menu_silhouette.py` → `assets/models/menu_silhouette.glb` (manequim do pedestal do espaço vazio, clipe `idle`);
  `tools/blender/menu_logo.py` → `assets/ui/logo_ragnaex.png` + `logo_subtitle_ato2.png`. Carregamento: `tools/blender/loading_art.py` (`blender -b --factory-startup --python tools/blender/loading_art.py -- [--only=a,b] [--scale=0.5] [--top] [--sheet]`)
  tira uma foto por zona do modelo real (`map_<zona>.glb` + `data/zones/<zona>.json`) e grava `assets/ui/loading/<mapa>.jpg` (1600x900; 26 hoje); `LoadingScreen` lê `res://assets/ui/loading/<mapa>.jpg` e sem arquivo usa o degradê de entardecer.
  **`ZONES` (nome, chão, clima, câmera) e `BOSSES` (modelo do chefe por masmorra) em `loading_art.py` espelham o catálogo À MÃO**: mapa novo, mudança de `ground_color` ou chefe novo de masmorra = atualizar lá e refazer o `.jpg` (check `_check_loading_art`: `.jpg` de todo mapa com cenário fora os interiores, nome/chão de `ZONES`, modelo/escala de `BOSSES`, chefe com spawner no mapa).
