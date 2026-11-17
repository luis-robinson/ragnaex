class_name TrapSystem
extends RefCounted
## Armadilhas (Ranger Atirador): ficam no mapa, armam, disparam quando um inimigo pisa, somem com o tempo.
## Muralha de Fogo (efeito "fire_wall", Elementalista): faixa de fogo no chão, atravessada na mira, que fica `duration` s
## e reacende a queimadura (o `dot` da skill) em quem estiver nela a cada `pulse` s; o dano direto sai só no lançamento.
## Mora na lista de armadilhas (m["traps"], kind WALL: não dispara, não conta no limite). Uma por dono.

const WALL := "fire_wall"

static func place_trap(sim: WorldSim, e: SimEntity, s: SkillDef, aim: Vector3, power: float, effects: Dictionary) -> void:
	var m: Dictionary = sim.maps[e.map_id]
	var traps: Array = m["traps"]
	var mine: Array = traps.filter(func(t): return t["owner"] == e.id and t["kind"] != WALL)
	while mine.size() >= ClassTalentSystem.trap_max(e):        # a mais antiga some
		var old: Dictionary = mine.pop_front()
		traps.erase(old)
		Events.post(&"trap_removed", old["id"], false)
	var td: Dictionary = effects["trap"]
	var fx := {}
	for k in ["root", "slow", "stun", "dot"]:
		if effects.has(k):
			fx[k] = effects[k]
	var pos := Vector3(aim.x, 0.0, aim.z)
	var t := {"id": sim._next_trap_id, "owner": e.id, "kind": td.get("kind", "jaw"), "pos": pos, "hit_radius": float(td.get("hit_radius", 1.3)),
		"radius": maxf(s.radius, float(td.get("hit_radius", 1.3))), "power": power, "effects": fx, "skill": s.id,
		"armed_at": sim.time + Balance.TRAP_ARM_TIME, "expires": sim.time + float(td.get("duration", 30.0))}
	sim._next_trap_id += 1
	traps.append(t)
	Events.post(&"trap_placed", t["id"], t["kind"], pos, t["radius"], e.map_id)

static func update_traps(sim: WorldSim, m: Dictionary) -> void:
	var traps: Array = m["traps"]
	for t in traps.duplicate():
		var owner: SimEntity = sim.entities.get(t["owner"])
		if sim.time >= float(t["expires"]) or owner == null or owner.map_id != m["def"].id:
			traps.erase(t)
			Events.post(&"trap_removed", t["id"], false)
			continue
		if t["kind"] == WALL:
			if sim.time >= float(t["next"]):
				_wall_pulse(sim, t, owner, m, false)
			continue
		if sim.time < float(t["armed_at"]):
			continue
		var pos: Vector3 = t["pos"]
		var stepped := false
		for o: SimEntity in m["entities"]:
			if o.is_alive() and owner.is_hostile_to(o) and Vector3(o.position.x, 0, o.position.z).distance_to(pos) <= float(t["hit_radius"]) + o.radius:
				stepped = true
				break
		if not stepped:
			continue
		traps.erase(t)
		for o: SimEntity in m["entities"]:        # dispara: dano e efeito em quem estiver na área
			if o.is_alive() and owner.is_hostile_to(o) and Vector3(o.position.x, 0, o.position.z).distance_to(pos) <= float(t["radius"]) + o.radius:
				var r := Combat.calc_damage(owner, o, float(t["power"]), SkillDef.Kind.PHYSICAL, sim.rng, pos)
				sim._deal_damage(owner, o, r["amount"], r["crit"], false, "physical", pos)
				sim._apply_effects(owner, o, t["effects"], float(t["power"]))
		Events.post(&"trap_removed", t["id"], true)
		Events.post(&"skill_effect", t["skill"], pos, pos, float(t["radius"]))

## Ergue a muralha: comprimento 2 × raio da skill (o talento de raio alarga), atravessada na direção de quem lança.
static func place_wall(sim: WorldSim, e: SimEntity, s: SkillDef, aim: Vector3, power: float, effects: Dictionary) -> Dictionary:
	var m: Dictionary = sim.maps[e.map_id]
	var traps: Array = m["traps"]
	for old in traps.duplicate():
		if old["owner"] == e.id and old["kind"] == WALL:
			traps.erase(old)
			Events.post(&"trap_removed", old["id"], false)
	var wd: Dictionary = effects[WALL]
	var fx := {}
	for k in ["root", "slow", "stun", "dot"]:
		if effects.has(k):
			fx[k] = effects[k]
	var f := e.forward()
	var pos := Vector3(aim.x, 0.0, aim.z)
	var t := {"id": sim._next_trap_id, "owner": e.id, "kind": WALL, "pos": pos, "along": Vector3(-f.z, 0.0, f.x).normalized(),
		"half_len": s.radius, "half_w": float(wd.get("width", Balance.FIRE_WALL_WIDTH)) * 0.5, "radius": s.radius,
		"power": power, "effects": fx, "skill": s.id, "kind_dmg": s.kind, "pulse": float(wd.get("pulse", Balance.FIRE_WALL_PULSE)),
		"next": 0.0, "armed_at": sim.time, "expires": sim.time + float(wd.get("duration", Balance.FIRE_WALL_TIME))}
	sim._next_trap_id += 1
	traps.append(t)
	Events.post(&"trap_placed", t["id"], WALL, pos, s.radius, e.map_id)
	Events.post(&"skill_effect", s.id, e.position, pos, s.radius)
	_wall_pulse(sim, t, e, m, true)
	return t

## Quem está dentro da faixa (retângulo de meio-comprimento half_len e meia-largura half_w).
static func in_wall(t: Dictionary, o: SimEntity) -> bool:
	var rel: Vector3 = o.position - (t["pos"] as Vector3)
	rel.y = 0.0
	var along: Vector3 = t["along"]
	var a := absf(rel.dot(along))
	var side := absf(rel.cross(along).y)
	return a <= float(t["half_len"]) + o.radius and side <= float(t["half_w"]) + o.radius

static func _wall_pulse(sim: WorldSim, t: Dictionary, owner: SimEntity, m: Dictionary, first: bool) -> void:
	t["next"] = sim.time + float(t["pulse"])
	var pos: Vector3 = t["pos"]
	var reach := float(t["half_len"]) + 2.0
	for o: SimEntity in m["entities"]:
		if not o.is_alive() or absf(o.position.x - pos.x) > reach or absf(o.position.z - pos.z) > reach:
			continue
		if not owner.is_hostile_to(o) or not in_wall(t, o):
			continue
		if first:                        # o lançamento bate (o resto do tempo só queima)
			var r := Combat.calc_damage(owner, o, float(t["power"]), int(t["kind_dmg"]), sim.rng, pos)
			sim._deal_damage(owner, o, r["amount"], r["crit"], false, "magical" if int(t["kind_dmg"]) == SkillDef.Kind.MAGICAL else "physical", pos)
		if not _renew_burn(sim, t, owner, o):         # já queima por esta muralha: só renova (dot comum acumula, aqui não)
			sim._apply_effects(owner, o, t["effects"], float(t["power"]))

static func _renew_burn(sim: WorldSim, t: Dictionary, owner: SimEntity, o: SimEntity) -> bool:
	var dot: Variant = (t["effects"] as Dictionary).get("dot")
	if not dot is Dictionary:
		return false
	var id := WorldSim.dot_id(owner, dot as Dictionary, sim._monster_side(owner))
	for d in o.debuffs:
		if d.get("kind") == "dot" and d.get("id") == id and d.get("fire", false):
			d["remaining"] = maxf(float(d["remaining"]), float((dot as Dictionary).get("duration", 4)))
			return true
	return false
