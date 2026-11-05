class_name RaidSystem
extends RefCounted
## Investidas periódicas (MapDef.raid): de tempos em tempos uma leva de monstros nasce em `from` e marcha
## pela `route` até `target` (o povoado). No caminho lutam com quem os ataca ou chega perto (MonsterBrain._march);
## no alvo atacam as sentinelas; passado `lifetime` recuam até `from` e somem. Estado em m["raid"].
##   {timer, n (levas já vindas), ids, t (s da leva atual), arrived, retreat}

static func state(m: Dictionary) -> Dictionary:
	if not m.has("raid"):
		var def: MapDef = m["def"]
		m["raid"] = {"timer": float(def.raid.get("first", 60.0)), "n": 0, "ids": [], "t": 0.0, "arrived": false, "retreat": false}
	return m["raid"]

static func update_raids(sim: WorldSim, m: Dictionary, dt: float) -> void:
	var def: MapDef = m["def"]
	if def.raid.is_empty():
		return
	var st := state(m)
	var ids: Array = st["ids"]
	if not ids.is_empty():
		_update_wave(sim, m, st, dt)
		return
	# o relógio só anda com o jogador no mapa (ou sem jogador: testes/servidor)
	if sim.player != null and sim.player.map_id != def.id:
		return
	st["timer"] = float(st["timer"]) - dt
	if float(st["timer"]) <= 0.0:
		start_raid(sim, m)

## Solta a próxima leva agora (o relógio também chama).
static func start_raid(sim: WorldSim, m: Dictionary) -> Array:
	var def: MapDef = m["def"]
	var st := state(m)
	var r := def.raid
	var n: int = st["n"]
	st["n"] = n + 1
	st["t"] = 0.0
	st["arrived"] = false
	st["retreat"] = false
	var from: Vector3 = r["from"]
	var spawned: Array = []
	for w in r.get("waves", []):
		var nth: int = int(w.get("every_nth", 1))
		if (n + 1) % nth != 0:
			continue
		var mobs: Dictionary = w["mobs"]
		for mid in mobs:
			var mdef: MonsterDef = GameData.monsters.get(mid)
			if mdef == null:
				continue
			for i in int(mobs[mid]):
				var p := MapGeometry.random_walkable(sim, def, from, 3.5)
				var e := sim.spawn_monster(mdef, def.id, p)
				e.raid_id = n
				e.raid_leg = 0
				spawned.append(e.id)
	st["ids"] = spawned
	st["total"] = spawned.size()
	Events.chat_message.emit("Sistema", str(r.get("say_start", "Uma investida inimiga se aproxima!")), "system")
	Events.raid_event.emit(def.id, "start")
	return spawned

static func _update_wave(sim: WorldSim, m: Dictionary, st: Dictionary, dt: float) -> void:
	var def: MapDef = m["def"]
	var r := def.raid
	st["t"] = float(st["t"]) + dt
	var target: Vector3 = r["target"]
	var from: Vector3 = r["from"]
	var radius: float = float(r.get("radius", 25.0))
	var alive: Array = []
	for id in st["ids"]:
		var e: SimEntity = sim.entities.get(id)
		if e == null or not e.is_alive() or e.map_id != def.id:
			continue
		if st["retreat"] and e.aggro_target < 0 and e.position.distance_to(from) < 3.5:
			sim.despawn(e)                      # voltou para casa
			continue
		alive.append(id)
		if not st["arrived"] and e.position.distance_to(target) < radius:
			st["arrived"] = true
			Events.chat_message.emit("Sistema", str(r.get("say_arrived", "Os inimigos chegaram às muralhas!")), "system")
			Events.raid_event.emit(def.id, "arrived")
	if alive.is_empty():
		var repelled: bool = not st["retreat"]
		st["ids"] = []
		st["timer"] = float(r.get("every", 180.0)) + sim.rng.randf_range(-1.0, 1.0) * float(r.get("jitter", 0.0))
		if repelled:
			Events.chat_message.emit("Sistema", str(r.get("say_repelled", "A investida foi repelida!")), "system")
		Events.raid_event.emit(def.id, "repelled" if repelled else "retreated")
		return
	st["ids"] = alive
	if not st["retreat"] and float(st["t"]) >= float(r.get("lifetime", 150.0)):
		st["retreat"] = true
		Events.chat_message.emit("Sistema", str(r.get("say_retreat", "Os inimigos recuam.")), "system")
		Events.raid_event.emit(def.id, "retreat")

## Leitura para a apresentação (faixa do HUD, minimapa): {} sem investida no mapa.
##   {active, alive, total, phase ("march" | "walls" | "retreat"), next_in (s até a próxima, só sem leva), target, radius}
static func status(sim: WorldSim, map_id: String) -> Dictionary:
	var m: Dictionary = sim.maps.get(map_id, {})
	if m.is_empty():
		return {}
	var def: MapDef = m["def"]
	if def.raid.is_empty():
		return {}
	var st := state(m)
	var alive := 0
	for id in st["ids"]:
		var e: SimEntity = sim.entities.get(id)
		if e != null and e.is_alive():
			alive += 1
	var active := not (st["ids"] as Array).is_empty()
	var phase := "retreat" if st["retreat"] else ("walls" if st["arrived"] else "march")
	return {"active": active, "alive": alive, "total": int(st.get("total", alive)), "phase": phase,
		"next_in": 0.0 if active else maxf(0.0, float(st["timer"])), "target": def.raid["target"], "radius": float(def.raid.get("radius", 25.0))}

## Rota da marcha (ida ou volta) e o ponto atual para a entidade.
static func march_point(sim: WorldSim, e: SimEntity) -> Vector3:
	var m: Dictionary = sim.maps[e.map_id]
	var def: MapDef = m["def"]
	var r := def.raid
	var st := state(m)
	var route: Array = r.get("route", []).duplicate()
	route.append(r["target"])
	if st["retreat"]:
		route.reverse()
		route.append(r["from"])
	e.raid_leg = clampi(e.raid_leg, 0, route.size() - 1)
	return route[e.raid_leg]

static func march_len(sim: WorldSim, e: SimEntity) -> int:
	var def: MapDef = sim.maps[e.map_id]["def"]
	return def.raid.get("route", []).size() + (2 if state(sim.maps[e.map_id])["retreat"] else 1)

## Começo da leva: junta na garganta (Balance.RAID_MUSTER s) antes de marchar.
static func mustering(sim: WorldSim, e: SimEntity) -> bool:
	return float(state(sim.maps[e.map_id])["t"]) < Balance.RAID_MUSTER

static func retreating(sim: WorldSim, e: SimEntity) -> bool:
	return state(sim.maps[e.map_id])["retreat"]

## Índice do ponto da rota mais perto (retomar a marcha depois de uma luta, ou ao virar para recuar).
static func nearest_leg(sim: WorldSim, e: SimEntity) -> int:
	var best := 0
	var bd := INF
	var saved := e.raid_leg
	for i in march_len(sim, e):
		e.raid_leg = i
		var d := march_point(sim, e).distance_to(e.position)
		if d < bd:
			bd = d
			best = i
	e.raid_leg = saved
	return best
