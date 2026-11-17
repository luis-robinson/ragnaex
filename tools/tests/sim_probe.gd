extends Node
## Sonda de custo da simulação (sem tela, sem bonecos): o mundo inteiro como no jogo (todos os mapas, bots, jogador na
## cidade parado), semente fixa, N ticks de 1/60 s. Imprime ms/tick (média, p95) e uma soma de conferência do estado:
## otimização da sim que não muda comportamento tem de dar a MESMA soma antes e depois.
##   godot --headless --path . tools/tests/sim_probe.tscn -- [--ticks=1200] [--warm=300] [--phases] [--at=x,z] [--map=<id>] [--suite] [--census] [--hops]
## --hops: registra cada troca de mapa dos bots (HOP) e conta idas e voltas A->B->A em menos de HOP_BOUNCE_S (vai-e-volta de portal).
## --phases liga o Sim.profile (ms/tick por fase; o próprio perfil custa um pouco).

const DT := 1.0 / 60.0

func _ready() -> void:
	await get_tree().process_frame
	Sim.running = false
	seed(4242)
	Sim.rng.seed = 1337
	for mid in GameData.maps:
		Sim.load_map(GameData.maps[mid])
	var suite := DevArgs.has("--suite")       # o mundo do teste longo do run_tests (bots no ponto de entrada, classes em rodízio)
	var town := GameData.town_map_id()
	var map_id := DevArgs.value("--map", town)
	var p: SimEntity
	if suite:
		p = Sim.spawn_player(GameData.classes["berserker"], "Tester", town)
		_populate_suite()
	else:
		_populate_bots()
		p = Sim.spawn_player(GameData.classes["paladin"], "Sonda", town)
	if map_id != town:
		Sim._change_map(p, map_id, GameData.maps[map_id].spawn_point)
		Sim._process_map_changes()
	if DevArgs.flag("--at"):
		var xz := DevArgs.value("--at").split(",")
		p.position = Vector3(float(xz[0]), 0, float(xz[1]))
	elif not suite:
		p.position = GameData.maps[map_id].town_center if GameData.maps[map_id].is_town else p.position
	p.hp = p.stats.max_hp * 1000.0          # o jogador parado não morre (estado estável para comparar)
	var warm := int(DevArgs.value("--warm", "300"))
	var n := int(DevArgs.value("--ticks", "1200"))
	for i in warm:
		Sim.tick(DT)
	Sim.profile = DevArgs.has("--phases")
	Sim.prof.clear()
	var hops := DevArgs.has("--hops")
	if hops:
		_watch_hops()
	var times: Array[float] = []
	var t_all := Time.get_ticks_usec()
	for i in n:
		var t0 := Time.get_ticks_usec()
		Sim.tick(DT)
		if hops:
			_watch_hops()
		times.append(float(Time.get_ticks_usec() - t0))
	var total := float(Time.get_ticks_usec() - t_all)
	times.sort()
	print("SIM ticks=%d avg_ms=%.3f p50_ms=%.3f p95_ms=%.3f max_ms=%.3f" % [n, total / n / 1000.0, times[n / 2] / 1000.0,
		times[int(n * 0.95)] / 1000.0, times[n - 1] / 1000.0])
	if Sim.profile:
		var keys: Array = Sim.prof.keys()
		keys.sort_custom(func(a, b): return Sim.prof[a] > Sim.prof[b])
		for k in keys.slice(0, 60):
			print("SIM   %-24s %.3f ms/tick" % [k, Sim.prof[k] / n / 1000.0])
	print("SIM checksum=%s alive=%d" % [_checksum(), Sim.entities.values().filter(func(e): return e.is_alive()).size()])
	if DevArgs.has("--census"):               # por mapa: entidades por tipo, monstros dormindo, loot no chão
		for mid in Sim.maps:
			var m: Dictionary = Sim.maps[mid]
			var c := [0, 0, 0, 0, 0]
			var asleep := 0
			for e in m["entities"]:
				c[e.kind] += 1
				if e.dormant:
					asleep += 1
			print("SIM   %-18s n=%d bots=%d mobs=%d (dormindo %d) npcs=%d summons=%d loot=%d proj=%d" % [mid, m["entities"].size(), c[1], c[2], asleep, c[3], c[4],
				m["loot"].size(), m["projectiles"].size()])
	if hops:
		_hop_report()
	get_tree().quit()

## Como o trecho "simulação longa" do run_tests: classes em rodízio, nível da faixa do mapa, todos no ponto de entrada.
func _populate_suite() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var names: Array = GameData.bot_names.duplicate()
	var classes: Array = GameData.class_list()
	var k := 0
	for mid in GameData.maps:
		var md: MapDef = GameData.maps[mid]
		for i in range(md.bot_population):
			var lv := rng.randi_range(md.level_range.x, md.level_range.y)
			Sim.spawn_bot(classes[k % classes.size()], names[k % names.size()], mid, Sim.random_walkable(md, md.spawn_point, 6.0), lv)
			k += 1

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

const HOP_BOUNCE_S := 60.0
var _hop_last := {}      # id do bot -> [mapa, hora da chegada, mapa anterior]
var _hop_count := {}
var _hop_bounces := 0

func _watch_hops() -> void:
	for e: SimEntity in Sim.entities.values():
		if e.kind != SimEntity.Kind.BOT:
			continue
		var last: Array = _hop_last.get(e.id, [])
		if last.is_empty():
			_hop_last[e.id] = [e.map_id, Sim.time, ""]
			continue
		if last[0] == e.map_id:
			continue
		var b: BotBrain = e.brain
		var lead: SimEntity = Sim.party_leader(e) if e.party_id >= 0 else null
		var bounce: bool = e.map_id == last[2] and Sim.time - float(last[1]) < HOP_BOUNCE_S
		if bounce:
			_hop_bounces += 1
		_hop_count[e.id] = int(_hop_count.get(e.id, 0)) + 1
		print("HOP t=%.1f id=%d lv=%d %s->%s stay=%.1f state=%s dest=%s party=%s%s" % [Sim.time, e.id, e.level, last[0], e.map_id,
			Sim.time - float(last[1]), BotBrain.S.keys()[b.state] if b else "?", b.dest_map if b else "?",
			("lead" if lead == e else "follow:%d@%s" % [lead.id, lead.map_id]) if lead else "-", " BOUNCE" if bounce else ""])
		_hop_last[e.id] = [e.map_id, Sim.time, last[0]]

func _hop_report() -> void:
	var tot := 0
	var worst := 0
	for id in _hop_count:
		tot += int(_hop_count[id])
		worst = maxi(worst, int(_hop_count[id]))
	print("HOPS total=%d bots_moved=%d worst_bot=%d bounces=%d (A->B->A < %.0f s)" % [tot, _hop_count.size(), worst, _hop_bounces, HOP_BOUNCE_S])
