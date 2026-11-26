extends Node
## Campo de Caça da Guilda (design/gdd/arena-da-guilda.md §8.5): grupo de 5 bots do nível na arena, levas até cair.
##   godot --headless --path . tools/tests/arena_probe.tscn -- [--level=20,30,40] [--runs=5] [--comp=paladin:guardiao,bishop:sacerdote,...]
##     [--limit=2400] [--dt=0.0166667] [--seed=N]
## Sem --comp: tanque + cura + 3 dano (paladin:guardiao, bishop:sacerdote e 3 classes de dano em rodízio por corrida).
## O 1º do grupo é o líder (os outros seguem; sem jogador, o líder luta pela regra BotBrain._arena).
## Saída por corrida: "ARENA lv=L run=i wave=W tempo=Ss abates=K ms_tick=M ms_tick_cheio=X (ticks com >= 25 vivos)"
## Resumo: "ARENA_SUM lv=L leva_media=W na_meta=N/T (12-18) tempo_medio=Mmin ms_tick=M ms_tick_cheio=X"
##   meta §4/§8.5: leva 12-18 em >= 70% das corridas, 15-25 min, tick <= 10 ms com 30 vivos.

const DPS := ["berserker", "elementalist", "ranger", "assassin", "necromancer", "druid"]

func _ready() -> void:
	await get_tree().process_frame
	HuntPotionSystem.bots_drink = false
	var levels := [20, 30, 40]
	var runs := 5
	var comp: Array = []
	var limit := 2400.0
	var dt := 1.0 / 60.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="): levels = Array(a.get_slice("=", 1).split(",")).map(func(x): return int(x))
		if a.begins_with("--runs="): runs = int(a.get_slice("=", 1))
		if a.begins_with("--comp="): comp = Array(a.get_slice("=", 1).split(","))
		if a.begins_with("--limit="): limit = float(a.get_slice("=", 1))
		if a.begins_with("--dt="): dt = float(a.get_slice("=", 1))
		if a.begins_with("--seed="): Sim.rng.seed = int(a.get_slice("=", 1))
	Sim.load_map(GameData.maps[GameData.town_map_id()])
	Sim.load_map(GameData.maps[MapsCatalog.GUILD_GROUNDS_ID])
	for lv in levels:
		var waves: Array = []
		var times: Array = []
		var ok := 0
		var ms_all := 0.0
		var ms_n := 0
		var full_all := 0.0
		var full_n := 0
		var full_max := 0.0
		for i in runs:
			var c: Array = comp if not comp.is_empty() else ["paladin:guardiao", "bishop:sacerdote", DPS[i % DPS.size()] + ":", DPS[(i + 2) % DPS.size()] + ":", DPS[(i + 4) % DPS.size()] + ":"]
			var group: Array = []
			for k in c.size():
				var parts: PackedStringArray = str(c[k]).split(":")
				var cls: ClassDef = GameData.classes[parts[0]]
				var b := Sim.spawn_bot(cls, "Sonda%d" % k, GameData.town_map_id(), GameData.maps[GameData.town_map_id()].spawn_point, lv)
				if parts.size() > 1 and parts[1] != "" and not cls.build_by_id(parts[1]).is_empty():
					RosterSystem.set_level(Sim, b, lv, parts[1])
				group.append(b)
			var run := ArenaSystem.start_run(Sim, group[0], group.slice(1), "probe")
			var t := 0.0
			var kills := 0
			var stalls := 0
			var stall_names := {}
			var r_ms := 0.0
			var r_n := 0
			while not ArenaSystem.run_of(Sim).is_empty() and t < limit:
				var t0 := Time.get_ticks_usec()
				Sim.tick(dt)
				var us := float(Time.get_ticks_usec() - t0)
				t += dt
				r_ms += us
				r_n += 1
				var st := ArenaSystem.status(Sim)
				if not st.is_empty():
					kills = int(st["kills"])
					stalls = int(st["stalls"])
					stall_names = st["stall_names"]
					if int(st["alive"]) >= 25:
						full_all += us
						full_n += 1
						full_max = maxf(full_max, us)
			var rec: Dictionary = (Sim.arena.get("last", {}) as Dictionary)
			var wave := int(rec.get("wave", 0))
			if not ArenaSystem.run_of(Sim).is_empty():
				wave = int(ArenaSystem.run_of(Sim)["wave"])
				ArenaSystem.finish(Sim, "leave")
			waves.append(wave)
			times.append(t)
			if wave >= 12 and wave <= 18:
				ok += 1
			ms_all += r_ms
			ms_n += r_n
			print("ARENA lv=%d run=%d wave=%d tempo=%.0fs abates=%d travadas=%d %s ms_tick=%.2f grupo=%s" % [lv, i, wave, t, kills, stalls, stall_names if stalls > 0 else "", r_ms / maxi(1, r_n) / 1000.0, ",".join(PackedStringArray(c))])
			for b: SimEntity in group:
				Sim.despawn(b)
			Sim.arena.erase("records")
			Sim.arena.erase("personal")
		var wsum := 0
		for w in waves:
			wsum += int(w)
		var tsum := 0.0
		for x in times:
			tsum += float(x)
		print("ARENA_SUM lv=%d leva_media=%.1f levas=%s na_meta=%d/%d (12-18) tempo_medio=%.1fmin ms_tick=%.2f ms_tick_cheio=%.2f (max %.1f, %d ticks)" % [lv,
			float(wsum) / maxi(1, waves.size()), waves, ok, runs, tsum / maxi(1, times.size()) / 60.0, ms_all / maxi(1, ms_n) / 1000.0,
			full_all / maxi(1, full_n) / 1000.0, full_max / 1000.0, full_n])
	print("ARENA_END")
	get_tree().quit()
