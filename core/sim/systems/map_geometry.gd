class_name MapGeometry
extends RefCounted
## Geometria do mapa: grade de colisores, rio/lago sólidos com vão nas pontes, desvio pela água (water_path) e chão andável.
## Estado fica no dicionário do mapa (`grid`, `colliders`, `bridges`, `water_nodes`, `water_adj`). Funções estáticas: recebem o WorldSim.

const GRID_CELL := 12.0

## Pré-computa colisores (círculo ou caixa rotacionada) e os indexa numa grade espacial.
## Água também é sólida: rio vira uma corrente de caixas curtas (com vão onde uma estrada cruza = ponte)
## e lago vira círculo; nada disso é "alto" (projéteis passam por cima).
static func build_collider_grid(sim: WorldSim, m: Dictionary) -> void:
	var def: MapDef = m["def"]
	var cols: Array = []
	var grid: Dictionary = {}
	for ob in def.obstacles:
		if not ob.get("solid", true):
			continue
		var kind: String = ob.get("kind", "house")
		if kind == "water":
			continue            # o lago vem de def.water (círculo, não o quadrado antigo)
		var pos: Vector3 = ob["pos"]
		var size: Vector3 = ob.get("size", Vector3.ONE)
		var circle: bool = kind in ["tree", "rock", "pillar", "well", "fountain", "lamp", "statue", "pine", "dead_tree", "stump", "hill"]
		add_collider(sim, cols, grid, {"circle": circle, "x": pos.x, "z": pos.z, "cr": maxf(size.x, size.z) * 0.5,
			"hx": size.x * 0.5, "hz": size.z * 0.5, "rot": deg_to_rad(float(ob.get("rot", 0.0))), "tall": size.y > 1.2})
	var bridges := water_crossings(def)
	m["bridges"] = bridges
	for w in def.water:
		if w["kind"] == "lake":
			var c: Vector2 = w["pos"]
			add_collider(sim, cols, grid, {"circle": true, "x": c.x, "z": c.y, "cr": float(w["r"]) - WATER_SHORE, "hx": 0.0, "hz": 0.0, "rot": 0.0, "tall": false})
			continue
		var pts: PackedVector2Array = w["pts"]
		var half_w: float = float(w["w"]) * 0.5 - WATER_SHORE
		for i in range(pts.size() - 1):
			var a := pts[i]
			var b := pts[i + 1]
			var seg_len := a.distance_to(b)
			var n := maxi(1, ceili(seg_len / RIVER_PIECE))
			var dir := (b - a) / seg_len if seg_len > 0.001 else Vector2.RIGHT
			for k in range(n):
				var c := a.lerp(b, (k + 0.5) / n)
				var on_bridge := false
				for br in bridges:
					if br["pos"].distance_to(c) < BRIDGE_HALF + seg_len / n * 0.5 + 0.35:
						on_bridge = true
						break
				if on_bridge:
					continue
				# caixa alinhada ao trecho (um pouco mais longa para não deixar fresta entre peças)
				add_collider(sim, cols, grid, {"circle": false, "x": c.x, "z": c.y, "cr": 0.0, "hx": seg_len / n * 0.5 + 0.35, "hz": half_w,
					"rot": -dir.angle(), "tall": false})
	m["colliders"] = cols
	m["grid"] = grid
	build_water_graph(sim, m)

const WATER_SHORE := 0.5      # m de água rasa andável na beirada

const RIVER_PIECE := 1.5      # comprimento de cada caixa do rio

const BRIDGE_HALF := 2.7      # meia-largura do vão da ponte (tabuleiro = estrada + 0,6 m)

static func add_collider(sim: WorldSim, cols: Array, grid: Dictionary, c: Dictionary) -> void:
	var idx := cols.size()
	cols.append(c)
	var reach: float = c["cr"] if c["circle"] else Vector2(c["hx"], c["hz"]).length()
	reach += 1.0          # raio de quem colide (a busca só olha a célula da entidade)
	var cx0 := floori((c["x"] - reach) / GRID_CELL); var cx1 := floori((c["x"] + reach) / GRID_CELL)
	var cz0 := floori((c["z"] - reach) / GRID_CELL); var cz1 := floori((c["z"] + reach) / GRID_CELL)
	for cx in range(cx0, cx1 + 1):
		for cz in range(cz0, cz1 + 1):
			var key := Vector2i(cx, cz)
			if not grid.has(key):
				grid[key] = []
			grid[key].append(idx)

## Pontes: onde cada estrada cruza cada rio. {"pos": Vector2 (no eixo do rio), "dir": Vector2 (ao longo do rio)}.
static func water_crossings(def: MapDef) -> Array:
	var out: Array = []
	for w in def.water:
		if w["kind"] != "river":
			continue
		var rp: PackedVector2Array = w["pts"]
		for r in def.roads:
			if r["kind"] != "road":
				continue
			var qp: PackedVector2Array = r["pts"]
			for i in range(rp.size() - 1):
				for j in range(qp.size() - 1):
					var hit = Geometry2D.segment_intersects_segment(rp[i], rp[i + 1], qp[j], qp[j + 1])
					if hit != null:
						out.append({"pos": hit, "dir": (rp[i + 1] - rp[i]).normalized(), "w": float(w["w"])})
	return out

## Caminho (pontos no chão) de `from` até `to` sem atravessar rio fora das pontes; vazio = linha reta serve.
## Grafo de visibilidade: cabeceiras das pontes + pontos nas duas margens (montado em _build_water_graph).
static func water_path(sim: WorldSim, map_id: String, from: Vector3, to: Vector3) -> Array:
	if not sim.maps.has(map_id):
		return []
	var m: Dictionary = sim.maps[map_id]
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	if m.get("bridges", []).is_empty() or not crosses_river(sim, m, a, b):
		return []
	var nodes: PackedVector2Array = m["water_nodes"]
	var adj: Array = m["water_adj"]
	var n := nodes.size()
	var dist := PackedFloat32Array()
	dist.resize(n)
	dist.fill(INF)
	var prev := PackedInt32Array()
	prev.resize(n)
	prev.fill(-1)
	var done := PackedByteArray()
	done.resize(n)
	for i in range(n):
		if not crosses_river(sim, m, a, nodes[i]):
			dist[i] = a.distance_to(nodes[i])
	var best_end := -1
	var best_total := INF
	for _k in range(n):
		var u := -1
		var du := INF
		for i in range(n):
			if done[i] == 0 and dist[i] < du:
				du = dist[i]
				u = i
		if u < 0 or du >= best_total:
			break
		done[u] = 1
		if not crosses_river(sim, m, nodes[u], b):
			var total := du + nodes[u].distance_to(b)
			if total < best_total:
				best_total = total
				best_end = u
		for edge in adj[u]:
			var v: int = edge[0]
			var nd: float = du + float(edge[1])
			if nd < dist[v]:
				dist[v] = nd
				prev[v] = u
	if best_end < 0:
		return []
	var out: Array = []
	var cur := best_end
	while cur >= 0:
		out.push_front(nodes[cur])
		cur = prev[cur]
	return out

## Nós do desvio: as duas cabeceiras de cada ponte (ligadas entre si) e pontos andáveis nas margens.
static func build_water_graph(sim: WorldSim, m: Dictionary) -> void:
	var def: MapDef = m["def"]
	var nodes := PackedVector2Array()
	var pairs: Array = []
	for br in m["bridges"]:
		var ends := bridge_ends(sim, br)
		pairs.append([nodes.size(), nodes.size() + 1])
		nodes.append(ends[0])
		nodes.append(ends[1])
	if not m["bridges"].is_empty():
		for w in def.water:
			if w["kind"] != "river":
				continue
			var pts: PackedVector2Array = w["pts"]
			var off: float = float(w["w"]) * 0.5 + 2.5
			var acc := 0.0
			for i in range(1, pts.size() - 1):
				acc += pts[i].distance_to(pts[i - 1])
				if acc < 12.0:
					continue
				acc = 0.0
				var t := (pts[i + 1] - pts[i - 1]).normalized()
				var nrm := Vector2(-t.y, t.x)
				for sgn in [1.0, -1.0]:
					var q: Vector2 = pts[i] + nrm * off * sgn
					if is_walkable(sim, Vector3(q.x, 0.0, q.y), def, 0.6):
						nodes.append(q)
		for w in def.water:            # anel em volta dos lagos (contornar)
			if w["kind"] != "lake":
				continue
			var c: Vector2 = w["pos"]
			for k in range(10):
				var q: Vector2 = c + Vector2.from_angle(TAU * k / 10.0) * (float(w["r"]) + 3.0)
				if is_walkable(sim, Vector3(q.x, 0.0, q.y), def, 0.6):
					nodes.append(q)
	var adj: Array = []
	for i in range(nodes.size()):
		adj.append([])
	for i in range(nodes.size()):
		for j in range(i + 1, nodes.size()):
			var d := nodes[i].distance_to(nodes[j])
			if d > 90.0 or crosses_river(sim, m, nodes[i], nodes[j]):
				continue
			adj[i].append([j, d])
			adj[j].append([i, d])
	for pr in pairs:              # atravessar a ponte (a linha corta o rio no vão: _crosses_river já deixa)
		var d := nodes[pr[0]].distance_to(nodes[pr[1]])
		if not adj[pr[0]].any(func(e): return e[0] == pr[1]):
			adj[pr[0]].append([pr[1], d])
			adj[pr[1]].append([pr[0], d])
	m["water_nodes"] = nodes
	m["water_adj"] = adj

## Cabeceiras da ponte (um pouco além da margem, dos dois lados).
static func bridge_ends(sim: WorldSim, br: Dictionary) -> Array:
	var across := Vector2(-br["dir"].y, br["dir"].x)
	var reach: float = br["w"] * 0.5 + 2.5
	return [br["pos"] + across * reach, br["pos"] - across * reach]

## A linha a→b corta água (rio fora do vão de uma ponte, ou lago)?
static func crosses_river(sim: WorldSim, m: Dictionary, a: Vector2, b: Vector2) -> bool:
	for w in m["def"].water:
		if w["kind"] == "lake":
			var c: Vector2 = w["pos"]
			if c.distance_to(Geometry2D.get_closest_point_to_segment(c, a, b)) < float(w["r"]) - WATER_SHORE:
				return true
			continue
		var pts: PackedVector2Array = w["pts"]
		for i in range(pts.size() - 1):
			var hit = Geometry2D.segment_intersects_segment(a, b, pts[i], pts[i + 1])
			if hit == null:
				continue
			var at_bridge := false
			for br in m.get("bridges", []):
				if br["pos"].distance_to(hit) < BRIDGE_HALF - 0.6:
					at_bridge = true
					break
			if not at_bridge:
				return true
	return false

static func nearby_colliders(sim: WorldSim, m: Dictionary, p: Vector3) -> Array:
	var key := Vector2i(floori(p.x / GRID_CELL), floori(p.z / GRID_CELL))
	return m["grid"].get(key, [])

static func resolve_obstacles(sim: WorldSim, p: Vector3, r: float, m: Dictionary) -> Vector3:
	var cols: Array = m["colliders"]
	for idx in nearby_colliders(sim, m, p):
		var c: Dictionary = cols[idx]
		if c["circle"]:
			var cr: float = c["cr"]
			var rel := Vector2(p.x - c["x"], p.z - c["z"])
			var d := rel.length()
			if d < cr + r:
				rel = rel / d * (cr + r) if d > 0.0001 else Vector2(cr + r, 0.0)
				p.x = c["x"] + rel.x
				p.z = c["z"] + rel.y
		else:
			var rot: float = c["rot"]
			var rel := Vector2(p.x - c["x"], p.z - c["z"]).rotated(rot)
			var hx: float = c["hx"] + r
			var hz: float = c["hz"] + r
			if absf(rel.x) < hx and absf(rel.y) < hz:
				var dx := hx - absf(rel.x)
				var dz := hz - absf(rel.y)
				if dx < dz:
					rel.x = signf(rel.x) * hx if rel.x != 0.0 else hx
				else:
					rel.y = signf(rel.y) * hz if rel.y != 0.0 else hz
				rel = rel.rotated(-rot)
				p.x = c["x"] + rel.x
				p.z = c["z"] + rel.y
	return p

static func point_in_solid(sim: WorldSim, p: Vector3, m: Dictionary) -> bool:
	var cols: Array = m["colliders"]
	for idx in nearby_colliders(sim, m, p):
		var c: Dictionary = cols[idx]
		if not c["tall"]:
			continue
		if c["circle"]:
			if Vector2(p.x - c["x"], p.z - c["z"]).length() < c["cr"]:
				return true
		else:
			var rel := Vector2(p.x - c["x"], p.z - c["z"]).rotated(c["rot"])
			if absf(rel.x) < c["hx"] and absf(rel.y) < c["hz"]:
				return true
	return false

static func is_walkable(sim: WorldSim, p: Vector3, def: MapDef, r: float = 0.45) -> bool:
	var h := def.half()
	if absf(p.x) > h.x - r or absf(p.z) > h.y - r:
		return false
	if not sim.maps.has(def.id):
		return true
	return resolve_obstacles(sim, p, r, sim.maps[def.id]).distance_to(p) < 0.01

static func random_walkable(sim: WorldSim, def: MapDef, center: Vector3, radius: float) -> Vector3:
	for i in range(12):
		var a := sim.rng.randf() * TAU
		var d := sim.rng.randf_range(0.0, radius)
		var p := center + Vector3(cos(a) * d, 0.0, sin(a) * d)
		if is_walkable(sim, p, def):
			return p
	return def.clamp_inside(center, 1.0)
