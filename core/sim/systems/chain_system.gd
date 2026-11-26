class_name ChainSystem
extends RefCounted
## Cadeias de eventos (GDD design/gdd/momentos-do-mundo.md §3.2-§3.3, §4, §5; piloto §9.2: Campina). Regras e falas em
## MomentsCatalog.CHAINS, números em Balance.CHAIN_*.
##  - o relógio da cadeia só anda com o jogador no mapa dela; a cada CHAIN_TICK min sorteia CHAIN_STEP_CHANCE;
##  - o passo é um evento de estrada com a regra da cadeia (RoadEventSystem.start; um evento por mapa);
##  - desfecho: resolvido = `arrived`, falhou/expirou = `fell`, investida = cancelado (volta ao sorteio);
##  - o desfecho liga uma marca de mundo (WorldState.set_mark) por CHAIN_MARK_MIN min de jogo, que vai para o save:
##      Feira (campina_fair): feirantes na praça, lojas do mapa (e casas dele) -CHAIN_FAIR_DISCOUNT;
##      Acampamento Bandido (campina_bandits): mandachuva + CHAIN_CAMP_BANDITS bandidos na estrada; limpo = acaba antes;
##  - depois da marca, CHAIN_COOLDOWN_MIN min sem passo novo.
## Estado em sim.chains[<cadeia>]: {clock, next, rng, phase idle|step|mark, cool, ids (acampamento/feirantes), spawned}.

static func state(sim: WorldSim, cid: String) -> Dictionary:
	if not sim.chains.has(cid):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([sim.rng.seed, cid, "chain"])         # sorteio próprio: não gasta o rng da sim
		sim.chains[cid] = {"clock": 0.0, "next": Balance.CHAIN_FIRST_MIN * 60.0, "rng": rng, "phase": "idle", "cool": 0.0,
			"ids": [], "spawned": ""}
	return sim.chains[cid]

## Cadeias deste mapa.
static func of_map(map_id: String) -> Array:
	var out: Array = []
	for cid in MomentsCatalog.CHAINS:
		if str(MomentsCatalog.CHAINS[cid]["map"]) == map_id:
			out.append(cid)
	return out

static func update(sim: WorldSim, m: Dictionary, dt: float) -> void:
	var def: MapDef = m["def"]
	if not MomentsCatalog.CHAINS.is_empty() and sim.player != null and sim.player.map_id == def.id:
		for cid in of_map(def.id):
			_update_chain(sim, m, cid, dt)

static func _update_chain(sim: WorldSim, m: Dictionary, cid: String, dt: float) -> void:
	var st := state(sim, cid)
	st["clock"] = float(st["clock"]) + dt
	var mk := mark_of(sim, cid)
	if mk != "":
		_keep_mark(sim, m, cid, st, mk)
		return
	if str(st["phase"]) == "mark":
		end_mark(sim, cid, "ended")                 # a marca venceu por fora (save antigo, teste)
	if str(st["phase"]) == "step":
		var ev: Dictionary = RoadEventSystem.state(sim, m)["active"]
		if ev.is_empty() or str(ev.get("chain", "")) != cid:
			st["phase"] = "idle"                     # o evento sumiu sem passar pelo fim (troca de mundo)
		return
	if float(st["clock"]) < float(st["next"]):
		return
	st["next"] = float(st["clock"]) + Balance.CHAIN_TICK * 60.0
	if float(st["clock"]) < float(st["cool"]):
		return
	var rng: RandomNumberGenerator = st["rng"]
	if rng.randf() < Balance.CHAIN_STEP_CHANCE:
		start_step(sim, cid)

## Começa o passo agora (o relógio também chama). `point` < 0 = ponto válido sorteado. Devolve o evento ({} = não deu).
static func start_step(sim: WorldSim, cid: String, point: int = -1) -> Dictionary:
	var c: Dictionary = MomentsCatalog.CHAINS.get(cid, {})
	if c.is_empty() or not sim.maps.has(str(c["map"])) or mark_of(sim, cid) != "":
		return {}
	var m: Dictionary = sim.maps[str(c["map"])]
	var a := RoadEventSystem.start(sim, m, point, c["step"])
	if a.is_empty():
		return {}
	a["chain"] = cid
	var st := state(sim, cid)
	st["phase"] = "step"
	st["step_at"] = a["pos"]
	Events.post(&"chat_message", "Sistema", str(c.get("announce", "")), "system")
	Events.post(&"chain_step", cid, str(c["map"]), "started")
	return a

## Fim do passo (RoadEventSystem.finish de um evento com `chain`).
static func on_step_end(sim: WorldSim, a: Dictionary, outcome: String) -> void:
	var cid := str(a.get("chain", ""))
	var c: Dictionary = MomentsCatalog.CHAINS.get(cid, {})
	if c.is_empty():
		return
	var st := state(sim, cid)
	if outcome == "resolved":
		_begin_mark(sim, cid, "arrived", a["pos"])
	elif outcome in ["failed", "expired"]:
		_begin_mark(sim, cid, "fell", a["pos"])
	else:
		st["phase"] = "idle"                         # investida no mapa: o passo é cancelado e volta ao sorteio
		Events.post(&"chain_step", cid, str(c["map"]), "aborted")

## Liga a marca do desfecho (`arrived` | `fell`) por CHAIN_MARK_MIN min; `at` = onde o passo aconteceu.
static func _begin_mark(sim: WorldSim, cid: String, outcome: String, at: Vector3) -> void:
	var c: Dictionary = MomentsCatalog.CHAINS[cid]
	var o: Dictionary = c[outcome]
	var st := state(sim, cid)
	st["phase"] = "mark"
	st["spawned"] = ""
	st["ids"] = []
	WorldState.set_mark(sim, str(o["mark"]), Balance.CHAIN_MARK_MIN * 60.0, str(c["map"]))
	if outcome == "fell":
		sim.world_marks[str(o["mark"])]["at"] = [at.x, at.z]          # o acampamento fica onde a caravana caiu (vai no save)
	Events.post(&"chat_message", "Sistema", str(o.get("announce", "")), "system")
	Events.post(&"chain_step", cid, str(c["map"]), outcome)
	if sim.maps.has(str(c["map"])):
		_keep_mark(sim, sim.maps[str(c["map"])], cid, st, str(o["mark"]))

## Marca de mundo ligada desta cadeia ("" = nenhuma).
static func mark_of(sim: WorldSim, cid: String) -> String:
	var c: Dictionary = MomentsCatalog.CHAINS.get(cid, {})
	for k in ["arrived", "fell"]:
		var mk := str((c.get(k, {}) as Dictionary).get("mark", ""))
		if mk != "" and sim.world_marks.has(mk):
			return mk
	return ""

## Enquanto a marca vale: põe o que ela muda no mapa (uma vez; depois de um load também) e vê se o acampamento caiu.
static func _keep_mark(sim: WorldSim, m: Dictionary, cid: String, st: Dictionary, mk: String) -> void:
	var c: Dictionary = MomentsCatalog.CHAINS[cid]
	st["phase"] = "mark"
	if str(st["spawned"]) != mk:
		st["spawned"] = mk
		st["ids"] = _spawn_fair(sim, m, c["arrived"]) if mk == str(c["arrived"]["mark"]) else _spawn_camp(sim, m, c["fell"], mk)
		return
	if mk == str(c["fell"]["mark"]):
		for id in st["ids"]:
			var e: SimEntity = sim.entities.get(id)
			if e != null and e.is_alive():
				return
		end_mark(sim, cid, "cleared")             # acampamento limpo: a marca acaba antes do prazo

static func _spawn_fair(sim: WorldSim, m: Dictionary, o: Dictionary) -> Array:
	var def: MapDef = m["def"]
	var ids: Array = []
	var k := 0
	for n in o.get("npcs", []):
		var d := {"id": "chain_" + str(n[0]), "name": str(n[1]), "role": "villager", "color": Color(0.85, 0.7, 0.45),
			"pos": Vector3(float(n[2]), 0.0, float(n[3])), "dialog": n[5], "barks": n[5], "look_seed": 7300 + k * 13, "facing": 180.0, "chain": true}
		if str(n[4]) != "":
			d["carry"] = str(n[4])
		k += 1
		ids.append(sim._spawn_npc(d, def.id).id)
	return ids

static func _spawn_camp(sim: WorldSim, m: Dictionary, o: Dictionary, mk: String) -> Array:
	var def: MapDef = m["def"]
	var at := camp_spot(sim, def, mk)
	var ids: Array = []
	var boss: MonsterDef = GameData.monsters.get(str(o["boss"]))
	var mob: MonsterDef = GameData.monsters.get(str(o["mob"]))
	if boss != null:
		var e := sim.spawn_monster(boss, def.id, at)
		e.home_position = at
		ids.append(e.id)
	if mob != null:
		for i in Balance.CHAIN_CAMP_BANDITS:
			var ang := TAU * float(i) / float(Balance.CHAIN_CAMP_BANDITS)
			var q := at + Vector3(cos(ang), 0.0, sin(ang)) * Balance.CHAIN_CAMP_RADIUS
			if not MapGeometry.is_walkable(sim, q, def, mob.radius):
				q = MapGeometry.random_walkable(sim, def, at, Balance.CHAIN_CAMP_RADIUS)
			var b := sim.spawn_monster(mob, def.id, q)
			b.home_position = q
			b.face_towards(at)
			ids.append(b.id)
	return ids

## Lugar do acampamento: CHAIN_CAMP_OFFSET m ao lado de onde a caravana caiu, em chão livre (sem esse ponto: o 1º ponto
## de evento do mapa).
static func camp_spot(sim: WorldSim, def: MapDef, mk: String) -> Vector3:
	var raw: Array = (sim.world_marks.get(mk, {}) as Dictionary).get("at", [])
	var base: Vector3 = Vector3(float(raw[0]), 0.0, float(raw[1])) if raw.size() >= 2 else (def.road_events[0]["pos"] if not def.road_events.is_empty() else def.spawn_point)
	var away := Vector3(base.x - def.town_center.x, 0.0, base.z - def.town_center.z).normalized()
	for k in 8:
		var ang := atan2(away.z, away.x) + PI * 0.5 * (1.0 if k % 2 == 0 else -1.0) + 0.35 * float(k >> 1)
		var q := base + Vector3(cos(ang), 0.0, sin(ang)) * Balance.CHAIN_CAMP_OFFSET
		if MapGeometry.is_walkable(sim, q, def, Balance.CHAIN_CAMP_RADIUS * 0.6):
			return q
	return base

## Termina a marca da cadeia: "ended" (prazo) | "cleared" (acampamento limpo). Leva o que ela pôs no mapa.
static func end_mark(sim: WorldSim, cid: String, why: String) -> void:
	var c: Dictionary = MomentsCatalog.CHAINS.get(cid, {})
	if c.is_empty():
		return
	var st := state(sim, cid)
	var was := str(st["spawned"])
	for k in ["arrived", "fell"]:
		WorldState.clear_mark(sim, str(c[k]["mark"]))
	for id in st["ids"]:
		var e: SimEntity = sim.entities.get(id)
		if e != null and (e.kind == SimEntity.Kind.NPC or e.aggro_target < 0 or why == "cleared"):
			sim.despawn(e)
		elif e != null:
			e.home_position = e.position             # bandido no meio da briga: termina a luta e fica (sem acampamento)
	st["ids"] = []
	st["spawned"] = ""
	st["phase"] = "idle"
	st["cool"] = float(st["clock"]) + Balance.CHAIN_COOLDOWN_MIN * 60.0
	st["next"] = maxf(float(st["next"]), float(st["cool"]))
	var o: Dictionary = c["fell"] if was == str(c["fell"]["mark"]) else c["arrived"]
	Events.post(&"chat_message", "Sistema", str(o.get("cleared" if why == "cleared" else "end", "")), "system")
	Events.post(&"chain_step", cid, str(c["map"]), why)

## Prazo das marcas (tick global): a que venceu leva o que a cadeia pôs no mapa.
static func tick_marks(sim: WorldSim, dt: float) -> void:
	if sim.world_marks.is_empty():
		return
	for mk in WorldState.tick_marks(sim, dt):
		for cid in MomentsCatalog.CHAINS:
			var c: Dictionary = MomentsCatalog.CHAINS[cid]
			if str(c["arrived"]["mark"]) == str(mk) or str(c["fell"]["mark"]) == str(mk):
				var st := state(sim, cid)
				st["spawned"] = str(mk)
				end_mark(sim, cid, "ended")

## Multiplicador de preço da loja para quem compra em `map_id` (Feira: -CHAIN_FAIR_DISCOUNT no mapa e nas casas dele).
static func shop_mult(sim: WorldSim, map_id: String) -> float:
	if sim.world_marks.is_empty():
		return 1.0
	var def: MapDef = GameData.maps.get(map_id)
	for cid in MomentsCatalog.CHAINS:
		var c: Dictionary = MomentsCatalog.CHAINS[cid]
		if not sim.world_marks.has(str(c["arrived"]["mark"])):
			continue
		if map_id == str(c["map"]) or (def != null and def.parent_map == str(c["map"])):
			return 1.0 - Balance.CHAIN_FAIR_DISCOUNT
	return 1.0

## Resumo para HUD/minimapa/testes: {chain, name, phase idle|step|mark, mark, label, left, pos} ({} = nenhuma no mapa).
static func status(sim: WorldSim, map_id: String) -> Dictionary:
	for cid in of_map(map_id):
		var c: Dictionary = MomentsCatalog.CHAINS[cid]
		var st: Dictionary = sim.chains.get(cid, {"phase": "idle"})       # leitura (HUD): não cria estado
		var out := {"chain": cid, "name": str(c["name"]), "phase": str(st["phase"]), "mark": "", "label": "", "left": 0.0, "pos": Vector3.INF}
		var mk := mark_of(sim, cid)
		if mk != "":
			out["phase"] = "mark"
			out["mark"] = mk
			out["left"] = WorldState.mark_left(sim, mk)
			var fell: bool = mk == str(c["fell"]["mark"])
			out["label"] = str(c["fell" if fell else "arrived"]["label"])
			var def: MapDef = GameData.maps.get(str(c["map"]))
			if fell and def != null:
				out["pos"] = camp_spot(sim, def, mk)
			elif def != null:
				out["pos"] = def.town_center
		elif str(st["phase"]) == "step":
			out["label"] = str(c["name"])
			out["pos"] = st.get("step_at", Vector3.INF)
		return out
	return {}

## Save: as marcas valem pelo sim.world_marks (WorldState); aqui só o relógio de recarga de cada cadeia.
static func to_save(sim: WorldSim) -> Dictionary:
	var marks := {}
	for id in sim.world_marks:
		marks[id] = (sim.world_marks[id] as Dictionary).duplicate(true)
	return {"v": 1, "marks": marks}

static func from_save(sim: WorldSim, d: Dictionary) -> void:
	sim.world_marks.clear()
	sim.chains.clear()
	var o: Dictionary = d.get("moments", {}) if d.get("moments") is Dictionary else {}
	var marks: Dictionary = o.get("marks", {}) if o.get("marks") is Dictionary else {}
	for id in marks:
		var mk: Variant = marks[id]
		if mk is Dictionary and float((mk as Dictionary).get("left", 0.0)) > 0.0:
			var keep := {"left": minf(float(mk["left"]), Balance.CHAIN_MARK_MIN * 60.0), "map": str(mk.get("map", ""))}
			if mk.get("at") is Array and (mk["at"] as Array).size() >= 2:
				keep["at"] = [float(mk["at"][0]), float(mk["at"][1])]
			sim.world_marks[str(id)] = keep
