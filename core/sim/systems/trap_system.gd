class_name TrapSystem
extends RefCounted
## Armadilhas (Ranger Atirador): ficam no mapa, armam, disparam quando um inimigo pisa, somem com o tempo.

static func place_trap(sim: WorldSim, e: SimEntity, s: SkillDef, aim: Vector3, power: float, effects: Dictionary) -> void:
	var m: Dictionary = sim.maps[e.map_id]
	var traps: Array = m["traps"]
	var mine: Array = traps.filter(func(t): return t["owner"] == e.id)
	while mine.size() >= ClassTalentSystem.trap_max(e):        # a mais antiga some
		var old: Dictionary = mine.pop_front()
		traps.erase(old)
		Events.trap_removed.emit(old["id"], false)
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
	Events.trap_placed.emit(t["id"], t["kind"], pos, t["radius"], e.map_id)

static func update_traps(sim: WorldSim, m: Dictionary) -> void:
	var traps: Array = m["traps"]
	for t in traps.duplicate():
		var owner: SimEntity = sim.entities.get(t["owner"])
		if sim.time >= float(t["expires"]) or owner == null or owner.map_id != m["def"].id:
			traps.erase(t)
			Events.trap_removed.emit(t["id"], false)
			continue
		if sim.time < float(t["armed_at"]):
			continue
		var pos: Vector3 = t["pos"]
		var stepped := false
		for o in m["entities"]:
			if o.is_alive() and owner.is_hostile_to(o) and Vector3(o.position.x, 0, o.position.z).distance_to(pos) <= float(t["hit_radius"]) + o.radius:
				stepped = true
				break
		if not stepped:
			continue
		traps.erase(t)
		for o in m["entities"]:        # dispara: dano e efeito em quem estiver na área
			if o.is_alive() and owner.is_hostile_to(o) and Vector3(o.position.x, 0, o.position.z).distance_to(pos) <= float(t["radius"]) + o.radius:
				var r := Combat.calc_damage(owner, o, float(t["power"]), SkillDef.Kind.PHYSICAL, sim.rng, pos)
				sim._deal_damage(owner, o, r["amount"], r["crit"], false, "physical", pos)
				sim._apply_effects(owner, o, t["effects"], float(t["power"]))
		Events.trap_removed.emit(t["id"], true)
		Events.skill_effect.emit(t["skill"], pos, pos, float(t["radius"]))
