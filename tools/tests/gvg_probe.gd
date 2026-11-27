extends Node
## Guerra de Guildas (design/gdd/guerra-de-guildas.md §4/§8.5): N guerras inteiras bot contra bot, 12 × 12, lados iguais.
##   godot --headless --path . tools/tests/gvg_probe.tscn -- [--wars=10] [--level=30] [--dt=0.0333] [--seed=N]
##     [--pers=agressiva,defensiva,...] [--limit=<s de luta>] [--trace] [--slow=<ms>]
## Lados iguais: as mesmas classes/builds nos dois lados (o SUL é a "sua guilda" de bots, o NORTE a guilda inimiga).
## A cada guerra alterna quem ataca e roda as personalidades (sul, norte) pela lista --pers.
## --trace [--every=60] [--who]: linha do estado a cada <s> (com --who, cada combatente).
## Saída por guerra: "GVG i=N atk=S venceu=atk|def motivo=crystal|time tempo=Mmin plano_atk=a>b plano_def=c>d mortes_atk=.. mortes_def=..
##   portoes=main_N@s,.. arietes_perdidos=R canhao=tiros/acertos ariete=tiros_no_ariete/acertos cristal=pct ms_tick=M ms_max=X"
## Resumo: "GVG_SUM atk_vence=W/N (alvo 45-55%) dur_media_vitoria_atk=Mmin (alvo 10-16) dur_media=Mmin ms_tick=M (alvo <= 10)
##   canhao_ariete=pct (alvo >= 50%) portao_principal_cai=pct tempo_portao=Mmin"
##   e uma linha por plano de ataque inicial (vitórias/guerras).

var dt := 1.0 / 30.0
var who := false                 # --who: com --trace, cada combatente (papel/classe:objetivo(x,z), X = morto)
var every := 60.0                # --every=<s>: intervalo do --trace
var nav := false                 # --nav: só confere o caminho (GvgSystem.waypoint) do renascer até cada ponto e sai
var slow := -1.0                 # --slow=<ms>: cada passo da luta acima disto imprime as fases (Sim.profile) e os campos montados

func _ready() -> void:
	await get_tree().process_frame
	HuntPotionSystem.bots_drink = false
	var wars := 10
	var level := 30
	var limit := -1.0
	var trace := false
	var pers: Array = ["agressiva", "defensiva", "astuta", "equilibrada"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--wars="): wars = int(a.get_slice("=", 1))
		if a.begins_with("--level="): level = int(a.get_slice("=", 1))
		if a.begins_with("--dt="): dt = float(a.get_slice("=", 1))
		if a.begins_with("--seed="): Sim.rng.seed = int(a.get_slice("=", 1))
		if a.begins_with("--pers="): pers = Array(a.get_slice("=", 1).split(","))
		if a.begins_with("--limit="): limit = float(a.get_slice("=", 1))
		if a == "--trace": trace = true
		if a == "--who": who = true
		if a.begins_with("--every="): every = float(a.get_slice("=", 1))
		if a == "--nav": nav = true
		if a.begins_with("--slow="): slow = float(a.get_slice("=", 1))
	Sim.load_map(GameData.maps[GameData.town_map_id()])
	Sim.load_map(GameData.maps[MapsCatalog.GVG_FIELD_ID])
	var atk_wins := 0
	var dur_all := 0.0
	var dur_atk := 0.0
	var ms_all := 0.0
	var ms_n := 0
	var ms_max := 0.0
	var ram_shots := 0
	var ram_hits := 0
	var main_fell := 0
	var main_t := 0.0
	var by_plan := {}
	for i in wars:
		var attack := i % 2 == 0                         # SUL ataca nas pares
		var ps: String = pers[i % pers.size()]
		var pn: String = pers[(i + 1 + i / pers.size()) % pers.size()]
		var comp := _comp(level)
		_guild("g_probe_s", "Sonda Sul", "SUL", ps, comp)
		_guild("g_probe_n", "Sonda Norte", "NOR", pn, comp)
		var mine: Array = []
		for k in comp.size():
			var c: Array = comp[k]
			var cls: ClassDef = GameData.classes[c[0]]
			var b := Sim.spawn_bot(cls, "SondaS%d" % k, GameData.town_map_id(), GameData.maps[GameData.town_map_id()].spawn_point, level)
			RosterSystem.set_level(Sim, b, level, str(c[1]))
			b.heal_full()
			mine.append(b)
		var run := GvgSystem.begin(Sim, mine[0], mine.slice(1), "g_probe_s", "g_probe_n", attack)
		if nav:
			_nav_report(run)
			break
		var atk_side := str(run["attacker"])
		var def_side := str(run["defender"])
		var plans := {"N": [], "S": []}
		var t := 0.0
		var r_ms := 0.0
		var r_n := 0
		var r_max := 0.0
		var cap := (Balance.GVG_TIME_MIN * 60.0 + Balance.GVG_PREP_S + 5.0) if limit < 0.0 else limit + Balance.GVG_PREP_S
		var next_trace := every
		while str(Sim.gvg.get("phase", "end")) != "end" and t < cap:
			if slow > 0.0:
				Sim.profile = true
				Sim.prof.clear()
			var t0 := Time.get_ticks_usec()
			Sim.tick(dt)
			var us := float(Time.get_ticks_usec() - t0)
			if slow > 0.0 and us > slow * 1000.0 and str(Sim.gvg.get("phase", "")) == "fight":
				_slow_row(t, us)
			t += dt
			if str(Sim.gvg.get("phase", "")) == "fight":
				r_ms += us
				r_n += 1
				r_max = maxf(r_max, us)
			for s in ["N", "S"]:
				var sd: Dictionary = (Sim.gvg.get("sides", {}) as Dictionary).get(s, {})
				var pl := str(sd.get("plan", ""))
				if pl != "" and ((plans[s] as Array).is_empty() or (plans[s] as Array).back() != pl):
					(plans[s] as Array).append(pl)
			if trace and t >= next_trace and not Sim.gvg.is_empty():
				next_trace += every
				_trace(t)
		var sm: Dictionary = Sim.gvg.get("summary", {})
		if sm.is_empty():                                  # passou do teto da sonda (--limit): conta como tempo
			sm = GvgSystem.finish(Sim, def_side, "probe_limit")
		var st: Dictionary = sm.get("stats", {})
		var won_atk := str(sm.get("winner", "")) == atk_side
		var fight_t := float(sm.get("time", 0.0))
		if won_atk:
			atk_wins += 1
			dur_atk += fight_t
		dur_all += fight_t
		ms_all += r_ms
		ms_n += r_n
		ms_max = maxf(ms_max, r_max)
		ram_shots += int(st.get("cannon_ram_shots", 0))
		ram_hits += int(st.get("cannon_ram_hits", 0))
		var gb: Dictionary = sm.get("gates_broken", {})
		if gb.has("main_" + def_side):
			main_fell += 1
			main_t += float(gb["main_" + def_side])
		var p0 := str((plans[atk_side] as Array).front()) if not (plans[atk_side] as Array).is_empty() else "?"
		var pr: Array = by_plan.get_or_add(p0, [0, 0])
		pr[0] = int(pr[0]) + (1 if won_atk else 0)
		pr[1] = int(pr[1]) + 1
		var gates := PackedStringArray()
		for k in gb:
			gates.append("%s@%.0fs" % [k, float(gb[k])])
		var deaths: Dictionary = sm.get("deaths", {})
		var gd: Dictionary = st.get("gate_dmg", {})
		print("GVG i=%d atk=%s pers_atk=%s pers_def=%s venceu=%s motivo=%s tempo=%.1fmin plano_atk=%s plano_def=%s mortes_atk=%d mortes_def=%d portoes=%s arietes_perdidos=%d golpes_ariete=%d canhao=%d/%d ariete=%d/%d dano_portao=cerco:%d,area:%d,comum:%d cristal=%.0f%% ms_tick=%.2f ms_max=%.1f" % [
			i, atk_side, ps if atk_side == "S" else pn, pn if atk_side == "S" else ps, "atk" if won_atk else "def", sm.get("reason", ""), fight_t / 60.0,
			">".join(PackedStringArray(plans[atk_side])), ">".join(PackedStringArray(plans[def_side])),
			int(deaths.get(atk_side, 0)), int(deaths.get(def_side, 0)), ",".join(gates), int(Sim.gvg["sides"][atk_side]["rams_lost"]) if not Sim.gvg.is_empty() else -1,
			int(st.get("ram_hits", 0)), int(st.get("cannon_shots", 0)), int(st.get("cannon_hits", 0)), int(st.get("cannon_ram_shots", 0)), int(st.get("cannon_ram_hits", 0)),
			int(gd.get("siege", 0)), int(gd.get("area", 0)), int(gd.get("plain", 0)), float(sm.get("crystal_pct", 0.0)) * 100.0,
			r_ms / maxi(1, r_n) / 1000.0, r_max / 1000.0])
		GvgSystem.close(Sim)
		for b: SimEntity in mine:
			if Sim.entities.has(b.id):
				Sim.despawn(b)
		Sim.guilds.clear()
	var plan_rows := PackedStringArray()
	for p in by_plan:
		plan_rows.append("%s=%d/%d" % [p, by_plan[p][0], by_plan[p][1]])
	print("GVG_SUM guerras=%d atk_vence=%d/%d (%.0f%%, alvo 45-55%%) dur_media_vitoria_atk=%.1fmin (alvo 10-16) dur_media=%.1fmin ms_tick=%.2f ms_max=%.1f (alvo <= 10) canhao_ariete=%d/%d (%.0f%%, alvo >= 50%%) portao_principal_cai=%d/%d tempo_portao=%.1fmin planos_atk=%s" % [
		wars, atk_wins, wars, 100.0 * atk_wins / maxi(1, wars), dur_atk / maxi(1, atk_wins) / 60.0, dur_all / maxi(1, wars) / 60.0,
		ms_all / maxi(1, ms_n) / 1000.0, ms_max / 1000.0, ram_hits, ram_shots, 100.0 * ram_hits / maxi(1, ram_shots), main_fell, wars,
		main_t / maxi(1, main_fell) / 60.0, " ".join(plan_rows)])
	print("GVG_END")
	get_tree().quit()

## 12 [classe, build] sorteados pela rng da sim: a mesma lista vai para os dois lados.
func _comp(_level: int) -> Array:
	var out: Array = []
	var classes: Array = GameData.class_list()
	for k in Balance.GVG_SIDE_SIZE:
		var cls: ClassDef = classes[Sim.rng.randi() % classes.size()]
		var build: String = cls.builds[Sim.rng.randi() % cls.builds.size()]["id"] if cls.builds.size() > 0 else ""
		out.append([cls.id, build])
	return out

func _guild(gid: String, nm: String, tag: String, pers: String, comp: Array) -> void:
	var members: Array = []
	for k in comp.size():
		members.append({"name": "%s%d" % [tag, k], "class": comp[k][0], "build": comp[k][1], "level": 0, "personality": "calmo", "rid": -1})
	Sim.guilds[gid] = {"id": gid, "name": nm, "tag": tag, "personality": pers, "crest": 0, "bot_guild": true, "player_member": false,
		"founded_by_player": false, "leader": members[0]["name"], "members": members}

## --nav: um "fantasma" de cada lado anda pelos pontos de GvgSystem.waypoint (1 m por passo) do renascer até cada alvo.
func _nav_report(run: Dictionary) -> void:
	run["phase"] = "fight"
	for s in ["S", "N"]:
		var e: SimEntity = Sim.entities[int(run["sides"][s]["ids"][1])]
		var foe := GvgSystem.other(s)
		for key in ["gate_main_" + foe, "gate_side_" + foe, "crystal_" + s, "cannon_%s_01" % s, "cannon_%s_03" % s, "cannon_hill_01", "cannon_hill_02",
				"ram_spawn_%s_01" % s, "gate_main_" + s, "spawn_" + foe]:
			var to := MapsCatalog.gvg_point(key)
			e.position = MapsCatalog.gvg_point("spawn_" + s)
			var steps := 0
			var walked := 0.0
			while steps < 600 and Vector2(e.position.x - to.x, e.position.z - to.z).length() > 2.5:
				var wp := GvgSystem._waypoint(Sim, e, to)
				var d := wp - e.position
				d.y = 0.0
				var st := minf(1.0, d.length())
				var np := e.position + d.normalized() * st if d.length() > 0.01 else e.position
				np = Sim._resolve_obstacles(np, Balance.ENTITY_RADIUS, Sim.maps[e.map_id])
				walked += np.distance_to(e.position)
				e.position = np
				GvgSystem._gates(Sim, run)
				steps += 1
			var ok := Vector2(e.position.x - to.x, e.position.z - to.z).length() <= 2.5
			print("NAV %s %s -> %s: %s passos=%d andou=%.0fm fim=(%.1f,%.1f)" % [s, "renascer", key, "ok" if ok else "PRESO", steps, walked, e.position.x, e.position.z])

## --slow: fases do passo lento (ms, maiores primeiro) + campos de caminho montados nele.
func _slow_row(t: float, us: float) -> void:
	var rows: Array = []
	for k in Sim.prof:
		if not str(k).begins_with("map_") and str(k) != "commands" and str(k) != "entities":
			rows.append([float(Sim.prof[k]), str(k)])
	rows.sort()
	rows.reverse()
	var parts := PackedStringArray()
	for r in rows.slice(0, 5):
		parts.append("%s=%.1f" % [r[1], float(r[0]) / 1000.0])
	var built := int(Sim.gvg.get("nav_n", 0)) if float(Sim.gvg.get("nav_tick", -1.0)) == Sim.time else 0
	print("SLOW t=%.1fs ms=%.1f campos=%d fila=%d %s" % [t, us / 1000.0, built, (Sim.gvg.get("nav_q", []) as Array).size(), " ".join(parts)])

func _trace(t: float) -> void:
	var g: Dictionary = Sim.gvg
	var a := str(g["attacker"])
	var d := str(g["defender"])
	var alive := {"N": GvgSystem.alive_of(Sim, "N").size(), "S": GvgSystem.alive_of(Sim, "S").size()}
	var rams := PackedStringArray()
	for o: Dictionary in GvgSystem.objects(Sim):
		if o["type"] == "ram":
			rams.append("%s:%.0f%%@(%.0f,%.0f)p%d" % [o["key"], float(o["hp_pct"]) * 100.0, (o["pos"] as Vector3).x, (o["pos"] as Vector3).z, int(o.get("pushers", 0))])
	var ops := 0
	for o: Dictionary in GvgSystem.objects(Sim):
		if o["type"] == "cannon" and int(o["operator_id"]) >= 0:
			ops += 1
	print("  t=%.0fs fase=%s plano=%s/%s vivos atk=%d def=%d portao=%.0f%% lateral=%.0f%% cristal=%.0f%% morro=%s canhoneiros=%d arietes=%s" % [t, g["phase"],
		g["sides"][a]["plan"], g["sides"][d]["plan"], alive[a], alive[d], GvgSystem.hp_pct(Sim, "main_" + d) * 100.0, GvgSystem.hp_pct(Sim, "side_" + d) * 100.0,
		GvgSystem.hp_pct(Sim, "crystal_" + d) * 100.0, g["hill"], ops, " ".join(rams)])
	if who:
		for s in [a, d]:
			var row := PackedStringArray()
			for id in g["sides"][s]["ids"]:
				var e: SimEntity = Sim.entities.get(int(id))
				if e == null:
					continue
				var w: Dictionary = (e.brain as BotBrain).war if e.brain is BotBrain else {}
				row.append("%s/%s:%s(%.0f,%.0f)%s" % [str(w.get("role", "?")).substr(0, 3), e.class_def.id.substr(0, 3), str(w.get("goal", "?")), e.position.x, e.position.z,
					"" if e.is_alive() else "X"])
			print("    %s %s: %s" % ["ATK" if s == a else "DEF", s, " ".join(row)])
