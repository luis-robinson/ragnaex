class_name StormSystem
extends RefCounted
## Tempestade de Suprema (efeito "storm"; GDD ultimates-lv40 §9) e a chuva de círculos com dono jogador ("barrage" de
## personagem, Corsário). Estado no mapa: m["storms"] (tempestades vivas) e m["ally_strikes"] (golpes avisados que ainda
## vão cair). Lista própria, fora de m["hazards"]: os bots fogem dos círculos de CHEFE, nunca destes (não ferem aliados).
## Tudo sorteado com o rng da sim (determinístico por comando).
##
## storm = {"anchor": "caster"|"ground", "mode": "strikes"|"pulse", "duration", "every", "radius", "strike_radius",
##   "bias", "warn", "prefer": ""|"unburnt"|"fresh", "fresh_s", "strike_mult", "effects": {...},
##   "chain": {count, radius, falloff}, "stun_chance": {pct, duration}, "slow_stack": {step, max, duration},
##   "freeze": {hits, duration}, "end": {power, radius, pull}}
## Poder de cada golpe = poder do lançamento (maestria, bônus de skill/elemento já contados) × strike_mult.

## Começa a tempestade de `e` (skill `s` lançada com `power`). Centro: "caster" segue o lançador; "ground" fica no ponto
## mirado (skill GROUND) ou onde o lançador estava (SELF).
static func start(sim: WorldSim, e: SimEntity, s: SkillDef, aim: Vector3, power: float, d: Dictionary) -> void:
	var m: Dictionary = sim.maps[e.map_id]
	if not m.has("storms"):
		m["storms"] = []
	var anchor := str(d.get("anchor", "caster"))
	var center := Vector3(aim.x, 0.0, aim.z) if anchor == "ground" and s.target == SkillDef.Target.GROUND else Vector3(e.position.x, 0.0, e.position.z)
	var dur := float(d.get("duration", 8.0))
	var st := {"owner": e.id, "skill": s.id, "anchor": anchor, "center": center, "until": sim.time + dur,
		"next_at": sim.time, "every": maxf(0.05, float(d.get("every", 1.0))), "radius": float(d.get("radius", 6.0)),
		"strike_r": float(d.get("strike_radius", 2.0)), "warn": float(d.get("warn", 0.0)), "bias": float(d.get("bias", 0.0)),
		"prefer": str(d.get("prefer", "")), "fresh_s": float(d.get("fresh_s", 0.8)), "mode": str(d.get("mode", "strikes")),
		"power": power * float(d.get("strike_mult", 1.0)), "cast_mult": power / maxf(0.01, s.power), "fx": d.get("effects", {}),
		"chain": d.get("chain", {}), "stun_chance": d.get("stun_chance", {}), "slow_stack": d.get("slow_stack", {}),
		"freeze": d.get("freeze", {}), "end": d.get("end", {}), "hits": {}, "frozen": {}, "last_hit": {}}
	m["storms"].append(st)
	Events.post(&"storm_started", e.map_id, e.id, s.id, center, float(st["radius"]), dur, anchor == "caster")

## Chuva de círculos do personagem (efeito "barrage" lançado por jogador/bot): `count` círculos de `radius` m, um em
## cada inimigo perto do ponto e o resto em volta (`spread` m), todos caem depois de `delay` s.
static func place_barrage(sim: WorldSim, e: SimEntity, s: SkillDef, aim: Vector3, power: float, effects: Dictionary) -> void:
	var m: Dictionary = sim.maps[e.map_id]
	var bd: Dictionary = effects["barrage"]
	var count := int(bd.get("count", 3))
	var r := float(bd.get("radius", maxf(1.5, s.radius)))
	var delay := float(bd.get("delay", 0.6))
	var spread := float(bd.get("spread", 6.0))
	var center := Vector3(aim.x, 0.0, aim.z)
	var fx := {}
	for k in ["root", "slow", "stun", "dot", "knockback", "wither"]:
		if effects.has(k):
			fx[k] = effects[k]
	var spots: Array = [center]
	for o: SimEntity in m["entities"]:
		if spots.size() >= count:
			break
		if o.is_alive() and e.is_hostile_to(o) and o.position.distance_to(center) <= spread:
			var p := Vector3(o.position.x, 0.0, o.position.z)
			if spots.all(func(q): return q.distance_to(p) > r):
				spots.append(p)
	var tries := 0
	while spots.size() < count and tries < count * 6:
		tries += 1
		var p := _random_spot(sim, m, center, spread)
		if p != Vector3.INF and spots.all(func(q): return q.distance_to(p) > r * 1.2):
			spots.append(p)
	for p in spots:
		_queue(sim, m, {"owner": e.id, "skill": s.id, "pos": p, "radius": r, "at": sim.time + delay, "power": power, "fx": fx})

## Tique do mapa: tempestades e golpes avisados. Dono morto/fora do mapa = some tudo dele.
static func tick(sim: WorldSim, m: Dictionary) -> void:
	var storms: Array = m.get("storms", [])
	if not storms.is_empty():
		for st: Dictionary in storms.duplicate():
			var owner: SimEntity = sim.entities.get(int(st["owner"]))
			if owner == null or not owner.is_alive() or owner.map_id != m["def"].id:
				storms.erase(st)
				continue
			if st["anchor"] == "caster":
				st["center"] = Vector3(owner.position.x, 0.0, owner.position.z)
			while sim.time >= float(st["next_at"]) and float(st["next_at"]) < float(st["until"]):
				st["next_at"] = float(st["next_at"]) + float(st["every"])
				_fire(sim, m, owner, st)
			if sim.time >= float(st["until"]):
				storms.erase(st)
				_end(sim, m, owner, st)
	var strikes: Array = m.get("ally_strikes", [])
	if strikes.is_empty():
		return
	for h: Dictionary in strikes.duplicate():
		var owner: SimEntity = sim.entities.get(int(h["owner"]))
		if owner == null or not owner.is_alive() or owner.map_id != m["def"].id:
			strikes.erase(h)
		elif sim.time >= float(h["at"]):
			strikes.erase(h)
			_land(sim, m, owner, h)

## Tempestades vivas de `e` no mapa dele (HUD/testes).
static func storms_of(sim: WorldSim, e: SimEntity) -> Array:
	if not sim.maps.has(e.map_id):
		return []
	return (sim.maps[e.map_id].get("storms", []) as Array).filter(func(st): return int(st["owner"]) == e.id)

static func _fire(sim: WorldSim, m: Dictionary, owner: SimEntity, st: Dictionary) -> void:
	var center: Vector3 = st["center"]
	var r := float(st["radius"])
	if st["mode"] == "pulse":
		_pulse(sim, m, owner, st)
		return
	var p := Vector3.INF
	if sim.rng.randf() < float(st["bias"]):
		var t := _pick(sim, m, owner, st)
		if t != null:
			p = Vector3(t.position.x, 0.0, t.position.z)
	if p == Vector3.INF:
		p = _random_spot(sim, m, center, r)
	if p == Vector3.INF:
		return                                       # 3 pontos não andáveis seguidos: este meteoro não cai
	var h := {"owner": owner.id, "skill": st["skill"], "pos": p, "radius": st["strike_r"], "at": sim.time + float(st["warn"]),
		"power": st["power"], "fx": st["fx"], "storm": st}
	if float(st["warn"]) <= 0.0:
		_land(sim, m, owner, h)
	else:
		_queue(sim, m, h)

static func _queue(sim: WorldSim, m: Dictionary, h: Dictionary) -> void:
	if not m.has("ally_strikes"):
		m["ally_strikes"] = []
	m["ally_strikes"].append(h)
	Events.post(&"ally_strike_placed", m["def"].id, h["pos"], float(h["radius"]), maxf(0.0, float(h["at"]) - sim.time), str(h["skill"]))

## Alvo preferido dentro da área: "unburnt" = sem queimadura do dono; "fresh" = não levou nos últimos fresh_s s.
## Sem preferido: o mais perto do centro.
static func _pick(sim: WorldSim, m: Dictionary, owner: SimEntity, st: Dictionary) -> SimEntity:
	var center: Vector3 = st["center"]
	var r := float(st["radius"])
	var best: SimEntity = null
	var best_s := -INF
	for o: SimEntity in m["entities"]:
		var d := Vector2(o.position.x - center.x, o.position.z - center.z).length()
		if d > r + o.radius or not o.is_alive() or not owner.is_hostile_to(o) or o.stealth_left > 0.0:
			continue
		var sc := -d
		match str(st["prefer"]):
			"unburnt":
				if not _burning(owner, o):
					sc += 100.0
			"fresh":
				if sim.time - float((st["last_hit"] as Dictionary).get(o.id, -1000.0)) > float(st["fresh_s"]):
					sc += 100.0
		sc += sim.rng.randf()                         # desempate sorteado (não cai sempre no mesmo)
		if sc > best_s:
			best_s = sc
			best = o
	return best

static func _burning(owner: SimEntity, o: SimEntity) -> bool:
	for d in o.debuffs:
		if d.get("kind") == "dot" and d.get("fire", false) and int(d.get("src", -1)) == owner.id:
			return true
	return false

static func _random_spot(sim: WorldSim, m: Dictionary, center: Vector3, r: float) -> Vector3:
	for i in range(Balance.STORM_WALK_TRIES):
		var a := sim.rng.randf() * TAU
		var d := sqrt(sim.rng.randf()) * r
		var p := center + Vector3(cos(a) * d, 0.0, sin(a) * d)
		if sim.is_walkable(p, m["def"], 0.3):
			return p
	return Vector3.INF

## Golpe que cai: todo inimigo dentro leva o poder + efeitos (chain e chance de atordoar opcionais).
static func _land(sim: WorldSim, m: Dictionary, owner: SimEntity, h: Dictionary) -> void:
	var s: SkillDef = GameData.skills.get(str(h["skill"]))
	if s == null:
		return
	var pos: Vector3 = h["pos"]
	var r := float(h["radius"])
	var st: Dictionary = h.get("storm", {})
	var hit: Array = []
	for o: SimEntity in m["entities"]:
		if Vector2(o.position.x - pos.x, o.position.z - pos.z).length() <= r + o.radius and o.is_alive() and owner.is_hostile_to(o):
			hit.append(o)
	Events.post(&"skill_effect", s.id, pos, pos, r)
	for o: SimEntity in hit:
		_hit(sim, owner, o, s, float(h["power"]), h["fx"], pos, st)
	if not hit.is_empty() and not st.is_empty() and (st["chain"] as Dictionary).size() > 0:
		sim._chain(owner, s, hit, float(h["power"]), st["chain"], h["fx"], m)

static func _hit(sim: WorldSim, owner: SimEntity, o: SimEntity, s: SkillDef, power: float, fx: Dictionary, from: Vector3, st: Dictionary) -> void:
	sim._strike(owner, o, s, power, s.kind if s.kind != SkillDef.Kind.SUMMON else SkillDef.Kind.MAGICAL, from)
	if not fx.is_empty():
		sim._apply_effects(owner, o, _ult_dot(fx, s), power)
	if st.is_empty():
		return
	(st["last_hit"] as Dictionary)[o.id] = sim.time
	var sc: Dictionary = st["stun_chance"]
	if not sc.is_empty() and o.is_alive() and sim.rng.randf() * 100.0 < float(sc.get("pct", 0.0)):
		sim._apply_effects(owner, o, {"stun": {"duration": float(sc.get("duration", 0.4))}}, 0.0)

## O dano no tempo de uma Suprema leva o id da skill e a marca "ult" (não enche a Carga Suprema).
static func _ult_dot(fx: Dictionary, s: SkillDef) -> Dictionary:
	if not (fx.get("dot") is Dictionary):
		return fx
	var out := fx.duplicate()
	out["dot"] = (fx["dot"] as Dictionary).merged({"skill": s.id, "ult": s.ultimate})
	return out

## Pulso em toda a área: lentidão que acumula (slow_stack) e congela no N-ésimo pulso (freeze; uma vez por alvo).
static func _pulse(sim: WorldSim, m: Dictionary, owner: SimEntity, st: Dictionary) -> void:
	var s: SkillDef = GameData.skills.get(str(st["skill"]))
	if s == null:
		return
	var center: Vector3 = st["center"]
	var r := float(st["radius"])
	var hits: Dictionary = st["hits"]
	var ss: Dictionary = st["slow_stack"]
	var fr: Dictionary = st["freeze"]
	Events.post(&"skill_effect", s.id, center, center, r)
	for o: SimEntity in m["entities"].duplicate():
		if Vector2(o.position.x - center.x, o.position.z - center.z).length() > r + o.radius or not o.is_alive() or not owner.is_hostile_to(o):
			continue
		hits[o.id] = int(hits.get(o.id, 0)) + 1
		if not ss.is_empty():                 # antes do golpe: o estilhaço de gelo (Combat.frost_mult) pega o retardado
			var pct := minf(float(ss.get("max", 45.0)), float(ss.get("step", 15.0)) * int(hits[o.id]))
			o.put_debuff({"kind": "slow", "id": "storm_slow_%d" % owner.id, "remaining": float(ss.get("duration", 2.0)) * o.stats.cc_mult(), "pct": pct, "frost": true})
		_hit(sim, owner, o, s, float(st["power"]), st["fx"], center, st)
		if not fr.is_empty() and o.is_alive() and int(hits[o.id]) >= int(fr.get("hits", 3)) and not (st["frozen"] as Dictionary).has(o.id):
			st["frozen"][o.id] = true
			sim._apply_effects(owner, o, {"stun": {"duration": float(fr.get("duration", 2.0))}}, 0.0)     # chefe: × 0,4 (resists_cc)

## Fim: implosão opcional ("end": puxa ao centro, chefe não, e bate `power` × multiplicador do lançamento).
static func _end(sim: WorldSim, m: Dictionary, owner: SimEntity, st: Dictionary) -> void:
	var en: Dictionary = st["end"]
	if en.is_empty():
		return
	var s: SkillDef = GameData.skills.get(str(st["skill"]))
	var center: Vector3 = st["center"]
	var r := float(en.get("radius", st["radius"]))
	Events.post(&"skill_effect", s.id, center, center, r)
	for o: SimEntity in m["entities"].duplicate():
		if Vector2(o.position.x - center.x, o.position.z - center.z).length() > r + o.radius or not o.is_alive() or not owner.is_hostile_to(o):
			continue
		if en.get("pull", false) and not (o.monster_def and o.monster_def.resists_cc()):
			var to := center - o.position
			to.y = 0.0
			if to.length() > 0.6:
				sim._charge(o, to.normalized() * (to.length() - 0.5), m)
		sim._strike(owner, o, s, float(en.get("power", 1.0)) * float(st["cast_mult"]), s.kind, center)
