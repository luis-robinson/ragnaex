extends Node
## Sonda de custo da simulação (sem tela, sem bonecos): o mundo inteiro como no jogo (todos os mapas, bots, jogador na
## cidade parado), semente fixa, N ticks de 1/60 s. Imprime ms/tick (média, p95) e uma soma de conferência do estado:
## otimização da sim que não muda comportamento tem de dar a MESMA soma antes e depois.
##   godot --headless --path . tools/tests/sim_probe.tscn -- [--ticks=1200] [--warm=300] [--phases] [--at=x,z] [--map=<id>]
## --phases liga o Sim.profile (ms/tick por fase; o próprio perfil custa um pouco).

const DT := 1.0 / 60.0

func _ready() -> void:
	await get_tree().process_frame
	Sim.running = false
	seed(4242)
	Sim.rng.seed = 1337
	for mid in GameData.maps:
		Sim.load_map(GameData.maps[mid])
	_populate_bots()
	var town := GameData.town_map_id()
	var map_id := DevArgs.value("--map", town)
	var p := Sim.spawn_player(GameData.classes["paladin"], "Sonda", town)
	if map_id != town:
		Sim._change_map(p, map_id, GameData.maps[map_id].spawn_point)
		Sim._process_map_changes()
	if DevArgs.flag("--at"):
		var xz := DevArgs.value("--at").split(",")
		p.position = Vector3(float(xz[0]), 0, float(xz[1]))
	else:
		p.position = GameData.maps[map_id].town_center if GameData.maps[map_id].is_town else p.position
	p.hp = p.stats.max_hp * 1000.0          # o jogador parado não morre (estado estável para comparar)
	var warm := int(DevArgs.value("--warm", "300"))
	var n := int(DevArgs.value("--ticks", "1200"))
	for i in warm:
		Sim.tick(DT)
	Sim.profile = DevArgs.has("--phases")
	Sim.prof.clear()
	var times: Array[float] = []
	var t_all := Time.get_ticks_usec()
	for i in n:
		var t0 := Time.get_ticks_usec()
		Sim.tick(DT)
		times.append(float(Time.get_ticks_usec() - t0))
	var total := float(Time.get_ticks_usec() - t_all)
	times.sort()
	print("SIM ticks=%d avg_ms=%.3f p50_ms=%.3f p95_ms=%.3f max_ms=%.3f" % [n, total / n / 1000.0, times[n / 2] / 1000.0,
		times[int(n * 0.95)] / 1000.0, times[n - 1] / 1000.0])
	if Sim.profile:
		var keys: Array = Sim.prof.keys()
		keys.sort_custom(func(a, b): return Sim.prof[a] > Sim.prof[b])
		for k in keys.slice(0, 24):
			print("SIM   %-24s %.3f ms/tick" % [k, Sim.prof[k] / n / 1000.0])
	print("SIM checksum=%s alive=%d" % [_checksum(), Sim.entities.values().filter(func(e): return e.is_alive()).size()])
	get_tree().quit()

## Mesmo sorteio do main._populate_bots, com semente fixa.
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

func _checksum() -> String:
	var ids: Array = Sim.entities.keys()
	ids.sort()
	var parts := PackedStringArray()
	for id in ids:
		var e: SimEntity = Sim.entities[id]
		parts.append("%d:%s:%.3f,%.3f:%.2f:%d" % [id, e.map_id, e.position.x, e.position.z, e.hp, e.level])
	return "%08x n=%d" % ["|".join(parts).hash(), ids.size()]
