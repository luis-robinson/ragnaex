extends Node
## Sonda de bots presos (sem tela): o mundo inteiro como no jogo (todos os mapas, bots do main._populate_bots, jogador
## parado na cidade, mapas sem o jogador a cada Sim.away_every ticks) por N minutos de sim. Amostra cada bot a cada
## SAMPLE_S e marca PRESO quando, numa janela de WINDOW_S: vivo, sem conjurar/colher/voltar/montar/atordoado, o cérebro
## manda andar em quase toda amostra, quase não ataca e o corpo não sai de um disco de STUCK_R m (vai-e-volta conta).
## PARADO = fora da vila, sem luta, sem comando de andar nem de agir, no mesmo lugar por FROZEN_S.
## Cada episódio guarda mapa, posição, estado do cérebro, alvo, portal, desvio da água, colisores perto, linha até o
## alvo bloqueada (e por quê), e como terminou (andou, trocou de mapa, morreu, fim da sonda).
##   godot --headless --path . tools/tests/stuck_probe.tscn -- [--minutes=30] [--seed=4242] [--out=<json>] [--verbose] [--player_map=<id>] [--quests=<a,b>]
## Saída: STUCK_EP (fim de cada episódio), STUCK_HOT (pontos quentes por mapa, células de HOT_CELL m), STUCK_SUM.

const DT := 1.0 / 60.0
const SAMPLE_TICKS := 30          # 0,5 s
const SAMPLE_S := SAMPLE_TICKS * DT
const WINDOW_S := 10.0
const WINDOW_N := int(WINDOW_S / SAMPLE_S)
const STUCK_R := 1.5              # m: o corpo não sai deste disco na janela
const MOVE_FRAC := 0.8            # fração das amostras com comando de andar
const ACT_FRAC := 0.2             # mais que isto de amostras atacando = está lutando, não preso
const FROZEN_S := 30.0
const HOT_CELL := 8.0

var seed_v := 4242
var hist := {}        # id -> Array de amostras {p, mv, act, ok, combat}
var open_ep := {}     # id -> episódio aberto
var frozen_t := {}    # id -> [pos, desde]
var episodes: Array = []
var bot_samples := 0  # amostras de bot vivo (para a taxa)
var stuck_samples := 0
var verbose := false

func _ready() -> void:
	await get_tree().process_frame
	Sim.running = false
	seed_v = int(DevArgs.value("--seed", "4242"))
	verbose = DevArgs.has("--verbose")
	seed(seed_v)
	Sim.rng.seed = seed_v * 7 + 1
	for mid in GameData.maps:
		Sim.load_map(GameData.maps[mid])
	_populate_bots()
	var town := GameData.town_map_id()
	# --player_map=<id> / --quests=<a,b>: jogador parado em outro mapa (o cerco/investida de lá anda) e estágio da conquista
	town = DevArgs.value("--player_map", town)
	var p: SimEntity = Sim.spawn_player(GameData.classes["paladin"], "Sonda", town)
	p.position = GameData.maps[town].town_center
	p.brain = null
	for q in DevArgs.value("--quests", "").split(",", false):
		p.quests_completed.append(q)
	p.hp = p.stats.max_hp * 1000.0
	var minutes := float(DevArgs.value("--minutes", "30"))
	var n := int(minutes * 60.0 / DT)
	var t0 := Time.get_ticks_msec()
	for i in n:
		if p.is_alive():
			p.hp = maxf(p.hp, p.stats.max_hp * 100.0)
		Sim.tick(DT)
		if i % SAMPLE_TICKS == 0:
			_sample()
		if i > 0 and i % int(300.0 / DT) == 0:
			print("STUCK_PROGRESS sim_min=%.0f real_s=%.0f open=%d eps=%d" % [i * DT / 60.0, (Time.get_ticks_msec() - t0) / 1000.0, open_ep.size(), episodes.size()])
	for id in open_ep.keys():
		_close(id, "fim_da_sonda")
	_report(minutes)
	get_tree().quit()

func _populate_bots() -> void:
	var names: Array = GameData.bot_names.duplicate()
	names.shuffle()
	var classes: Array = GameData.class_list()
	var k := 0
	for mid in GameData.maps:
		var md: MapDef = GameData.maps[mid]
		for i in range(md.bot_population):
			var cls: ClassDef = classes[randi() % classes.size()]
			var lv := randi_range(md.level_range.x, md.level_range.y)
			if md.is_town:
				lv = randi_range(1, 30)
			var pos := Sim.random_walkable(md, md.spawn_point if not md.is_town else md.town_center, 10.0)
			Sim.spawn_bot(cls, names[k % names.size()], mid, pos, lv)
			k += 1

# ---------------------------------------------------------------------------
func _sample() -> void:
	for e: SimEntity in Sim.entities.values():
		if e.kind != SimEntity.Kind.BOT:
			continue
		var id := e.id
		var h: Array = hist.get(id, [])
		if not e.is_alive():
			if open_ep.has(id):
				_close(id, "morreu")
			h.clear()
			hist[id] = h
			frozen_t.erase(id)
			continue
		bot_samples += 1
		var c: InputCommand = e.brain_cmd
		var mv: bool = c != null and c.move.length() > 0.2
		var act: bool = (c != null and (c.attack or c.skill_slot >= 0)) or e.state == SimEntity.State.ATTACKING or e.state == SimEntity.State.CASTING
		var busy: bool = e.state in [SimEntity.State.STUNNED, SimEntity.State.DASHING, SimEntity.State.BLOCKING] or e.recall_left > 0.0 \
			or e.gather_left > 0.0 or e.mount_left > 0.0 or (e.current_skill != null and e.state == SimEntity.State.CASTING)
		var s := {"p": e.position, "map": e.map_id, "mv": mv, "act": act, "busy": busy}
		if not h.is_empty() and h[-1]["map"] != e.map_id:
			if open_ep.has(id):
				_close(id, "trocou_mapa")
			h.clear()
		h.append(s)
		while h.size() > WINDOW_N:
			h.pop_front()
		hist[id] = h
		var stuck := _is_stuck(h)
		if stuck:
			stuck_samples += 1
			if not open_ep.has(id):
				_open(e, h)
			else:
				open_ep[id]["n"] = int(open_ep[id]["n"]) + 1
		elif open_ep.has(id):
			_close(id, "andou")
		_frozen(e, mv, act, busy)

func _is_stuck(h: Array) -> bool:
	if h.size() < WINDOW_N:
		return false
	var nmv := 0
	var nact := 0
	var c := Vector3.ZERO
	for s in h:
		if s["busy"]:
			return false
		if s["mv"]:
			nmv += 1
		if s["act"]:
			nact += 1
		c += s["p"]
	if nmv < WINDOW_N * MOVE_FRAC or nact > WINDOW_N * ACT_FRAC:
		return false
	c /= h.size()
	for s in h:
		if (s["p"] as Vector3).distance_to(c) > STUCK_R:
			return false
	return true

## Parado fora da vila sem nada para fazer (ex.: RETURN sem portal, seguidor sem rota).
func _frozen(e: SimEntity, mv: bool, act: bool, busy: bool) -> void:
	var m: Dictionary = Sim.maps[e.map_id]
	var def: MapDef = m["def"]
	if mv or act or busy or def.in_town(e.position) or e.combat_timer > 0.0:
		frozen_t.erase(e.id)
		return
	var f: Array = frozen_t.get(e.id, [])
	if f.is_empty() or (f[0] as Vector3).distance_to(e.position) > 1.0 or f[2] != e.map_id:
		frozen_t[e.id] = [e.position, Sim.time, e.map_id, false]
		return
	if not f[3] and Sim.time - float(f[1]) > FROZEN_S:
		f[3] = true
		var info := _describe(e, "parado")
		info["start"] = float(f[1])
		info["dur"] = Sim.time - float(f[1])
		info["end"] = "parado"
		episodes.append(info)
		if verbose:
			print("STUCK_FROZEN ", JSON.stringify(info))

func _open(e: SimEntity, h: Array) -> void:
	var info := _describe(e, "preso")
	info["start"] = Sim.time - WINDOW_S
	info["n"] = 1
	open_ep[e.id] = info

func _close(id: int, why: String) -> void:
	var info: Dictionary = open_ep[id]
	open_ep.erase(id)
	info["end"] = why
	info["dur"] = Sim.time - float(info["start"])
	var e: SimEntity = Sim.entities.get(id)
	if e:
		info["end_state"] = _state_name(e)
	episodes.append(info)
	if verbose or float(info["dur"]) >= 30.0:
		print("STUCK_EP ", JSON.stringify(info))

static func _state_name(e: SimEntity) -> String:
	var b: BotBrain = e.brain
	return BotBrain.S.keys()[b.state] if b else "?"

# ---------------------------------------------------------------------------
## Tudo o que ajuda a achar a causa: estado, alvo, portal, desvio da água, colisores perto, linha até o alvo.
func _describe(e: SimEntity, kind: String) -> Dictionary:
	var m: Dictionary = Sim.maps[e.map_id]
	var def: MapDef = m["def"]
	var b: BotBrain = e.brain
	var c: InputCommand = e.brain_cmd
	var goal: Vector3 = c.aim if c else e.position
	var info := {"kind": kind, "id": e.id, "lv": e.level, "cls": e.class_def.id if e.class_def else "?", "map": e.map_id,
		"x": snappedf(e.position.x, 0.1), "z": snappedf(e.position.z, 0.1), "state": _state_name(e), "dest": b.dest_map if b else "",
		"sim_state": SimEntity.State.keys()[e.state], "mounted": e.mounted, "in_town": def.in_town(e.position),
		"combat": e.combat_timer > 0.0, "move": [snappedf(c.move.x, 0.01), snappedf(c.move.y, 0.01)] if c else [],
		"aim": [snappedf(goal.x, 0.1), snappedf(goal.z, 0.1)], "aim_d": snappedf(goal.distance_to(e.position), 0.1)}
	if b:
		info["target_pos"] = [snappedf(b.target_pos.x, 0.1), snappedf(b.target_pos.z, 0.1)]
		info["detour_tries"] = b.detour_tries
		info["water_path"] = b.water_path.size()
		info["stall_t"] = snappedf(b.stall_t, 0.1)
		if b.state in [BotBrain.S.TRAVEL, BotBrain.S.RETURN]:
			var pt := PortalSystem.portal_towards(def, b.dest_map)
			if not pt.is_empty():
				info["portal"] = pt["target_map"]
				info["portal_pos"] = [snappedf(pt["pos"].x, 0.1), snappedf(pt["pos"].z, 0.1)]
				info["portal_d"] = snappedf((pt["pos"] as Vector3).distance_to(e.position), 0.1)
	if e.party_id >= 0:
		var lead: SimEntity = Sim.party_leader(e)
		if lead:
			info["party"] = "lead" if lead == e else "follow"
			info["leader_map"] = lead.map_id
			info["leader_d"] = snappedf(lead.position.distance_to(e.position), 0.1) if lead.map_id == e.map_id else -1.0
	var foe := Combat.nearest_hostile(e, m["entities"], 16.0)
	if foe:
		info["foe"] = foe.monster_def.id if foe.monster_def else str(foe.kind)
		info["foe_d"] = snappedf(foe.position.distance_to(e.position), 0.1)
		info["foe_pos"] = [snappedf(foe.position.x, 0.1), snappedf(foe.position.z, 0.1)]
		info["foe_aggro_me"] = foe.aggro_target == e.id
		info["foe_line"] = _line_block(e, foe.position, m)
		info["foe_water"] = MapGeometry.crosses_river(Sim, m, Vector2(e.position.x, e.position.z), Vector2(foe.position.x, foe.position.z))
	info["goal_line"] = _line_block(e, goal, m)
	info["goal_water"] = MapGeometry.crosses_river(Sim, m, Vector2(e.position.x, e.position.z), Vector2(goal.x, goal.z))
	info["near"] = _near_colliders(e.position, m, 3.0)
	var best := INF
	for pt in def.portals:
		var d: float = (pt["pos"] as Vector3).distance_to(e.position)
		if d < best:
			best = d
			info["near_portal"] = "%s%s@%.1f" % [pt["target_map"], " (player_only)" if pt.get("player_only", false) else "", d]
	if def.town_radius > 0.0:
		info["town_d"] = snappedf(e.position.distance_to(def.town_center) - def.town_radius, 0.1)
	return info

## Primeiro ponto da reta até `to` (até 20 m) onde um corpo de raio 0,4 não cabe, e o colisor de lá.
func _line_block(e: SimEntity, to: Vector3, m: Dictionary) -> String:
	var def: MapDef = m["def"]
	var a := e.position
	var d := minf(a.distance_to(to), 20.0)
	if d < 0.6:
		return ""
	var dir := (to - a).normalized()
	var t := 0.6
	while t < d:
		var q := a + dir * t
		if not MapGeometry.is_walkable(Sim, q, def, 0.4):
			var col := _near_colliders(q, m, 0.5)
			return "%.1fm:%s" % [t, col[0] if not col.is_empty() else "borda"]
		t += 0.5
	return ""

## Colisores a até `r` m de `p` (borda), como texto: tipo do obstáculo (ou água), tamanho, alto.
func _near_colliders(p: Vector3, m: Dictionary, r: float) -> Array:
	var out: Array = []
	var cols: Array = m["colliders"]
	var def: MapDef = m["def"]
	for idx in MapGeometry.nearby_colliders(Sim, m, p):
		var c: Dictionary = cols[idx]
		var gap: float
		if c["circle"]:
			gap = Vector2(p.x - c["x"], p.z - c["z"]).length() - float(c["cr"])
		else:
			var rel := Vector2(p.x - c["x"], p.z - c["z"]).rotated(c["rot"])
			var q := Vector2(maxf(absf(rel.x) - c["hx"], 0.0), maxf(absf(rel.y) - c["hz"], 0.0))
			gap = q.length()
		if gap > r:
			continue
		var kind := "agua"
		for ob in def.obstacles:
			var op: Vector3 = ob["pos"]
			if absf(op.x - c["x"]) < 0.01 and absf(op.z - c["z"]) < 0.01:
				kind = ob.get("kind", "house")
				break
		if c["circle"]:
			out.append("%s(o r%.1f @%.0f,%.0f gap%.1f)" % [kind, c["cr"], c["x"], c["z"], gap])
		else:
			out.append("%s(box %.1fx%.1f @%.0f,%.0f gap%.1f)" % [kind, c["hx"] * 2, c["hz"] * 2, c["x"], c["z"], gap])
	return out

# ---------------------------------------------------------------------------
func _report(minutes: float) -> void:
	var hot := {}
	var stuck_s := 0.0
	var by_state := {}
	var by_end := {}
	for ep in episodes:
		var key := "%s|%d|%d|%s" % [ep["map"], floori(float(ep["x"]) / HOT_CELL), floori(float(ep["z"]) / HOT_CELL), ep["kind"]]
		var hrec: Dictionary = hot.get(key, {"map": ep["map"], "kind": ep["kind"], "n": 0, "s": 0.0, "bots": {}, "states": {}, "x": 0.0, "z": 0.0, "ex": ep})
		hrec["n"] += 1
		hrec["s"] += float(ep["dur"])
		hrec["bots"][ep["id"]] = true
		hrec["x"] += float(ep["x"])
		hrec["z"] += float(ep["z"])
		var st := "%s%s" % [ep["state"], "+luta" if ep["combat"] else ""]
		hrec["states"][st] = int(hrec["states"].get(st, 0)) + 1
		hot[key] = hrec
		if ep["kind"] == "preso":
			stuck_s += float(ep["dur"])
			by_state[st] = int(by_state.get(st, 0)) + 1
		by_end[ep["end"]] = int(by_end.get(ep["end"], 0)) + 1
	var keys: Array = hot.keys()
	keys.sort_custom(func(a, b): return hot[a]["s"] > hot[b]["s"])
	for k in keys.slice(0, 40):
		var h: Dictionary = hot[k]
		print("STUCK_HOT map=%s at=%.1f,%.1f kind=%s eps=%d bot_s=%.0f bots=%d states=%s ex=%s" % [h["map"], h["x"] / h["n"], h["z"] / h["n"], h["kind"], h["n"], h["s"],
			h["bots"].size(), JSON.stringify(h["states"]), JSON.stringify(h["ex"])])
	var bot_s := bot_samples * SAMPLE_S
	print("STUCK_SUM seed=%d minutes=%.0f bots=%d episodes=%d preso_bot_s=%.0f alive_bot_s=%.0f rate=%.4f by_state=%s by_end=%s" % [seed_v, minutes,
		hist.size(), episodes.size(), stuck_s, bot_s, stuck_s / maxf(bot_s, 1.0), JSON.stringify(by_state), JSON.stringify(by_end)])
	var out := DevArgs.value("--out", "")
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify({"seed": seed_v, "minutes": minutes, "alive_bot_s": bot_s, "preso_bot_s": stuck_s, "episodes": episodes}, " "))
			f.close()
