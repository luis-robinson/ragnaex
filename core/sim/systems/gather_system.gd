class_name GatherSystem
extends RefCounted
## Colheita: pontos espalhados pelo mapa (ervas, minério...), F perto para colher, voltam depois.

## Espalha os pontos de `def.gather` em chão livre (semente do mapa: sempre nos mesmos lugares).
static func spread_gather(sim: WorldSim, def: MapDef) -> Array:
	var out: Array = []
	var gr := RandomNumberGenerator.new()
	gr.seed = absi(def.id.hash())
	for rule in def.gather:
		var at: Vector3 = rule["at"]
		var r: float = float(rule.get("radius", 8.0))
		for i in range(int(rule.get("count", 4))):
			var p := at
			for tries in range(30):
				var a := gr.randf() * TAU
				var d := sqrt(gr.randf()) * r
				p = at + Vector3(cos(a) * d, 0, sin(a) * d)
				if MapGeometry.is_walkable(sim, p, def, 0.6):
					break
			out.append({"item": rule["item"], "kind": rule.get("kind", "herb"), "pos": p, "ready_at": 0.0, "min": int(rule.get("min", 1)), "max": int(rule.get("max", 2))})
	return out

## Ponto pronto mais perto de `e` dentro do alcance (ou {}).
static func nearest_gather(sim: WorldSim, e: SimEntity) -> Dictionary:
	if e == null or not sim.maps.has(e.map_id):
		return {}
	var best: Dictionary = {}
	var bd := Balance.GATHER_RANGE
	for node in sim.maps[e.map_id].get("gather", []):
		if float(node["ready_at"]) > sim.time:
			continue
		var d: float = Vector2(node["pos"].x - e.position.x, node["pos"].z - e.position.z).length()
		if d < bd:
			bd = d
			best = node
	return best

static func start_gather(sim: WorldSim, e: SimEntity, m: Dictionary) -> void:
	if not e.is_character() or e.gather_left > 0.0 or e.mounted:
		return
	var node := nearest_gather(sim, e)
	if node.is_empty():
		return
	if e.combat_timer > 0.0:
		if e == sim.player:
			Events.post(&"notification", "Não dá para colher em combate")
		return
	if e.bag_full_for(node["item"]):
		if e == sim.player:
			Events.post(&"notification", "Bolsa cheia (%d/%d)" % [e.inventory.size(), e.bag_capacity()])
		return
	e.face_towards(node["pos"])
	e.gather_left = Balance.GATHER_TIME
	e.gather_node = node
	e.gather_hp = e.hp

static func update_gather(sim: WorldSim, e: SimEntity, cmd: InputCommand, action_cmd: InputCommand, dt: float) -> void:
	if e.gather_left <= 0.0:
		return
	var node := e.gather_node
	if not e.is_alive() or cmd.move.length_squared() > 0.04 or action_cmd.attack or action_cmd.skill_slot >= 0 or action_cmd.dash \
			or action_cmd.jump or cmd.block or e.hp < e.gather_hp - 0.5 or e.combat_timer > 0.0 or float(node.get("ready_at", 0.0)) > sim.time:
		e.gather_left = 0.0                  # andou, atacou, apanhou ou alguém colheu antes
		e.gather_node = {}
		return
	e.gather_left -= dt
	if e.gather_left > 0.0:
		return
	e.gather_left = 0.0
	e.gather_node = {}
	var n := sim.rng.randi_range(int(node["min"]), int(node["max"]))
	e.add_item(node["item"], n)
	node["ready_at"] = sim.time + Balance.GATHER_RESPAWN
	var idx: int = (sim.maps[e.map_id]["gather"] as Array).find(node)
	Events.post(&"gathered", e.map_id, idx, e.id)
	if e == sim.player:
		Events.post(&"notification", "Colheu %d %s" % [n, GameData.items[node["item"]].name])
