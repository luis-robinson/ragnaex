class_name CardsCatalog
extends RefCounted
## Cartas de Monstro dos Atos I e II (GDD design/gdd/cartas.md, listas em cartas-ato1.md e cartas-ato2.md). Números SÓ em Balance.CARD_*.

## Comuns: [monstro, encaixe, efeito, família do efeito ("" = não usa), grupo]
const COMMONS := [
	["slime", "accessory", "mp_on_kill", "", "aldara_fields"],
	["slime_blue", "head", "mp_regen_combat", "", "aldara_fields"],
	["boar", "chest", "hp_pct", "", "aldara_fields"],
	["crab", "offhand", "family_def", "beast", "crab_beach"],
	["crab_sand", "boots", "speed_pct", "", "crab_beach"],
	["crab_hermit", "chest", "def_pct", "", "crab_beach"],
	["wasp", "weapon", "proc_poison", "", "hollow_swarm"],
	["wasp_soldier", "head", "cc_resist_pct", "", "hollow_swarm"],
	["hive", "accessory", "gold_pct", "", "hollow_swarm"],
	["bear_cub", "boots", "dash_pct", "", "bears"],
	["bear", "chest", "hp_pct", "", "bears"],
	["grove_bear", "weapon", "family_dmg", "beast", "bears"],
	["wolf", "boots", "speed_pct", "", "wolf_pack"],
	["grove_wolf", "weapon", "crit", "", "wolf_pack"],
	["rot_wolf", "accessory", "xp_pct", "", "wolf_pack"],
	["zombie", "chest", "heal_taken_pct", "", "catacomb_dead"],
	["bone_recruit", "offhand", "family_def", "undead", "catacomb_dead"],
	["bone_archer", "weapon", "family_dmg", "undead", "catacomb_dead"],
	["wraith", "head", "mp_regen_combat", "", "wraiths"],
	["ghost", "boots", "evasion", "", "wraiths"],
	["rest_thaw_wraith", "weapon", "proc_slow", "", "wraiths"],
	["golem_moss", "chest", "def_pct", "", "quarry_golems"],
	["golem_stone", "offhand", "thorns", "", "quarry_golems"],
	["golem_shard", "weapon", "family_dmg", "construct", "quarry_golems"],
	["bandit_footpad", "boots", "dash_pct", "", "road_gang"],
	["bandit_thief", "accessory", "gold_pct", "", "road_gang"],
	["bandit_archer", "weapon", "crit", "", "road_gang"],
	["bandit", "weapon", "family_dmg", "humanoid", "outlaws"],
	["bandit_outlaw", "head", "cc_resist_pct", "", "outlaws"],
	["marsh_smuggler", "accessory", "xp_pct", "", "outlaws"],
	["spider", "weapon", "proc_poison", "", "spiders"],
	["marsh_spider", "boots", "evasion", "", "spiders"],
	["sap_spider", "offhand", "family_def", "insect", "spiders"],
	["trent_young", "chest", "hp_pct", "", "woken_grove"],
	["ent", "offhand", "thorns", "", "woken_grove"],
	["trent", "head", "cc_resist_pct", "", "woken_grove"],
	["elf_lynx", "boots", "speed_pct", "", "elf_beasts"],
	["griffin", "weapon", "crit", "", "elf_beasts"],
	["griffin_raider", "accessory", "mp_on_kill", "", "elf_beasts"],
	["marsh_leech", "accessory", "lifesteal", "", "marsh"],
	["bog_toad", "chest", "heal_taken_pct", "", "marsh"],
	["web_weaver", "weapon", "proc_slow", "", "marsh"],
	["shaman_shifter", "head", "mp_regen_combat", "", "grove_circle"],
	["shaman_caller", "accessory", "mp_on_kill", "", "grove_circle"],
	["elf_tender", "chest", "hp_pct", "", "grove_circle"],
	["elf_raider", "weapon", "family_dmg", "elf", "elf_scouts"],
	["elf_raider_archer", "offhand", "family_def", "elf", "elf_scouts"],
	["elf_raider_mage", "head", "cc_resist_pct", "", "elf_scouts"],
	["elf_archer", "weapon", "crit", "", "tree_guard"],
	["elf_warrior", "chest", "def_pct", "", "tree_guard"],
	["elf_sergeant", "offhand", "block", "", "tree_guard"],
	["ghoul", "weapon", "proc_slow", "", "ghouls"],
	["rot_ghoul", "accessory", "lifesteal", "", "ghouls"],
	["rest_ghoul", "head", "cc_resist_pct", "", "ghouls"],
	["larva", "accessory", "xp_pct", "", "rot"],
	["rot_zombie", "chest", "heal_taken_pct", "", "rot"],
	["rot_bear", "offhand", "family_def", "undead", "rot"],
	["skel_archer", "weapon", "family_dmg", "undead", "bone_legion"],
	["skeleton", "chest", "def_pct", "", "bone_legion"],
	["skel_guard", "offhand", "block", "", "bone_legion"],
	["rest_bones", "boots", "dash_pct", "", "masterless"],
	["rest_bone_archer", "weapon", "crit", "", "masterless"],
	["rest_lost_adept", "head", "mp_regen_combat", "", "masterless"],
	["cultist", "head", "cc_resist_pct", "", "lich_cult"],
	["citadel_adept", "accessory", "mp_on_kill", "", "lich_cult"],
	["citadel_horror", "offhand", "family_def", "undead", "lich_cult"],
	["night_digger", "boots", "speed_pct", "", "gravediggers"],
	["grave_hauler", "chest", "hp_pct", "", "gravediggers"],
	["carrion_crow", "accessory", "gold_pct", "", "gravediggers"],
	["oath_sworn", "chest", "def_pct", "", "oathsworn"],
	["oath_archer", "weapon", "family_dmg", "undead", "oathsworn"],
	["vel_shade", "boots", "evasion", "", "oathsworn"],
	["archive_copyist", "head", "xp_pct", "", "velthar_archive"],
	["archive_warden", "offhand", "family_def", "construct", "velthar_archive"],
	["ink_wraith", "weapon", "proc_slow", "", "velthar_archive"],
	# Ato II (cartas-ato2.md, G26-G31)
	["goblin_lancer", "boots", "speed_pct", "", "goblin_caves"],
	["goblin_impaler", "weapon", "family_dmg", "horde", "goblin_caves"],
	["goblin_agitator", "head", "cc_resist_pct", "", "goblin_caves"],
	["wolf_rider", "boots", "dash_pct", "", "riders"],
	["wolf_raider", "accessory", "gold_pct", "", "riders"],
	["dire_wolf_rider", "weapon", "proc_slow", "", "riders"],
	["naga_tide", "head", "mp_regen_combat", "", "broken_coast"],
	["naga_warrior", "offhand", "thorns", "", "broken_coast"],
	["orc_recruit", "chest", "hp_pct", "", "broken_coast"],
	["troll_whelp", "chest", "heal_taken_pct", "", "trolls"],
	["troll", "weapon", "regen_cut", "", "trolls"],
	["troll_thrower", "offhand", "family_def", "horde", "trolls"],
	["orc_archer", "weapon", "crit", "", "horde_archers"],
	["orc_crossbow", "offhand", "ranged_def", "", "horde_archers"],
	["orc_fire_archer", "accessory", "mp_on_kill", "", "horde_archers"],
	["dire_wolf", "boots", "evasion", "", "kharzun_slopes"],
	["goblin_assassin", "weapon", "proc_poison", "", "kharzun_slopes"],
	["lava_salamander", "chest", "def_pct", "", "kharzun_slopes"],
]

## Núcleos: [monstro, encaixe, efeito]. Chefe ou monstro comum (o MonsterDef diz).
const CORES := [
	["boar_brute", "chest", "hp_pct"], ["crab_king", "offhand", "thorns"], ["bear_mother", "chest", "low_dr"],
	["boar_king", "weapon", "atk_pct"], ["bone_captain", "head", "cc_resist_pct"], ["slime_king", "accessory", "kill_heal"],
	["wailing_widow", "weapon", "dot_pct"], ["count_vargo", "weapon", "lifesteal"], ["golem_ancient", "chest", "dr_pct"],
	["crystal_warden", "head", "crit"], ["quarry_heart", "offhand", "block"], ["bog_mother", "accessory", "heal_taken_pct"],
	["boss_archdruid", "head", "summon_time_pct"], ["boss_sap_mother", "accessory", "heal_pct"], ["spider_queen", "weapon", "proc_stun"],
	["elf_captain_hunter", "boots", "speed_pct"], ["elf_captain_sky", "offhand", "pet_pct"], ["elf_captain_sap", "head", "mp_cost_pct"],
	["elf_king", "weapon", "crit_dmg_pct"], ["bandit_chief", "accessory", "gold_pct"], ["ghoul_giant", "chest", "low_leech"],
	["death_knight", "offhand", "threat_pct"], ["fallen_bearer", "head", "buff_pct"], ["frost_mage", "weapon", "frost_pct"],
	["crypt_lord", "accessory", "mp_regen_combat"], ["boss_azhar_scribe", "head", "cdr"], ["lich_king", "weapon", "matk_pct"],
	["dragonling", "accessory", "fire_pct"],
	["sap_sprout", "boots", "evasion"], ["elf_warden", "chest", "aspd_pct"], ["rest_bear", "chest", "hp_pct"],
	["tower_bat", "weapon", "backstab"], ["golem", "chest", "def_pct"], ["citadel_knight", "offhand", "dr_pct"],
	# Chefes de Mundo do Ato I (momentos-do-mundo §10; Ato II/III depois): presa que atordoa, galhada de espinhos, couro de pedra
	["ancestral_boar", "weapon", "proc_stun"], ["ancient_elk", "offhand", "thorns"], ["ruins_basilisk", "chest", "dr_pct"],
	# Ato II (cartas-ato2.md): chefes de campo/masmorra/fortaleza/cidadela/raide e de mundo
	["boss_tide_mother", "accessory", "heal_pct"], ["boss_agitator_lord", "weapon", "storm_pct"], ["boss_troll_king", "chest", "hp_pct"],
	["boss_crossbow_master", "weapon", "crit_dmg_pct"], ["boss_ghar", "offhand", "thorns"], ["boss_dire_mother", "head", "pet_pct"],
	["boss_shazka", "accessory", "dot_pct"], ["boss_ulgra", "boots", "speed_pct"], ["boss_gorbash", "accessory", "kill_heal"],
	["boss_kragmar", "weapon", "fire_pct"], ["boss_durgash", "head", "cdr"], ["war_rhino", "chest", "def_pct"],
	["iron_wolf_king", "weapon", "aspd_pct"],
	# Ato II: núcleos de monstro comum (2 brutos + 4 elites, estas com Balance.CARD_ELITE_ROLE_MULT)
	["orc_warrior", "head", "buff_pct"], ["troll_brute", "chest", "low_dr"], ["orc_warlord", "weapon", "leader_dmg"],
	["goblin_slayer", "weapon", "backstab"], ["clan_guard", "offhand", "block"], ["basalt_golem", "chest", "dr_pct"],
]

## Eco de chefe dá a carta do chefe original (com Balance.CARD_CHANCE_ECHO).
## Acampamento Bandido (cadeia da Campina, momentos-do-mundo §3.2) também: bandido do acampamento dá a carta do bandido original.
const ECHOES := {"echo_ghoul_giant": "ghoul_giant", "echo_death_knight": "death_knight", "echo_frost_mage": "frost_mage",
	"camp_bandit": "bandit_footpad", "camp_bandit_boss": "bandit"}

## Família de cada monstro do Ato I (alvo de family_dmg / family_def). Chefes também.
const FAMILY := {
	"beast": ["boar", "wolf", "crab", "crab_sand", "crab_hermit", "bear_cub", "bear", "grove_bear", "grove_wolf", "elf_lynx",
		"griffin", "griffin_raider", "bog_toad", "tower_bat", "carrion_crow", "rest_bear", "boar_brute", "boar_king", "crab_king",
		"bear_mother", "bog_mother", "dragonling", "elf_captain_sky", "ancestral_boar", "ancient_elk", "ruins_basilisk",
		"dire_wolf", "lava_salamander", "boss_dire_mother", "war_rhino", "iron_wolf_king"],
	"insect": ["wasp", "wasp_soldier", "hive", "spider", "marsh_spider", "sap_spider", "marsh_leech", "web_weaver", "larva", "spider_queen"],
	"undead": ["zombie", "bone_recruit", "bone_archer", "ghoul", "wraith", "ghost", "rest_thaw_wraith", "rot_wolf", "rot_zombie",
		"rot_ghoul", "rest_ghoul", "rot_bear", "skel_archer", "skeleton", "skel_guard", "rest_bones", "rest_bone_archer",
		"citadel_horror", "citadel_knight", "oath_sworn", "oath_archer", "vel_shade", "night_digger", "grave_hauler", "ink_wraith",
		"bone_captain", "wailing_widow", "count_vargo", "ghoul_giant", "echo_ghoul_giant", "death_knight", "echo_death_knight",
		"fallen_bearer", "crypt_lord", "lich_king", "boss_azhar_scribe"],
	"humanoid": ["bandit_footpad", "bandit_thief", "bandit_archer", "bandit", "bandit_outlaw", "marsh_smuggler", "shaman_shifter",
		"shaman_caller", "cultist", "citadel_adept", "rest_lost_adept", "archive_copyist", "bandit_chief", "boss_archdruid",
		"frost_mage", "echo_frost_mage", "naga_tide", "naga_warrior", "boss_tide_mother"],
	"elf": ["elf_raider", "elf_raider_archer", "elf_raider_mage", "elf_archer", "elf_warrior", "elf_sergeant", "elf_warden",
		"elf_tender", "elf_captain_hunter", "elf_captain_sap", "elf_king"],
	"construct": ["slime", "slime_blue", "golem_moss", "golem_stone", "golem_shard", "golem", "archive_warden", "slime_king",
		"golem_ancient", "crystal_warden", "quarry_heart", "basalt_golem"],
	"plant": ["trent_young", "ent", "trent", "sap_sprout", "boss_sap_mother"],
	# Ato II: a Horda (goblins, orcs, trolls, ginetes); bichos da Horda ficam em beast
	"horde": ["goblin_lancer", "goblin_impaler", "goblin_agitator", "wolf_rider", "wolf_raider", "dire_wolf_rider", "orc_recruit",
		"orc_warrior", "orc_warlord", "troll_whelp", "troll", "troll_thrower", "troll_brute", "orc_archer", "orc_crossbow",
		"orc_fire_archer", "goblin_assassin", "goblin_slayer", "clan_guard", "boss_agitator_lord", "boss_troll_king",
		"boss_crossbow_master", "boss_ghar", "boss_shazka", "boss_ulgra", "boss_gorbash", "boss_kragmar", "boss_durgash"],
}

## Falas do bot que achou uma carta (%s = nome da carta).
const BOT_LINES := ["Opa! %s!", "Caiu uma %s aqui!", "Olha só, %s. Alguém quer?", "%s! Essa vai para a coleção.",
	"Mais uma: %s."]

## Nome das famílias e dos grupos (texto do jogo).
const FAMILY_NAMES := {"beast": "feras", "insect": "insetos", "undead": "mortos-vivos", "humanoid": "humanos",
	"elf": "elfos", "construct": "constructos", "plant": "plantas", "horde": "a Horda"}
const GROUP_NAMES := {
	"aldara_fields": "Campos de Aldara", "crab_beach": "Praia dos Caranguejos", "hollow_swarm": "Enxame do Vale",
	"bears": "Ursos da Mata", "wolf_pack": "Matilha", "catacomb_dead": "Mortos da Catacumba", "wraiths": "Espectros",
	"quarry_golems": "Golens da Pedreira", "road_gang": "Bando da Estrada", "outlaws": "Fora da Lei", "spiders": "Aranhas",
	"woken_grove": "Bosque Desperto", "elf_beasts": "Feras Élficas", "marsh": "Brejo", "grove_circle": "Círculo do Bosque",
	"elf_scouts": "Batedores Élficos", "tree_guard": "Guarda da Árvore", "ghouls": "Carniçais", "rot": "Podridão",
	"bone_legion": "Legião de Ossos", "masterless": "Desgarrados", "lich_cult": "Culto do Lich", "gravediggers": "Coveiros",
	"oathsworn": "Juramentados", "velthar_archive": "Arquivo de Vel'Thar",
	"goblin_caves": "Grutas Goblin", "riders": "Ginetes", "broken_coast": "Costa Partida", "trolls": "Trolls",
	"horde_archers": "Arqueiros da Horda", "kharzun_slopes": "Encostas de Kharzun"}
const SLOT_NAMES := {"weapon": "Arma", "offhand": "Mão secundária", "head": "Cabeça", "chest": "Peito", "boots": "Botas",
	"accessory": "Acessório"}

## Texto de um efeito (carta ou combo). Ex.: describe("family_dmg", 8, "undead") -> "+8% de dano em mortos-vivos".
static func describe(effect: String, v: float, family: String = "") -> String:
	var n := ("%d" % int(v)) if is_equal_approx(v, roundf(v)) else ("%.2f" % v).rstrip("0").replace(".", ",")
	var fam: String = FAMILY_NAMES.get(family, family)
	match effect:
		"family_dmg": return ("+%s%% de dano na %s" % [n, fam.substr(2)]) if fam.begins_with("a ") else ("+%s%% de dano em %s" % [n, fam])
		"family_def": return ("-%s%% de dano recebido da %s" % [n, fam.substr(2)]) if fam.begins_with("a ") else ("-%s%% de dano recebido de %s" % [n, fam])
		"proc_poison": return "%s%% de chance de envenenar ao acertar" % n
		"proc_slow": return "%s%% de chance de deixar lento ao acertar" % n
		"proc_stun": return "%s%% de chance de atordoar ao acertar" % n
		"kill_heal": return "Abates curam %s%% da vida" % n
		"xp_pct": return "+%s%% de XP de abate" % n
		"gold_pct": return "+%s%% de ouro de monstros" % n
		"dash_pct": return "+%s%% de distância do dash" % n
		"crit": return "+%s%% de crítico" % n
		"thorns": return "Devolve %s%% do dano corpo a corpo" % n
		"block": return "+%s%% de bloqueio (com escudo)" % n
		"cc_resist_pct": return "-%s%% de duração de controle" % n
		"mp_regen_combat": return "+%s%% de mana/s em combate" % n
		"hp_pct": return "+%s%% de vida" % n
		"mp_pct": return "+%s%% de mana" % n
		"def_pct": return "+%s%% de defesa" % n
		"heal_taken_pct": return "+%s%% de cura recebida" % n
		"speed_pct": return "+%s%% de velocidade" % n
		"evasion": return "+%s%% de esquiva" % n
		"mp_on_kill": return "Abates devolvem %s%% da mana" % n
		"lifesteal": return "+%s%% de roubo de vida" % n
		"dr_pct": return "-%s%% de todo dano recebido" % n
		"low_dr": return "-%s%% de dano recebido com pouca vida" % n
		"low_leech": return "+%s%% de roubo de vida com pouca vida" % n
		"atk_pct": return "+%s%% de ATK" % n
		"matk_pct": return "+%s%% de MATK" % n
		"cdr": return "-%s%% de recarga das skills" % n
		"crit_dmg_pct": return "+%s%% de dano crítico" % n
		"aspd_pct": return "+%s%% de velocidade de ataque" % n
		"dot_pct": return "+%s%% de dano no tempo" % n
		"heal_pct": return "+%s%% de cura" % n
		"buff_pct": return "+%s%% de duração das bênçãos" % n
		"summon_time_pct": return "+%s%% de duração das invocações" % n
		"pet_pct": return "+%s%% de vida e ataque do companheiro" % n
		"mp_cost_pct": return "-%s%% de custo de mana" % n
		"frost_pct": return "+%s%% de dano de gelo" % n
		"fire_pct": return "+%s%% de dano de fogo" % n
		"threat_pct": return "+%s%% de ameaça" % n
		"backstab": return "+%s%% de dano pelas costas" % n
		"hit_slow": return "Golpes físicos deixam %s%% de lentidão" % n
		"storm_pct": return "+%s%% de dano de raio" % n
		"regen_cut": return "Golpes cortam a regeneração por %s s" % n
		"ranged_def": return "-%s%% de dano recebido de ataques à distância" % n
		"leader_dmg": return "+%s%% de dano em líderes, elites e chefes" % n
	return "%s %s" % [effect, n]

## Texto de um bônus de combo (dicionário de Balance.CARD_GROUP_BONUS).
static func describe_bonus(b: Dictionary) -> String:
	var parts: Array = []
	for k in b:
		if b[k] is Dictionary:
			for f in b[k]:
				parts.append(describe(k, float(b[k][f]), f))
		else:
			parts.append(describe(k, float(b[k])))
	return ", ".join(parts)

## Faixa pelo nível do monstro.
static func tier_of(level: int) -> int:
	var t := 0
	for lv in Balance.CARD_TIER_LEVELS:
		if level > int(lv):
			t += 1
	return t

## Monta as CardDef (CatalogUtil.fill). `monsters` = GameData.monsters (nome e nível); monstro que falta fica de fora.
static func build(monsters: Dictionary) -> Array[CardDef]:
	var out: Array[CardDef] = []
	var fam_of := {}
	for f in FAMILY:
		for mid in FAMILY[f]:
			fam_of[mid] = f
	for r in COMMONS:
		var c := _mk(monsters, str(r[0]), {"slot": r[1], "effect": r[2], "family": r[3], "group": r[4]}, false)
		if c:
			out.append(c)
	for r in CORES:
		var c := _mk(monsters, str(r[0]), {"slot": r[1], "effect": r[2]}, true)
		if c:
			out.append(c)
	return out

static func _mk(monsters: Dictionary, mid: String, d: Dictionary, core: bool) -> CardDef:
	var m: MonsterDef = monsters.get(mid)
	if m == null:
		push_warning("CardsCatalog: monstro sem def %s" % mid)
		return null
	var c := CardDef.new()
	var full := d.duplicate()
	full["id"] = "card_" + mid
	full["monster_id"] = mid
	full["name"] = "Carta de " + m.name
	full["core"] = core
	full["boss"] = m.is_boss
	full["tier"] = tier_of(m.level)
	var table: Dictionary = Balance.CARD_CORE if core else Balance.CARD_COMMON
	full["value"] = float(table[d["effect"]][full["tier"]]) if table.has(d["effect"]) else 0.0
	CatalogUtil.fill(c, full)
	return c

## Item da bolsa de uma carta (tipo CARD, empilha, preço baixo; ícone assets/icons/card_<monstro>.png).
static func item_for(c: CardDef) -> ItemDef:
	var it := ItemDef.new()
	it.id = c.id
	it.name = c.name
	it.type = ItemDef.Type.CARD
	it.rarity = 3 if c.core else 2
	it.price = Balance.CARD_PRICE_CORE if c.core else Balance.CARD_PRICE_COMMON
	it.stack_max = 99
	it.icon = c.id
	it.icon_color = Color(0.95, 0.78, 0.3) if c.core else Color(0.75, 0.7, 0.95)
	var fam := c.family
	it.description = "%s — %s: %s" % ["Núcleo" if c.core else "Carta", SLOT_NAMES.get(c.slot, c.slot), describe(c.effect, c.value, fam)]
	if c.group != "":
		it.description += "\nGrupo: %s" % GROUP_NAMES.get(c.group, c.group)
	return it
