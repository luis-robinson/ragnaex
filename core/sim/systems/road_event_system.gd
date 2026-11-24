class_name RoadEventSystem
extends RefCounted
## Eventos de estrada (GDD design/gdd/living-towns.md 3.5): pequenos encontros que aparecem perto do jogador numa
## estrada, duram pouco e somem se ninguém ajudar. Regras em `MapsCatalog.ROAD_EVENTS[<mapa>][<tipo>]`, pontos em
## `MapDef.road_events` (marcadores `SPAWN_event_<tipo>_NN` do build da zona), números em `Balance.EVENT_*`.
##  - o relógio só anda com o jogador no mapa (mapa sem jogador não sorteia nem simula evento);
##  - no máximo 1 evento ativo por mapa; nunca durante uma investida;
##  - o NPC do evento não morre (NPC comum: ninguém o mira); os monstros não dão XP nem saque de tabela nem contam
##    para quest (LootSystem.on_monster_killed os entrega a `on_mob_killed`): o prêmio é um só, pago uma vez;
##  - nada vai para o save.
## Estado em m["road_event"]: {timer, clock (s com o jogador no mapa), seen (Sim.time do último passo), cd {i: clock},
## rng (próprio: não gasta o sim.rng, a soma das sondas não muda), active {}, leaving [[npc_id, until]], count}.
## active = {kind, i, pos, ids, npc, t, engaged, t_engaged, credit {id: true}, grace}

static func state(sim: WorldSim, m: Dictionary) -> Dictionary:
	if not m.has("road_event"):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([sim.rng.seed, (m["def"] as MapDef).id, "road_event"])
		m["road_event"] = {"timer": Balance.EVENT_FIRST_S + rng.randf() * Balance.EVENT_JITTER_S, "clock": 0.0, "seen": sim.time,
			"cd": {}, "rng": rng, "active": {}, "leaving": [], "count": 0}
	return m["road_event"]

## Regras do tipo de evento neste mapa ({} = não existe).
static func rules(map_id: String, kind: String) -> Dictionary:
	return (MapsCatalog.ROAD_EVENTS.get(map_id, {}) as Dictionary).get(kind, {})

static func update(sim: WorldSim, m: Dictionary, dt: float) -> void:
	var def: MapDef = m["def"]
	if def.road_events.is_empty():
		return
	if sim.player == null or sim.player.map_id != def.id:
		return                                   # sem o jogador no mapa o evento congela (e não nasce)
	var st := state(sim, m)
	var away: float = sim.time - float(st["seen"]) - dt
	st["seen"] = sim.time
	st["clock"] = float(st["clock"]) + dt
	_update_leaving(sim, m, st)
	var a: Dictionary = st["active"]
	if raid_on(m):                               # investida no mapa: o evento termina em silêncio e nenhum nasce
		if not a.is_empty():
			finish(sim, m, "raid")
		return
	if not a.is_empty():
		if away > Balance.EVENT_LIFETIME:        # o jogador saiu (dungeon, cristal) e demorou: expira sem prêmio
			finish(sim, m, "expired")
			return
		_update_active(sim, m, st, a, dt)
		return
	st["timer"] = float(st["timer"]) - dt
	if float(st["timer"]) <= 0.0:
		if start(sim, m).is_empty():
			st["timer"] = Balance.EVENT_RETRY_S   # sem ponto válido agora: tenta de novo daqui a pouco

static func raid_on(m: Dictionary) -> bool:
	var def: MapDef = m["def"]
	for i in RaidSystem.routes(def).size():
		var key := "raid" if i == 0 else "raid_%d" % i
		if m.has(key) and not (m[key]["ids"] as Array).is_empty():
			return true
	return false

## Pontos onde um evento pode nascer agora: a EVENT_NEAR_M..EVENT_FAR_M do jogador, fora da recarga, em chão livre.
static func valid_points(sim: WorldSim, m: Dictionary) -> Array:
	var def: MapDef = m["def"]
	var st := state(sim, m)
	var out: Array = []
	if sim.player == null or sim.player.map_id != def.id:
		return out
	for i in def.road_events.size():
		var p: Dictionary = def.road_events[i]
		var rule := rules(def.id, str(p["kind"]))
		if rule.is_empty() or not WorldState.active(sim, rule):     # tipo com `if`/`unless` (ex.: escolta élfica some depois do Rei)
			continue
		var d: float = (p["pos"] as Vector3).distance_to(sim.player.position)
		if d < Balance.EVENT_NEAR_M or d > Balance.EVENT_FAR_M:
			continue
		if float(st["clock"]) < float((st["cd"] as Dictionary).get(i, 0.0)):
			continue
		if not MapGeometry.is_walkable(sim, p["pos"], def, 0.6):
			continue
		out.append(i)
	return out

## Monstro do evento: o do ponto, nunca acima do spawner comum mais perto (GDD 4), sem XP, ouro nem saque de tabela,
## preso a EVENT_LEASH_M do ponto. Guardado em sim._raid_defs (mesma ideia do RaidSystem.scaled_def).
static func event_def(sim: WorldSim, base: MonsterDef, level: int, rule: Dictionary) -> MonsterDef:
	level = clampi(level, 1, base.level)
	var key := "%s@event@%d" % [base.id, level]
	if sim._raid_defs.has(key):
		return sim._raid_defs[key]
	var d: MonsterDef = base.duplicate()
	var k := float(level) / float(maxi(1, base.level))
	d.level = level
	d.hp = base.hp * lerpf(1.0, k, Balance.EVENT_MOB_SCALE)
	d.atk = base.atk * lerpf(1.0, k, Balance.EVENT_MOB_SCALE)
	d.matk = base.matk * lerpf(1.0, k, Balance.EVENT_MOB_SCALE)
	d.name = str(rule.get("mob_name", base.name))
	d.xp = 0
	d.gold_min = 0
	d.gold_max = 0
	d.loot_table = ""
	d.leash_range = Balance.EVENT_LEASH_M
	sim._raid_defs[key] = d
	return d

## Nível do spawner comum mais perto do ponto, dentro da faixa do mapa.
static func point_level(def: MapDef, pos: Vector3) -> int:
	var best := INF
	var lv := def.level_range.y
	for sp in def.spawners:
		var md: MonsterDef = GameData.monsters.get(str(sp["monster_id"]))
		if md == null or md.is_boss or md.elite_of != "" or int(sp.get("count", 1)) <= 1:
			continue
		var d: float = (sp["pos"] as Vector3).distance_to(pos)
		if d < best:
			best = d
			lv = md.level
	return clampi(lv, def.level_range.x, def.level_range.y)

## Começa um evento agora (o relógio também chama). `point` < 0 = sorteia entre os válidos. Devolve o evento ({} = não deu).
static func start(sim: WorldSim, m: Dictionary, point: int = -1) -> Dictionary:
	var def: MapDef = m["def"]
	var st := state(sim, m)
	if not (st["active"] as Dictionary).is_empty() or raid_on(m) or def.road_events.is_empty():
		return {}
	var rng: RandomNumberGenerator = st["rng"]
	if point < 0:
		var ok := valid_points(sim, m)
		if ok.is_empty():
			return {}
		point = ok[rng.randi() % ok.size()]
	var p: Dictionary = def.road_events[point]
	var rule := rules(def.id, str(p["kind"]))
	var base: MonsterDef = GameData.monsters.get(str(p.get("mob", rule.get("mob", ""))))
	if rule.is_empty() or base == null:
		return {}
	var pos: Vector3 = p["pos"]
	var mdef := event_def(sim, base, point_level(def, pos), rule)
	var count: Array = rule.get("count", [2, 3])
	var n := mini(rng.randi_range(int(count[0]), int(count[1])), Balance.EVENT_MAX_MOBS)
	var ids: Array = []
	var a0 := rng.randf() * TAU
	for i in n:
		var at := pos
		for k in 8:                                # em volta do lavrador, em chão livre
			var ang := a0 + TAU * float(i) / float(n) + k * 0.7
			var q := pos + Vector3(cos(ang), 0.0, sin(ang)) * (2.4 + 0.4 * k)
			if MapGeometry.is_walkable(sim, q, def, mdef.radius):
				at = q
				break
		var mob := sim.spawn_monster(mdef, def.id, at)
		mob.home_position = pos
		mob.road_event = true
		mob.face_towards(pos)
		ids.append(mob.id)
	var v: Array = rule.get("victim", ["Viajante", Color(0.6, 0.5, 0.4)])
	var npc := sim._spawn_npc({"id": "road_event_victim", "name": str(v[0]), "role": "villager", "color": v[1], "pos": pos,
		"dialog": rule.get("cry", []), "barks": rule.get("cry", []), "look_seed": 4100 + point * 7 + int(st["count"]), "facing": 180.0,
		"road_event": str(p["kind"])}, def.id)
	st["count"] = int(st["count"]) + 1
	st["active"] = {"kind": str(p["kind"]), "i": point, "pos": pos, "ids": ids, "npc": npc.id, "t": 0.0, "engaged": false, "t_engaged": 0.0,
		"credit": {}, "grace": false}
	_set_grace(sim, st["active"])
	_say(sim, npc, rule.get("cry", []), rng)
	Events.post(&"road_event_started", def.id, str(p["kind"]), pos)
	return st["active"]

static func _say(sim: WorldSim, npc: SimEntity, lines: Array, rng: RandomNumberGenerator) -> void:
	if npc == null or lines.is_empty() or sim.player == null or sim.player.map_id != npc.map_id:
		return
	Events.post(&"notification", "%s: %s" % [npc.name, str(lines[rng.randi() % lines.size()])])

## Graça dos bots (GDD 3.7): nos primeiros EVENT_BOT_GRACE s, com o jogador a até EVENT_FAR_M do ponto, bot de fora do
## grupo dele não mira os monstros do evento nem é mirado por eles (SimEntity.is_hostile_to).
static func _set_grace(sim: WorldSim, a: Dictionary) -> void:
	var on: bool = float(a["t"]) < Balance.EVENT_BOT_GRACE and sim.player != null \
		and sim.player.position.distance_to(a["pos"]) <= Balance.EVENT_FAR_M
	a["grace"] = on
	for id in a["ids"]:
		var mob: SimEntity = sim.entities.get(id)
		if mob != null:
			mob.road_grace = on
			mob.road_grace_party = sim.player.party_id if on else -1

static func _update_active(sim: WorldSim, m: Dictionary, st: Dictionary, a: Dictionary, dt: float) -> void:
	a["t"] = float(a["t"]) + dt
	var alive := 0
	for id in a["ids"]:
		var mob: SimEntity = sim.entities.get(id)
		if mob != null and mob.is_alive():
			alive += 1
	if alive == 0:
		finish(sim, m, "resolved")
		return
	if bool(a["grace"]) or float(a["t"]) < Balance.EVENT_BOT_GRACE + dt:
		_set_grace(sim, a)
	if not bool(a["engaged"]):
		var near2: float = Balance.EVENT_ENGAGE_M * Balance.EVENT_ENGAGE_M
		for c: SimEntity in m.get("chars", []):
			if c.is_alive() and c.position.distance_squared_to(a["pos"]) <= near2 and (c.kind == SimEntity.Kind.PLAYER or not bool(a["grace"])):
				a["engaged"] = true
				break
		if not bool(a["engaged"]) and float(a["t"]) >= Balance.EVENT_LIFETIME:
			finish(sim, m, "expired")
		return
	a["t_engaged"] = float(a["t_engaged"]) + dt
	if float(a["t_engaged"]) >= Balance.EVENT_RESOLVE_S:
		finish(sim, m, "failed")

## Abate de um monstro de evento (LootSystem.on_monster_killed): anota quem contribuiu; sem XP de abate, saque ou quest.
static func on_mob_killed(sim: WorldSim, mob: SimEntity, killer: SimEntity) -> void:
	var m: Dictionary = sim.maps.get(mob.map_id, {})
	if m.is_empty() or not m.has("road_event"):
		return
	var a: Dictionary = m["road_event"]["active"]
	if a.is_empty() or not (a["ids"] as Array).has(mob.id):
		return
	var credit := LootSystem.top_damager(sim, mob, killer)
	if credit != null and credit.is_character():
		for c: SimEntity in PartySystem.kill_sharers(sim, credit, mob):
			a["credit"][c.id] = true
	var left := 0
	for id in a["ids"]:
		var o: SimEntity = sim.entities.get(id)
		if o != null and o != mob and o.is_alive():
			left += 1
	if left == 0:
		finish(sim, m, "resolved")

## Prêmio do evento para um personagem de nível `level` num grupo de `n` que contribuíram: {xp, gold}.
static func reward_of(level: int, n: int) -> Dictionary:
	n = maxi(1, n)
	var share := (1.0 + Balance.PARTY_XP_BONUS * (n - 1)) / float(n)
	return {"xp": int(round(Balance.xp_for_level(level) * Balance.EVENT_XP_FRAC * share)),
		"gold": maxi(1, int(ceil((Balance.EVENT_COIN_BASE + Balance.EVENT_COIN_PER_LV * level) / float(n))))}

## Termina o evento: "resolved" paga quem contribuiu (uma vez), qualquer outro fim só limpa. Os monstros que sobraram
## somem com ele, o ponto entra em recarga e o relógio do próximo recomeça.
static func finish(sim: WorldSim, m: Dictionary, outcome: String) -> void:
	var def: MapDef = m["def"]
	var st := state(sim, m)
	var a: Dictionary = st["active"]
	if a.is_empty():
		return
	st["active"] = {}
	var rng: RandomNumberGenerator = st["rng"]
	var rule := rules(def.id, str(a["kind"]))
	var npc: SimEntity = sim.entities.get(a["npc"])
	for id in a["ids"]:
		var mob: SimEntity = sim.entities.get(id)
		if mob != null:
			mob.road_grace = false
			if mob.is_alive():
				sim.despawn(mob)
	if outcome == "resolved":
		var who: Array = []
		for id in a["credit"]:
			var c: SimEntity = sim.entities.get(id)
			if c != null and c.is_character() and c.map_id == def.id:
				who.append(c)
		var item := str(rule.get("reward_item", ""))
		for c: SimEntity in who:
			var r := reward_of(c.level, who.size())
			ProgressionSystem.gain_xp(sim, c, int(r["xp"]))
			c.gold += int(r["gold"])
			if item != "" and GameData.items.has(item):
				c.add_item(item, int(rule.get("reward_count", 1)))
				Events.post(&"item_gained", c.id, item, int(rule.get("reward_count", 1)))
		_say(sim, npc, rule.get("thanks", []), rng)
		# bot que resolveu sem o jogador conta no chat (mundo vivo)
		if not who.is_empty() and not who.any(func(c): return c.kind == SimEntity.Kind.PLAYER):
			var lines: Array = rule.get("bot_chat", [])
			if not lines.is_empty():
				Events.post(&"chat_message", (who[0] as SimEntity).name, str(lines[rng.randi() % lines.size()]), "global")
	elif outcome == "failed":
		_say(sim, npc, rule.get("flee", []), rng)
	if npc != null:                              # o lavrador vai embora andando (para casa, ou ferido para a vila) e some
		var home: Array = rule.get("home", [def.town_center.x, def.town_center.z])
		var to := Vector3(float(home[0]), 0.0, float(home[1])) if outcome == "resolved" else def.town_center
		npc.npc_data["route"] = [[to.x, to.z]]
		npc.npc_data["flow"] = true
		npc.npc_data.erase("barks")
		npc.npc_goal = Vector3.ZERO
		npc.npc_wait = 0.0
		var keep: float = Balance.EVENT_LEAVE_S if outcome in ["resolved", "failed"] else 0.0
		(st["leaving"] as Array).append([npc.id, float(st["clock"]) + keep])
	st["cd"][int(a["i"])] = float(st["clock"]) + Balance.EVENT_POINT_CD_S
	st["timer"] = Balance.EVENT_EVERY_S + rng.randf() * Balance.EVENT_JITTER_S
	st["last"] = {"kind": a["kind"], "i": a["i"], "outcome": outcome, "paid": (a["credit"] as Dictionary).size() if outcome == "resolved" else 0}
	Events.post(&"road_event_ended", def.id, str(a["kind"]), outcome)

static func _update_leaving(sim: WorldSim, m: Dictionary, st: Dictionary) -> void:
	var leaving: Array = st["leaving"]
	if leaving.is_empty():
		return
	for i in range(leaving.size() - 1, -1, -1):
		if float(st["clock"]) >= float(leaving[i][1]):
			sim.despawn(sim.entities.get(leaving[i][0]))
			leaving.remove_at(i)

## Resumo para a apresentação/testes: {active, kind, pos, t, engaged, grace, mobs (vivos), timer, last}.
static func status(sim: WorldSim, map_id: String) -> Dictionary:
	var m: Dictionary = sim.maps.get(map_id, {})
	if m.is_empty() or (m["def"] as MapDef).road_events.is_empty():
		return {"active": false}
	var st := state(sim, m)
	var a: Dictionary = st["active"]
	var out := {"active": not a.is_empty(), "timer": st["timer"], "last": st.get("last", {})}
	if not a.is_empty():
		var alive := 0
		for id in a["ids"]:
			var mob: SimEntity = sim.entities.get(id)
			if mob != null and mob.is_alive():
				alive += 1
		out.merge({"kind": a["kind"], "pos": a["pos"], "t": a["t"], "engaged": a["engaged"], "grace": a["grace"], "mobs": alive, "npc": a["npc"], "i": a["i"]})
	return out
