extends Node
## Sonda dos Chefes de Mundo com hora marcada (design/gdd/momentos-do-mundo.md §3.1, §8; WorldBossSystem).
##   godot --headless --path . tools/tests/world_boss_probe.tscn -- --spots [--search]
##     lugar de cada chefe: livre em volta (alvo >= SPOT_CLEAR m), alcançável a pé da chegada, longe de estrada/portal/
##     spawner/hub (SPOT_*); `--search` acha o melhor lugar perto do atual que passa em tudo (imprime SPOT_PICK).
##   godot --headless --path . tools/tests/world_boss_probe.tscn -- [--boss=<id>,..] [--trials=10] [--bots=10] [--limit=480]
##     o mundo inteiro como no jogo; N bots da faixa (metade no povoado do mapa, metade no mapa vizinho a 1 portal), o
##     chefe nasce pelo WorldBossSystem e os bots vêm pelo BotBrain normal. Conta quem chegou a WORLD_BOSS_ARRIVE_M antes
##     de ele cair (ou do limite). Alvo §8: >= 6 de 10 em 10 lutas. Linha ARRIVE por chefe; FLAG = abaixo.

const DT := 1.0 / 60.0
static var SPOT_CLEAR := 13.0     # raio livre (26 m de roda)  (--clear=)
static var SPOT_ROAD := 8.0       # longe do eixo das estradas (--road=)
static var SPOT_PORTAL := 45.0    # longe de portal (luta espalha; bot empurrado não sai do mapa) (--portal=)
static var SPOT_SPAWNER := 12.0   # além do raio do spawner (--spawner=)
static var SPOT_HUB := Vector2(50.0, 125.0)

func _ready() -> void:
	await get_tree().process_frame
	Sim.running = false
	HuntPotionSystem.bots_drink = false
	SPOT_CLEAR = float(DevArgs.value("--clear", str(SPOT_CLEAR)))
	SPOT_ROAD = float(DevArgs.value("--road", str(SPOT_ROAD)))
	SPOT_PORTAL = float(DevArgs.value("--portal", str(SPOT_PORTAL)))
	SPOT_SPAWNER = float(DevArgs.value("--spawner", str(SPOT_SPAWNER)))
	if DevArgs.has("--spots"):
		_spots(DevArgs.has("--search"))
		get_tree().quit()
		return
	var only: Array = MonstersCatalog.WORLD_BOSSES.keys()
	if DevArgs.flag("--boss"):
		only = Array(DevArgs.value("--boss").split(","))
	var trials := int(DevArgs.value("--trials", "10"))
	var nbots := int(DevArgs.value("--bots", "10"))
	var limit := float(DevArgs.value("--limit", "480"))
	for bid in only:
		_arrivals(str(bid), trials, nbots, limit)
	print("PROBE_END")
	get_tree().quit()

# ---------------------------------------------------------------------------
# Lugares
# ---------------------------------------------------------------------------
func _spots(search: bool) -> void:
	for bid in MonstersCatalog.WORLD_BOSSES:
		var wb: Dictionary = MonstersCatalog.WORLD_BOSSES[bid]
		var def: MapDef = GameData.maps[str(wb["map"])]
		Sim.load_map(def)
		var seen := reach(def, def.spawn_point)
		var at := WorldBossSystem.spot(bid)
		var r := judge(def, at, seen)
		print("SPOT %-16s %s at=(%.0f,%.0f) livre=%.1f alcance=%s estrada=%.1f portal=%.1f spawner=%.1f hub=%.1f %s" % [bid, def.id, at.x, at.z,
			r["clear"], str(r["reach"]), r["road"], r["portal"], r["spawner"], r["hub"], "OK" if r["ok"] else "FLAG"])
		if search:
			var best := Vector3.INF
			var best_d := INF
			var step := 3.0
			var h := def.half()
			var x := -h.x
			while x <= h.x:
				var z := -h.y
				while z <= h.y:
					var q := Vector3(x, 0.0, z)
					var d := q.distance_to(at)
					if d < best_d:
						var rq := judge(def, q, seen)
						if rq["ok"]:
							best = q
							best_d = d
					z += step
				x += step
			if best != Vector3.INF:
				var rb := judge(def, best, seen)
				print("SPOT_PICK %s [%.1f, %.1f] (%.0f m do atual) livre=%.1f estrada=%.1f portal=%.1f spawner=%.1f hub=%.1f" % [bid, best.x, best.z, best_d,
					rb["clear"], rb["road"], rb["portal"], rb["spawner"], rb["hub"]])
			else:
				print("SPOT_PICK %s nenhum" % bid)

## Medidas de um lugar: {clear, reach, road, portal, spawner (folga além do raio), hub, ok}.
static func judge(def: MapDef, at: Vector3, seen: Dictionary) -> Dictionary:
	var clear := 0.0
	var r := 1.0
	while r <= SPOT_CLEAR + 0.01:
		var ok := Sim.is_walkable(at, def, 0.45)
		for k in 24:
			var ang := TAU * float(k) / 24.0
			if not ok or not Sim.is_walkable(at + Vector3(cos(ang), 0.0, sin(ang)) * r, def, 0.45):
				ok = false
				break
		if not ok:
			break
		clear = r
		r += 1.0
	var road := INF
	for rd in def.roads:
		for pt in rd["pts"]:
			var v: Vector2 = pt if pt is Vector2 else Vector2(pt.x, pt.z)
			road = minf(road, v.distance_to(Vector2(at.x, at.z)))
	var portal := INF
	for p in def.portals:
		portal = minf(portal, (p["pos"] as Vector3).distance_to(at))
	var spawner := INF
	for sp in def.spawners:
		spawner = minf(spawner, (sp["pos"] as Vector3).distance_to(at) - float(sp.get("radius", 6.0)))
	var hub := Vector2(at.x - def.town_center.x, at.z - def.town_center.z).length()
	var reached := _reached(seen, at)
	var good := clear >= SPOT_CLEAR and reached and road >= SPOT_ROAD and portal >= SPOT_PORTAL and spawner >= SPOT_SPAWNER \
		and hub >= SPOT_HUB.x and hub <= SPOT_HUB.y and not def.in_town(at)
	return {"clear": clear, "reach": reached, "road": road, "portal": portal, "spawner": spawner, "hub": hub, "ok": good}

static func reach(def: MapDef, from: Vector3) -> Dictionary:
	var step := 1.5
	var seen := {}
	var open: Array[Vector2i] = [Vector2i(roundi(from.x / step), roundi(from.z / step))]
	seen[open[0]] = true
	while not open.is_empty():
		var c: Vector2i = open.pop_back()
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if not seen.has(n) and Sim.is_walkable(Vector3(n.x * step, 0, n.y * step), def, 0.45):
				seen[n] = true
				open.append(n)
	return seen

static func _reached(seen: Dictionary, p: Vector3) -> bool:
	var c := Vector2i(roundi(p.x / 1.5), roundi(p.z / 1.5))
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			if seen.has(c + Vector2i(dx, dz)):
				return true
	return false

# ---------------------------------------------------------------------------
# Chegada dos bots
# ---------------------------------------------------------------------------
func _arrivals(bid: String, trials: int, nbots: int, limit: float) -> void:
	var wb: Dictionary = MonstersCatalog.WORLD_BOSSES[bid]
	var map_id := str(wb["map"])
	var band: Array = wb["band"]
	var classes: Array = GameData.classes.keys()
	classes.sort()
	var ok_trials := 0
	var arrived_sum := 0
	var wins := 0
	var t_sum := 0.0
	var first_sum := 0.0
	for trial in trials:
		Sim.reset_world()
		Sim.rng.seed = 9100 + trial * 31
		for mid in GameData.maps:
			Sim.load_map(GameData.maps[mid])
		var def: MapDef = GameData.maps[map_id]
		var p := Sim.spawn_player(GameData.classes["paladin"], "Sonda", map_id)
		p.position = def.town_center if def.town_radius > 0.0 or def.is_town else def.spawn_point
		p.hp = p.stats.max_hp * 1000.0
		var near := ""                                     # mapa vizinho (1 portal) para metade dos bots
		for pt in def.portals:
			var nd: MapDef = GameData.maps.get(str(pt["target_map"]))
			if nd != null and nd.parent_map == "" and not nd.instance:
				near = nd.id
				break
		var bots: Array = []
		for i in nbots:
			var mid := map_id if (i % 2 == 0 or near == "") else near
			var md: MapDef = GameData.maps[mid]
			var from: Vector3 = md.town_center if md.town_radius > 0.0 else md.spawn_point
			var lv := clampi(int(band[0]) + (i * 3) % maxi(1, int(band[1]) - int(band[0]) + 1), int(band[0]), int(band[1]))
			var b := Sim.spawn_bot(GameData.classes[classes[i % classes.size()]], "W%d" % i, mid, MapGeometry.random_walkable(Sim, md, from, 12.0), lv)
			bots.append(b)
		var boss := WorldBossSystem.spawn(Sim, bid)
		if boss == null:
			print("ARRIVE %s #%d: não nasceu" % [bid, trial])
			continue
		var came := {}
		var t := 0.0
		while t < limit and boss.is_alive():
			Sim.tick(DT)
			t += DT
			if int(t / DT) % 30 == 0:
				for b: SimEntity in bots:
					if not came.has(b.id) and b.is_alive() and b.map_id == map_id and b.position.distance_to(boss.position) <= Balance.WORLD_BOSS_ARRIVE_M:
						came[b.id] = t
		var won := not boss.is_alive()
		if won:
			wins += 1
			t_sum += t
		var first := INF
		for id in came:
			first = minf(first, float(came[id]))
		first_sum += first if first < INF else limit
		arrived_sum += came.size()
		if came.size() >= 6:
			ok_trials += 1
		print("ARRIVE_TRIAL %s #%d chegaram=%d/%d venceu=%s t=%.0fs 1o=%.0fs" % [bid, trial, came.size(), nbots, str(won), t, first])
	print("ARRIVE %-16s lutas=%d com>=6=%d media=%.1f/%d vitorias=%d tempo_vit=%.0fs 1a_chegada=%.0fs %s" % [bid, trials, ok_trials,
		float(arrived_sum) / maxf(1.0, trials), nbots, wins, t_sum / maxf(1.0, wins), first_sum / maxf(1.0, trials), "OK" if ok_trials == trials else "FLAG"])
