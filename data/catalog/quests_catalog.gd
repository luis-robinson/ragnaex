class_name QuestsCatalog
extends RefCounted
## Cadeia principal Aldara → Catacumbas → Floresta → Ruínas (os portões ficam em MapsCatalog.PORTAL_GATES), laterais e recompensas repetíveis.

const KILL := QuestDef.Type.KILL
const COLLECT := QuestDef.Type.COLLECT
const TALK := QuestDef.Type.TALK
const CRAFT := QuestDef.Type.CRAFT
const REACH := QuestDef.Type.REACH

static func _mk(d: Dictionary) -> QuestDef:
	var q := QuestDef.new()
	for k in d:
		q.set(k, d[k])
	return q

const HUNT_GIVERS := {"city_aldara": "board", "field_forest": "stone_druid", "field_ruins": "stone_obelisk", "elf_city": "moon_altar"}

## Quests da história e laterais dão Balance.XP_QUEST_SHARE da XP de cada faixa de nível: o peso relativo entre elas
## fica (o número escrito em cada uma), o total da faixa é escalado. Repetíveis (caçadas e quadros) ficam como estão.
static func scale_xp(quests: Dictionary) -> void:
	for band in Balance.XP_BANDS:
		var a: int = band[0]
		var b: int = band[1]
		var sum := 0
		var qs: Array = []
		for qid in quests:
			var q: QuestDef = quests[qid]
			if not q.repeatable and q.level_req >= a and q.level_req < b:
				sum += q.reward_xp
				qs.append(q)
		if sum <= 0:
			continue
		var k := Balance.XP_QUEST_SHARE * Balance.band_xp(a, b) / float(sum)
		for q in qs:
			q.reward_xp = int(round(q.reward_xp * k / 10.0)) * 10

## Caçadas repetíveis: uma por monstro comum que aparece em algum mapa e ainda não tem recompensa própria.
## Quem oferece depende do nível (quadro da vila, pedra druídica, obelisco). Gerado depois de monstros e mapas.
static func hunts(monsters: Dictionary, maps: Dictionary, existing: Dictionary) -> Array:
	var covered := {}
	for qid in existing:
		var q: QuestDef = existing[qid]
		if q.repeatable and q.type == KILL:
			covered[q.target_id] = true
	var where := {}           # monstro -> nome do mapa onde aparece
	var zone_of := {}         # monstro -> zona (mapa pai das dungeons)
	for mid in maps:
		var md: MapDef = maps[mid]
		for sp in md.spawners:
			if not where.has(sp["monster_id"]):
				where[sp["monster_id"]] = md.name
				var z: String = mid
				while maps.has(z) and maps[z].parent_map != "":
					z = maps[z].parent_map
				zone_of[sp["monster_id"]] = z
	var out: Array = []
	for id in monsters:
		var m: MonsterDef = monsters[id]
		if m.is_boss or m.xp <= 0 or covered.has(id) or not where.has(id):
			continue
		var giver: String = HUNT_GIVERS.get(zone_of.get(id, ""), "board")
		var n: int = Balance.HUNT_COUNT
		out.append(_mk({"id": "h_" + id, "title": "Caçada: %s" % m.name, "giver_npc": giver, "type": KILL, "target_id": id, "count": n,
			"level_req": maxi(1, m.level - 2), "repeatable": true,
			"reward_xp": int(round(m.xp * n * Balance.HUNT_XP_MULT)), "reward_gold": int(round(m.level * n * Balance.HUNT_GOLD_PER_LEVEL / 4.0)),
			"map_hint": where[id], "description": "Abata %d %s. Repetível." % [n, m.name],
			"dialog_offer": "Precisamos de %d %s a menos. Volte quando quiser repetir." % [n, m.name],
			"dialog_progress": "Procure em %s." % where[id], "dialog_complete": "Pago. O trabalho continua amanhã."}))
	return out

static func build() -> Array:
	var L := [
		{"id": "q01_welcome", "title": "Bem-vindo a Aldara", "giver_npc": "elder", "turnin_npc": "captain", "type": TALK, "target_id": "captain", "count": 1, "level_req": 1,
		 "reward_xp": 30, "reward_gold": 15, "reward_items": {"potion_hp_s": 2}, "map_hint": "Cidade de Aldara",
		 "description": "O Ancião Ravi quer que você se apresente à Capitã Mira, na praça.",
		 "dialog_offer": "Rosto novo! Vá falar com a Capitã Mira perto do portal sul. Ela sempre precisa de braços.",
		 "dialog_progress": "A Capitã está perto do portal sul da praça.", "dialog_complete": "Ótimo. Ravi me falou de você. Vamos ao trabalho."},
		{"id": "q02_slimes", "title": "Praga Gelatinosa", "giver_npc": "captain", "type": KILL, "target_id": "slime", "count": 6, "level_req": 1, "prereq_quest": "q01_welcome",
		 "reward_xp": 90, "reward_gold": 40, "reward_items": {"potion_hp_s": 2}, "map_hint": "Campina: lago (portão sul)",
		 "description": "Elimine 6 Slimes no lago ao sul de Aldara (portão sul).",
		 "dialog_offer": "Os slimes da Campina estão comendo as plantações. Derrube 6 deles.",
		 "dialog_progress": "Ainda tem slime na Campina. Use WASD para andar e o botão esquerdo para atacar.", "dialog_complete": "Menos gosma, mais colheita. Bom trabalho."},
		{"id": "q03_gel", "title": "Gel para a Alquimista", "giver_npc": "captain", "turnin_npc": "alchemist", "type": COLLECT, "target_id": "slime_gel", "count": 5, "level_req": 2, "prereq_quest": "q02_slimes",
		 "reward_xp": 110, "reward_gold": 30, "reward_items": {"herb_green": 3}, "map_hint": "Campina",
		 "description": "Leve 5 Géis de Slime para Lyra, a alquimista.",
		 "dialog_offer": "Lyra, a alquimista, paga bem por gel de slime. Leve 5 pra ela.",
		 "dialog_progress": "Preciso de 5 géis. Os slimes da Campina soltam isso.", "dialog_complete": "Perfeito! Isso vai render boas poções."},
		{"id": "q04_potion", "title": "Primeira Poção", "giver_npc": "alchemist", "type": CRAFT, "target_id": "potion_hp_s", "count": 2, "level_req": 2, "prereq_quest": "q03_gel",
		 "reward_xp": 120, "reward_gold": 25, "reward_items": {"potion_mp_s": 2}, "map_hint": "Alquimista (Aldara)",
		 "description": "Use o caldeirão de Lyra e crie 2 Poções de Vida (P).",
		 "dialog_offer": "Vou te ensinar: fale comigo de novo e use o caldeirão. Crie 2 poções de vida.",
		 "dialog_progress": "Abra o caldeirão (fale comigo) e crie as poções com erva verde + gel.", "dialog_complete": "Olha só, um alquimista nato!"},
		{"id": "q05_boars", "title": "Presas de Javali", "giver_npc": "smith", "type": COLLECT, "target_id": "boar_tusk", "count": 4, "level_req": 4, "prereq_quest": "q04_potion",
		 "reward_xp": 200, "reward_gold": 60, "reward_items": {"iron_ore": 4}, "map_hint": "Campina: bosque (portão leste)",
		 "description": "Traga 4 Presas de Javali para Brom, o ferreiro.",
		 "dialog_offer": "Presa de javali faz cabo bom. Me traz 4 e eu te mostro a forja.",
		 "dialog_progress": "Os javalis ficam no bosque a leste da vila.", "dialog_complete": "Agora sim. Na forja eu faço anéis e amuletos, e aprimoro o que você veste: +1 até +9, sem quebrar nada."},
		{"id": "q06_wolves", "title": "Uivos na Noite", "giver_npc": "captain", "type": KILL, "target_id": "wolf", "count": 8, "level_req": 6, "prereq_quest": "q05_boars",
		 "reward_xp": 320, "reward_gold": 80, "reward_items": {"potion_hp_m": 2}, "map_hint": "Campina: colinas (portão norte)",
		 "description": "Lobos atacam viajantes. Mate 8 na Campina.",
		 "dialog_offer": "Os lobos estão ousados. Elimine 8 deles.",
		 "dialog_progress": "Lobos são rápidos — use o bloqueio (botão direito) quando eles avançarem.", "dialog_complete": "A estrada está mais segura. Por enquanto."},
		{"id": "q07_king", "title": "O Rei Javali", "giver_npc": "captain", "type": KILL, "target_id": "boar_king", "count": 1, "level_req": 8, "prereq_quest": "q06_wolves",
		 "reward_xp": 600, "reward_gold": 150, "reward_items": {"elixir_might": 1}, "map_hint": "Campina: clareira (oeste, além do rio)",
		 "description": "Derrote o Rei Javali na clareira oeste da Campina, além da ponte do rio.",
		 "dialog_offer": "Um javali gigante lidera os outros. Leve poções. Derrote-o.",
		 "dialog_progress": "Ele fica na clareira oeste. Desvie da investida com Shift.", "dialog_complete": "O Rei caiu! O Ancião Ravi quer falar com você: algo o preocupa mais que javalis."},
		# ---- Catacumbas do Conde: liga Aldara à Floresta; o Trono é opcional e pede grupo ----
		{"id": "c1_digging", "title": "Terra Revirada", "giver_npc": "elder", "turnin_npc": "hermit_ines", "type": TALK, "target_id": "hermit_ines", "count": 1, "level_req": 8, "prereq_quest": "q07_king",
		 "reward_xp": 350, "reward_gold": 80, "reward_items": {"potion_hp_m": 1}, "map_hint": "Cabana da Eremita Inês (sudeste do vale)",
		 "description": "Túmulos do velho cemitério amanheceram abertos. Pergunte à Eremita Inês o que ela viu.",
		 "dialog_offer": "Com o Rei Javali morto eu esperava paz. Mas os túmulos do Conde Vargo amanheceram abertos. Inês mora perto e não dorme: fale com ela.",
		 "dialog_progress": "A cabana de Inês fica a sudeste, passando o bosque.", "dialog_complete": "Vi o chão ceder perto daqui. Há escadas lá embaixo, e alguém subindo por elas."},
		{"id": "c2_descent", "title": "Desça às Catacumbas", "giver_npc": "hermit_ines", "turnin_npc": "sister_odete", "type": REACH, "target_id": "dg_catacumbas", "count": 1, "level_req": 8, "prereq_quest": "c1_digging",
		 "reward_xp": 450, "reward_gold": 90, "reward_items": {"potion_hp_m": 2}, "map_hint": "Catacumbas do Conde (entrada a sudeste do vale)",
		 "description": "Entre nas Catacumbas do Conde e procure a Irmã Odete no vestíbulo.",
		 "dialog_offer": "A Irmã Odete desceu faz três dias com uma vela e muita teimosia. Encontre ela antes dos mortos.",
		 "dialog_progress": "A entrada abriu perto da minha cabana. Odete deve estar logo depois.", "dialog_complete": "Graças. Ouça: o túmulo do Conde está selado por dois guardiões, e os dois acordaram."},
		{"id": "c3_captain", "title": "A Guarda do Conde", "giver_npc": "sister_odete", "type": KILL, "target_id": "bone_captain", "count": 1, "level_req": 9, "prereq_quest": "c2_descent",
		 "reward_xp": 900, "reward_gold": 180, "reward_items": {"elixir_stone": 1}, "map_hint": "Catacumbas: ala oeste, salão do fundo",
		 "description": "Derrote o Capitão de Ossos no fim da ala oeste.",
		 "dialog_offer": "A ala oeste é a caserna dele. O Capitão de Ossos ainda chama os soldados para a formação.",
		 "dialog_progress": "Derrube os soldados que ele levanta, ou eles cercam você.", "dialog_complete": "Um selo a menos. Os ossos da ala oeste pararam de marchar."},
		{"id": "c4_widow", "title": "O Pranto no Escuro", "giver_npc": "gravedigger_bento", "turnin_npc": "gravedigger_bento", "type": KILL, "target_id": "wailing_widow", "count": 1, "level_req": 9, "prereq_quest": "c2_descent",
		 "reward_xp": 1000, "reward_gold": 200, "reward_items": {"elixir_might": 1}, "map_hint": "Catacumbas: ala leste, salão do fundo",
		 "description": "Dê descanso à Viúva Lamentosa no fim da ala leste.",
		 "dialog_offer": "A viúva do Conde chora há trezentos anos no fim da ala leste. Dê um fim a isso, por favor.",
		 "dialog_progress": "O lamento dela vem em cone: saia da frente. E o toque corta qualquer cura.", "dialog_complete": "Silêncio. Nunca pensei que fosse sentir falta dele."},
		{"id": "c_dust", "title": "Sal da Terra", "giver_npc": "gravedigger_bento", "type": COLLECT, "target_id": "grave_dust", "count": 6, "level_req": 8, "prereq_quest": "c2_descent",
		 "reward_xp": 400, "reward_gold": 120, "reward_items": {"potion_mp_m": 2}, "map_hint": "Catacumbas: mortos andantes, carniçais e aparições",
		 "description": "Traga 6 punhados de Pó de Cova para Bento.",
		 "dialog_offer": "Pó de cova benzido fecha as galerias de novo. Me traz seis punhados, os mortos andam cheios disso.",
		 "dialog_progress": "Mortos andantes, carniçais e aparições carregam isso.", "dialog_complete": "Isso segura as galerias por mais uma geração."},
		{"id": "c5_report", "title": "Os Selos Caíram", "giver_npc": "sister_odete", "turnin_npc": "captain", "type": TALK, "target_id": "captain", "count": 1, "level_req": 9, "prereq_quest": "c3_captain", "prereq_all": ["c4_widow"] as Array[String],
		 "reward_xp": 600, "reward_gold": 150, "reward_gear_tier": 1, "map_hint": "Capitã Mira (praça de Aldara)",
		 "description": "Leve à Capitã Mira a notícia: os guardiões caíram.",
		 "dialog_offer": "Os dois guardiões caíram. Avise a Capitã Mira: a cidade precisa saber, e a estrada leste pode abrir.",
		 "dialog_progress": "Volte à superfície e procure a Capitã na praça.", "dialog_complete": "Então é verdade. Mando abrir o desfiladeiro da Floresta. Aqui, uma peça do arsenal para quem desceu."},
		{"id": "c6_count", "title": "Trezentos Anos de Dívida", "giver_npc": "sister_odete", "type": KILL, "target_id": "count_vargo", "count": 1, "level_req": 11, "prereq_quest": "c5_report",
		 "reward_xp": 2400, "reward_gold": 500, "reward_gear_tier": 1, "reward_items": {"elixir_might": 2}, "map_hint": "Catacumbas: selo ao norte do vestíbulo (leve um grupo)",
		 "description": "Atravesse o selo e derrote o Conde Vargo no trono. Leve um grupo.",
		 "dialog_offer": "O selo ao norte já cede para quem derrubou os guardiões. O Conde não vai cair para uma pessoa só: leve um grupo.",
		 "dialog_progress": "Ele drena quem fica à frente, ergue os mortos e, no fim, perde a compostura.", "dialog_complete": "Acabou. Pela primeira vez em trezentos anos, Aldara não deve nada a ninguém."},
		{"id": "q08_forest", "title": "Rumo à Floresta", "giver_npc": "captain", "turnin_npc": "ranger_post", "type": TALK, "target_id": "ranger_post", "count": 1, "level_req": 10, "prereq_quest": "c5_report",
		 "reward_xp": 250, "reward_gold": 50, "reward_items": {}, "map_hint": "Floresta (desfiladeiro leste do vale)",
		 "description": "Procure o acampamento do Ranger Teo no centro da Floresta.",
		 "dialog_offer": "Teo vigia a Floresta a leste. Ele vai precisar de ajuda.",
		 "dialog_progress": "O portal leste da cidade leva à Floresta.", "dialog_complete": "Mira te mandou? Bom. Tem aranha demais aqui."},
		{"id": "q09_spiders", "title": "Teias por Toda Parte", "giver_npc": "ranger_post", "type": COLLECT, "target_id": "spider_silk", "count": 6, "level_req": 10, "prereq_quest": "q08_forest",
		 "reward_xp": 700, "reward_gold": 120, "reward_items": {"potion_mp_m": 2}, "map_hint": "Floresta: ninhos de aranha (NO e SO)",
		 "description": "Colete 6 Sedas de Aranha.",
		 "dialog_offer": "Seda de aranha vende bem e as aranhas são praga. Traga 6.",
		 "dialog_progress": "As aranhas ficam entre as árvores grandes.", "dialog_complete": "Excelente. Isso paga a estadia de um mês."},
		{"id": "q10_bandits", "title": "Bandidos na Trilha", "giver_npc": "ranger_post", "type": KILL, "target_id": "bandit", "count": 10, "level_req": 12, "prereq_quest": "q09_spiders",
		 "reward_xp": 1100, "reward_gold": 200, "reward_items": {"iron_ore": 6}, "map_hint": "Floresta: paliçada dos bandidos (NE)",
		 "description": "Derrube 10 Bandidos na paliçada a nordeste da Floresta.",
		 "dialog_offer": "Bandidos montaram acampamento a nordeste. Reduza o número deles.",
		 "dialog_progress": "O acampamento fica a nordeste da Floresta. Cuidado com os arqueiros.", "dialog_complete": "Eles vão pensar duas vezes agora."},
		{"id": "q10b_nest", "title": "A Mãe das Teias", "giver_npc": "ranger_post", "type": KILL, "target_id": "spider_queen", "count": 1, "level_req": 16, "prereq_quest": "q10_bandits",
		 "reward_xp": 1800, "reward_gold": 300, "reward_gear_tier": 2, "map_hint": "Ninho Profundo (entrada a sudoeste da Floresta)",
		 "description": "Desça ao Ninho Profundo e derrote a Rainha Aranha.",
		 "dialog_offer": "Enquanto a rainha viver as trilhas não abrem. Os bandidos só engordam com isso. Desça ao Ninho.",
		 "dialog_progress": "A entrada fica a sudoeste. A Rainha dorme no último salão.", "dialog_complete": "As trilhas abriram. Agora dá para chegar no Chefe."},
		{"id": "q11_chief", "title": "O Chefe", "giver_npc": "ranger_post", "type": KILL, "target_id": "bandit_chief", "count": 1, "level_req": 17, "prereq_quest": "q10b_nest",
		 "reward_xp": 2500, "reward_gold": 400, "reward_items": {"elixir_stone": 1}, "map_hint": "Floresta: centro da paliçada dos bandidos",
		 "description": "Derrote o Chefe dos Bandidos.",
		 "dialog_offer": "Sem o chefe, o bando se desfaz. Vá até o fundo do acampamento.",
		 "dialog_progress": "Ele gira a arma — saia do alcance quando ele começar a girar.", "dialog_complete": "A Floresta respira de novo. Obrigado."},
		{"id": "q12_ruins", "title": "Sussurros das Ruínas", "giver_npc": "elder", "turnin_npc": "ruins_scholar", "type": KILL, "target_id": "skeleton", "count": 12, "level_req": 20, "prereq_quest": "el6_king",
		 "reward_xp": 3200, "reward_gold": 500, "reward_items": {"potion_hp_m": 3}, "map_hint": "Ruínas (passagem oeste do vale)",
		 "description": "Os mortos despertaram nas Ruínas a oeste. Elimine 12 Esqueletos (cemitério e bairro sul).",
		 "dialog_offer": "Algo mexeu nas Ruínas. Os ossos andam. Vá pelo portal oeste.",
		 "dialog_progress": "Esqueletos são resistentes a dano físico fraco — melhore sua arma na forja.", "dialog_complete": "Ravi te mandou? Então é verdade. Algo ancestral despertou. Procure Brom: sem armas melhores você não passa daqui."},
		{"id": "q13_cores", "title": "Coração de Pedra", "giver_npc": "smith", "type": COLLECT, "target_id": "golem_core", "count": 2, "level_req": 24, "prereq_quest": "q12_ruins",
		 "reward_xp": 4500, "reward_gold": 800, "reward_items": {"bone_shard": 5}, "map_hint": "Ruínas: pedreira dos golens (SO)",
		 "description": "Traga 2 Núcleos de Golem para Brom.",
		 "dialog_offer": "Com núcleo de golem eu forjo armas lendárias. Traz dois.",
		 "dialog_progress": "Golens ficam no fundo das Ruínas. Eles são lentos — use isso.", "dialog_complete": "Isso... isso é poder de verdade. A forja está pronta pra você."},
		{"id": "q13b_crypt", "title": "Quem Dá as Ordens", "giver_npc": "ruins_scholar", "type": KILL, "target_id": "crypt_lord", "count": 1, "level_req": 25, "prereq_quest": "q13_cores",
		 "reward_xp": 6500, "reward_gold": 1000, "reward_gear_tier": 3, "map_hint": "Cripta de Vel'Thar (entrada junto ao zigurate)",
		 "description": "Desça à Cripta de Vel'Thar e derrote o Senhor da Cripta.",
		 "dialog_offer": "Os mortos marcham em ordem. Alguém comanda lá embaixo, na Cripta sob o zigurate. Comece por ele.",
		 "dialog_progress": "Ele espera no último salão da Cripta.", "dialog_complete": "Sem o comando eles dispersam. Agora sobra o que respira debaixo do altar."},
		{"id": "q14_dragon", "title": "O Dragonete Ancestral", "giver_npc": "ruins_scholar", "type": KILL, "target_id": "dragonling", "turnin_npc": "elder", "count": 1, "level_req": 27, "prereq_quest": "q13b_crypt",
		 "reward_xp": 9000, "reward_gold": 2000, "reward_items": {"dragon_scale": 2, "elixir_might": 3}, "map_hint": "Ruínas: altar (oeste)",
		 "description": "Derrote o Dragonete Ancestral no altar das Ruínas.",
		 "dialog_offer": "A fonte dos sussurros é um dragonete adormecido há séculos. Acabe com isso.",
		 "dialog_progress": "O bafo de fogo cobre um cone — fique ao lado dele.", "dialog_complete": "Aldara está em dívida com você. Que sua lenda seja contada."},
		# ======== Aldara (1-10): o Lago, a fazenda, entregas e a casa do Ancião ========
		{"id": "l1_pincas", "title": "Pinças no Píer", "giver_npc": "vil_fisher", "type": KILL, "target_id": "crab", "count": 8, "level_req": 3,
		 "reward_xp": 300, "reward_gold": 40, "reward_items": {"potion_hp_s": 2}, "map_hint": "Praia dos Caranguejos (margem sul do lago)",
		 "description": "Espante 8 Caranguejos da praia sul do lago.", "dialog_offer": "Os caranguejos tomaram a praia sul e cortam as minhas redes. Oito a menos e eu volto a pescar.",
		 "dialog_progress": "A praia fica na margem sul do lago, depois do píer.", "dialog_complete": "Ouviu isso? Silêncio de pinça. Obrigada!"},
		{"id": "l2_cascos", "title": "Cascos para o Píer", "giver_npc": "vil_fisher", "type": COLLECT, "target_id": "crab_shell", "count": 6, "level_req": 4, "prereq_quest": "l1_pincas",
		 "reward_xp": 350, "reward_gold": 45, "map_hint": "Praia dos Caranguejos: caranguejos e conchas no chão (F)",
		 "description": "Junte 6 Cascos de Caranguejo (dos caranguejos ou colhidos na areia com F).", "dialog_offer": "Casco de caranguejo tapa buraco de barco melhor que piche. Me traz seis? Tem uns soltos na areia também.",
		 "dialog_progress": "Os que brilham na areia dá para pegar com F.", "dialog_complete": "Agora o barco aguenta até o Rei, se ele aparecer."},
		{"id": "l3_cesto", "title": "Peixe Fresco", "giver_npc": "vil_fisher", "turnin_npc": "tav_barkeep", "type": COLLECT, "target_id": "fish_basket", "count": 1, "level_req": 4, "prereq_quest": "l2_cascos",
		 "give_items": {"fish_basket": 1}, "reward_xp": 250, "reward_gold": 60, "map_hint": "Taverna do Javali Dourado (praça de Aldara)",
		 "description": "Leve o Cesto de Peixes ao Taberneiro Gus, na taverna.", "dialog_offer": "Com o barco pronto eu pesquei de novo! Leva esse cesto para o Gus, na taverna? Ele paga você.",
		 "dialog_progress": "A taverna fica na praça; a porta tem a placa 'Taverna'.", "dialog_complete": "Peixe da Nalu! Hoje tem ensopado. E ouça o que dizem do lago..."},
		{"id": "l4_lenda", "title": "A Lenda do Lago", "giver_npc": "tav_barkeep", "turnin_npc": "eld_scribe", "type": TALK, "target_id": "eld_scribe", "count": 1, "level_req": 5, "prereq_quest": "l3_cesto",
		 "reward_xp": 250, "reward_gold": 40, "map_hint": "Casa do Ancião (praça de Aldara)",
		 "description": "Pergunte ao Escriba Tomé sobre a criatura do lago.", "dialog_offer": "Os velhos falam de um caranguejo do tamanho de uma carroça no fundo do lago. O Escriba Tomé sabe dessas histórias.",
		 "dialog_progress": "Tomé mora na casa do Ancião Ravi.", "dialog_complete": "O Caranguejo-Rei! Está nos registros de cem anos atrás. Ele sobe quando os filhotes somem."},
		{"id": "l5_isca", "title": "Isca de Erva Azul", "giver_npc": "eld_scribe", "turnin_npc": "apo_assistant", "type": COLLECT, "target_id": "herb_blue", "count": 6, "level_req": 6, "prereq_quest": "l4_lenda",
		 "reward_xp": 350, "reward_gold": 50, "map_hint": "Margem do lago (ervas azuis brilhando, F)",
		 "description": "Colha 6 Ervas Azuis na margem do lago e leve para a Assistente Mel, na botica.", "dialog_offer": "Os registros dizem: erva azul cozida chama o Rei para a margem. Colha seis na beira do lago e leve à botica.",
		 "dialog_progress": "As ervas azuis crescem em volta do lago. Chegue perto e aperte F.", "dialog_complete": "Pronto, isca fervida. Cheira a lago e a coragem."},
		{"id": "l6_rei", "title": "O Rei do Lago", "giver_npc": "apo_assistant", "turnin_npc": "vil_fisher", "type": KILL, "target_id": "crab_king", "count": 1, "level_req": 8, "prereq_quest": "l5_isca",
		 "reward_xp": 900, "reward_gold": 200, "reward_gear_tier": 1, "reward_items": {"legend_coin": 1}, "map_hint": "Praia dos Caranguejos (ele sai do lago)",
		 "description": "Derrote o Caranguejo-Rei do Lago na praia sul.", "dialog_offer": "Jogue a isca na praia sul. Quando ele sair da água, derrube-o. E cuidado com os filhotes.",
		 "dialog_progress": "Ele chama filhotes quando apanha. Derrube-os ou saia do meio.", "dialog_complete": "O Rei caiu?! O lago é nosso de novo. Tome, é o melhor que eu tenho."},
		{"id": "f1_cenouras", "title": "Ladrões de Cenoura", "giver_npc": "vil_farmer", "type": KILL, "target_id": "slime_blue", "count": 10, "level_req": 3,
		 "reward_xp": 300, "reward_gold": 45, "map_hint": "Fazenda (sudoeste do vale)",
		 "description": "Derrube 10 Slimes Azuis que comem a horta da fazenda.", "dialog_offer": "Os slimes azuis comem as cenouras antes de mim. Derruba dez?",
		 "dialog_progress": "Eles ficam na fazenda e perto do lago.", "dialog_complete": "Minhas cenouras agradecem."},
		{"id": "f2_pao", "title": "Pão para o Campo", "giver_npc": "vil_baker", "turnin_npc": "vil_farmer", "type": COLLECT, "target_id": "bread_basket", "count": 1, "level_req": 2,
		 "give_items": {"bread_basket": 1}, "reward_xp": 180, "reward_gold": 30, "reward_items": {"potion_hp_s": 2}, "map_hint": "Fazenda (sudoeste do vale)",
		 "description": "Leve a Cesta de Pão da Padeira Rosa ao Lavrador Beto, na fazenda.", "dialog_offer": "O Beto saiu sem almoço de novo. Leva essa cesta para ele na fazenda?",
		 "dialog_progress": "A fazenda fica a sudoeste, saindo pelo portão sul.", "dialog_complete": "Pão da Rosa! Ainda quente. Você é um anjo."},
		{"id": "g1_ervas", "title": "Ervas para a Botica", "giver_npc": "apo_assistant", "type": COLLECT, "target_id": "herb_green", "count": 8, "level_req": 2,
		 "reward_xp": 220, "reward_gold": 35, "reward_items": {"potion_hp_s": 3}, "map_hint": "Campina (ervas verdes brilhando, F)",
		 "description": "Colha 8 Ervas Verdes na Campina.", "dialog_offer": "A Lyra gasta erva verde como água. Colhe oito para mim? Elas brilham no campo; é só chegar perto e apertar F.",
		 "dialog_progress": "Campos a leste e a oeste da vila.", "dialog_complete": "Cheirinho de poção nova."},
		{"id": "g2_minerio", "title": "Ferro das Colinas", "giver_npc": "smi_apprentice", "type": COLLECT, "target_id": "iron_ore", "count": 6, "level_req": 5,
		 "reward_xp": 380, "reward_gold": 60, "map_hint": "Colinas dos lobos (norte, veios de minério, F)",
		 "description": "Traga 6 Minérios de Ferro das colinas ao norte.", "dialog_offer": "Mestre Brom quer ferro e eu não quero lobo. Pega seis minérios nas colinas para mim?",
		 "dialog_progress": "Os veios brilham entre as pedras das colinas.", "dialog_complete": "Agora eu bato ferro e o mestre me deixa em paz."},
		{"id": "d1_carta", "title": "Carta para o Lenhador", "giver_npc": "elder", "turnin_npc": "woodcutter_nils", "type": COLLECT, "target_id": "sealed_letter", "count": 1, "level_req": 5,
		 "give_items": {"sealed_letter": 1}, "reward_xp": 300, "reward_gold": 50, "map_hint": "Cabana do Lenhador Nils (noroeste do vale)",
		 "description": "Leve a Carta Selada do Ancião ao Lenhador Nils.", "dialog_offer": "Nils precisa saber do conselho da vila. Leve esta carta a ele, sem abrir.",
		 "dialog_progress": "A cabana dele fica a noroeste, na beira da mata.", "dialog_complete": "Carta do Ravi? Hm. Diga a ele que eu vou."},
		{"id": "e1_presa", "title": "O Presa-Rachada", "giver_npc": "vil_kid_a", "type": KILL, "target_id": "boar_brute", "count": 1, "level_req": 5,
		 "reward_xp": 500, "reward_gold": 80, "reward_items": {"legend_coin": 1}, "map_hint": "Bosque dos javalis (leste)",
		 "description": "Derrube o Javali Presa-Rachada no bosque a leste.", "dialog_offer": "Eu vi! Um javali com a presa rachada, ENORME, no bosque. Se você derrubar ele eu conto para todo mundo!",
		 "dialog_progress": "Ele anda no meio do bosque a leste, com os outros javalis.", "dialog_complete": "VOCÊ DERRUBOU?! Toma, é minha moeda da sorte. Achei no lago."},
		# ======== Floresta (10-20): os bandidos, a herborista, entregas ========
		{"id": "b1_trilhas", "title": "Trilhas Perigosas", "giver_npc": "hunter_dario", "type": KILL, "target_id": "bandit", "count": 12, "level_req": 11,
		 "reward_xp": 1200, "reward_gold": 150, "map_hint": "Floresta: estrada e paliçada (leste)",
		 "description": "Derrube 12 Bandidos nas trilhas a leste.", "dialog_offer": "Bandidos nas minhas trilhas de caça. Doze a menos e eu volto a caçar em paz.",
		 "dialog_progress": "Eles patrulham a estrada e a paliçada a leste.", "dialog_complete": "As trilhas respiram."},
		{"id": "b2_carga", "title": "A Carga Roubada", "giver_npc": "hunter_dario", "type": COLLECT, "target_id": "stolen_goods", "count": 6, "level_req": 12, "prereq_quest": "b1_trilhas",
		 "reward_xp": 1300, "reward_gold": 180, "reward_items": {"potion_hp_m": 2}, "map_hint": "Floresta: acampamento a leste (caixotes, F)",
		 "description": "Recupere 6 caixotes de Carga Roubada no acampamento dos bandidos.", "dialog_offer": "Eles roubaram as carroças de Aldara. Os caixotes estão largados no acampamento a leste. Recupere seis.",
		 "dialog_progress": "Os caixotes ficam perto das barracas. Chegue perto e aperte F.", "dialog_complete": "Farinha, sal, ferro... Aldara vai comer este inverno."},
		{"id": "b3_arqueiros", "title": "Flechas no Escuro", "giver_npc": "hunter_dario", "type": KILL, "target_id": "bandit_archer", "count": 10, "level_req": 14, "prereq_quest": "b2_carga",
		 "reward_xp": 1500, "reward_gold": 200, "map_hint": "Floresta: paliçada dos bandidos",
		 "description": "Derrube 10 Arqueiros Bandidos.", "dialog_offer": "Os arqueiros cobrem a paliçada. Derrube dez e o caminho para o chefe abre.",
		 "dialog_progress": "Feche a distância: arqueiro de perto é fraco.", "dialog_complete": "Sem arqueiros, o chefe está nu."},
		{"id": "b4_relatorio", "title": "Relatório para a Capitã", "giver_npc": "hunter_dario", "turnin_npc": "captain", "type": COLLECT, "target_id": "ranger_report", "count": 1, "level_req": 14, "prereq_quest": "b3_arqueiros",
		 "give_items": {"ranger_report": 1}, "reward_xp": 900, "reward_gold": 150, "map_hint": "Capitã Mira (praça de Aldara)",
		 "description": "Leve o relatório do Ranger à Capitã Mira em Aldara.", "dialog_offer": "Mira precisa saber quantos são e onde. Leve isto a ela em Aldara.",
		 "dialog_progress": "Pela garganta oeste até o vale, depois a praça.", "dialog_complete": "Tantos assim? Vou mandar reforços. Volte com uma ordem minha para o Teo."},
		{"id": "b5_ordens", "title": "Ordens de Aldara", "giver_npc": "captain", "turnin_npc": "ranger_post", "type": TALK, "target_id": "ranger_post", "count": 1, "level_req": 15, "prereq_quest": "b4_relatorio",
		 "reward_xp": 900, "reward_gold": 120, "map_hint": "Acampamento do Ranger Teo (Floresta)",
		 "description": "Leve as ordens da Capitã ao Ranger Teo.", "dialog_offer": "Diga ao Teo: reforços em sete dias. Até lá, que ninguém saia sozinho.",
		 "dialog_progress": "Teo fica no acampamento no centro da Floresta.", "dialog_complete": "Sete dias. Dá para segurar. Mas eu quero aquele chefe caído antes."},
		{"id": "b6_limpeza", "title": "Limpar a Paliçada", "giver_npc": "ranger_post", "type": KILL, "target_id": "bandit", "count": 18, "level_req": 18, "prereq_quest": "b5_ordens",
		 "reward_xp": 2400, "reward_gold": 320, "reward_gear_tier": 2, "map_hint": "Floresta: paliçada dos bandidos",
		 "description": "Derrube 18 Bandidos para o bando não se reerguer.", "dialog_offer": "Depois do chefe, o resto tenta se reagrupar. Limpe a paliçada de vez.",
		 "dialog_progress": "Paliçada a leste.", "dialog_complete": "Acabou o bando. Isto é seu: do arsenal dos reforços."},
		# ======== Cerco élfico (14-20): o Posto dos Caçadores resiste e a guerra vai até a Árvore-Mãe ========
		{"id": "el1_alarm", "title": "Trompas ao Norte", "giver_npc": "ranger_post", "turnin_npc": "forest_commander", "type": TALK, "target_id": "forest_commander", "count": 1, "level_req": 14, "prereq_quest": "q10_bandits",
		 "reward_xp": 600, "reward_gold": 120, "map_hint": "Comandante Hela (quartel do Posto dos Caçadores)",
		 "description": "Apresente-se à Comandante Hela no quartel do Posto.",
		 "dialog_offer": "Ouviu as trompas? Os elfos descem pela garganta norte, atrás da Árvore-Mãe. A Comandante Hela organiza a defesa: fale com ela no quartel.",
		 "dialog_progress": "O quartel fica no lado nordeste do Posto, perto do portão norte.", "dialog_complete": "Teo te mandou? Ótimo. Precisamos de cada arco e cada espada."},
		{"id": "el2_defense", "title": "Segurar o Portão Norte", "giver_npc": "forest_commander", "type": KILL, "target_id": "elf_raider", "count": 8, "level_req": 15, "prereq_quest": "el1_alarm",
		 "reward_xp": 1600, "reward_gold": 260, "reward_items": {"potion_hp_m": 3}, "map_hint": "Floresta: estrada norte (as investidas descem da garganta élfica)",
		 "description": "Derrube 8 Batedores Élficos das investidas que atacam o Posto.",
		 "dialog_offer": "Eles vêm em levas: batedores na frente, arqueiros atrás, linces no meio. Ajude as sentinelas e derrube oito batedores.",
		 "dialog_progress": "Espere as trompas e vá para o portão norte, ou corte a leva na estrada antes que chegue.", "dialog_complete": "O portão aguentou. Agora vamos levar a guerra até eles."},
		{"id": "el3_scout", "title": "Além da Garganta", "giver_npc": "forest_commander", "turnin_npc": "siege_scout", "type": TALK, "target_id": "siege_scout", "count": 1, "level_req": 16, "prereq_quest": "el2_defense",
		 "reward_xp": 900, "reward_gold": 160, "map_hint": "Cidade Élfica: acampamento do cerco (entrada sul)",
		 "description": "Atravesse a garganta élfica e encontre a Batedora Yara no acampamento do cerco.",
		 "dialog_offer": "Mandei a Yara na frente. Ela montou um acampamento na entrada da cidade deles. Passe pela garganta norte e encontre-a.",
		 "dialog_progress": "A garganta fica atrás da Árvore-Mãe. Do outro lado, siga a estrada até a cabana do cerco.", "dialog_complete": "Você passou pelos batedores? Então dá pra começar o cerco de verdade."},
		{"id": "el4_roots", "title": "Raízes que Andam", "giver_npc": "siege_scout", "type": KILL, "target_id": "trent", "count": 4, "level_req": 17, "prereq_quest": "el3_scout",
		 "reward_xp": 2000, "reward_gold": 320, "reward_items": {"elixir_stone": 1}, "map_hint": "Cidade Élfica: bosque dos trents (nordeste)",
		 "description": "Derrube 4 Trents Anciões no bosque a nordeste da cidade.",
		 "dialog_offer": "Os trents seguram qualquer exército no lugar com aquelas raízes. Derrube quatro no bosque a nordeste.",
		 "dialog_progress": "Quando o chão começar a se mexer, saia do círculo: as raízes prendem por dois segundos.", "dialog_complete": "Menos quatro muralhas que andam."},
		{"id": "el5_wardens", "title": "Os Guardiões da Raiz", "giver_npc": "siege_scout", "type": KILL, "target_id": "elf_warden", "count": 3, "level_req": 18, "prereq_quest": "el4_roots",
		 "reward_xp": 2400, "reward_gold": 380, "reward_items": {"elixir_might": 1}, "map_hint": "Cidade Élfica: raiz norte, diante do Coração da Árvore",
		 "description": "Derrube 3 Guardiões da Árvore diante da raiz norte. Leve um grupo.",
		 "dialog_offer": "A raiz norte desce até o salão do rei. Os Guardiões da Árvore não deixam ninguém chegar perto. Três deles, e a passagem é nossa.",
		 "dialog_progress": "Saia da frente da saraivada: ela vem em leque.", "dialog_complete": "A raiz está aberta. Agora é o rei."},
		{"id": "el6_king", "title": "A Coroa da Árvore", "giver_npc": "siege_scout", "turnin_npc": "forest_commander", "type": KILL, "target_id": "elf_king", "count": 1, "level_req": 19, "prereq_quest": "el5_wardens", "prereq_all": ["q10b_nest"] as Array[String],
		 "reward_xp": 4200, "reward_gold": 700, "reward_gear_tier": 2, "reward_items": {"elixir_might": 2}, "map_hint": "Coração da Árvore (raiz norte da Cidade Élfica): leve um grupo",
		 "description": "Desça ao Coração da Árvore e derrote o Rei Élfico Aelthar. Volte à Comandante Hela.",
		 "dialog_offer": "Aelthar está no Coração da Árvore, embaixo de tudo. Enquanto ele viver, as investidas não param. Leve um grupo.",
		 "dialog_progress": "Ele chama a Guarda Real, depois a floresta inteira. No fim perde a calma: segure firme.", "dialog_complete": "Acabou? As trompas pararam... A garganta oeste para as Ruínas está liberada. E isto é do arsenal do Posto."},
		{"id": "els_lynx", "title": "Faro Élfico", "giver_npc": "forest_commander", "type": KILL, "target_id": "elf_lynx", "count": 6, "level_req": 15, "prereq_quest": "el1_alarm",
		 "reward_xp": 1100, "reward_gold": 180, "map_hint": "Floresta: investidas élficas (estrada norte)",
		 "description": "Derrube 6 Linces de Guerra das investidas.", "dialog_offer": "Os linces correm na frente e farejam as sentinelas. Sem eles, os elfos chegam cegos.",
		 "dialog_progress": "Eles vêm junto das investidas.", "dialog_complete": "Sem faro, sem surpresa."},
		{"id": "els_steel", "title": "Aço que Pesa Nada", "giver_npc": "forest_smith", "type": COLLECT, "target_id": "elf_steel", "count": 5, "level_req": 16, "prereq_quest": "el2_defense",
		 "reward_xp": 1200, "reward_gold": 220, "reward_items": {"elf_steel": 2}, "map_hint": "Cidade Élfica: guerreiros e arqueiros élficos",
		 "description": "Traga 5 Aços Élficos para Gunnar estudar.", "dialog_offer": "Quero ver de perto esse aço élfico. Traga cinco e eu te mostro o que ele faz numa peça da Glória.",
		 "dialog_progress": "Os elfos da cidade carregam. Os batedores, às vezes.", "dialog_complete": "Leve como pena! Fica com dois de volta: na Glória, isso vale ouro."},
		{"id": "els_feathers", "title": "Penas de Grifo", "giver_npc": "elf_deserter", "type": COLLECT, "target_id": "griffin_feather", "count": 6, "level_req": 17,
		 "reward_xp": 1500, "reward_gold": 240, "reward_items": {"potion_mp_m": 2}, "map_hint": "Cidade Élfica: ninho dos grifos (noroeste)",
		 "description": "Traga 6 Penas de Grifo para Caelir.", "dialog_offer": "Os grifos do rei aninham nos penhascos a noroeste. Com as penas deles eu faço flechas que os elfos não conhecem.",
		 "dialog_progress": "Eles mergulham: quando o grifo subir, saia de baixo.", "dialog_complete": "Flechas para o cerco. A Yara vai gostar."},
		{"id": "els_heart", "title": "Cerne Adormecido", "giver_npc": "elf_deserter", "type": COLLECT, "target_id": "heartwood", "count": 3, "level_req": 18, "prereq_quest": "els_feathers",
		 "reward_xp": 1700, "reward_gold": 260, "reward_items": {"mother_sap": 1}, "map_hint": "Cidade Élfica: bosque dos trents (nordeste)",
		 "description": "Traga 3 Cernes de Trent para Caelir.", "dialog_offer": "O cerne dos trents guarda a seiva da Árvore. Três deles e eu destilo uma gota para você.",
		 "dialog_progress": "Os trents mais velhos ficam no bosque escuro a nordeste.", "dialog_complete": "Uma gota de Seiva da Árvore-Mãe. Gunnar sabe o que fazer com ela."},
		# ======== Ruínas (20-30): a erudita, relíquias e minério estelar ========
		{"id": "r1_reliquias", "title": "Cacos de Vel'Thar", "giver_npc": "ruins_scholar", "type": COLLECT, "target_id": "ancient_relic", "count": 6, "level_req": 20, "prereq_quest": "q12_ruins",
		 "reward_xp": 3000, "reward_gold": 400, "map_hint": "Ruínas: escavação (nordeste) e entrada da cripta (relíquias, F)",
		 "description": "Recolha 6 Relíquias Antigas nas Ruínas.", "dialog_offer": "Cada caco conta um pedaço da cidade que desceu. Recolha seis: a escavação a nordeste está cheia.",
		 "dialog_progress": "Os cacos brilham na terra revirada. Chegue perto e aperte F.", "dialog_complete": "Runas de comando... alguém dava ordens aos mortos."},
		{"id": "r2_espectros", "title": "Os Que Guardam", "giver_npc": "ruins_scholar", "type": KILL, "target_id": "ghost", "count": 10, "level_req": 22, "prereq_quest": "r1_reliquias",
		 "reward_xp": 3400, "reward_gold": 450, "map_hint": "Ruínas: pântano e bairro norte",
		 "description": "Dissipe 10 Espectros que guardam as ruínas.", "dialog_offer": "Os espectros guardam o que sobrou. Dissipe dez e eu leio o resto.",
		 "dialog_progress": "Eles atravessam paredes. Não fuja em linha reta.", "dialog_complete": "Agora consigo ler: 'a pedra das estrelas abre o selo'."},
		{"id": "r3_estelar", "title": "A Pedra das Estrelas", "giver_npc": "ruins_scholar", "turnin_npc": "smith", "type": COLLECT, "target_id": "star_ore", "count": 5, "level_req": 23, "prereq_quest": "r2_espectros",
		 "reward_xp": 3600, "reward_gold": 500, "map_hint": "Ruínas: pedreira dos golens (veios azuis, F); entregar ao Brom em Aldara",
		 "description": "Colha 5 Minérios Estelares na pedreira e leve ao ferreiro Brom.", "dialog_offer": "Minério estelar só na pedreira dos golens. Brom, em Aldara, sabe trabalhar isso. Leve cinco para ele.",
		 "dialog_progress": "Os veios azuis ficam entre os golens. Cuidado com eles.", "dialog_complete": "Estelar! Faz trinta anos que eu não vejo isso. Com isto eu forjo a chave que a Senna quer."},
		{"id": "r4_chave", "title": "A Chave Forjada", "giver_npc": "smith", "turnin_npc": "ruins_scholar", "type": COLLECT, "target_id": "sealed_letter", "count": 1, "level_req": 24, "prereq_quest": "r3_estelar",
		 "give_items": {"sealed_letter": 1}, "reward_xp": 2400, "reward_gold": 300, "reward_gear_tier": 3, "map_hint": "Erudita Senna (centro das Ruínas)",
		 "description": "Leve à Erudita Senna o embrulho selado do Brom.", "dialog_offer": "Embrulhei a chave com o lacre da forja. Leve à Senna e nada de espiar.",
		 "dialog_progress": "Senna fica no acampamento do centro das Ruínas.", "dialog_complete": "Com isto o selo da cripta abre. Tome, Brom mandou isto também."},
		{"id": "r5_vigilia", "title": "Vigília dos Ossos", "giver_npc": "gravedigger_osric", "type": KILL, "target_id": "skeleton", "count": 15, "level_req": 24,
		 "reward_xp": 3000, "reward_gold": 400, "map_hint": "Ruínas: cemitério e bairro sul",
		 "description": "Derrube 15 Esqueletos no cemitério.", "dialog_offer": "Eu enterro, eles levantam. Quinze a menos e eu fecho o portão.",
		 "dialog_progress": "Cemitério e bairro sul.", "dialog_complete": "Portão fechado. Por hoje."},
		# ---- laterais: NPCs das cabanas (places.py), sem pré-requisito ----
		{"id": "s_wolf_den", "title": "Lobos no Quintal", "giver_npc": "woodcutter_nils", "type": KILL, "target_id": "wolf", "count": 6, "level_req": 6,
		 "reward_xp": 300, "reward_gold": 70, "reward_items": {"potion_hp_s": 3}, "map_hint": "Aldara: covil ao norte da vila",
		 "description": "Derrube 6 Lobos no covil ao norte da vila.",
		 "dialog_offer": "Lobos armaram covil perto da estrada norte. Tire eles de lá e eu volto a dormir.",
		 "dialog_progress": "O covil fica ao norte da vila, antes das colinas.", "dialog_complete": "Silêncio de novo. Obrigado."},
		{"id": "s_slime_king", "title": "O Que Borbulha", "giver_npc": "hermit_ines", "type": KILL, "target_id": "slime_king", "count": 1, "level_req": 8,
		 "reward_xp": 500, "reward_gold": 120, "reward_gear_tier": 1, "map_hint": "Gruta Gotejante (entrada a nordeste do vale)",
		 "description": "Derrote o Rei Slime no fundo da Gruta Gotejante.",
		 "dialog_offer": "A gruta a nordeste tem um dono. Vá até o fundo e acabe com ele.",
		 "dialog_progress": "Siga o corredor até o último salão da gruta.", "dialog_complete": "Enfim, silêncio. Era isso que eu queria."},
		{"id": "s_silk", "title": "Linha de Sutura", "giver_npc": "herbalist_maren", "type": COLLECT, "target_id": "spider_silk", "count": 5, "level_req": 11,
		 "reward_xp": 700, "reward_gold": 130, "reward_items": {"potion_hp_s": 4}, "map_hint": "Floresta: ninhos de aranha",
		 "description": "Traga 5 Sedas de Aranha para Maren.",
		 "dialog_offer": "Traga seda de aranha. Os ninhos ficam a noroeste e aqui no sudoeste.",
		 "dialog_progress": "Cinco fios bons, por favor.", "dialog_complete": "Vai salvar muita gente."},
		{"id": "s_queen", "title": "Cogumelos da Sombra", "giver_npc": "herbalist_maren", "type": COLLECT, "target_id": "forest_mushroom", "count": 8, "level_req": 13, "prereq_quest": "s_silk",
		 "reward_xp": 1400, "reward_gold": 200, "reward_gear_tier": 1, "map_hint": "Floresta: sombra das árvores grandes (cogumelos, F)",
		 "description": "Colha 8 Cogumelos da Mata para Maren.",
		 "dialog_offer": "Com seda eu costuro; com cogumelo da sombra eu curo. Colha oito: crescem aqui perto e no bosque dos ents.",
		 "dialog_progress": "Chapéus vermelhos no chão, perto das árvores grandes. Aperte F.", "dialog_complete": "Isso vira unguento para a vila inteira. Leve isto, foi do meu filho."},
		{"id": "s_ents", "title": "Bosque que Anda", "giver_npc": "hunter_dario", "type": KILL, "target_id": "ent", "count": 4, "level_req": 15,
		 "reward_xp": 1500, "reward_gold": 240, "reward_items": {"potion_hp_s": 5}, "map_hint": "Floresta: bosque dos ents (SE)",
		 "description": "Derrube 4 Ents no bosque a sudeste.",
		 "dialog_offer": "Os ents estão descendo para a trilha. Faça eles voltarem.",
		 "dialog_progress": "Bata e saia: eles são lentos.", "dialog_complete": "Agora a trilha é nossa de novo."},
		{"id": "s_ghosts", "title": "Descanso Forçado", "giver_npc": "gravedigger_osric", "type": KILL, "target_id": "ghost", "count": 6, "level_req": 22,
		 "reward_xp": 3200, "reward_gold": 420, "reward_items": {"potion_hp_s": 5}, "map_hint": "Ruínas: pântano ao norte",
		 "description": "Dissipe 6 Espectros.",
		 "dialog_offer": "Os espectros não deixam ninguém descansar. Nem eu.",
		 "dialog_progress": "Eles vêm do pântano ao norte.", "dialog_complete": "Hoje eu durmo."},
		{"id": "s_crypt", "title": "Pedras que Andam", "giver_npc": "digger_vera", "type": KILL, "target_id": "golem", "count": 6, "level_req": 26,
		 "reward_xp": 5000, "reward_gold": 700, "reward_gear_tier": 3, "map_hint": "Ruínas: pedreira dos golens (SO)",
		 "description": "Quebre 6 Golens que pisoteiam a escavação.",
		 "dialog_offer": "Os golens descem da pedreira e esmagam meus achados. Quebre seis.",
		 "dialog_progress": "Eles são lentos: bata e saia.", "dialog_complete": "Minhas trincheiras agradecem. Leve isto, achei na terra."},
		# ---- recompensas repetíveis nos quadros: caça com propósito depois da história ----
		{"id": "b_wolves", "title": "Recompensa: Lobos", "giver_npc": "board", "type": KILL, "target_id": "wolf", "count": 10, "level_req": 6, "repeatable": true,
		 "reward_xp": 260, "reward_gold": 90, "map_hint": "Aldara: colinas e covil ao norte",
		 "description": "Abata 10 Lobos.", "dialog_offer": "Pagamos por dez lobos abatidos.", "dialog_progress": "Colinas ao norte.", "dialog_complete": "Pago."},
		{"id": "b_zombies", "title": "Recompensa: Mortos Andantes", "giver_npc": "board", "type": KILL, "target_id": "zombie", "count": 8, "level_req": 9, "repeatable": true,
		 "reward_xp": 440, "reward_gold": 130, "map_hint": "Catacumbas do Conde",
		 "description": "Abata 8 Mortos Andantes.", "dialog_offer": "Os mortos não param de subir. Oito a menos ajudam.", "dialog_progress": "Alas das Catacumbas.", "dialog_complete": "Pago."},
		{"id": "b_bones", "title": "Recompensa: Recrutas de Ossos", "giver_npc": "board", "type": KILL, "target_id": "bone_recruit", "count": 8, "level_req": 10, "repeatable": true,
		 "reward_xp": 520, "reward_gold": 150, "map_hint": "Catacumbas: ala oeste",
		 "description": "Abata 8 Recrutas de Ossos.", "dialog_offer": "A caserna do Conde se refaz sozinha. Quebre oito.", "dialog_progress": "Ala oeste das Catacumbas.", "dialog_complete": "Pago."},
		{"id": "b_spiders", "title": "Pedra: Aranhas", "giver_npc": "stone_druid", "type": KILL, "target_id": "spider", "count": 12, "level_req": 12, "repeatable": true,
		 "reward_xp": 1000, "reward_gold": 220, "map_hint": "Floresta: ninhos de aranha",
		 "description": "Abata 12 Aranhas Gigantes.", "dialog_offer": "Riscado na pedra: 'as teias sufocam a raiz'.", "dialog_progress": "Ninhos a noroeste e sudoeste.", "dialog_complete": "O musgo parece mais verde."},
		{"id": "b_bandits", "title": "Pedra: Bandidos", "giver_npc": "stone_druid", "type": KILL, "target_id": "bandit", "count": 12, "level_req": 15, "repeatable": true,
		 "reward_xp": 1500, "reward_gold": 320, "map_hint": "Floresta: paliçada (NE)",
		 "description": "Abata 12 Bandidos.", "dialog_offer": "Riscado na pedra: 'quem corta a raiz perde o caminho'.", "dialog_progress": "Paliçada a nordeste.", "dialog_complete": "O musgo parece mais verde."},
		{"id": "b_ents", "title": "Pedra: Ents Inquietos", "giver_npc": "stone_druid", "type": KILL, "target_id": "ent", "count": 5, "level_req": 18, "repeatable": true,
		 "reward_xp": 2200, "reward_gold": 400, "map_hint": "Floresta: bosque dos ents (SE)",
		 "description": "Acalme 5 Ents.", "dialog_offer": "Riscado na pedra: 'até a árvore precisa dormir'.", "dialog_progress": "Bosque a sudeste.", "dialog_complete": "O musgo parece mais verde."},
		{"id": "b_skeletons", "title": "Obelisco: Esqueletos", "giver_npc": "stone_obelisk", "type": KILL, "target_id": "skeleton", "count": 15, "level_req": 22, "repeatable": true,
		 "reward_xp": 6000, "reward_gold": 700, "map_hint": "Ruínas: cemitério e bairro sul",
		 "description": "Abata 15 Esqueletos.", "dialog_offer": "As runas brilham quando os mortos caem.", "dialog_progress": "Cemitério e bairro sul.", "dialog_complete": "As runas se apagam, por enquanto."},
		{"id": "b_ghosts", "title": "Obelisco: Espectros", "giver_npc": "stone_obelisk", "type": KILL, "target_id": "ghost", "count": 12, "level_req": 25, "repeatable": true,
		 "reward_xp": 10000, "reward_gold": 950, "map_hint": "Ruínas: pântano ao norte",
		 "description": "Dissipe 12 Espectros.", "dialog_offer": "As runas brilham quando os mortos caem.", "dialog_progress": "Pântano ao norte.", "dialog_complete": "As runas se apagam, por enquanto."},
		{"id": "b_golems", "title": "Obelisco: Golens", "giver_npc": "stone_obelisk", "type": KILL, "target_id": "golem", "count": 6, "level_req": 27, "repeatable": true,
		 "reward_xp": 16000, "reward_gold": 1300, "map_hint": "Ruínas: pedreira (SO)",
		 "description": "Quebre 6 Golens de Pedra.", "dialog_offer": "As runas brilham quando os mortos caem.", "dialog_progress": "Pedreira a sudoeste.", "dialog_complete": "As runas se apagam, por enquanto."},
	]
	var out: Array = []
	for d in L:
		out.append(_mk(d))
	return out
