class_name ItemsCatalog
extends RefCounted
## Materiais, consumíveis e equipamentos. Equipamento = pontos de atributo.
## rarity 0..3 também é o "tier" (lv 1 / 8 / 16 / 24).

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
	for k in d:
		it.set(k, d[k])
	return it

static func _mat(id: String, name: String, price: int, desc: String, color: Color) -> Dictionary:
	return {"id": id, "name": name, "type": MAT, "price": price, "description": desc, "icon_color": color}

static func _weapon(id: String, name: String, wtype: String, tier: int, atk: float, matk: float, attrs: Dictionary, color: Color, classes: Array = []) -> Dictionary:
	var cr: Array[String] = []
	for c in classes:
		cr.append(c)
	return {"id": id, "name": name, "type": EQ, "slot": S_O if wtype == "shield" else S_W, "weapon_type": wtype, "rarity": tier, "level_req": [1, 8, 16, 24][tier],
		"atk": atk, "matk": matk, "attributes": attrs, "icon_color": color, "price": [40, 220, 700, 1800][tier], "stack_max": 1, "class_restriction": cr}

static func _armor(id: String, name: String, slot: int, tier: int, def: float, mdef: float, attrs: Dictionary, color: Color) -> Dictionary:
	return {"id": id, "name": name, "type": EQ, "slot": slot, "rarity": tier, "level_req": [1, 8, 16, 24][tier],
		"def": def, "mdef": mdef, "attributes": attrs, "icon_color": color, "price": [30, 180, 600, 1500][tier], "stack_max": 1}

static func build() -> Array:
	var L := [
		# ---------------- consumíveis ----------------
		{"id": "potion_hp_s", "name": "Poção de Vida (P)", "type": CON, "price": 15, "icon_color": Color(1, 0.35, 0.35), "description": "Recupera 60 HP.", "consume": {"heal": 60}, "consume_cooldown": 4.0},
		{"id": "potion_hp_m", "name": "Poção de Vida (M)", "type": CON, "price": 45, "icon_color": Color(1, 0.2, 0.2), "description": "Recupera 35% do HP.", "consume": {"heal_pct": 0.35}, "consume_cooldown": 4.0, "level_req": 8},
		{"id": "potion_mp_s", "name": "Poção de Mana (P)", "type": CON, "price": 18, "icon_color": Color(0.35, 0.5, 1), "description": "Recupera 40 MP.", "consume": {"mana": 40}, "consume_cooldown": 4.0},
		{"id": "potion_mp_m", "name": "Poção de Mana (M)", "type": CON, "price": 50, "icon_color": Color(0.2, 0.35, 1), "description": "Recupera 35% do MP.", "consume": {"mana_pct": 0.35}, "consume_cooldown": 4.0, "level_req": 8},
		{"id": "elixir_might", "name": "Elixir da Força", "type": CON, "price": 90, "icon_color": Color(1, 0.7, 0.2), "description": "+20% ATK/MATK por 45s.", "consume": {"buff": {"id": "elixir", "duration": 45, "atk_pct": 20, "matk_pct": 20}}, "consume_cooldown": 6.0},
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
		# bolsas ampliadas (alquimista costura): +Balance.BAG_STEP espaços cada, na ordem I -> IV
		{"id": "bag_t0", "name": "Bolsa Ampliada I", "type": CON, "price": 40, "icon_color": Color(0.62, 0.45, 0.3), "description": "Use: +8 espaços na bolsa (1ª ampliação).", "consume": {"bag": 0}, "stack_max": 1},
		{"id": "bag_t1", "name": "Bolsa Ampliada II", "type": CON, "price": 120, "icon_color": Color(0.5, 0.55, 0.35), "description": "Use: +8 espaços na bolsa (2ª ampliação).", "consume": {"bag": 1}, "stack_max": 1},
		{"id": "bag_t2", "name": "Bolsa Ampliada III", "type": CON, "price": 260, "icon_color": Color(0.4, 0.45, 0.7), "description": "Use: +8 espaços na bolsa (3ª ampliação).", "consume": {"bag": 2}, "stack_max": 1},
		{"id": "bag_t3", "name": "Bolsa Ampliada IV", "type": CON, "price": 500, "icon_color": Color(0.7, 0.45, 0.75), "description": "Use: +8 espaços na bolsa (última ampliação).", "consume": {"bag": 3}, "stack_max": 1},
		_mat("wolf_pelt", "Pele de Lobo", 9, "Couro resistente.", Color(0.55, 0.45, 0.35)),
		_mat("boar_tusk", "Presa de Javali", 10, "Afiada. Boa para adornos.", Color(0.95, 0.9, 0.8)),
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
		_mat("elf_steel", "Aço Élfico", 28, "Leve como pena. Aprimora peças da Glória (+1 a +5) no ferreiro.", Color(0.7, 0.9, 0.75)),
		_mat("mother_sap", "Seiva da Árvore-Mãe", 70, "Dourada e morna. Aprimora peças da Glória (+6 a +9) no ferreiro.", Color(0.95, 0.8, 0.3)),
		_mat("heartwood", "Cerne de Trent", 24, "O coração de madeira de um Trent Ancião.", Color(0.5, 0.36, 0.2)),
		_mat("griffin_feather", "Pena de Grifo", 18, "Dourada na ponta. Flecheiros pagam bem.", Color(0.95, 0.85, 0.55)),
		_mat("golem_core", "Núcleo de Golem", 60, "Pulsa com magia antiga.", Color(0.9, 0.6, 0.2)),
		_mat("dragon_scale", "Escama de Dragonete", 80, "Rara. Quase indestrutível.", Color(0.8, 0.2, 0.3)),
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
		_armor("cape_vargo", "Manto do Conde", S_C, 1, 5, 5, {"VIT": 4, "WILL": 3}, Color(0.4, 0.22, 0.55)),
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
