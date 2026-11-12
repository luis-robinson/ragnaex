class_name LivingAudit
extends Node
## Censo de "vida" por mapa (sem tela): moradores que passeiam/rondam, sentinelas, falas soltas (barks), interiores,
## colheita, pontos de bot, investidas, levas aliadas, rondas de monstro, troca por estágio, bichos de ambiente.
##   godot --headless --path . tools/tests/living_audit.tscn -- [--maps=a,b,c]
## Só lê os catálogos (MapDef + tabelas); imprime uma linha por mapa (formato de tabela markdown).

const MAPS := ["city_aldara", "field_forest", "elf_city", "field_ruins", "fort_ghoul", "fort_bones", "dg_catacumbas",
	"city_port", "field_coast", "dg_goblin", "field_steppe", "fort_trolls", "fort_fire", "fort_war"]

func _ready() -> void:
	await get_tree().process_frame
	var only: Array = DevArgs.value("--maps", "").split(",", false) if DevArgs.flag("--maps") else MAPS
	print("LIVING | mapa | npcs | servicos | passeio | ronda | sentinelas | sentinelas_ronda | so_estagio | barks | interiores | colheita | hangouts | investidas | levas | mob_ronda | estagio_vis | bots | bichos |")
	for mid in only:
		if not GameData.maps.has(mid):
			continue
		print(_row(GameData.maps[mid]))
	get_tree().quit()

static func census(def: MapDef) -> Dictionary:
	var c := {"npcs": 0, "services": 0, "wander": 0, "route": 0, "guards": 0, "guard_route": 0, "staged": 0, "barks": 0,
		"interiors": 0, "gather": 0, "hangouts": def.bot_hangouts.size(), "raids": 0, "assaults": def.assaults.size(),
		"mob_route": 0, "vis": def.conquest_vis.size(), "bots": def.bot_population, "critters": 0}
	for n in def.npcs:
		c["npcs"] += 1
		var role: String = n.get("role", "")
		var moves: bool = n.has("wander") or n.has("route")
		if n.has("fighter"):
			c["guards"] += 1
			if moves:
				c["guard_route"] += 1
		elif n.has("route"):
			c["route"] += 1
		elif n.has("wander"):
			c["wander"] += 1
		elif role in ["smith", "alchemy", "merchant", "storage", "relic"]:
			c["services"] += 1
		if n.has("if") or n.has("unless"):
			c["staged"] += 1
		if not (n.get("barks", []) as Array).is_empty():
			c["barks"] += 1
	for iid in MapsCatalog.INTERIORS:
		if str(MapsCatalog.INTERIORS[iid].get("map", "city_aldara")) == def.id:
			c["interiors"] += 1
	c["gather"] = (MapsCatalog.GATHER.get(def.id, []) as Array).size()
	c["raids"] = (0 if def.raid.is_empty() else 1) + def.raids.size()
	for sp in def.spawners:
		if sp.has("route"):
			c["mob_route"] += 1
	c["critters"] = AmbientLife.count_for(def.id)
	return c

func _row(def: MapDef) -> String:
	var c := census(def)
	return "LIVING | %s | %d | %d | %d | %d | %d | %d | %d | %d | %d | %d | %d | %d | %d | %d | %d | %d | %d |" % [def.id, c["npcs"], c["services"],
		c["wander"], c["route"], c["guards"], c["guard_route"], c["staged"], c["barks"], c["interiors"], c["gather"], c["hangouts"],
		c["raids"], c["assaults"], c["mob_route"], c["vis"], c["bots"], c["critters"]]
