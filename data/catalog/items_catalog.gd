class_name ItemsCatalog
extends RefCounted
## Materiais, consumíveis e equipamentos. Equipamento = pontos de atributo.
## rarity 0..3 também é o "tier" (lv 1 / 8 / 16 / 24); o tier 4 (lv 32, Ato II) só tem itens gerados (GearCatalog), raridade 3.

const MAT := ItemDef.Type.MATERIAL
const CON := ItemDef.Type.CONSUMABLE
const EQ := ItemDef.Type.EQUIPMENT
const QST := ItemDef.Type.QUEST
const S_W := ItemDef.Slot.WEAPON; const S_O := ItemDef.Slot.OFFHAND; const S_H := ItemDef.Slot.HEAD
const S_B := ItemDef.Slot.BODY; const S_F := ItemDef.Slot.BOOTS; const S_R := ItemDef.Slot.RING
const S_G := ItemDef.Slot.GLOVES; const S_L := ItemDef.Slot.LEGS; const S_C := ItemDef.Slot.CAPE; const S_M := ItemDef.Slot.AMULET

## Conjunto inicial de cada classe (nível 1): estilo do kit, cor, nomes e os atributos do corpo (os mesmos
## da antiga peça única, então os atributos iniciais não mudam); elmo/luvas/botas só dão um pouco de defesa.
const STARTER_SETS := {
	"paladin": ["plate", Color(0.8, 0.83, 0.9), "do Escudeiro", {"VIT": 2, "FOR": 1}],
	"berserker": ["leather", Color(0.6, 0.26, 0.2), "do Saqueador", {"VIT": 2, "AGI": 1}],
	"bishop": ["cloth", Color(0.95, 0.92, 0.82), "do Noviço", {"WILL": 2, "INT": 1}],
	"druid": ["leather", Color(0.42, 0.62, 0.32), "do Bosque", {"VIT": 2, "AGI": 1}],
	"ranger": ["leather", Color(0.3, 0.5, 0.46), "do Batedor", {"VIT": 2, "AGI": 1}],
	"assassin": ["leather", Color(0.32, 0.24, 0.42), "das Sombras", {"VIT": 2, "AGI": 1}],
	"elementalist": ["cloth", Color(0.36, 0.52, 0.92), "do Aprendiz Arcano", {"WILL": 2, "INT": 1}],
	"necromancer": ["cloth", Color(0.25, 0.27, 0.25), "do Acólito", {"WILL": 2, "INT": 1}],
}
const STARTER_PIECES := {
	"head": [S_H, {"plate": "Elmo", "leather": "Capuz", "cloth": "Capuz"}],
	"body": [S_B, {"plate": "Cota", "leather": "Gibão", "cloth": "Túnica"}],
	"legs": [S_L, {"plate": "Perneiras", "leather": "Calças", "cloth": "Calças"}],
	"gloves": [S_G, {"plate": "Manoplas", "leather": "Luvas", "cloth": "Luvas"}],
	"boots": [S_F, {"plate": "Grevas", "leather": "Botas", "cloth": "Sandálias"}],
	"cape": [S_C, {"plate": "Capa", "leather": "Capa", "cloth": "Capa"}],
}

## Acessórios únicos (drops de chefe/quest): os números escritos em build() são só a PROPORÇÃO entre os atributos; o valor
## sai de GearCatalog.unique_acc (spec acessórios F6: min(1,25x a comum do nível; 0,9x a do tier seguinte)) no fim de build().
const UNIQUE_ACCESSORIES := ["ring_gel", "ring_captain", "ring_vargo", "amulet_widow", "cape_vargo", "amulet_tusk", "amulet_silk",
	"ring_spectral", "amulet_golem"]

## escudos comuns também têm silhueta própria
const SHIELD_LOOK := {"shield_wood": "tabuas", "shield_iron": "ferro", "shield_bone": "ossario", "shield_dragon": "escama"}

## ids do conjunto inicial de uma classe (cabeça, peito, calça, luvas, botas, capa)
static func starter_ids(class_id: String) -> Array:
	var out: Array = []
	for piece in STARTER_PIECES:
		out.append("start_%s_%s" % [class_id, piece])
	return out

static func _starter_items() -> Array:
	var out: Array = []
	for cid in STARTER_SETS:
		var st: Array = STARTER_SETS[cid]
		var style: String = st[0]
		for piece in STARTER_PIECES:
			var info: Array = STARTER_PIECES[piece]
			var body: bool = piece == "body"
			var phys := style != "cloth"
			var col: Color = st[1]
			if piece in ["gloves", "boots"]:
				col = col.darkened(0.12)
			elif piece == "legs":
				col = col.darkened(0.3)
			elif piece == "cape":
				col = ItemDef.accent(col)
			var d := _armor("start_%s_%s" % [cid, piece], "%s %s" % [info[1][style], st[2]], info[0], 0,
				(4.0 if phys else 2.0) if body else 1.0, (2.0 if phys else 4.0) if body else 1.0,
				st[3] if body else {}, col)
			d["armor_style"] = "cape" if piece == "cape" else style
			var cr: Array[String] = [cid]
			d["class_restriction"] = cr
			d["description"] = "Conjunto inicial (%s)." % cid
			out.append(d)
	return out

static func _mk(d: Dictionary) -> ItemDef:
	var it := ItemDef.new()
	CatalogUtil.fill(it, d)
	return it

static func _mat(id: String, name: String, price: int, desc: String, color: Color) -> Dictionary:
	return {"id": id, "name": name, "type": MAT, "price": price, "description": desc, "icon_color": color}

static func _weapon(id: String, name: String, wtype: String, tier: int, atk: float, matk: float, attrs: Dictionary, color: Color, classes: Array = []) -> Dictionary:
	var cr: Array[String] = []
	for c in classes:
		cr.append(c)
	return {"id": id, "name": name, "type": EQ, "slot": S_O if wtype == "shield" else S_W, "weapon_type": wtype, "rarity": tier, "level_req": Balance.COMMON_TIER_LEVELS[tier],
		"atk": atk, "matk": matk, "attributes": attrs, "icon_color": color, "price": Balance.STARTER_WEAPON_PRICES[tier], "stack_max": 1, "class_restriction": cr}

static func _armor(id: String, name: String, slot: int, tier: int, def: float, mdef: float, attrs: Dictionary, color: Color) -> Dictionary:
	return {"id": id, "name": name, "type": EQ, "slot": slot, "rarity": tier, "level_req": Balance.COMMON_TIER_LEVELS[tier],
		"def": def, "mdef": mdef, "attributes": attrs, "icon_color": color, "price": Balance.STARTER_ARMOR_PRICES[tier], "stack_max": 1}

static func build() -> Array:
	var L := [
		# ---------------- consumíveis ----------------
		{"id": "potion_hp_s", "name": "Poção de Vida (P)", "type": CON, "price": 15, "icon_color": Color(1, 0.35, 0.35), "description": "Recupera 60 HP.", "consume": {"heal": 60}, "consume_cooldown": 4.0},
		{"id": "potion_hp_m", "name": "Poção de Vida (M)", "type": CON, "price": 45, "icon_color": Color(1, 0.2, 0.2), "description": "Recupera 35% do HP.", "consume": {"heal_pct": 0.35}, "consume_cooldown": 4.0, "level_req": 8},
		{"id": "potion_mp_s", "name": "Poção de Mana (P)", "type": CON, "price": 18, "icon_color": Color(0.35, 0.5, 1), "description": "Recupera 40 MP.", "consume": {"mana": 40}, "consume_cooldown": 4.0},
		{"id": "potion_mp_m", "name": "Poção de Mana (M)", "type": CON, "price": 50, "icon_color": Color(0.2, 0.35, 1), "description": "Recupera 35% do MP.", "consume": {"mana_pct": 0.35}, "consume_cooldown": 4.0, "level_req": 8},
		{"id": "elixir_might", "name": "Elixir da Força", "type": CON, "price": 90, "icon_color": Color(1, 0.7, 0.2), "description": "+20% ATK/MATK por 45s.", "consume": {"buff": {"id": "elixir", "duration": 45, "atk_pct": 20, "matk_pct": 20}}, "consume_cooldown": 6.0},
		{"id": "clear_wine", "name": "Vinho Claro", "type": CON, "price": 120, "icon_color": Color(0.86, 0.82, 1.0), "level_req": 46,
		 "description": "Vinho filtrado na seda do Festim: recupera %d%% do MP." % roundi(Balance.CLEAR_WINE_MANA_PCT * 100.0),
		 "consume": {"mana_pct": Balance.CLEAR_WINE_MANA_PCT}, "consume_cooldown": 4.0},
		{"id": "elixir_stone", "name": "Elixir de Pedra", "type": CON, "price": 90, "icon_color": Color(0.6, 0.6, 0.7), "description": "+25% DEF por 45s.", "consume": {"buff": {"id": "stoneskin", "duration": 45, "def_pct": 25}}, "consume_cooldown": 6.0},
		# ---------------- materiais ----------------
		{"id": "legend_coin", "name": "Moeda Lendária", "type": MAT, "price": 0, "stack_max": 999, "icon_color": Color(1.0, 0.62, 0.18),
		 "description": "Troque com Iara, a Relicária (praça de Aldara), por uma peça lendária: nível 5 = 1 moeda, nível 10 = 2, nível 15 = 3..."},
		_mat("slime_gel", "Gel de Slime", 4, "Pegajoso. Alquimistas adoram.", Color(0.4, 0.9, 0.5)),
		_mat("crab_shell", "Casco de Caranguejo", 7, "Duro e leve. O ferreiro faz escudos e grevas com ele.", Color(0.9, 0.45, 0.32)),
		# colhidos no mundo (F perto do ponto que brilha) e de entrega (quest)
		_mat("forest_mushroom", "Cogumelo da Mata", 9, "Cresce na sombra das árvores grandes. Herboristas pagam bem.", Color(0.85, 0.35, 0.3)),
		_mat("ancient_relic", "Relíquia Antiga", 22, "Caco de cerâmica com runas de Vel'Thar.", Color(0.75, 0.68, 0.45)),
		_mat("star_ore", "Minério Estelar", 30, "Pedra que brilha no escuro. Só aparece nas Ruínas.", Color(0.55, 0.65, 0.95)),
		_mat("fish_basket", "Cesto de Peixes", 0, "Encomenda da Pescadora Nalu para a taverna.", Color(0.7, 0.55, 0.35)),
		_mat("bread_basket", "Cesta de Pão", 0, "Pão quentinho da Padeira Rosa.", Color(0.9, 0.7, 0.4)),
		_mat("sealed_letter", "Carta Selada", 0, "Lacre de cera do Ancião. Não abra.", Color(0.9, 0.85, 0.7)),
		_mat("ranger_report", "Relatório do Ranger", 0, "Anotações do Ranger Teo sobre a Floresta.", Color(0.6, 0.75, 0.5)),
		_mat("stolen_goods", "Carga Roubada", 0, "Caixotes que os bandidos tiraram das carroças.", Color(0.62, 0.48, 0.32)),
		# bolsas ampliadas (alquimista costura): vestidas nas vagas de bolsa, +Balance.BAG_SIZES[tier] espaços cada
		{"id": "bag_t0", "name": "Bolsa Ampliada I", "type": CON, "price": 40, "icon_color": Color(0.62, 0.45, 0.3), "description": "Bolsa: +6 espaços. Vista numa das 4 vagas de bolsa (clique ou arraste); repetidas valem.", "consume": {"bag": 0}, "stack_max": 1},
		{"id": "bag_t1", "name": "Bolsa Ampliada II", "type": CON, "price": 120, "icon_color": Color(0.5, 0.55, 0.35), "description": "Bolsa: +8 espaços. Vista numa das 4 vagas de bolsa (clique ou arraste); repetidas valem.", "consume": {"bag": 1}, "stack_max": 1},
		{"id": "bag_t2", "name": "Bolsa Ampliada III", "type": CON, "price": 260, "icon_color": Color(0.4, 0.45, 0.7), "description": "Bolsa: +10 espaços. Vista numa das 4 vagas de bolsa (clique ou arraste); repetidas valem.", "consume": {"bag": 2}, "stack_max": 1},
		{"id": "bag_t3", "name": "Bolsa Ampliada IV", "type": CON, "price": 500, "icon_color": Color(0.7, 0.45, 0.75), "description": "Bolsa: +12 espaços. Vista numa das 4 vagas de bolsa (clique ou arraste); repetidas valem.", "consume": {"bag": 3}, "stack_max": 1},
		_mat("wolf_pelt", "Pele de Lobo", 9, "Couro resistente.", Color(0.55, 0.45, 0.35)),
		_mat("boar_tusk", "Presa de Javali", 10, "Afiada. Boa para adornos.", Color(0.95, 0.9, 0.8)),
		_mat("honey_comb", "Favo de Mel", 8, "Mel da Mata dos Zumbidos. O Apicultor Osvaldo e a alquimista disputam cada favo.", Color(0.98, 0.72, 0.2)),
		_mat("bear_hide", "Couro de Urso", 11, "Grosso e quente. Caçadores fazem gibões com ele.", Color(0.45, 0.3, 0.2)),
		_mat("painted_hide", "Pele Pintada", 18, "Couro marcado com tinta de casca. Os xamãs do bosque pintam a pele antes de virar bicho.", Color(0.62, 0.4, 0.28)),
		_mat("spirit_feather", "Pena Espiritual", 20, "Pena de gavião que nunca cai reta. A herbalista diz que ela ainda lembra do voo.", Color(0.85, 0.82, 0.62)),
		_mat("totem_bark", "Casca de Totem", 22, "Lasca de totem dos Chamadores, gravada com olhos. Arde devagar e cheira a resina.", Color(0.45, 0.32, 0.22)),
		_mat("wasp_stinger", "Ferrão de Vespa", 7, "Ainda pinga veneno. Cuidado ao guardar.", Color(0.95, 0.85, 0.35)),
		_mat("herb_green", "Erva Verde", 5, "Base de poções de vida.", Color(0.3, 0.8, 0.3)),
		_mat("herb_blue", "Erva Azul", 6, "Base de poções de mana.", Color(0.3, 0.5, 0.95)),
		_mat("iron_ore", "Minério de Ferro", 8, "Derretido vira lâminas.", Color(0.5, 0.5, 0.55)),
		_mat("spider_silk", "Seda de Aranha", 12, "Fina e forte.", Color(0.9, 0.9, 0.95)),
		_mat("ent_bark", "Casca de Ent", 15, "Madeira viva.", Color(0.45, 0.3, 0.2)),
		_mat("bandit_badge", "Insígnia de Bandido", 14, "Prova de serviço prestado.", Color(0.7, 0.2, 0.2)),
		_mat("bone_shard", "Fragmento de Osso", 16, "Ainda sussurra.", Color(0.9, 0.9, 0.8)),
		_mat("grave_dust", "Pó de Cova", 9, "Frio mesmo no sol.", Color(0.55, 0.52, 0.58)),
		_mat("ghost_essence", "Essência Espectral", 25, "Fria ao toque.", Color(0.6, 0.9, 1.0)),
		# Cerco élfico: aprimoram o conjunto lendário da Glória (nível 20) no ferreiro
		_mat("holy_silver", "Prata Consagrada", 34, "Prata benzida na catedral da Aurora. Aprimora lendários 25+ (+1 a +5) no ferreiro.", Color(0.86, 0.9, 1.0)),
		_mat("dawn_shard", "Fragmento da Aurora", 90, "Lasca de luz sólida. Aprimora lendários 25+ (+6 a +9) no ferreiro.", Color(1.0, 0.82, 0.4)),
		_mat("rot_gel", "Bile Pútrida", 16, "Gosma verde que os mortos do Carniçal deixam. Os alquimistas da Aurora queimam.", Color(0.55, 0.8, 0.3)),
		_mat("elf_steel", "Aço Élfico", 28, "Leve como pena. Aprimora peças da Glória (+1 a +5) no ferreiro.", Color(0.7, 0.9, 0.75)),
		_mat("mother_sap", "Seiva da Árvore-Mãe", 70, "Dourada e morna. Aprimora peças da Glória (+6 a +9) no ferreiro.", Color(0.95, 0.8, 0.3)),
		_mat("heartwood", "Cerne de Trent", 24, "O coração de madeira de um Trent Ancião.", Color(0.5, 0.36, 0.2)),
		_mat("palisade_log", "Tora de Estaca", 6, "Tora cortada no estaleiro do porto. O Carpinteiro Bruno faz dela uma estaca de paliçada.", Color(0.66, 0.5, 0.32)),
		_mat("griffin_feather", "Pena de Grifo", 18, "Dourada na ponta. Flecheiros pagam bem.", Color(0.95, 0.85, 0.55)),
		_mat("golem_core", "Núcleo de Golem", 60, "Pulsa com magia antiga.", Color(0.9, 0.6, 0.2)),
		_mat("stone_core", "Núcleo de Pedra", 22, "Coração de um golem da Pedreira; ainda morno.", Color(0.66, 0.58, 0.46)),
		_mat("dragon_scale", "Escama de Dragonete", 80, "Rara. Quase indestrutível.", Color(0.8, 0.2, 0.3)),
		# Ato II, a Horda (30-35): Costa Partida e Grutas Goblin
		_mat("goblin_fang", "Dente de Goblin", 26, "Amarelo e torto. O Porto Esperança paga por prova de abate.", Color(0.92, 0.86, 0.55)),
		_mat("horde_badge", "Insígnia da Horda", 34, "Pano vermelho com o punho da Horda. Os oficiais do porto querem saber de onde vêm.", Color(0.78, 0.16, 0.14)),
		_mat("rider_pelt", "Pele de Lobo de Guerra", 30, "Pelo grosso, cheira a fumaça de acampamento.", Color(0.45, 0.42, 0.4)),
		_mat("orc_tusk", "Presa de Orc", 36, "Pesada como pedra. Os ferreiros do porto fazem cabos com ela.", Color(0.9, 0.88, 0.75)),
		_mat("naga_scale", "Escama de Naga", 32, "Turquesa, ainda molhada. Brilha no sol.", Color(0.3, 0.8, 0.75)),
		_mat("tide_essence", "Essência da Maré", 95, "Água que não escorre. A Mãe das Marés guardava no peito.", Color(0.4, 0.85, 0.95)),
		_mat("war_drum_hide", "Couro do Tambor de Guerra", 95, "O couro do tambor do Agitador-Mor. Ainda vibra.", Color(0.65, 0.35, 0.25)),
		# Ato II, Estepes de Cinza (35-40): missões das paralelas
		_mat("mammoth_tusk", "Presa de Mamute", 48, "Inteira, branca, mais velha que a Horda. Sai da cinza do Cemitério dos Mamutes.", Color(0.96, 0.93, 0.82)),
		_mat("caravan_goods", "Fardo da Caravana", 0, "Sal, couro e presa de troll. Encomenda da Mercadora Noêmia para o porto.", Color(0.74, 0.58, 0.38)),
		# Ato II, Estepes de Cinza (35-40): trolls, arqueiros de fogo, guerreiros orcs e os chefes dos acampamentos
		_mat("troll_hide", "Couro de Troll", 40, "Cinza-azulado e grosso. Um corte nele fecha sozinho por horas.", Color(0.5, 0.6, 0.72)),
		_mat("troll_tusk", "Presa de Troll", 46, "Dá um cabo que não racha, diz o Ferreiro Baltazar.", Color(0.86, 0.88, 0.8)),
		_mat("ember_feather", "Pena de Flecha de Fogo", 38, "Empenagem untada de piche. Ainda cheira a fumaça.", Color(0.95, 0.5, 0.2)),
		_mat("orc_steel", "Aço Negro Orc", 44, "Ferro escuro batido na Forja Negra de Kharzun.", Color(0.32, 0.32, 0.38)),
		_mat("rock_core", "Coração de Rocha", 110, "O Rei-da-Rocha tinha pedra onde devia ter coração. Ainda pulsa, devagar.", Color(0.5, 0.62, 0.8)),
		_mat("ember_essence", "Brasa do Mestre Besteiro", 110, "A brasa que acendia cada virote do Mestre Besteiro. Não apaga.", Color(1.0, 0.45, 0.15)),
		_mat("ghar_badge", "Insígnia de Ghar", 120, "O punho da Horda em ferro negro. Só um Senhor da Guerra usa.", Color(0.6, 0.12, 0.1)),
		# Ato II, Monte Kharzun (40-45): materiais dos monstros (receitas/aprimoramento 45 no WP10)
		_mat("dire_pelt", "Pele de Lobo Atroz", 58, "Cinza-chumbo, pesada como um cobertor de inverno. Os ginetes dormem embaixo dela.", Color(0.55, 0.55, 0.58)),
		_mat("salamander_scale", "Escama de Salamandra", 64, "Ainda morna. Na mão, solta um chiado quando cai água.", Color(1.0, 0.5, 0.2)),
		_mat("basalt_ore", "Basalto Rúnico", 70, "Pedra negra com fendas que brilham. Os anões juram que as runas são deles.", Color(0.28, 0.26, 0.3)),
		_mat("dwarf_steel", "Aço Anão", 76, "Liga clara e dura, batida por escravos anões na Forja Negra. Pertence a eles.", Color(0.72, 0.74, 0.8)),
		_mat("kharzun_ember_core", "Brasa de Kharzun", 120, "Carvão do coração da montanha. Arde dias sem apagar.", Color(1.0, 0.36, 0.1)),
		# troféus dos chefes de Kharzun (joias e capas 45, RecipesCatalog.KHARZUN_TROPHIES; caem dos chefes, WP7)
		_mat("ulgra_fang", "Presa de Ulgra", 160, "Presa do lobo de Ulgra, gasta de morder escudo. O Clã do Lobo jurava por ela.", Color(0.9, 0.86, 0.74)),
		_mat("basalt_heart", "Coração de Basalto", 160, "A pedra que Gorbash carregava no peito. Bate uma vez por minuto.", Color(0.36, 0.3, 0.34)),
		_mat("broken_hammer", "Martelo Partido", 160, "A cabeça do martelo de Kragmar, rachada ao meio. Ainda quente por dentro.", Color(0.25, 0.22, 0.24)),
		_mat("durgash_banner", "Estandarte de Durgash", 240, "O estandarte do Grão-Senhor. Rasgado, chamuscado, e ainda pesado de tanta guerra.", Color(0.62, 0.12, 0.1)),
		# Ato III, o Excesso (45-50; ato3-excesso-45-50 §3/§8): material comum e raro dos monstros (joias 48 e rank de skill no WP11)
		_mat("festim_ribbon", "Fita do Festim", 68, "Fita de seda que nunca desbota. Ainda cheira a vinho e a música velha.", Color(0.92, 0.58, 0.68)),
		_mat("weeping_porcelain", "Porcelana Chorosa", 140, "Caco de máscara branca com uma lágrima pintada. Está sempre um pouco úmido.", Color(0.94, 0.9, 0.84)),
		# troféu da raide (O Eco de Amarante, missão hx3_echo; D9): joias/capas 50 no WP11
		_mat("empty_crown", "Coroa Vazia", 400, "A coroa que flutuava sobre o Eco de Amarante. Fria, leve, e ninguém consegue usá-la por muito tempo.", Color(0.9, 0.82, 0.6)),
		# troféus dos chefes do Ato III (joias e capas 50, RecipesCatalog.LUMERIA_TROPHIES; caem dos chefes)
		_mat("varo_goblet", "Taça de Varo", 260, "A taça que o Anfitrião nunca deixava esvaziar. Agora está seca, e pesa mais assim.", Color(0.78, 0.18, 0.3)),
		_mat("countess_frame", "Moldura da Condessa", 260, "Moldura dourada sem espelho. Quem olha pelo vão ainda vê alguém olhando de volta.", Color(0.9, 0.74, 0.36)),
		_mat("broken_baton", "Batuta Partida", 260, "A batuta da Mestra Ressoa, quebrada no último compasso. Não marca mais tempo nenhum.", Color(0.36, 0.28, 0.5)),
		_mat("hostess_fan", "Leque da Anfitriã", 320, "O leque de Vessaline, de seda e lâminas finas. Fechado, parece um sorriso.", Color(0.95, 0.6, 0.72)),
		# Vinhas do Perfume: uva das Vinhas Sedentas (hx3_grapes) e base do Vinho Claro (alquimia)
		_mat("bitter_grapes", "Uvas Amargas", 22, "Cacho roxo das Vinhas Sedentas. Amarga como quem acorda depois da festa.", Color(0.48, 0.22, 0.55)),
		{"id": "letter_sealed", "name": "Carta Lacrada", "type": QST, "price": 0, "icon_color": Color(0.9, 0.85, 0.6), "description": "Carta do Ancião para a Capitã da guarda."},
		# ---------------- armas tier 0 (lv1) ----------------
		_weapon("sword_rusty", "Espada Enferrujada", "sword", 0, 8, 0, {"FOR": 3, "VIT": 1}, Color(0.6, 0.6, 0.6)),
		_weapon("axe_old", "Machado Velho", "axe2h", 0, 12, 0, {"FOR": 4}, Color(0.55, 0.45, 0.4)),
		_weapon("staff_novice", "Cajado de Noviço", "staff", 0, 2, 9, {"WILL": 3, "INT": 1}, Color(0.8, 0.7, 0.5)),
		_weapon("staff_oak", "Cajado de Carvalho", "staff", 0, 2, 8, {"INT": 2, "WILL": 2}, Color(0.5, 0.4, 0.25)),
		_weapon("bow_short", "Arco Curto", "bow", 0, 7, 0, {"AGI": 4}, Color(0.6, 0.45, 0.3)),
		_weapon("dagger_iron", "Adaga de Ferro", "dagger", 0, 6, 0, {"AGI": 3, "FOR": 1}, Color(0.7, 0.7, 0.75)),
		_weapon("wand_apprentice", "Varinha de Aprendiz", "wand", 0, 1, 10, {"INT": 4}, Color(0.6, 0.5, 0.9)),
		_weapon("scythe_bone", "Foice de Osso", "scythe", 0, 4, 8, {"INT": 3, "WILL": 1}, Color(0.85, 0.85, 0.75)),
		_weapon("shield_wood", "Escudo de Madeira", "shield", 0, 0, 0, {"FOR": 1, "VIT": 2}, Color(0.5, 0.35, 0.2)),
		# ---------------- armas tier 1 (lv8) — craft no ferreiro ----------------
		_weapon("sword_iron", "Espada de Ferro", "sword", 1, 16, 0, {"FOR": 6, "VIT": 2}, Color(0.75, 0.75, 0.8)),
		_weapon("axe_iron", "Machado de Ferro", "axe2h", 1, 24, 0, {"FOR": 8, "VIT": 1}, Color(0.7, 0.65, 0.6)),
		_weapon("staff_silk", "Cajado de Seda", "staff", 1, 3, 18, {"WILL": 5, "INT": 4}, Color(0.9, 0.85, 0.95)),
		_weapon("bow_hunter", "Arco do Caçador", "bow", 1, 15, 0, {"AGI": 8, "FOR": 1}, Color(0.4, 0.55, 0.3)),
		_weapon("dagger_fang", "Adaga Presa", "dagger", 1, 12, 0, {"AGI": 7, "FOR": 2}, Color(0.9, 0.85, 0.7)),
		_weapon("wand_silk", "Varinha de Seda", "wand", 1, 2, 20, {"INT": 8, "WILL": 1}, Color(0.7, 0.5, 1)),
		_weapon("scythe_iron", "Foice de Ferro", "scythe", 1, 8, 17, {"INT": 6, "WILL": 3}, Color(0.6, 0.6, 0.65)),
		_weapon("shield_iron", "Escudo de Ferro", "shield", 1, 0, 0, {"FOR": 3, "VIT": 5}, Color(0.6, 0.6, 0.65)),
		# ---------------- armas tier 2 (lv16) ----------------
		_weapon("sword_ent", "Espada de Ent", "sword", 2, 28, 0, {"FOR": 10, "VIT": 5, "AGI": 2}, Color(0.4, 0.6, 0.3)),
		_weapon("axe_bone", "Machado de Osso", "axe2h", 2, 40, 0, {"FOR": 14, "AGI": 2}, Color(0.9, 0.9, 0.8)),
		_weapon("staff_spectral", "Cajado Espectral", "staff", 2, 5, 32, {"WILL": 9, "INT": 8}, Color(0.6, 0.9, 1)),
		_weapon("bow_ent", "Arco de Ent", "bow", 2, 26, 0, {"AGI": 14, "VIT": 2}, Color(0.35, 0.5, 0.25)),
		_weapon("dagger_spectral", "Adaga Espectral", "dagger", 2, 21, 0, {"AGI": 12, "INT": 3, "FOR": 2}, Color(0.7, 0.95, 1)),
		_weapon("wand_spectral", "Varinha Espectral", "wand", 2, 3, 36, {"INT": 15, "WILL": 2}, Color(0.6, 0.8, 1)),
		_weapon("scythe_spectral", "Foice Espectral", "scythe", 2, 12, 30, {"INT": 11, "WILL": 6}, Color(0.5, 0.9, 0.9)),
		_weapon("shield_bone", "Escudo de Osso", "shield", 2, 0, 0, {"FOR": 6, "VIT": 9}, Color(0.9, 0.9, 0.85)),
		# ---------------- armas tier 3 (lv24) — boss ----------------
		_weapon("sword_dragon", "Espada Dracônica", "sword", 3, 44, 0, {"FOR": 16, "VIT": 8, "AGI": 4}, Color(0.9, 0.3, 0.3)),
		_weapon("axe_golem", "Machado do Golem", "axe2h", 3, 62, 0, {"FOR": 22, "VIT": 4}, Color(0.9, 0.6, 0.2)),
		_weapon("staff_dragon", "Cajado Dracônico", "staff", 3, 8, 50, {"WILL": 14, "INT": 13}, Color(0.9, 0.4, 0.4)),
		_weapon("bow_dragon", "Arco Dracônico", "bow", 3, 42, 0, {"AGI": 22, "FOR": 3}, Color(0.8, 0.3, 0.3)),
		_weapon("dagger_golem", "Adaga do Golem", "dagger", 3, 34, 0, {"AGI": 19, "FOR": 4, "INT": 3}, Color(0.9, 0.65, 0.3)),
		_weapon("wand_dragon", "Varinha Dracônica", "wand", 3, 5, 56, {"INT": 23, "WILL": 3}, Color(1, 0.4, 0.5)),
		_weapon("scythe_golem", "Foice do Golem", "scythe", 3, 18, 46, {"INT": 17, "WILL": 9}, Color(0.95, 0.6, 0.25)),
		_weapon("shield_dragon", "Escudo Dracônico", "shield", 3, 0, 0, {"FOR": 10, "VIT": 14}, Color(0.85, 0.3, 0.3)),
		# ---------------- armaduras ----------------
		_armor("armor_leather", "Armadura de Couro", S_B, 0, 4, 2, {"VIT": 2, "AGI": 1}, Color(0.55, 0.4, 0.25)),
		_armor("robe_cloth", "Túnica de Pano", S_B, 0, 2, 4, {"WILL": 2, "INT": 1}, Color(0.6, 0.6, 0.85)),
		_armor("armor_wolf", "Armadura de Lobo", S_B, 1, 10, 4, {"VIT": 5, "FOR": 2}, Color(0.5, 0.4, 0.3)),
		_armor("robe_silk", "Túnica de Seda", S_B, 1, 5, 10, {"WILL": 4, "INT": 3}, Color(0.85, 0.8, 0.95)),
		_armor("armor_ent", "Armadura de Ent", S_B, 2, 18, 8, {"VIT": 9, "FOR": 3, "AGI": 2}, Color(0.4, 0.55, 0.3)),
		_armor("robe_spectral", "Túnica Espectral", S_B, 2, 8, 18, {"WILL": 8, "INT": 6}, Color(0.6, 0.85, 1)),
		_armor("armor_dragon", "Armadura Dracônica", S_B, 3, 28, 12, {"VIT": 14, "FOR": 5, "AGI": 3}, Color(0.85, 0.3, 0.3)),
		_armor("robe_dragon", "Túnica Dracônica", S_B, 3, 12, 28, {"WILL": 12, "INT": 10}, Color(1, 0.5, 0.5)),
		_armor("cap_leather", "Gorro de Couro", S_H, 0, 2, 1, {"VIT": 1}, Color(0.55, 0.4, 0.25)),
		_armor("helm_iron", "Elmo de Ferro", S_H, 1, 6, 2, {"VIT": 3, "FOR": 1}, Color(0.65, 0.65, 0.7)),
		_armor("hood_silk", "Capuz de Seda", S_H, 1, 2, 6, {"INT": 2, "WILL": 2}, Color(0.85, 0.8, 0.95)),
		_armor("helm_bone", "Elmo de Osso", S_H, 2, 10, 5, {"VIT": 5, "FOR": 3}, Color(0.9, 0.9, 0.8)),
		_armor("crown_spectral", "Coroa Espectral", S_H, 2, 4, 11, {"INT": 5, "WILL": 4}, Color(0.6, 0.9, 1)),
		_armor("boots_leather", "Botas de Couro", S_F, 0, 1, 1, {"AGI": 1}, Color(0.5, 0.35, 0.2)),
		_armor("boots_wolf", "Botas de Lobo", S_F, 1, 4, 2, {"AGI": 3, "VIT": 1}, Color(0.5, 0.4, 0.3)),
		_armor("boots_ent", "Botas de Ent", S_F, 2, 8, 4, {"AGI": 5, "VIT": 3}, Color(0.4, 0.55, 0.3)),
		_armor("ring_gel", "Anel de Gel", S_R, 0, 0, 0, {"WILL": 2}, Color(0.4, 0.9, 0.5)),
		_armor("ring_captain", "Anel do Capitão", S_R, 1, 2, 0, {"FOR": 3, "VIT": 3}, Color(0.9, 0.82, 0.6)),
		_armor("amulet_widow", "Lágrima da Viúva", S_M, 1, 0, 3, {"INT": 4, "WILL": 3}, Color(0.7, 0.8, 1.0)),
		_armor("ring_vargo", "Selo de Vargo", S_R, 1, 0, 2, {"INT": 4, "AGI": 3}, Color(0.55, 0.35, 0.8)),
		_armor("cape_vargo", "Manto do Conde", S_C, 1, 4, 4, {"VIT": 4, "WILL": 3}, Color(0.4, 0.22, 0.55)),
		_armor("amulet_tusk", "Amuleto de Presa", S_M, 1, 0, 0, {"FOR": 3, "AGI": 2}, Color(0.95, 0.9, 0.8)),
		_armor("amulet_silk", "Amuleto de Seda", S_M, 1, 0, 0, {"INT": 3, "WILL": 2}, Color(0.9, 0.9, 0.95)),
		_armor("ring_spectral", "Anel Espectral", S_R, 2, 0, 0, {"INT": 4, "AGI": 4}, Color(0.6, 0.9, 1)),
		_armor("amulet_golem", "Amuleto do Golem", S_M, 3, 0, 0, {"FOR": 6, "VIT": 6, "WILL": 4}, Color(0.9, 0.6, 0.2)),
	]
	L.append_array(_starter_items())
	var out: Array = []
	for d in L:
		var it := _mk(d)
		if SHIELD_LOOK.has(it.id):
			it.shield_style = SHIELD_LOOK[it.id]
			it.icon = it.id
		if it.is_equipment() and it.slot in [S_H, S_B, S_F] and it.armor_style == "":
			it.armor_style = _style_from_id(it.id)
		if it.is_equipment() and it.slot == S_C:
			it.armor_style = "cape"
		if it.id in UNIQUE_ACCESSORIES:
			GearCatalog.unique_acc(it)      # atributos escritos = proporção; total pela curva dos acessórios
		out.append(it)
	return out

## Visual das armaduras escritas à mão (o jogo mostra a peça do kit desse estilo).
static func _style_from_id(id: String) -> String:
	for k in ["robe", "hood", "crown", "silk"]:
		if k in id:
			return "cloth"
	for k in ["helm", "armor_ent", "armor_dragon"]:
		if k in id:
			return "plate"
	return "leather"
