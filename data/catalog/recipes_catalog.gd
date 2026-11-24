class_name RecipesCatalog
extends RefCounted

static func _mk(d: Dictionary) -> RecipeDef:
	var r := RecipeDef.new()
	CatalogUtil.fill(r, d)
	return r

static func _r(result: String, count: int, station: String, lv: int, gold: int, ing: Dictionary) -> Dictionary:
	return {"id": "rec_" + result, "result_item": result, "result_count": count, "station": station, "level_req": lv, "gold_cost": gold, "ingredients": ing}

static func build() -> Array:
	var L := [
		# ---- alquimia ----
		_r("potion_hp_s", 2, "alchemy", 1, 0, {"herb_green": 1, "slime_gel": 1}),
		_r("potion_mp_s", 2, "alchemy", 1, 0, {"herb_blue": 1, "slime_gel": 1}),
		_r("potion_hp_m", 1, "alchemy", 8, 10, {"herb_green": 3, "spider_silk": 1}),
		_r("potion_mp_m", 1, "alchemy", 8, 10, {"herb_blue": 3, "spider_silk": 1}),
		_r("elixir_might", 1, "alchemy", 10, 40, {"boar_tusk": 2, "herb_green": 2, "wolf_pelt": 1}),
		_r("elixir_stone", 1, "alchemy", 14, 40, {"ent_bark": 2, "iron_ore": 1, "herb_blue": 1}),
		_r("clear_wine", 2, "alchemy", 46, 120, {"bitter_grapes": 3, "festim_ribbon": 1}),     # Vinho Claro (Destiladora, hx3_vd_wine)
		_r("ring_gel", 1, "alchemy", 3, 20, {"slime_gel": 8, "herb_blue": 2}),
		_r("amulet_silk", 1, "alchemy", 10, 60, {"spider_silk": 6, "herb_blue": 3}),
		_r("ring_spectral", 1, "alchemy", 18, 150, {"ghost_essence": 4, "spider_silk": 3}),
		# ---- ferraria ----
		_r("amulet_tusk", 1, "smith", 8, 60, {"boar_tusk": 5, "iron_ore": 1}),
		_r("amulet_golem", 1, "smith", 26, 500, {"golem_core": 2, "dragon_scale": 1}),
	]
	L.append_array(gear_recipes())
	L.append_array(kharzun_recipes())
	L.append_array(lumeria_recipes())
	var out: Array = []
	for d in L:
		out.append(_mk(d))
	return out

## Joias e capas de cada tier e tema (GearCatalog.THEME_PIECES x THEMES): anel e amuleto no ferreiro, capa na alquimista.
## Material principal e secundário do tier (das zonas daquele nível) + um do tema. Bolsas Ampliadas também saem daqui.
## Um tier por Balance.COMMON_TIER_LEVELS (1, 8, 16, 24 e, no Ato II, 32 Costa Partida e 40 Estepes de Cinza; Ato III 48); há check.
## Tier 48 (Ato III, GDD ato3 §3/§8): Fita do Festim / Porcelana Chorosa; tema = fita (Guerreiro), Uvas Amargas (Caçador), erva azul (Sábio).
const JEWEL_MATS := [["iron_ore", "crab_shell"], ["spider_silk", "grave_dust"], ["bone_shard", "bandit_badge"], ["star_ore", "ancient_relic"],
	["orc_tusk", "goblin_fang"], ["orc_steel", "troll_tusk"], ["festim_ribbon", "weeping_porcelain"]]
const CAPE_MATS := [["wolf_pelt", "slime_gel"], ["spider_silk", "wolf_pelt"], ["ent_bark", "forest_mushroom"], ["ghost_essence", "ancient_relic"],
	["rider_pelt", "horde_badge"], ["troll_hide", "horde_badge"], ["festim_ribbon", "weeping_porcelain"]]
const THEME_MAT := {"guerreiro": ["boar_tusk", "boar_tusk", "bandit_badge", "golem_core", "horde_badge", "orc_tusk", "festim_ribbon"],
	"cacador": ["wolf_pelt", "spider_silk", "ent_bark", "bone_shard", "rider_pelt", "ember_feather", "bitter_grapes"],
	"sabio": ["herb_blue", "herb_blue", "forest_mushroom", "ghost_essence", "naga_scale", "naga_scale", "herb_blue"]}
const BAG_RECIPES := [[3, 40, {"wolf_pelt": 4, "slime_gel": 4}], [10, 150, {"spider_silk": 6, "wolf_pelt": 4}],
	[16, 300, {"ent_bark": 6, "bandit_badge": 4}], [24, 600, {"ghost_essence": 5, "ancient_relic": 3}]]

## Joias e capas 45 (Monte Kharzun, GearCatalog.kharzun_jewels): materiais da montanha + um troféu de chefe por tema
## (capas pedem também o Estandarte de Durgash). Troféu -> chefe que o solta (loot do chefe: WP7).
const KHARZUN_TROPHIES := {"broken_hammer": "boss_kragmar", "ulgra_fang": "boss_ulgra", "basalt_heart": "boss_gorbash", "durgash_banner": "boss_durgash"}
const KHARZUN_THEME_TROPHY := {"guerreiro": "broken_hammer", "cacador": "ulgra_fang", "sabio": "basalt_heart"}
const KHARZUN_JEWEL_MATS := {"dwarf_steel": 8, "basalt_ore": 6, "kharzun_ember_core": 1}
const KHARZUN_CAPE_MATS := {"dire_pelt": 8, "salamander_scale": 6, "durgash_banner": 1}

static func kharzun_recipes() -> Array:
	var out: Array = []
	for piece in GearCatalog.THEME_PIECES:
		for theme in GearCatalog.THEMES:
			var ing: Dictionary = (KHARZUN_CAPE_MATS if piece == "cape" else KHARZUN_JEWEL_MATS).duplicate()
			ing[KHARZUN_THEME_TROPHY[theme]] = 1
			out.append(_r("%s_%s_k45" % [piece, theme], 1, "alchemy" if piece == "cape" else "smith", Balance.KHARZUN_JEWEL_LEVEL,
				Balance.KHARZUN_JEWEL_GOLD, ing))
	return out

## Joias e capas 50 (Lumeria, GearCatalog.lumeria_jewels; GDD ato3 §8): Fitas + Porcelanas + o troféu do tema; a capa pede
## também o Leque da Anfitriã e o amuleto a Coroa Vazia (raide). Troféu -> chefe que o solta.
const LUMERIA_TROPHIES := {"varo_goblet": "boss_varo", "countess_frame": "boss_countess", "broken_baton": "boss_ressoa",
	"hostess_fan": "vessaline", "empty_crown": "boss_sylvare_echo"}
const LUMERIA_THEME_TROPHY := {"guerreiro": "varo_goblet", "cacador": "countess_frame", "sabio": "broken_baton"}
const LUMERIA_PIECE_TROPHY := {"cape": "hostess_fan", "amulet": "empty_crown"}

static func lumeria_recipes() -> Array:
	var out: Array = []
	for piece in GearCatalog.THEME_PIECES:
		for theme in GearCatalog.THEMES:
			var ing := {"festim_ribbon": Balance.LUMERIA_JEWEL_RIBBON, "weeping_porcelain": Balance.LUMERIA_JEWEL_PORCELAIN}
			ing[LUMERIA_THEME_TROPHY[theme]] = 1
			if LUMERIA_PIECE_TROPHY.has(piece):
				ing[LUMERIA_PIECE_TROPHY[piece]] = 1
			out.append(_r("%s_%s_l50" % [piece, theme], 1, "alchemy" if piece == "cape" else "smith", Balance.LUMERIA_JEWEL_LEVEL,
				Balance.LUMERIA_JEWEL_GOLD, ing))
	return out

static func gear_recipes() -> Array:
	var out: Array = []
	for tier in range(Balance.COMMON_TIER_LEVELS.size()):
		for piece in GearCatalog.THEME_PIECES:
			var mats: Array = CAPE_MATS[tier] if piece == "cape" else JEWEL_MATS[tier]
			for theme in GearCatalog.THEMES:
				var ing := {mats[0]: 3 + tier, mats[1]: 2 + tier}
				var tm: String = THEME_MAT[theme][tier]
				ing[tm] = int(ing.get(tm, 0)) + 2
				out.append(_r("%s_%s_t%d" % [piece, theme, tier], 1, "alchemy" if piece == "cape" else "smith", int(Balance.COMMON_TIER_LEVELS[tier]),
					20 * (tier + 1) * (tier + 1), ing))
	for i in range(BAG_RECIPES.size()):
		var b: Array = BAG_RECIPES[i]
		out.append(_r("bag_t%d" % i, 1, "alchemy", int(b[0]), int(b[1]), b[2]))
	return out
