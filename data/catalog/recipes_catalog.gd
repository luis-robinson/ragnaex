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
		_r("ring_gel", 1, "alchemy", 3, 20, {"slime_gel": 8, "herb_blue": 2}),
		_r("amulet_silk", 1, "alchemy", 10, 60, {"spider_silk": 6, "herb_blue": 3}),
		_r("ring_spectral", 1, "alchemy", 18, 150, {"ghost_essence": 4, "spider_silk": 3}),
		# ---- ferraria ----
		_r("amulet_tusk", 1, "smith", 8, 60, {"boar_tusk": 5, "iron_ore": 1}),
		_r("amulet_golem", 1, "smith", 26, 500, {"golem_core": 2, "dragon_scale": 1}),
	]
	L.append_array(gear_recipes())
	var out: Array = []
	for d in L:
		out.append(_mk(d))
	return out

## Joias e capas de cada tier e tema (GearCatalog.THEME_PIECES x THEMES): anel e amuleto no ferreiro, capa na alquimista.
## Material principal e secundário do tier (das zonas daquele nível) + um do tema. Bolsas Ampliadas também saem daqui.
const TIER_LEVELS := [1, 8, 16, 24]
const JEWEL_MATS := [["iron_ore", "crab_shell"], ["spider_silk", "grave_dust"], ["bone_shard", "bandit_badge"], ["star_ore", "ancient_relic"]]
const CAPE_MATS := [["wolf_pelt", "slime_gel"], ["spider_silk", "wolf_pelt"], ["ent_bark", "forest_mushroom"], ["ghost_essence", "ancient_relic"]]
const THEME_MAT := {"guerreiro": ["boar_tusk", "boar_tusk", "bandit_badge", "golem_core"], "cacador": ["wolf_pelt", "spider_silk", "ent_bark", "bone_shard"],
	"sabio": ["herb_blue", "herb_blue", "forest_mushroom", "ghost_essence"]}
const BAG_RECIPES := [[3, 40, {"wolf_pelt": 4, "slime_gel": 4}], [10, 150, {"spider_silk": 6, "wolf_pelt": 4}],
	[16, 300, {"ent_bark": 6, "bandit_badge": 4}], [24, 600, {"ghost_essence": 5, "ancient_relic": 3}]]

static func gear_recipes() -> Array:
	var out: Array = []
	for tier in range(TIER_LEVELS.size()):
		for piece in GearCatalog.THEME_PIECES:
			var mats: Array = CAPE_MATS[tier] if piece == "cape" else JEWEL_MATS[tier]
			for theme in GearCatalog.THEMES:
				var ing := {mats[0]: 3 + tier, mats[1]: 2 + tier}
				var tm: String = THEME_MAT[theme][tier]
				ing[tm] = int(ing.get(tm, 0)) + 2
				out.append(_r("%s_%s_t%d" % [piece, theme, tier], 1, "alchemy" if piece == "cape" else "smith", TIER_LEVELS[tier],
					20 * (tier + 1) * (tier + 1), ing))
	for i in range(BAG_RECIPES.size()):
		var b: Array = BAG_RECIPES[i]
		out.append(_r("bag_t%d" % i, 1, "alchemy", int(b[0]), int(b[1]), b[2]))
	return out
