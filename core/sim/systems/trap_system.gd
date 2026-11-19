class_name TrapSystem
extends RefCounted
## Armadilhas (Ranger Atirador): ficam no mapa, armam, disparam quando um inimigo pisa, somem com o tempo.
## Muralha de Fogo (efeito "fire_wall", Elementalista): faixa de fogo no chão, atravessada na mira, que fica `duration` s
## e reacende a queimadura (o `dot` da skill) em quem estiver nela a cada `pulse` s; o dano direto sai só no lançamento.
## Mora na lista de armadilhas (m["traps"], kind WALL: não dispara, não conta no limite). Uma por dono.
## Chão que fica (efeito "zone", GDD skills-fill-2026-11-19 M1): círculo no ponto mirado que pulsa (kind ZONE, mesma lista):
## inimigos dentro levam dano e o `dot` renova, aliados dentro recebem cura e buff curto. Um por (dono, skill).

const WALL := "fire_wall"
const ZONE := "zone"

static func place_trap(sim: WorldSim, e: SimEntity, s: SkillDef, aim: Vector3, power: float, effects: Dictionary) -> void:
	var m: Dictionary = sim.maps[e.map_id]
	var traps: Array = m["traps"]
	var mine: Array = traps.filter(func(t): return t["owner"] == e.id and t["kind"] != WALL and t["kind"] != ZONE)
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
		if t["kind"] == ZONE and owner != null and owner.is_alive() and owner.map_id == m["def"].id:
			while sim.time >= float(t["next"]) and float(t["next"]) <= float(t["expires"]):
				_zone_pulse(sim, t, owner, m)          # o último pulso cai no fim do tempo (antes de sumir)
		if sim.time >= float(t["expires"]) or owner == null or owner.map_id != m["def"].id or (t["kind"] == ZONE and not owner.is_alive()):
			traps.erase(t)
			Events.post(&"trap_removed", t["id"], false)
			continue
		if t["kind"] == WALL:
			if sim.time >= float(t["next"]):
				_wall_pulse(sim, t, owner, m, false)
			continue
		if t["kind"] == ZONE:
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

## Chão que fica (efeito "zone"): o golpe da skill já bateu; aqui só nasce o círculo (o 1º pulso sai `pulse` s depois).
## `power` = poder do lançamento (maestria, Juramento etc.); o pulso bate foe_power/power-base desse poder.
static func place_zone(sim: WorldSim, e: SimEntity, s: SkillDef, aim: Vector3, power: float, effects: Dictionary) -> Dictionary:
	var m: Dictionary = sim.maps[e.map_id]
	var traps: Array = m["traps"]
	for old in traps.duplicate():
		if old["owner"] == e.id and old["kind"] == ZONE and old["skill"] == s.id:
			traps.erase(old)
			Events.post(&"trap_removed", old["id"], false)
	var zd: Dictionary = effects[ZONE]
	var fx := {}
	if effects.has("dot"):
		fx["dot"] = effects["dot"]
	var scale := power / maxf(0.01, s.power)          # o que multiplicou o lançamento vale para os pulsos
	var pos := Vector3(aim.x, 0.0, aim.z)
	var t := {"id": sim._next_trap_id, "owner": e.id, "kind": ZONE, "zone": str(zd.get("id", s.id)), "pos": pos, "radius": s.radius,
		"skill": s.id, "theme": SkillsCatalog.vfx_theme(s), "kind_dmg": s.kind, "effects": fx,
		"foe_power": float(zd.get("foe_power", 0.0)) * scale, "ally_heal": float(zd.get("ally_heal", 0.0)) * scale,
		"ally_buff": zd.get("ally_buff", {}), "foe_slow": float(zd.get("foe_slow", 0.0)),
		"foe_radius": float(zd.get("foe_radius", 0.0)), "foe_max": int(zd.get("foe_max", 0)), "mend_pct": float(zd.get("mend_pct", 0.0)),
		"pulse": float(zd.get("pulse", 1.0)), "next": sim.time + float(zd.get("pulse", 1.0)), "pulses": 0,
		"armed_at": sim.time, "expires": sim.time + float(zd.get("duration", 6.0)) + 0.001}     # folga: o pulso do fim cabe
	sim._next_trap_id += 1
	traps.append(t)
	Events.post(&"trap_placed", t["id"], ZONE, pos, s.radius, e.map_id)
	return t

## Quem está dentro do círculo da zona (mesma régua da área de chão: raio + raio do corpo).
static func in_zone(t: Dictionary, o: SimEntity) -> bool:
	var pos: Vector3 = t["pos"]
	return Vector2(o.position.x - pos.x, o.position.z - pos.z).length() <= float(t["radius"]) + o.radius

## Um pulso da zona: inimigos dentro levam o dano (sem crítico) e o dot/lentidão; aliados dentro, cura e buff curto.
static func _zone_pulse(sim: WorldSim, t: Dictionary, owner: SimEntity, m: Dictionary) -> void:
	t["next"] = float(t["next"]) + float(t["pulse"])
	t["pulses"] = int(t["pulses"]) + 1
	var pos: Vector3 = t["pos"]
	var foe_r := float(t.get("foe_radius", 0.0))     # Coração do Bosque: os inimigos vêm de mais longe que a cura
	var reach := maxf(float(t["radius"]), foe_r) + 2.0
	var magical: bool = int(t["kind_dmg"]) == SkillDef.Kind.MAGICAL
	var picked: Array = _zone_pick(t, owner, m, foe_r) if int(t.get("foe_max", 0)) > 0 else []
	var linger := float(t["pulse"]) + Balance.ZONE_BUFF_LINGER
	var buff: Dictionary = t["ally_buff"]
	var ut := WorldSim.is_ult_id(str(t["skill"]))     # zona de Suprema: o dano (e os dots) contam em ult_dealt (medição)
	for o: SimEntity in m["entities"].duplicate():
		if absf(o.position.x - pos.x) > reach or absf(o.position.z - pos.z) > reach:
			continue
		if not o.is_alive():
			continue
		if owner.is_hostile_to(o) and foe_r > 0.0:
			if Vector2(o.position.x - pos.x, o.position.z - pos.z).length() > foe_r + o.radius or (int(t.get("foe_max", 0)) > 0 and not picked.has(o)):
				continue
		elif not in_zone(t, o):
			continue
		if owner.is_hostile_to(o):
			if float(t["foe_power"]) > 0.0:
				var r := Combat.calc_damage(owner, o, float(t["foe_power"]), SkillDef.Kind.MAGICAL if magical else SkillDef.Kind.PHYSICAL, sim.rng, pos)
				var amount: int = int(r["amount"])
				if r["crit"]:
					amount = maxi(1, int(round(amount / owner.stats.crit_mult())))     # pulso não critica
				sim.ult_tag += 1 if ut else 0         # Sol do Julgamento / Coração do Bosque: dano de Suprema (medição)
				var landed: bool = sim._deal_damage(owner, o, amount, false, r["blocked"], "magical" if magical else "physical", pos)
				sim.ult_tag -= 1 if ut else 0
				if landed and float(t.get("mend_pct", 0.0)) > 0.0 and owner.is_alive():
					sim.mend(owner, amount, float(t["mend_pct"]))     # Sol do Julgamento: o chão aceso cura o aliado mais ferido
				if foe_r > 0.0 and o.is_alive():
					Events.post(&"skill_effect", str(t["skill"]) + "_bolt", pos, o.position, 0.5)     # Coração do Bosque: Fogo Lunar da árvore
			if not o.is_alive():
				continue
			if float(t["foe_slow"]) > 0.0:
				o.put_debuff({"kind": "slow", "id": "zone_slow_%d" % int(t["id"]), "remaining": linger * o.stats.cc_mult(), "pct": float(t["foe_slow"])})
			if not _renew_burn(sim, t, owner, o) and not (t["effects"] as Dictionary).is_empty():
				sim.ult_tag += 1 if ut else 0
				sim._apply_effects(owner, o, t["effects"], float(t["foe_power"]))
				sim.ult_tag -= 1 if ut else 0
		elif o == owner or owner.is_friend(o):
			if o.kind == SimEntity.Kind.MONSTER or (o.kind == SimEntity.Kind.NPC and not o.guard):
				continue
			if float(t["ally_heal"]) > 0.0:
				sim._heal(owner, o, Combat.calc_heal(owner, float(t["ally_heal"]), sim.rng))
			if not buff.is_empty():
				var had := o.buffs.any(func(b): return b.get("id") == buff.get("id"))
				var b := buff.duplicate()
				b["remaining"] = linger
				o.put_buff(b)
				o.recompute_stats()
				if not had:
					Events.post(&"buff_applied", o.id, b.get("id", "buff"), linger)

## Coração do Bosque (zona com "foe_max"): os `foe_max` inimigos mais perto do centro a até `foe_r` m (Fogo Lunar da árvore).
static func _zone_pick(t: Dictionary, owner: SimEntity, m: Dictionary, foe_r: float) -> Array:
	var pos: Vector3 = t["pos"]
	var near: Array = []
	for o: SimEntity in m["entities"]:
		if o.is_alive() and owner.is_hostile_to(o) and Vector2(o.position.x - pos.x, o.position.z - pos.z).length() <= foe_r + o.radius:
			near.append(o)
	near.sort_custom(func(a, b): return a.position.distance_squared_to(pos) < b.position.distance_squared_to(pos))
	return near.slice(0, int(t.get("foe_max", 0)))
