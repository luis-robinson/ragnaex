extends Node
## Apoio do stuck_probe: imprime o water_path e as pontes de um mapa entre dois pontos (sem bots).
##   godot --headless --path . tools/tests/stuck_path_probe.tscn -- --map=<id> --from=x,z --to=x,z

func _ready() -> void:
	await get_tree().process_frame
	Sim.running = false
	var mid := DevArgs.value("--map", "field_ruins")
	Sim.load_map(GameData.maps[mid])
	var m: Dictionary = Sim.maps[mid]
	var f := DevArgs.value("--from", "0,0").split(",")
	var t := DevArgs.value("--to", "0,0").split(",")
	var a := Vector3(float(f[0]), 0, float(f[1]))
	var b := Vector3(float(t[0]), 0, float(t[1]))
	for br in m["bridges"]:
		print("BRIDGE pos=%s half=%.2f ends=%s" % [br["pos"], br["half"], MapGeometry.bridge_ends(Sim, br)])
	print("CROSSES ", MapGeometry.crosses_river(Sim, m, Vector2(a.x, a.z), Vector2(b.x, b.z)))
	var path: Array = Sim.water_path(mid, a, b)
	print("PATH ", path)
	for q in path:
		print("  node %s walkable=%s" % [q, MapGeometry.is_walkable(Sim, Vector3(q.x, 0, q.y), GameData.maps[mid])])
	# anda como a sim (passo de 0,09 m + resolve_obstacles) até o 1º nó do caminho (ou o destino) e diz onde parou
	var goal: Vector3 = Vector3(path[0].x, 0, path[0].y) if not path.is_empty() else b
	var p := a
	var r := 0.45
	for i in 400:
		var d := goal - p
		if d.length() < 0.2:
			break
		var np := MapGeometry.resolve_obstacles(Sim, p + d.normalized() * 0.09, r, m)
		if np.distance_to(p) < 0.005:
			print("WALK blocked at %s after %d steps, goal %s" % [p, i, goal])
			break
		p = np
	print("WALK end %s goal %s dist %.2f" % [p, goal, p.distance_to(goal)])
	get_tree().quit()
