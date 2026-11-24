class_name SiegeSystem
extends RefCounted
## Cerco Vivo (design/gdd/act2-siege-life.md): o relógio do cerco de um povoado (MapDef.siege). Sem estado no save:
## trechos, pressão e cenário vêm de `quests_completed` (WorldState); relógios e Chamas vivem em m["siege"].
## - Trechos (`segments`): cada um fecha com a quest dele ou com `close_all` (WorldState "a|b"). Aberto = a rota do
##   trecho (`cerco_<id>`) vale e a Horda entra por ele; fechado = a leva daquele lado vai ao portão (`gate_route`).
## - Pressão 0-3 (`pressure`): frequência (SIEGE_EVERY_MULT), tamanho (SIEGE_SIZE_MULT), leva grande (SIEGE_BIG_NTH) e
##   assédio (só p >= 2). p = 1 usa a rota `low_route` (patrulha rara); p = 0 = paz.
## - Por mapa: números em Balance.SIEGE_MAP (num), ordem dos lados em `rotation`, tema da salva em `volley_skill` (Posto dos Caçadores).
## - Uma leva por vez no mapa, revezando os lados; depois de repelida, calmaria (SIEGE_QUIET_MIN).
## - Assédio (`harass_route`): atiradores nascem no ponto de tiro, SIEGE_HARASS_WINDUP s depois soltam uma salva de círculos
##   avisados (dano = % da vida, não esquivável) perto de uma brecha aberta, e somem. Matar o atirador cancela os círculos dele.
## - Batedores (spawner com `horn`): em luta há SIEGE_HORN_DELAY s tocam a trompa e adiantam a próxima leva.
## - Reserva (`responder` no NPC sentinela): corre para o alvo da leva e volta ao posto quando ela acaba.
## - Repelida: buff Colônia de Pé em quem defendeu (e conta nas quests DEFEND); chegou e não foi repelida: Chamas (visual).
## Estado m["siege"]: {wave_t, harass_t, quiet, n, side, horns, scorch, p, shooters, age, shot, seen, horn_t, horned, hold}
##   `hold` = relógios parados (sondas/testes que soltam as levas à mão).

const MORALE_BUFF := "colonia_de_pe"
const VOLLEY_SKILL := "mob_fire_arrows"        # tema/som do círculo da salva (flechas de fogo)
const SCAN := 0.5
const SERVICE_ROLES := ["smith", "alchemy", "merchant", "storage", "crystal", "board"]

static func managed(def: MapDef) -> bool:
	return not def.siege.is_empty()

## Número do cerco no mapa: Balance.SIEGE_MAP[<mapa>][key] se houver, senão o SIEGE_* geral (`base`).
static func num(def: MapDef, key: String, base: float) -> float:
	if def == null:
		return base
	return float((Balance.SIEGE_MAP.get(def.id, {}) as Dictionary).get(key, base))

static func state(m: Dictionary) -> Dictionary:
	if not m.has("siege"):
		var def: MapDef = m.get("def")
		m["siege"] = {"wave_t": num(def, "first_wave", Balance.SIEGE_FIRST_WAVE), "harass_t": num(def, "first_harass", Balance.SIEGE_FIRST_HARASS), "quiet": 0.0, "n": 0, "side": 0, "horns": 0,
			"scorch": false, "p": 2, "shooters": [], "age": 0.0, "shot": false, "seen": {}, "horn_t": {}, "horned": {}, "scan": 0.0, "salvo": {}}
	return m["siege"]

## Pressão do mapa agora: a 1ª linha de `pressure` que vale (a tabela vai da mais específica à geral).
static func pressure(sim: WorldSim, def: MapDef) -> int:
	for row in def.siege.get("pressure", []):
		if WorldState.active(sim, row):
			return int(row["p"])
	return 0

## Condição de "trecho fechado" (a quest dele ou a que fecha tudo).
static func segment_cond(def: MapDef, seg: Dictionary) -> String:
	var all := str(def.siege.get("close_all", ""))
	return str(seg["quest"]) if all == "" else "%s|%s" % [seg["quest"], all]

static func segment_closed(sim: WorldSim, def: MapDef, seg: Dictionary) -> bool:
	return WorldState.active(sim, {"if": segment_cond(def, seg)})

static func route_index(def: MapDef, side: String) -> int:
	var all := RaidSystem.routes(def)
	for i in all.size():
		if str(all[i].get("side", "")) == side:
			return i
	return -1

## Rota com leva viva no mapa (-1 = nenhuma). Vale também para a leva solta à mão (sonda).
static func active_route(m: Dictionary) -> int:
	var all := RaidSystem.routes(m["def"])
	for i in all.size():
		if not (RaidSystem.state(m, i)["ids"] as Array).is_empty():
			return i
	return -1

## Multiplicador do tamanho da leva pela pressão (RaidSystem.start_raid).
static func size_mult(sim: WorldSim, m: Dictionary) -> float:
	if not managed(m["def"]):
		return 1.0
	return float(Balance.SIEGE_SIZE_MULT.get(pressure(sim, m["def"]), 1.0))

## De quantas em quantas levas vem a leva grande (grupos com `every_nth` > 1).
static func big_nth(sim: WorldSim, m: Dictionary, nth: int) -> int:
	if nth <= 1 or not managed(m["def"]):
		return nth
	return int(Balance.SIEGE_BIG_NTH.get(pressure(sim, m["def"]), nth))

## F1: s até a próxima leva pela rota `r` na pressão `p` (u = sorteio -1..1).
static func wave_interval(r: Dictionary, p: int, u: float) -> float:
	return maxf(Balance.SIEGE_QUIET_MIN, float(r.get("every", 90.0)) * float(Balance.SIEGE_EVERY_MULT.get(p, 1.0)) + u * float(r.get("jitter", 0.0)))

static func harass_interval(p: int, u: float, def: MapDef = null) -> float:
	return maxf(Balance.SIEGE_QUIET_MIN * 0.5, num(def, "harass_every", Balance.SIEGE_HARASS_EVERY) * float(Balance.SIEGE_HARASS_MULT.get(p, 1.0)) + u * Balance.SIEGE_HARASS_JITTER)

static func update(sim: WorldSim, m: Dictionary, dt: float) -> void:
	var def: MapDef = m["def"]
	if def.siege.is_empty():
		return
	var st := state(m)
	var wave := active_route(m)
	st["scan"] = float(st["scan"]) - dt
	if float(st["scan"]) <= 0.0:
		st["scan"] = SCAN
		_responders(sim, m, wave)
		_horns(sim, m, st)
		if wave >= 0:
			_presence(sim, m, st, wave)
	_update_harass(sim, m, st, dt)
	if st.get("hold", false):
		return
	# o relógio só anda com o jogador no mapa (ou sem jogador: testes/servidor), como o do RaidSystem
	if sim.player != null and sim.player.map_id != def.id:
		return
	var p := pressure(sim, def)
	st["p"] = p
	if p <= 0:
		return
	st["quiet"] = maxf(0.0, float(st["quiet"]) - dt)
	st["wave_t"] = float(st["wave_t"]) - dt                      # início a início: anda também durante a leva
	if wave < 0 and float(st["wave_t"]) <= 0.0 and float(st["quiet"]) <= 0.0:
		_start_wave(sim, m, st, p)
		wave = active_route(m)
	if p < 2:
		return
	st["harass_t"] = float(st["harass_t"]) - dt                  # anda sempre; a salva espera a leva acabar (R12)
	if wave >= 0 or not (st["shooters"] as Array).is_empty() or float(st["harass_t"]) > 0.0:
		return
	var hi := route_index(def, str(def.siege.get("harass_route", "")))
	if hi >= 0 and WorldState.active(sim, RaidSystem.routes(def)[hi]):
		start_harass(sim, m)

## Rota da próxima leva: o lado da vez; trecho aberto = a brecha dele, fechado = o portão; p <= 1 = a patrulha.
static func next_route(sim: WorldSim, m: Dictionary, p: int) -> int:
	var def: MapDef = m["def"]
	var all := RaidSystem.routes(def)
	var st := state(m)
	if p >= 2 and def.siege.has("rotation"):        # ordem própria dos lados ("gate" = o portão; trecho fechado também cai no portão)
		var rot: Array = def.siege["rotation"]
		var key := str(rot[int(st["side"]) % rot.size()])
		for seg in def.siege.get("segments", []):
			if str(seg["id"]) == key:
				var si := route_index(def, str(seg["route"]))
				if si >= 0 and WorldState.active(sim, all[si]):
					return si
		var gi := route_index(def, str(def.siege.get("gate_route", "")))
		if gi >= 0 and WorldState.active(sim, all[gi]):
			return gi
	elif p >= 2:
		var segs: Array = def.siege.get("segments", [])
		if not segs.is_empty():
			var seg: Dictionary = segs[int(st["side"]) % segs.size()]
			var i := route_index(def, str(seg["route"]))
			if i >= 0 and WorldState.active(sim, all[i]):
				return i
		var g := route_index(def, str(def.siege.get("gate_route", "")))
		if g >= 0 and WorldState.active(sim, all[g]):
			return g
	var low := route_index(def, str(def.siege.get("low_route", "")))
	if low >= 0 and WorldState.active(sim, all[low]):
		return low
	return -1

static func _start_wave(sim: WorldSim, m: Dictionary, st: Dictionary, p: int) -> void:
	var i := next_route(sim, m, p)
	st["side"] = int(st["side"]) + 1
	if i < 0:
		st["wave_t"] = Balance.SIEGE_QUIET_MIN
		return
	start_wave(sim, m, i)

## Solta agora a leva da rota `i` (o relógio também chama) e marca a próxima. Devolve os ids.
static func start_wave(sim: WorldSim, m: Dictionary, i: int) -> Array:
	var st := state(m)
	var r := RaidSystem.route_def(m["def"], i)
	RaidSystem.state(m, i)["n"] = int(st["n"])                  # leva grande pela contagem do mapa, não da rota
	st["n"] = int(st["n"]) + 1
	st["horns"] = 0
	st["seen"] = {}
	st["wave_t"] = wave_interval(r, pressure(sim, m["def"]), sim.rng.randf_range(-1.0, 1.0))
	return RaidSystem.start_raid(sim, m, i)

## Fim de uma leva (RaidSystem._update_wave): repelida -> calmaria, Colônia de Pé, DEFEND, apaga as Chamas;
## chegou e recuou sem ser repelida -> Chamas. Leva que nem chegou não muda nada (R17).
static func on_wave_end(sim: WorldSim, m: Dictionary, _i: int, repelled: bool, arrived: bool) -> void:
	var def: MapDef = m["def"]
	if def.siege.is_empty():
		return
	var st := state(m)
	if repelled:
		st["quiet"] = Balance.SIEGE_QUIET_MIN
		st["harass_t"] = maxf(float(st["harass_t"]), Balance.SIEGE_QUIET_MIN * 0.5)
		if st["scorch"]:
			st["scorch"] = false
			Events.post(&"siege_event", def.id, "fire_out")
		for id in st["seen"]:
			var e: SimEntity = sim.entities.get(id)
			if e == null or not e.is_alive() or e.map_id != def.id:
				continue
			e.put_buff({"id": "colonia_de_pe", "remaining": Balance.SIEGE_MORALE_TIME, "duration": Balance.SIEGE_MORALE_TIME,
				"xp_pct": Balance.SIEGE_MORALE_XP_PCT, "map": def.id})
			Events.post(&"buff_applied", e.id, MORALE_BUFF, Balance.SIEGE_MORALE_TIME)
			if e.kind == SimEntity.Kind.PLAYER:
				QuestSystem.on_defend(e, def.id)
		Events.post(&"siege_event", def.id, "repelled")
	elif arrived and not st["scorch"]:
		st["scorch"] = true
		if def.siege.has("say_scorch"):
			Events.post(&"chat_message", "Sistema", str(def.siege["say_scorch"]), "system")
		Events.post(&"siege_event", def.id, "scorch")
	st["seen"] = {}

## Ainda cabe um bot avulso na defesa desta leva? (BotBrain._defend; mapa sem cerco = sempre)
static func bot_may_defend(m: Dictionary, wave: int) -> bool:
	if not managed(m["def"]):
		return true
	var n := 0
	for e: SimEntity in m["entities"]:
		if e.kind == SimEntity.Kind.BOT and e.brain is BotBrain and (e.brain as BotBrain).defend_wave == wave:
			n += 1
	return n < Balance.SIEGE_BOT_DEFENDERS

## Colônia de Pé: multiplicador da XP de abate de `e` neste mapa (LootSystem).
static func xp_mult(e: SimEntity, map_id: String) -> float:
	for b in e.buffs:
		if b.get("id") == MORALE_BUFF and str(b.get("map", "")) == map_id:
			return 1.0 + float(b.get("xp_pct", 0.0)) / 100.0
	return 1.0

## Quem esteve no raio do Bastião do alvo durante a leva (recebe a Colônia de Pé e conta DEFEND).
static func _presence(_sim: WorldSim, m: Dictionary, st: Dictionary, wave: int) -> void:
	var r := RaidSystem.route_def(m["def"], wave)
	var target: Vector3 = r["target"]
	var reach: float = float(r.get("radius", 25.0)) + Balance.RAID_RALLY_MARGIN
	var seen: Dictionary = st["seen"]
	for e: SimEntity in m["entities"]:
		if (e.kind == SimEntity.Kind.PLAYER or e.kind == SimEntity.Kind.BOT) and e.is_alive() and e.position.distance_to(target) <= reach:
			seen[e.id] = true

## Reserva: sentinela `responder` ancora no alvo da leva enquanto ela ataca; sem leva (ou no recuo) volta ao posto.
static func _responders(_sim: WorldSim, m: Dictionary, wave: int) -> void:
	var rally := Vector3.INF
	if wave >= 0 and not RaidSystem.state(m, wave)["retreat"]:
		var r := RaidSystem.route_def(m["def"], wave)
		var route: Array = r.get("route", [])
		rally = r["target"]
		if not route.is_empty():                                  # entre o alvo e a entrada: recebe a leva na brecha/portão
			rally = (rally as Vector3).lerp(route[route.size() - 1], 0.45)
	for e: SimEntity in m["entities"]:
		if not e.guard or not e.npc_data.get("responder", false):
			continue
		var want: Vector3 = rally if rally != Vector3.INF else e.npc_data["pos"]
		if rally != Vector3.INF:                                  # cada um num ponto da linha (não empilham)
			want += Vector3(float(e.id % 3) - 1.0, 0.0, float(int(e.id / 3.0) % 3) - 1.0) * 1.3
		if e.home_position.distance_to(want) > 0.5:
			e.home_position = want

## Batedores com trompa: em luta há SIEGE_HORN_DELAY s e vivos -> tocam (uma vez por vida).
static func _horns(sim: WorldSim, m: Dictionary, st: Dictionary) -> void:
	var horn_t: Dictionary = st["horn_t"]
	var horned: Dictionary = st["horned"]
	var live := {}
	for sp in m["spawners"]:
		if not (sp["def"] as Dictionary).get("horn", false):
			continue
		for id in sp["alive"]:
			var e: SimEntity = sim.entities.get(id)
			if e == null or not e.is_alive():
				continue
			live[id] = true
			if e.aggro_target < 0:
				horn_t.erase(id)
				continue
			horn_t[id] = float(horn_t.get(id, 0.0)) + SCAN
			if float(horn_t[id]) >= Balance.SIEGE_HORN_DELAY and not horned.has(id):
				horned[id] = true
				horn(sim, m)
	for id in horned.keys():
		if not live.has(id):
			horned.erase(id)
			horn_t.erase(id)

## Uma trompa soou: adianta a próxima leva (teto SIEGE_HORN_MAX por leva; a calmaria continua valendo).
static func horn(sim: WorldSim, m: Dictionary) -> bool:
	var st := state(m)
	var def: MapDef = m["def"]
	Events.post(&"siege_event", def.id, "horn")
	if sim.player != null and sim.player.map_id == def.id:
		Events.post(&"chat_message", "Sistema", str(def.siege.get("say_horn", "Uma trompa soa na estrada!")), "system")
	if int(st["horns"]) >= Balance.SIEGE_HORN_MAX:
		return false
	st["horns"] = int(st["horns"]) + 1
	st["wave_t"] = float(st["wave_t"]) - Balance.SIEGE_HORN_HASTEN
	return true

# ----------------------------------------------------------------------------
# Assédio
# ----------------------------------------------------------------------------

## Solta os atiradores do assédio agora (o relógio também chama). Devolve os ids.
static func start_harass(sim: WorldSim, m: Dictionary) -> Array:
	var def: MapDef = m["def"]
	var st := state(m)
	var hi := route_index(def, str(def.siege.get("harass_route", "")))
	if hi < 0:
		return []
	var r: Dictionary = RaidSystem.routes(def)[hi]
	var mdef: MonsterDef = GameData.monsters.get(str(def.siege.get("harass_mob", "")))
	if mdef == null:
		return []
	var ids: Array = []
	for _k in int(num(def, "harass_shooters", Balance.SIEGE_HARASS_SHOOTERS)):
		var e := sim.spawn_monster(mdef, def.id, MapGeometry.random_walkable(sim, def, r["from"], 2.5))
		ids.append(e.id)
	st["shooters"] = ids
	st["age"] = 0.0
	st["shot"] = false
	st["harass_t"] = harass_interval(pressure(sim, def), sim.rng.randf_range(-1.0, 1.0), def)
	if sim.player != null and sim.player.map_id == def.id:
		Events.post(&"chat_message", "Sistema", str(def.siege.get("say_harass", "Flechas de fogo sobre a paliçada!")), "system")
	Events.post(&"siege_event", def.id, "harass")
	return ids

static func _update_harass(sim: WorldSim, m: Dictionary, st: Dictionary, dt: float) -> void:
	var ids: Array = st["shooters"]
	if ids.is_empty():
		return
	st["age"] = float(st["age"]) + dt
	var alive: Array = []
	for id in ids:
		var e: SimEntity = sim.entities.get(id)
		if e != null and e.is_alive():
			alive.append(id)
	if not alive.is_empty() and not st["shot"] and float(st["age"]) >= Balance.SIEGE_HARASS_WINDUP:
		st["shot"] = true
		volley(sim, m, alive)
	if float(st["age"]) >= Balance.SIEGE_HARASS_LIFE:           # recuam e somem (quem ainda luta fica mais um pouco)
		var late: bool = float(st["age"]) >= Balance.SIEGE_HARASS_LIFE + 15.0
		for id in alive.duplicate():
			var e: SimEntity = sim.entities[id]
			if e.aggro_target < 0 or late:
				sim.despawn(e)
				alive.erase(id)
	st["shooters"] = alive

## Alvo da salva: a brecha aberta (alvo da rota do trecho) mais perto do ponto de tiro; todas fechadas = o alvo do assédio.
static func harass_aim(sim: WorldSim, def: MapDef) -> Vector3:
	var all := RaidSystem.routes(def)
	var hi := route_index(def, str(def.siege.get("harass_route", "")))
	var from: Vector3 = all[hi]["from"]
	var best: Vector3 = all[hi]["target"]
	var bd := INF
	for seg in def.siege.get("segments", []):
		var i := route_index(def, str(seg["route"]))
		if i < 0 or not WorldState.active(sim, all[i]):
			continue
		var t: Vector3 = all[i]["target"]
		if t.distance_to(from) < bd:
			bd = t.distance_to(from)
			best = t
	if bd == INF:
		var g := route_index(def, str(def.siege.get("gate_route", "")))
		if g >= 0:
			best = all[g]["target"]
	return best

## Pontos proibidos para círculo de assédio: chegada, portais de zona, cristal e NPCs de serviço.
static func safe_points(def: MapDef) -> Array:
	var out: Array = [def.spawn_point]
	for pt in def.portals:
		if not pt.get("player_only", false):          # porta de casa não é chegada de zona
			out.append(pt["pos"])
	for n in def.npcs:
		if str(n.get("role", "")) in SERVICE_ROLES:
			out.append(n["pos"])
	return out

## Um ponto de círculo em volta de `aim` fora das zonas seguras (8 tentativas; Vector3.INF = não nasce).
static func volley_spot(sim: WorldSim, def: MapDef, aim: Vector3, safe: Array) -> Vector3:
	for _t in 8:
		var p := MapGeometry.random_walkable(sim, def, aim, Balance.SIEGE_HARASS_SPREAD)
		p.y = 0.0
		var ok := true
		for q in safe:
			if Vector2(p.x - q.x, p.z - q.z).length() < Balance.SIEGE_SAFE_RADIUS + Balance.SIEGE_HARASS_RADIUS:
				ok = false
				break
		if ok:
			return p
	return Vector3.INF

## A salva: SIEGE_HARASS_CIRCLES círculos avisados (m["hazards"], dono = um atirador vivo; morto antes do impacto, o círculo some).
static func volley(sim: WorldSim, m: Dictionary, shooters: Array) -> int:
	var def: MapDef = m["def"]
	var st := state(m)
	var aim := harass_aim(sim, def)
	var safe := safe_points(def)
	var skill := str(def.siege.get("volley_skill", VOLLEY_SKILL))       # tema/som da salva do mapa (Posto: flecha de raiz)
	var pct := num(def, "harass_dmg_pct", Balance.SIEGE_HARASS_DMG_PCT)
	st["salvo"] = {}
	var n := 0
	for k in Balance.SIEGE_HARASS_CIRCLES:
		var p := volley_spot(sim, def, aim, safe)
		if p == Vector3.INF:
			continue
		var h := {"owner": int(shooters[k % shooters.size()]), "pos": p, "radius": Balance.SIEGE_HARASS_RADIUS, "at": sim.time + Balance.SIEGE_HARASS_WARN,
			"power": 0.0, "kind": SkillDef.Kind.PHYSICAL, "effects": {}, "skill": skill, "hp_pct": pct}
		BossSignatures.add_hazard(m, h, sim.time)
		Events.post(&"hazard_placed", def.id, p, Balance.SIEGE_HARASS_RADIUS, Balance.SIEGE_HARASS_WARN, skill)
		n += 1
	return n

## Impacto de um círculo de assédio (BossSignatures.update_hazards): % da vida máxima em aventureiros (jogador e bots) dentro,
## não esquivável; por salva cada alvo leva no máximo 2 círculos e, se tinha >= 30% de vida antes dela, não morre.
static func land(sim: WorldSim, m: Dictionary, owner: SimEntity, h: Dictionary) -> void:
	var st := state(m)
	var salvo: Dictionary = st["salvo"]
	var pos: Vector3 = h["pos"]
	for o: SimEntity in m["entities"]:
		if not o.is_alive() or not (o.kind == SimEntity.Kind.PLAYER or o.kind == SimEntity.Kind.BOT) or not BossSignatures.inside(h, o.position, o.radius):
			continue
		var rec: Dictionary = salvo.get(o.id, {"n": 0, "safe": o.hp >= o.stats.max_hp * 0.3})
		salvo[o.id] = rec
		if int(rec["n"]) >= 2:
			continue
		rec["n"] = int(rec["n"]) + 1
		var amount := int(round(o.stats.max_hp * float(h["hp_pct"]) / 100.0))
		if rec["safe"]:
			amount = mini(amount, int(o.hp + o.shield_hp) - 1)
		if amount > 0:
			sim._deal_damage(owner, o, amount, false, false, "physical", pos, false)
	Events.post(&"skill_effect", h["skill"], pos, pos, float(h["radius"]))

## Leitura para a apresentação e os testes: {} se o mapa não tem cerco.
##   {p, scorch, next_wave (s), next_harass (s), harass (atiradores vivos), wave (rota da leva viva, -1 = nenhuma), segments: {id: fechado}}
static func status(sim: WorldSim, map_id: String) -> Dictionary:
	var m: Dictionary = sim.maps.get(map_id, {})
	if m.is_empty() or (m["def"] as MapDef).siege.is_empty():
		return {}
	var def: MapDef = m["def"]
	var st := state(m)
	var segs := {}
	for seg in def.siege.get("segments", []):
		segs[seg["id"]] = segment_closed(sim, def, seg)
	return {"p": pressure(sim, def), "scorch": bool(st["scorch"]), "next_wave": maxf(maxf(0.0, float(st["wave_t"])), float(st["quiet"])),
		"next_harass": maxf(0.0, float(st["harass_t"])), "harass": (st["shooters"] as Array).size(), "wave": active_route(m), "segments": segs}
