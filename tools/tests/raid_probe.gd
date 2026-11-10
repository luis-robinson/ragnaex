extends Node
## Investidas élficas contra o Posto dos Caçadores (calibrar RAID/GUARD/elfos): N levas por cenário, sem os outros spawners.
##   godot --headless --path . tools/tests/raid_probe.tscn -- [--trials=20] [--bots=0,1,3] [--level=15] [--map=field_forest] [--raid_level=20]
## --route=N = lado da cidade atacada por vários lados (0 = MapDef.raid). --raid_level = nível do jogador que dá a força da leva (Balance.RAID_SCALE_*); sem ele, força base.
## Cenário = quantos bots (nível --level) esperam no portão norte junto das sentinelas.
## Saída: "RAID bots=N repelidas=R/T chegada=Ss duracao=Ss sentinelas_mortas=G bots_mortos=B presos=P"
##   repelidas = leva toda derrubada antes do recuo; chegada = s até a 1ª entrar no raio do povoado;
##   presos = elfos parados 10 s fora de luta antes de chegar (FLAG: rota/pathing quebrado).
## --reinforce=N: os reforços das N primeiras fortalezas retomadas (assaults "reforco_*" do mapa) já rondando a praça,
##   cheios até o `max` de cada um, como no jogo depois das retomadas (sem eles a sonda mede só a guarnição).

const LIMIT := 260.0
const DT := 1.0 / 20.0
var route_i := 0
var reclaimed := 0               # --reclaimed=N: fortalezas retomadas (fúria das levas, RaidSystem.reclaimed)                 # --route=N: qual lado da cidade (RaidSystem.routes)
var reinforce := 0

func _ready() -> void:
	await get_tree().process_frame
	var trials := 20
	var bot_counts := [0, 1, 3]
	var level := 15
	var mid := "field_forest"
	var raid_level := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--trials="): trials = int(a.get_slice("=", 1))
		if a.begins_with("--bots="): bot_counts = Array(a.get_slice("=", 1).split(",")).map(func(x): return int(x))
		if a.begins_with("--level="): level = int(a.get_slice("=", 1))
		if a.begins_with("--map="): mid = a.get_slice("=", 1)
		if a.begins_with("--raid_level="): raid_level = int(a.get_slice("=", 1))
		if a.begins_with("--route="): route_i = int(a.get_slice("=", 1))
		if a.begins_with("--reclaimed="): reclaimed = int(a.get_slice("=", 1))
		if a.begins_with("--reinforce="): reinforce = int(a.get_slice("=", 1))
	Sim.load_map(GameData.maps[GameData.town_map_id()])
	var m: Dictionary = Sim.load_map(GameData.maps[mid])
	m["spawners"].clear()
	RaidSystem.state(m)["force_level"] = raid_level
	RaidSystem.state(m)["force_reclaimed"] = reclaimed
	for e in m["entities"].duplicate():
		if e.kind == SimEntity.Kind.MONSTER:
			Sim.despawn(e)
	for n in bot_counts:
		var r := _run(m, n, level, trials)
		print("RAID bots=%d reforcos=%d repelidas=%d/%d chegada=%.0fs duracao=%.0fs sentinelas_mortas=%.1f bots_mortos=%.1f presos=%d%s" % [
			n, r["allies"], r["repelled"], trials, r["arrive"], r["dur"], r["guards"], r["bots"], r["stuck"], "  FLAG" if r["stuck"] > 0 else ""])
	print("RAID_END")
	get_tree().quit()

func _run(m: Dictionary, nbots: int, level: int, trials: int) -> Dictionary:
	var def: MapDef = m["def"]
	var r := RaidSystem.route_def(def, route_i)
	var guards: Array = m["entities"].filter(func(e): return e.guard)
	var gate: Vector3 = r["route"][r["route"].size() - 1]
	var classes: Array = GameData.classes.keys()
	var out := {"repelled": 0, "arrive": 0.0, "dur": 0.0, "guards": 0.0, "bots": 0.0, "stuck": 0}
	var arrived_n := 0
	for trial in range(trials):
		for g in guards:                 # sentinelas inteiras no posto
			g.position = g.home_position if not g.npc_data.has("route") else g.npc_data["pos"]
			g.home_position = g.npc_data["pos"]
			g.set_state(SimEntity.State.IDLE)
			g.threat.clear()
			g.aggro_target = -1
			g.recompute_stats()
			g.heal_full()
		var bots: Array = []
		for i in range(nbots):
			var cid: String = classes[(trial * 3 + i * 5) % classes.size()]
			bots.append(Sim.spawn_bot(GameData.classes[cid], "D%d" % i, def.id, gate + Vector3(-3 + i * 3, 0, 4), level))
		var allies := _reinforcements(m)
		m["sortie_cd"] = 0.0                  # no jogo a recarga (180 s) cabe entre duas levas
		var st := RaidSystem.state(m, route_i)
		st["n"] = trial % 3                  # alterna as levas (a 3ª traz o grifo)
		var ids := RaidSystem.start_raid(Sim, m, route_i)
		var t := 0.0
		var arrive := -1.0
		var guard_dead := {}
		var bot_dead := {}
		var last_pos := {}
		var still := {}
		var stuck_ids := {}
		while t < LIMIT and not st["ids"].is_empty():
			Sim.tick(DT)
			t += DT
			if arrive < 0.0 and st["arrived"]:
				arrive = t
			for g in guards:
				if not g.is_alive():
					guard_dead[g.id] = true
			for b in bots:
				if not b.is_alive():
					bot_dead[b.id] = true
			if int(t / DT) % 20 == 0:              # 1x por segundo: vigia de elfo parado fora de luta
				for id in st["ids"]:
					var e: SimEntity = Sim.entities.get(id)
					if e == null or e.aggro_target >= 0 or st["arrived"] or st["retreat"] or float(st["t"]) < Balance.RAID_MUSTER:
						still.erase(id)
						continue
					if last_pos.has(id) and e.position.distance_to(last_pos[id]) < 0.5:
						still[id] = int(still.get(id, 0)) + 1
						if still[id] >= 10:
							stuck_ids[id] = true
					else:
						still.erase(id)
					last_pos[id] = e.position
		if not st["retreat"] and st["ids"].is_empty():
			out["repelled"] += 1
		if arrive >= 0.0:
			out["arrive"] += arrive
			arrived_n += 1
		out["dur"] += t
		out["guards"] += guard_dead.size()
		out["bots"] += bot_dead.size()
		out["stuck"] += stuck_ids.size()
		for id in st["ids"].duplicate():
			if Sim.entities.has(id):
				Sim.despawn(Sim.entities[id])
		st["ids"] = []
		for b in bots:
			Sim.despawn(b)
		for id in allies:
			if Sim.entities.has(id):
				Sim.despawn(Sim.entities[id])
		for e in m["entities"].duplicate():           # corpos e lacaios que sobraram
			if e.kind == SimEntity.Kind.MONSTER:
				Sim.despawn(e)
	out["arrive"] = out["arrive"] / maxf(1, arrived_n)
	out["allies"] = _ally_count
	return _finish(out, trials)

var _ally_count := 0

## Reforços das `reinforce` primeiras fortalezas retomadas já na praça (fim da marcha), cheios até o max.
func _reinforcements(m: Dictionary) -> Array:
	var def: MapDef = m["def"]
	var ids: Array = []
	var done := 0
	for i in def.assaults.size():
		var a: Dictionary = def.assaults[i]
		if not str(a.get("id", "")).begins_with("reforco_") or done >= reinforce:
			continue
		done += 1
		var mine: Array = []
		while mine.size() < int(a.get("max", 8)):
			var got: Array = WorldState.spawn_assault(Sim, m, i)
			if got.is_empty():
				break
			mine.append_array(got)
		for id in mine:
			var e: SimEntity = Sim.entities[id]
			e.position = MapGeometry.random_walkable(Sim, def, a["target"], float(a.get("radius", 10.0)))
			e.raid_leg = (e.npc_data["march"] as Array).size() - 1
		ids.append_array(mine)
	_ally_count = ids.size()
	return ids

func _finish(out: Dictionary, trials: int) -> Dictionary:
	out["dur"] = out["dur"] / trials
	out["guards"] = out["guards"] / trials
	out["bots"] = out["bots"] / trials
	return out
