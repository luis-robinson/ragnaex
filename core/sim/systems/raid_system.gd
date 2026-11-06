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
	var step := power_step(sim, m)
	var groups: Array = []
	for w in r.get("waves", []):
		var nth: int = int(w.get("every_nth", 1))
		if (n + 1) % nth == 0:
			groups.append(w["mobs"])
	var extra: Dictionary = r.get("scale_extra", {})
	for at in extra:
		if step >= int(at):
			groups.append(extra[at])
	var top := 0
	for mobs in groups:
		for mid in mobs:
			var mdef: MonsterDef = scaled_def(sim, GameData.monsters.get(mid), step)
			if mdef == null:
				continue
			top = maxi(top, mdef.level)
			for i in int(mobs[mid]):
				var p := MapGeometry.random_walkable(sim, def, from, 3.5)
				var e := sim.spawn_monster(mdef, def.id, p)
				e.raid_id = n
				e.raid_leg = 0
				spawned.append(e.id)
	st["ids"] = spawned
	st["total"] = spawned.size()
	st["step"] = step
	st["level"] = top
	Events.chat_message.emit("Sistema", str(r.get("say_start", "Uma investida inimiga se aproxima!")), "system")
	if step >= 3 and r.has("say_strong"):
		Events.chat_message.emit("Sistema", str(r["say_strong"]), "system")
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
	_rally(sim, m, st, dt)
	if not st["retreat"] and float(st["t"]) >= float(r.get("lifetime", 150.0)):
		st["retreat"] = true
		Events.chat_message.emit("Sistema", str(r.get("say_retreat", "Os inimigos recuam.")), "system")
		Events.raid_event.emit(def.id, "retreat")

## Força da próxima leva: passos de nível do jogador no mapa acima de RAID_SCALE_FROM (máx. RAID_SCALE_TO).
## `m["raid"]["force_level"]` fixa o nível (sondas/testes); sem jogador no mapa a leva vem na força base.
static func power_step(sim: WorldSim, m: Dictionary) -> int:
	var st := state(m)
	var lv := int(st.get("force_level", 0))
	if lv <= 0 and sim.player != null and sim.player.map_id == (m["def"] as MapDef).id:
		lv = sim.player.level
	return clampi(mini(lv, Balance.RAID_SCALE_TO) - Balance.RAID_SCALE_FROM, 0, Balance.RAID_SCALE_TO - Balance.RAID_SCALE_FROM)

## Monstro da investida: x RAID_POWER (vida/ataque) e x RAID_SMART (aggro) sobre o base, mais `step` passos de nível
## (mesmo id: quests, loot e abates contam igual). Guardado por id e passo.
static func scaled_def(sim: WorldSim, base: MonsterDef, step: int) -> MonsterDef:
	if base == null:
		return base
	var key := "%s@%d" % [base.id, step]
	if sim._raid_defs.has(key):
		return sim._raid_defs[key]
	var d: MonsterDef = base.duplicate()
	d.level = base.level + step
	d.hp = base.hp * (1.0 + step * Balance.RAID_SCALE_HP_PCT / 100.0) * Balance.RAID_POWER
	d.atk = base.atk * (1.0 + step * Balance.RAID_SCALE_ATK_PCT / 100.0) * Balance.RAID_POWER
	d.matk = base.matk * (1.0 + step * Balance.RAID_SCALE_ATK_PCT / 100.0) * Balance.RAID_POWER
	d.aggro_range = base.aggro_range * Balance.RAID_SMART
	d.def = base.def * (1.0 + step * Balance.RAID_SCALE_DEF_PCT / 100.0)
	d.mdef = base.mdef * (1.0 + step * Balance.RAID_SCALE_DEF_PCT / 100.0)
	d.xp = int(round(base.xp * (1.0 + step * Balance.RAID_SCALE_XP_PCT / 100.0)))
	sim._raid_defs[key] = d
	return d

## Portão que a leva ataca: o portão do povoado mais perto do fim da rota (sem portões, o próprio alvo).
static func gate_point(def: MapDef) -> Vector3:
	var r := def.raid
	var route: Array = r.get("route", [])
	var last: Vector3 = route[route.size() - 1] if not route.is_empty() else r["target"]
	var best: Vector3 = r["target"]
	var bd := 1e9
	for g in def.town_gates:
		var d: float = (g as Vector3).distance_to(last)
		if d < bd:
			bd = d
			best = g
	return best

## Bastião: aventureiros (jogador e bots) junto das muralhas durante a leva ganham defesa e regeneram vida,
## para segurar o portão por um tempo. Renova a cada 0,5 s; some 1,5 s depois de sair da área ou da leva acabar.
static func _rally(sim: WorldSim, m: Dictionary, st: Dictionary, dt: float) -> void:
	st["rally_t"] = float(st.get("rally_t", 0.0)) - dt
	if float(st["rally_t"]) > 0.0:
		return
	st["rally_t"] = 0.5
	var def: MapDef = m["def"]
	var target: Vector3 = def.raid["target"]
	var reach: float = float(def.raid.get("radius", 25.0)) + Balance.RAID_RALLY_MARGIN
	for e in m["entities"]:
		if e.guard and e.is_alive() and e.position.distance_to(target) <= reach:
			e.hp = minf(e.stats.max_hp, e.hp + e.stats.max_hp * Balance.RAID_RALLY_REGEN * 0.5)    # sentinela: só a regeneração
			continue
		if not (e.kind == SimEntity.Kind.PLAYER or e.kind == SimEntity.Kind.BOT) or not e.is_alive():
			continue
		if e.position.distance_to(target) > reach:
			continue
		var had := false
		for b in e.buffs:
			if b.get("id") == "bastion":
				b["remaining"] = 1.5
				had = true
		if not had:
			e.put_buff({"id": "bastion", "remaining": 1.5, "duration": 1.5, "def_pct": Balance.RAID_RALLY_DEF_PCT})
			e.recompute_stats()
			Events.buff_applied.emit(e.id, "bastion", 1.5)
		e.hp = minf(e.stats.max_hp, e.hp + e.stats.max_hp * Balance.RAID_RALLY_REGEN * 0.5)

## Leitura para a apresentação (faixa do HUD, minimapa): {} sem investida no mapa.
##   {active, alive, total, phase ("march" | "walls" | "retreat"), wave, step (força 0-5), level (maior nível da leva), next_in (s até a próxima, só sem leva), target, radius,
##    gate (portão atacado), ids (invasores vivos)}
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
	return {"active": active, "alive": alive, "total": int(st.get("total", alive)), "phase": phase, "wave": int(st["n"]), "step": int(st.get("step", 0)), "level": int(st.get("level", 0)),
		"next_in": 0.0 if active else maxf(0.0, float(st["timer"])), "target": def.raid["target"], "radius": float(def.raid.get("radius", 25.0)),
		"gate": gate_point(def), "ids": (st["ids"] as Array).duplicate()}

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
