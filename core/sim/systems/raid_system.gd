class_name RaidSystem
extends RefCounted
## Investidas periódicas (MapDef.raid): de tempos em tempos uma leva de monstros nasce em `from` e marcha
## pela `route` até `target` (o povoado). No caminho lutam com quem os ataca ou chega perto (MonsterBrain._march);
## no alvo atacam as sentinelas; passado `lifetime` recuam até `from` e somem. Estado em m["raid"].
##   {timer, n (levas já vindas), ids, t (s da leva atual), arrived, retreat}
## Várias rotas (cidade atacada por vários lados): a rota 0 é `MapDef.raid`, as outras `MapDef.raids`; cada uma com
## estado próprio (m["raid"], m["raid_1"]...) e a entidade sabe a dela (`SimEntity.raid_route`). Rota com `if`/`unless`
## (WorldState) só solta leva enquanto vale: a fortaleza daquele lado retomada cala a investida dela.

## Fortalezas retomadas: rotas do mapa caladas pela quest delas (`unless` concluída). Sondas fixam em state(m)["force_reclaimed"].
static func reclaimed(sim: WorldSim, m: Dictionary) -> int:
	var st := state(m)
	if st.has("force_reclaimed"):
		return int(st["force_reclaimed"])
	var n := 0
	for r in routes(m["def"]):
		if r.has("unless") and not WorldState.active(sim, {"unless": r["unless"]}):
			n += 1
	return n

## Rotas de investida do mapa (vazio = sem investida).
static func routes(def: MapDef) -> Array:
	var out: Array = []
	if not def.raid.is_empty():
		out.append(def.raid)
	out.append_array(def.raids)
	return out

static func route_def(def: MapDef, i: int) -> Dictionary:
	var all := routes(def)
	if all.is_empty():
		return def.raid
	return all[clampi(i, 0, all.size() - 1)]

static func state(m: Dictionary, i: int = 0) -> Dictionary:
	var key := "raid" if i == 0 else "raid_%d" % i
	if not m.has(key):
		var r := route_def(m["def"], i)
		m[key] = {"timer": float(r.get("first", 60.0)), "n": 0, "ids": [], "t": 0.0, "arrived": false, "retreat": false}
	return m[key]

static func update_raids(sim: WorldSim, m: Dictionary, dt: float) -> void:
	var def: MapDef = m["def"]
	var all := routes(def)
	if float(m.get("sortie_cd", 0.0)) > 0.0:
		m["sortie_cd"] = float(m["sortie_cd"]) - dt
	for i in all.size():
		var st := state(m, i)
		if not (st["ids"] as Array).is_empty():
			_update_wave(sim, m, st, dt, i)
			continue
		if not WorldState.active(sim, all[i]):
			continue
		# o relógio só anda com o jogador no mapa (ou sem jogador: testes/servidor)
		if sim.player != null and sim.player.map_id != def.id:
			continue
		st["timer"] = float(st["timer"]) - dt
		if float(st["timer"]) <= 0.0:
			start_raid(sim, m, i)

## Solta a próxima leva agora (o relógio também chama).
static func start_raid(sim: WorldSim, m: Dictionary, i: int = 0) -> Array:
	var def: MapDef = m["def"]
	var st := state(m, i)
	var r := route_def(def, i)
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
	# fúria: cada fortaleza retomada aumenta a leva dos fronts que sobram (x RAID_RECLAIM_MULT^k) e soma elites
	var k := reclaimed(sim, m)
	var mult := pow(Balance.RAID_RECLAIM_MULT, k)
	var rx: Dictionary = r.get("reclaim_extra", {})
	var elites: Array = []
	for at in rx:
		if k >= int(at):
			elites.append(rx[at])
	var total := 0
	for mobs in groups:
		for mid in mobs:
			total += int(round(int(mobs[mid]) * mult))
	var fit := minf(1.0, float(Balance.RAID_WAVE_CAP) / maxf(1.0, float(total)))
	var scaled: Array = []
	for mobs in groups:
		var g := {}
		for mid in mobs:
			g[mid] = maxi(1, int(round(int(mobs[mid]) * mult * fit)))
		scaled.append(g)
	groups = scaled + elites
	if k > int(st.get("seen_reclaimed", 0)):
		st["seen_reclaimed"] = k
		if r.has("say_reclaim"):
			Events.chat_message.emit("Sistema", str(r["say_reclaim"]), "system")
	var top := 0
	for mobs in groups:
		for mid in mobs:
			var mdef: MonsterDef = scaled_def(sim, GameData.monsters.get(mid), step)
			if mdef == null:
				continue
			top = maxi(top, mdef.level)
			for _k in int(mobs[mid]):
				var p := MapGeometry.random_walkable(sim, def, from, 3.5)
				var e := sim.spawn_monster(mdef, def.id, p)
				e.raid_id = n
				e.raid_leg = 0
				e.raid_route = i
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

static func _update_wave(sim: WorldSim, m: Dictionary, st: Dictionary, dt: float, i: int = 0) -> void:
	var def: MapDef = m["def"]
	var r := route_def(def, i)
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
			if not def.sortie.is_empty() and float(m.get("sortie_cd", 0.0)) <= 0.0:
				m["sortie_cd"] = float(def.sortie.get("cooldown", Balance.RAID_SORTIE_COOLDOWN))
				st["sortie"] = WorldState.spawn_sortie(sim, m, i)
	if alive.is_empty():
		WorldState.end_sortie(sim, st.get("sortie", []))
		st["sortie"] = []
		var repelled: bool = not st["retreat"]
		st["ids"] = []
		st["timer"] = (float(r.get("every", 180.0)) + sim.rng.randf_range(-1.0, 1.0) * float(r.get("jitter", 0.0))) * pow(Balance.RAID_RECLAIM_EVERY, reclaimed(sim, m))
		if repelled:
			Events.chat_message.emit("Sistema", str(r.get("say_repelled", "A investida foi repelida!")), "system")
		Events.raid_event.emit(def.id, "repelled" if repelled else "retreated")
		return
	st["ids"] = alive
	_rally(sim, m, st, dt, i)
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
static func gate_point(def: MapDef, i: int = 0) -> Vector3:
	var r := route_def(def, i)
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
static func _rally(sim: WorldSim, m: Dictionary, st: Dictionary, dt: float, i: int = 0) -> void:
	st["rally_t"] = float(st.get("rally_t", 0.0)) - dt
	if float(st["rally_t"]) > 0.0:
		return
	st["rally_t"] = 0.5
	var r := route_def(m["def"], i)
	var target: Vector3 = r["target"]
	var reach: float = float(r.get("radius", 25.0)) + Balance.RAID_RALLY_MARGIN
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
	var all := routes(def)
	if all.is_empty():
		return {}
	var i := _status_route(sim, m, all)
	var r: Dictionary = all[i]
	var st := state(m, i)
	var alive := 0
	for id in st["ids"]:
		var e: SimEntity = sim.entities.get(id)
		if e != null and e.is_alive():
			alive += 1
	var active := not (st["ids"] as Array).is_empty()
	var phase := "retreat" if st["retreat"] else ("walls" if st["arrived"] else "march")
	return {"active": active, "alive": alive, "total": int(st.get("total", alive)), "phase": phase, "wave": int(st["n"]), "step": int(st.get("step", 0)), "level": int(st.get("level", 0)),
		"next_in": 0.0 if active else maxf(0.0, float(st["timer"])), "target": r["target"], "radius": float(r.get("radius", 25.0)),
		"gate": gate_point(def, i), "ids": (st["ids"] as Array).duplicate(), "route": i, "side": str(r.get("side", ""))}

## Rota que o HUD mostra: a leva viva com mais invasores; sem leva, a próxima a sair (só rotas que ainda valem).
static func _status_route(sim: WorldSim, m: Dictionary, all: Array) -> int:
	var best := 0
	var best_alive := 0
	var soon := INF
	var soon_i := -1
	for i in all.size():
		var st := state(m, i)
		var n := (st["ids"] as Array).size()
		if n > best_alive:
			best_alive = n
			best = i
		elif n == 0 and WorldState.active(sim, all[i]) and float(st["timer"]) < soon:
			soon = float(st["timer"])
			soon_i = i
	return best if best_alive > 0 else maxi(soon_i, 0)

## Rota da marcha (ida ou volta) e o ponto atual para a entidade.
static func march_point(sim: WorldSim, e: SimEntity) -> Vector3:
	var m: Dictionary = sim.maps[e.map_id]
	var r := route_def(m["def"], e.raid_route)
	var st := state(m, e.raid_route)
	var route: Array = r.get("route", []).duplicate()
	route.append(r["target"])
	if st["retreat"]:
		route.reverse()
		route.append(r["from"])
	e.raid_leg = clampi(e.raid_leg, 0, route.size() - 1)
	return route[e.raid_leg]

static func march_len(sim: WorldSim, e: SimEntity) -> int:
	var m: Dictionary = sim.maps[e.map_id]
	return route_def(m["def"], e.raid_route).get("route", []).size() + (2 if state(m, e.raid_route)["retreat"] else 1)

## Começo da leva: junta na garganta (Balance.RAID_MUSTER s) antes de marchar.
static func mustering(sim: WorldSim, e: SimEntity) -> bool:
	return float(state(sim.maps[e.map_id], e.raid_route)["t"]) < Balance.RAID_MUSTER

static func retreating(sim: WorldSim, e: SimEntity) -> bool:
	return state(sim.maps[e.map_id], e.raid_route)["retreat"]

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
