extends Node
## Investidas élficas contra o Posto dos Caçadores (calibrar RAID/GUARD/elfos): N levas por cenário, sem os outros spawners.
##   godot --headless --path . tools/tests/raid_probe.tscn -- [--trials=20] [--bots=0,1,3] [--level=15] [--map=field_forest] [--raid_level=20]
## --route=N = lado da cidade atacada por vários lados (0 = MapDef.raid). --raid_level = nível do jogador que dá a força da leva (Balance.RAID_SCALE_*); sem ele, força base.
## Cenário = quantos bots (nível --level) esperam no portão norte junto das sentinelas.
## Saída: "RAID bots=N repelidas=R/T chegada=Ss duracao=Ss sentinelas_mortas=G bots_mortos=B presos=P"
##   repelidas = leva toda derrubada antes do recuo; chegada = s até a 1ª entrar no raio do povoado;
##   presos = elfos parados 10 s fora de luta antes de chegar (FLAG: rota/pathing quebrado).
## --quests=<id,...>: mede um estágio da conquista (ex.: `--map=city_port --route=1 --quests=hx_palisade` = C1, paliçada fechada).
## --side=<lado>: escolhe a rota pelo nome (ex.: `--map=city_port --side=cerco_ne`), em vez do índice de --route.
## --siege_run=<s>: Cerco Vivo de verdade (mapa com MapDef.siege): um jogador parado na chegada, o relógio do SiegeSystem solta
##   levas, assédios e trompas por <s> segundos. Saída: "SIEGE levas=N repelidas=R (x%) chamas=C assedios=A trompas=T
##   intervalo_medio=Ss (eventos = leva + assédio) min_pos_repelida=Ss invasores_max=N hazards_max=N xp_cerco_min=X"
##   (--bots=N põe N bots do nível --level na praça; --quests= fixa o estágio).
## --reinforce=N: os reforços das N primeiras fortalezas retomadas (assaults "reforco_*" do mapa) já rondando a praça,
##   cheios até o `max` de cada um, como no jogo depois das retomadas (sem eles a sonda mede só a guarnição).
## --sync: mapa com ataque simultâneo (Balance.RAID_SYNC_MAPS, ex. `--map=field_ruins`): solta todos os lados juntos
##   (RaidSystem.start_sync), bots na praça. Saída: "SYNC bots=N tudo_repelido=R/T lados_repelidos=L/3 invasores=N
##   chegaram=C duracao=Ss sentinelas_mortas=G bots_mortos=B ms_tick=M ms_tick_max=X"

const LIMIT := 260.0
const DT := 1.0 / 20.0
var route_i := 0
var reclaimed := 0               # --reclaimed=N: fortalezas retomadas (fúria das levas, RaidSystem.reclaimed)                 # --route=N: qual lado da cidade (RaidSystem.routes)
var reinforce := 0
var side := ""                   # --side=<lado>: rota pelo nome
var siege_run := 0.0             # --siege_run=<s>: relógio do cerco de verdade
var sync := false                # --sync: todos os lados juntos (RaidSystem.start_sync)
var quests: PackedStringArray = []   # --quests=<id,...>: quests feitas (WorldState: rota, guarnição e colisores do estágio; ex. hx_palisade com --route=1)

func _ready() -> void:
	await get_tree().process_frame
	HuntPotionSystem.bots_drink = false        # calibragem sem Poção de Caça (design/gdd/pocoes-de-caca.md §3.5)
	var trials := 20
	var bot_counts := [0, 1, 3]
	var level := 15
	var mid := "field_forest"
	var raid_level := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--trials="): trials = int(a.get_slice("=", 1))
		if a.begins_with("--seed="): Sim.rng.seed = int(a.get_slice("=", 1))   # semente da sim (fixa por padrão: pedaços repetem a mesma amostra)
		if a.begins_with("--bots="): bot_counts = Array(a.get_slice("=", 1).split(",")).map(func(x): return int(x))
		if a.begins_with("--level="): level = int(a.get_slice("=", 1))
		if a.begins_with("--map="): mid = a.get_slice("=", 1)
		if a.begins_with("--raid_level="): raid_level = int(a.get_slice("=", 1))
		if a.begins_with("--route="): route_i = int(a.get_slice("=", 1))
		if a.begins_with("--reclaimed="): reclaimed = int(a.get_slice("=", 1))
		if a.begins_with("--reinforce="): reinforce = int(a.get_slice("=", 1))
		if a.begins_with("--quests="): quests = a.get_slice("=", 1).split(",")
		if a.begins_with("--side="): side = a.get_slice("=", 1)
		if a.begins_with("--siege_run="): siege_run = float(a.get_slice("=", 1))
		if a == "--sync": sync = true
	Sim.load_map(GameData.maps[GameData.town_map_id()])
	var m: Dictionary = Sim.load_map(GameData.maps[mid])
	m["spawners"].clear()
	if not quests.is_empty():          # estágio da conquista: um jogador parado no ponto de entrada do mapa (mapa acordado), com as quests feitas
		var p := Sim.spawn_player(GameData.classes["paladin"], "Sonda", mid)
		p.brain = null
		for q in quests:
			p.quests_completed.append(q)
		WorldState.sync_npcs(Sim, m)
		MapGeometry.sync_stage(Sim, m)
	if side != "":
		route_i = maxi(0, SiegeSystem.route_index(GameData.maps[mid], side))
	if siege_run > 0.0:
		for n in bot_counts:
			_siege_run(m, n, level)
		print("RAID_END")
		get_tree().quit()
		return
	if SiegeSystem.managed(GameData.maps[mid]):
		SiegeSystem.state(m)["hold"] = true          # a sonda solta as levas à mão: o relógio do cerco fica parado (a reserva continua respondendo)
	RaidSystem.state(m)["force_level"] = raid_level
	RaidSystem.state(m)["force_reclaimed"] = reclaimed
	for e in m["entities"].duplicate():
		if e.kind == SimEntity.Kind.MONSTER:
			Sim.despawn(e)
	if sync:
		RaidSystem.sync_state(m)["timer"] = INF      # a sonda solta os ataques à mão
		for n in bot_counts:
			_sync_run(m, n, level, trials)
		print("RAID_END")
		get_tree().quit()
		return
	for n in bot_counts:
		var r := _run(m, n, level, trials)
		print("RAID bots=%d reforcos=%d repelidas=%d/%d chegada=%.0fs duracao=%.0fs mediana=%.0fs luta_mediana=%.0fs chegaram=%.1f/%.1f sentinelas_mortas=%.1f sentinelas_vida_min=%.0f%% bots_mortos=%.1f presos=%d%s" % [
			n, r["allies"], r["repelled"], trials, r["arrive"], r["dur"], r["median"], r["fight_median"], r["reached"], r["size"], r["guards"], r["guard_hp"] * 100.0, r["bots"], r["stuck"], "  FLAG" if r["stuck"] > 0 else ""])
		print("SPREAD bots=%d chegada_desvio=%.1fs aglomerado_max=%d vivos_max=%d" % [n, float(r.get("spread", 0.0)) / maxf(1.0, float(r.get("spread_n", 0))), int(r.get("clump_max", 0)), int(r.get("live_max", 0))])
	print("RAID_END")
	get_tree().quit()

func _run(m: Dictionary, nbots: int, level: int, trials: int) -> Dictionary:
	var def: MapDef = m["def"]
	var r := RaidSystem.route_def(def, route_i)
	var guards: Array = m["entities"].filter(func(e): return e.guard)
	var gate: Vector3 = r["route"][r["route"].size() - 1]
	var classes: Array = GameData.classes.keys()
	var out := {"repelled": 0, "arrive": 0.0, "dur": 0.0, "guards": 0.0, "bots": 0.0, "stuck": 0, "reached": 0.0, "size": 0.0, "guard_hp": 0.0}
	var durs: Array = []             # duração de cada leva (mediana) e da luta (da chegada ao fim)
	var fights: Array = []
	var radius: float = float(r.get("radius", 25.0))
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
		var reached := {}                # invasores que entraram no raio do alvo (chegaram à brecha/portão)
		var hp_min := 1.0                # menor fração de vida somada da guarnição durante a leva
		out["size"] += int(st.get("total", ids.size()))      # escalões: conta quem ainda vai nascer
		var t := 0.0
		var arrive := -1.0
		var guard_dead := {}
		var bot_dead := {}
		var last_pos := {}
		var still := {}
		var stuck_ids := {}
		var arr_t := {}                  # SPREAD: id -> s em que entrou no raio do alvo
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
			if int(t / DT) % 10 == 0:
				for id in st["ids"]:
					var inv: SimEntity = Sim.entities.get(id)
					if inv != null and inv.position.distance_to(r["target"]) < radius:
						reached[id] = true
						if not arr_t.has(id):
							arr_t[id] = t
				var hp := 0.0
				var hp_max := 0.0
				for g in guards:
					hp += maxf(0.0, g.hp) if g.is_alive() else 0.0
					hp_max += g.stats.max_hp
				hp_min = minf(hp_min, hp / maxf(1.0, hp_max))
			if int(t / DT) % 20 == 0:              # SPREAD: maior bolo (círculo de 6 m) de invasores em marcha e vivos ao mesmo tempo
				var live_inv: Array = []
				for id in st["ids"]:
					var v: SimEntity = Sim.entities.get(id)
					if v != null and v.is_alive():
						live_inv.append(v)
				out["live_max"] = maxi(int(out.get("live_max", 0)), live_inv.size())
				for a in live_inv:
					if arr_t.has(a.id):
						continue
					var c := 0
					for b in live_inv:
						if not arr_t.has(b.id) and a.position.distance_to(b.position) < 6.0:
							c += 1
					out["clump_max"] = maxi(int(out.get("clump_max", 0)), c)
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
		durs.append(t)
		if arrive >= 0.0:
			fights.append(t - arrive)
		out["reached"] += reached.size()
		if arr_t.size() >= 2:                     # SPREAD: desvio padrão dos tempos de chegada (s)
			var mean := 0.0
			for id in arr_t:
				mean += float(arr_t[id])
			mean /= arr_t.size()
			var var_ := 0.0
			for id in arr_t:
				var_ += pow(float(arr_t[id]) - mean, 2.0)
			out["spread"] = float(out.get("spread", 0.0)) + sqrt(var_ / arr_t.size())
			out["spread_n"] = int(out.get("spread_n", 0)) + 1
		out["guard_hp"] += hp_min
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
	durs.sort()
	fights.sort()
	out["median"] = durs[durs.size() / 2] if not durs.is_empty() else 0.0
	out["fight_median"] = fights[fights.size() / 2] if not fights.is_empty() else 0.0
	out["reached"] = out["reached"] / trials
	out["size"] = out["size"] / trials
	out["guard_hp"] = out["guard_hp"] / trials
	return _finish(out, trials)

var _ally_count := 0

## --sync: N ataques simultâneos (todos os lados), bots na praça, guarnição inteira a cada ataque.
func _sync_run(m: Dictionary, nbots: int, level: int, trials: int) -> void:
	var def: MapDef = m["def"]
	var n_routes := RaidSystem.routes(def).size()
	var guards: Array = m["entities"].filter(func(e): return e.guard)
	var classes: Array = GameData.classes.keys()
	var all_rep := 0
	var sides_rep := 0
	var size := 0.0
	var reached_sum := 0.0
	var dur := 0.0
	var guards_dead := 0.0
	var bots_dead := 0.0
	var tick_ms := 0.0
	var ticks := 0
	var tick_max := 0.0
	for trial in range(trials):
		for g in guards:
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
			bots.append(Sim.spawn_bot(GameData.classes[cid], "D%d" % i, def.id, Sim.random_walkable(def, def.town_center, 6.0), level))
		var allies := _reinforcements(m)
		m["sortie_cd"] = 0.0
		for i in n_routes:
			RaidSystem.state(m, i)["n"] = trial % 2
		var ids := RaidSystem.start_sync(Sim, m)
		size += ids.size()
		var reached := {}
		var guard_dead := {}
		var bot_dead := {}
		var t := 0.0
		var live := true
		while t < LIMIT * 1.5 and live:
			var t0 := Time.get_ticks_usec()
			Sim.tick(DT)
			var ms := (Time.get_ticks_usec() - t0) / 1000.0
			tick_ms += ms
			ticks += 1
			tick_max = maxf(tick_max, ms)
			t += DT
			live = false
			for i in n_routes:
				if not (RaidSystem.state(m, i)["ids"] as Array).is_empty():
					live = true
			for g in guards:
				if not g.is_alive():
					guard_dead[g.id] = true
			for b in bots:
				if not b.is_alive():
					bot_dead[b.id] = true
			if int(t / DT) % 10 == 0:
				for i in n_routes:
					var rr := RaidSystem.route_def(def, i)
					for id in RaidSystem.state(m, i)["ids"]:
						var inv: SimEntity = Sim.entities.get(id)
						if inv != null and inv.position.distance_to(rr["target"]) < float(rr.get("radius", 25.0)):
							reached[id] = true
		var rep := 0
		for i in n_routes:
			var st := RaidSystem.state(m, i)
			if not st["retreat"] and (st["ids"] as Array).is_empty():
				rep += 1
			for id in (st["ids"] as Array).duplicate():
				if Sim.entities.has(id):
					Sim.despawn(Sim.entities[id])
			st["ids"] = []
			st["retreat"] = false
		sides_rep += rep
		if rep == n_routes:
			all_rep += 1
		reached_sum += reached.size()
		dur += t
		guards_dead += guard_dead.size()
		bots_dead += bot_dead.size()
		for b in bots:
			Sim.despawn(b)
		for id in allies:
			if Sim.entities.has(id):
				Sim.despawn(Sim.entities[id])
		for e in m["entities"].duplicate():
			if e.kind == SimEntity.Kind.MONSTER:
				Sim.despawn(e)
	print("SYNC bots=%d nivel=%d tudo_repelido=%d/%d lados_repelidos=%.1f/%d invasores=%.0f chegaram=%.1f duracao=%.0fs sentinelas_mortas=%.1f bots_mortos=%.1f ms_tick=%.2f ms_tick_max=%.1f" % [
		nbots, level, all_rep, trials, float(sides_rep) / trials, n_routes, size / trials, reached_sum / trials, dur / trials,
		guards_dead / trials, bots_dead / trials, tick_ms / maxf(1, ticks), tick_max])
var _ev: Array = []              # --siege_run: [tempo, tipo]

## Cerco de verdade por `siege_run` s: jogador parado na chegada do mapa (longe do muro), relógio do SiegeSystem.
func _siege_run(m: Dictionary, nbots: int, level: int) -> void:
	var def: MapDef = m["def"]
	for e in m["entities"].duplicate():
		if e.kind == SimEntity.Kind.MONSTER or e.kind == SimEntity.Kind.BOT:
			Sim.despawn(e)
	m.erase("siege")
	for i in RaidSystem.routes(def).size():
		m.erase("raid" if i == 0 else "raid_%d" % i)
	if Sim.player == null:
		var p := Sim.spawn_player(GameData.classes["paladin"], "Sonda", def.id)
		p.brain = null
		p.level = level                      # a força da leva segue o nível do jogador no mapa (RaidSystem.power_step)
		for q in quests:
			p.quests_completed.append(q)
		WorldState.sync_npcs(Sim, m)
		MapGeometry.sync_stage(Sim, m)
	var classes: Array = GameData.classes.keys()
	var bots: Array = []
	for i in range(nbots):
		bots.append(Sim.spawn_bot(GameData.classes[classes[(i * 5) % classes.size()]], "D%d" % i, def.id, def.town_center + Vector3(-3 + i * 3, 0, 4), level))
	_ev.clear()
	var on_raid := func(mid: String, kind: String) -> void:
		if mid == def.id: _ev.append([Sim.time, "raid_" + kind])
	var on_siege := func(mid: String, kind: String) -> void:
		if mid == def.id: _ev.append([Sim.time, "siege_" + kind])
	Events.raid_event.connect(on_raid)
	Events.siege_event.connect(on_siege)
	var t0: float = Sim.time
	var t := 0.0
	var max_inv := 0
	var max_hz := 0
	var xp := 0.0
	var seen_dead := {}
	while t < siege_run:
		Sim.tick(DT)
		t += DT
		if int(t / DT) % 20 == 0:
			var inv := 0
			for e in m["entities"]:
				if e.kind == SimEntity.Kind.MONSTER:
					if e.is_alive():
						inv += 1
					elif not seen_dead.has(e.id):
						seen_dead[e.id] = true
						xp += e.monster_def.xp
			max_inv = maxi(max_inv, inv)
			max_hz = maxi(max_hz, (m.get("hazards", []) as Array).size())
			Sim.player.hp = Sim.player.stats.max_hp          # a sonda mede a guarnição: o jogador parado não morre
	Events.raid_event.disconnect(on_raid)
	Events.siege_event.disconnect(on_siege)
	var waves := 0
	var repelled := 0
	var scorch := 0
	var harass := 0
	var horns := 0
	var starts: Array = []
	var min_after := INF
	var last_rep := -1.0
	for ev in _ev:
		var at: float = float(ev[0]) - t0
		match str(ev[1]):
			"raid_start":
				waves += 1
				starts.append(at)
				if last_rep >= 0.0:
					min_after = minf(min_after, at - last_rep)
					last_rep = -1.0
			"raid_repelled":
				repelled += 1
				last_rep = at
			"siege_scorch": scorch += 1
			"siege_harass":
				harass += 1
				starts.append(at)
			"siege_horn": horns += 1
	starts.sort()
	var gap := 0.0
	for i in range(1, starts.size()):
		gap += float(starts[i]) - float(starts[i - 1])
	var ended: int = _ev.filter(func(ev): return str(ev[1]) in ["raid_repelled", "raid_retreated"]).size()
	print("SIEGE bots=%d p=%d levas=%d repelidas=%d/%d (%.0f%%) chamas=%d assedios=%d trompas=%d intervalo_medio=%.0fs min_pos_repelida=%.0fs invasores_max=%d hazards_max=%d xp_cerco_min=%.0f" % [
		nbots, SiegeSystem.pressure(Sim, def), waves, repelled, ended, 100.0 * repelled / maxf(1.0, ended), scorch, harass, horns,
		gap / maxf(1.0, starts.size() - 1), min_after if min_after != INF else -1.0, max_inv, max_hz, xp / (siege_run / 60.0)])
	for b in bots:
		Sim.despawn(b)

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
