class_name HopSystem
extends RefCounted
## Golpes que saltam entre inimigos (efeito "hop_strikes"; Supremas Sete Ventos e Lua Rubra, GDD ultimates-lv40 §9).
## Estado no lançador: SimEntity.hop = {skill, power, left, next_at, every, radius, iframe, prefer, last, fx, fury_end}.
## A cada `every` s some e reaparece ao lado de um inimigo a `radius` m (outro que o anterior, se houver; nunca através
## de parede) e bate com o poder do lançamento. Sem inimigo no raio = acaba na hora. Dash corta o resto.
## d = {"count", "every", "radius", "iframe": "all"|s, "prefer": ""|"unbled", "effects": {...}, "fury_end": n}

## Começa a sequência (o 1º salto sai neste tique).
static func start(sim: WorldSim, e: SimEntity, s: SkillDef, power: float, d: Dictionary) -> void:
	e.hop = {"skill": s.id, "power": power, "left": int(d.get("count", 3)), "next_at": sim.time,
		"every": maxf(0.05, float(d.get("every", 0.2))), "radius": float(d.get("radius", 8.0)), "iframe": d.get("iframe", 0.0),
		"prefer": str(d.get("prefer", "")), "last": -1, "fx": d.get("effects", {}), "fury_end": int(d.get("fury_end", 0))}
	tick(sim, e, sim.maps[e.map_id])

## Dash do lançador: o resto da sequência se perde.
static func cancel(e: SimEntity) -> void:
	e.hop = {}

## Por tique enquanto há sequência (WorldSim._update_entity).
static func tick(sim: WorldSim, e: SimEntity, m: Dictionary) -> void:
	var h := e.hop
	if not e.is_alive() or e.state == SimEntity.State.STUNNED:
		e.hop = {}
		return
	if str(h["iframe"]) == "all":
		e.iframe_left = maxf(e.iframe_left, 0.1)         # intocável a sequência inteira
	var s: SkillDef = GameData.skills.get(str(h["skill"]))
	while int(h["left"]) > 0 and sim.time >= float(h["next_at"]):
		var t := _pick(sim, e, m, h)
		if t == null or s == null:
			_finish(sim, e)
			return
		if not _jump(sim, e, t, m, s):
			h["last"] = t.id                          # sem chão andável ao lado dele: pula este alvo (nunca bate de longe)
			h["skip"] = int(h.get("skip", 0)) + 1
			if int(h["skip"]) > 3:
				_finish(sim, e)
				return
			continue
		if not (h["iframe"] is String) and float(h["iframe"]) > 0.0:
			e.iframe_left = maxf(e.iframe_left, float(h["iframe"]))
		sim._strike(e, t, s, float(h["power"]), s.kind, e.position)
		if not (h["fx"] as Dictionary).is_empty():
			sim._apply_effects(e, t, h["fx"], float(h["power"]))
		h["last"] = t.id
		h["left"] = int(h["left"]) - 1
		h["next_at"] = float(h["next_at"]) + float(h["every"])
	if int(h["left"]) <= 0:
		_finish(sim, e)

static func _finish(sim: WorldSim, e: SimEntity) -> void:
	var n := int(e.hop.get("fury_end", 0))
	e.hop = {}
	if n > 0:
		FistSystem.gain_fury(sim, e, n)

## Próximo alvo: inimigo vivo a `radius` m com caminho livre; prefere outro que o anterior (e, com "unbled", quem não
## sangra por você); entre iguais o mais perto.
static func _pick(sim: WorldSim, e: SimEntity, m: Dictionary, h: Dictionary) -> SimEntity:
	var r := float(h["radius"])
	var best: SimEntity = null
	var best_s := -INF
	for o: SimEntity in m["entities"]:
		var d := o.position.distance_to(e.position)
		if d > r + o.radius or not o.is_alive() or not e.is_hostile_to(o) or o.stealth_left > 0.0:
			continue
		if not MapGeometry.line_walkable(sim, m, e.position, o.position, o.radius + e.radius):
			continue
		var sc := -d
		if o.id != int(h["last"]):
			sc += 100.0
		if str(h["prefer"]) == "unbled" and not _bleeding(e, o):
			sc += 50.0
		if sc > best_s:
			best_s = sc
			best = o
	return best

static func _bleeding(e: SimEntity, o: SimEntity) -> bool:
	for d in o.debuffs:
		if d.get("kind") == "dot" and int(d.get("src", -1)) == e.id:
			return true
	return false

## Some e reaparece ao lado do alvo (do lado de onde veio), encarando-o. false = sem chão andável ao lado (não salta).
static func _jump(sim: WorldSim, e: SimEntity, t: SimEntity, m: Dictionary, s: SkillDef) -> bool:
	var from := e.position
	var dir := t.position - e.position
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = -t.forward()
	dir = dir.normalized()
	var to := t.position - dir * (t.radius + e.radius + Balance.HOP_GAP)
	if not sim.is_walkable(to, m["def"], e.radius):
		return false
	e.position = to
	e.face_towards(t.position)
	Events.post(&"skill_effect", s.id, from, e.position, 0.6)
	return true
