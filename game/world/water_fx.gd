class_name WaterFx
extends Node3D
## Água do mapa (só apresentação): materiais do shader `spatial_env_water`, textura de distância da margem
## e pequenas animações (ondas de passos/pedras/pontes, peixe que pula, folhas à deriva), tudo em pool e
## limitado pela distância do jogador. Um por mapa, filho do nó do mapa (MapBuilder.build).

const SHADER := "res://shaders/spatial_env_water.gdshader"
const MAX_RIPPLES := 12            # tem de bater com `ripples[12]` do shader
const SHORE_MAX := 8.0             # m: o valor 1.0 da textura de margem
const CELL := 0.5                  # m por texel da textura de margem
const NEAR := 46.0                 # m: além disso (do jogador) não há animação
const WATER_Y := 0.05
const FISH_POOL := 3
const LEAF_POOL := 8
const LEAF_LIFE := 14.0

var def: MapDef
var natural := true                # água de verdade (peixe/folha); gelo, almas e bile ficam só com ondas
var _mats: Dictionary = {}         # nome do material do GLB -> ShaderMaterial
var _shader: Shader
var _shore_tex: ImageTexture
var _origin := Vector2.ZERO
var _extent := Vector2.ONE
var _segs := PackedVector2Array()  # bordas da água (pares de pontos, em x,z), entrada do bake
var _task := -1
var _bake_bytes := PackedByteArray()
var _bake_size := Vector2i.ZERO

var _ripples := PackedVector4Array()
var _rip_i := 0
var _clock := 0.0
var _ripples_live := 0.0           # s até a última onda acabar
var _scan_t := 0.0
var _last_pos: Dictionary = {}     # id da entidade -> última posição (x,z)
var _bridges: Array = []
var _rocks := PackedVector3Array() # x, z, ângulo para a água (rad): pedras na beirada
var _rock_next := PackedFloat32Array()
var _bridge_t := 0.0
var _fish: Array = []              # {node, t, from, to}
var _fish_t := 3.0
var _fish_mesh: Mesh
var _leaves: Array = []            # {node, t, pos, vel}
var _leaf_t := 1.0
var _rng := RandomNumberGenerator.new()

## Cria o gerenciador do mapa: lê as malhas de água do modelo e começa a medir a margem (em outra thread).
static func create(model: Node, map_def: MapDef) -> WaterFx:
	var w := WaterFx.new()
	w.name = "WaterFx"
	w.def = map_def
	w._rng.seed = hash(map_def.id)
	w._shader = load(SHADER)
	w._ripples.resize(MAX_RIPPLES)
	w._collect_segments(model, model)
	w._start_bake()
	w._prepare_shapes()
	return w

## Nome de material do GLB que vira água.
static func is_water(mname: String) -> bool:
	return mname in ["water", "water_dark", "icewater", "soulwater", "bile"] or mname.begins_with("agua_")

## Material de água para um tipo do GLB. Um por tipo e mapa: as ondas e a margem são compartilhadas.
func material_for(mname: String, base: Color) -> ShaderMaterial:
	var key := mname if not mname.begins_with("agua_funda") else "agua_mar"
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = _shader
	var shallow := base.lerp(Color(0.4, 0.66, 0.86), 0.25).lightened(0.1)
	var deep := shallow.darkened(0.26).lerp(Color(0.14, 0.34, 0.7), 0.2)
	var foam := Color(0.95, 0.99, 1.0)
	var deep_dist := 3.2
	var speed := 1.0
	var sparkle := 0.7
	var glow := 0.0
	var alpha := 0.93
	if key.begins_with("agua_"):                     # mar e poças de maré: cores do Blender
		shallow = Color(0.45, 0.84, 0.86) if key == "agua_rasa" else base.lerp(Color(0.45, 0.85, 0.88), 0.3).lightened(0.05)
		deep = Color(0.16, 0.5, 0.66) if key != "agua_rasa" else shallow.darkened(0.12)
		deep_dist = 7.5 if key != "agua_rasa" else 1.4
		speed = 1.15
	elif key == "icewater":                          # buraco no gelo: escuro, quase parado
		shallow = base.lightened(0.18)
		deep = base.darkened(0.1)
		foam = Color(0.82, 0.93, 1.0)
		speed = 0.35
		sparkle = 0.25
		alpha = 0.96
	elif key == "soulwater":                         # poço de almas: verde que respira
		shallow = base.lightened(0.15)
		deep = base.darkened(0.1)
		foam = Color(0.55, 1.0, 0.7)
		glow = 0.55
		speed = 0.5
		sparkle = 0.15
	elif key == "bile":                              # bile: grossa e lenta
		shallow = base.lightened(0.1)
		deep = base.darkened(0.25)
		foam = Color(0.78, 0.8, 0.3)
		speed = 0.3
		sparkle = 0.0
		alpha = 0.97
	elif def.water_tints.has(key):                   # cor própria da zona (mangue): turva, sem azul
		var t: Color = def.water_tints[key]
		shallow = t.lightened(0.06)
		deep = t.darkened(0.3)
		foam = Color(0.86, 0.92, 0.84)
		speed = 0.55
		sparkle = 0.25
		alpha = 0.96
	if key in ["water_dark"] and not def.water_tints.has(key):    # poço/pântano/rio escuro sem cor própria
		shallow = base.lightened(0.14)
		deep = base.darkened(0.22)
	m.set_shader_parameter("shallow_color", shallow)
	m.set_shader_parameter("deep_color", deep)
	m.set_shader_parameter("foam_color", foam)
	m.set_shader_parameter("sky_color", shallow.lerp(Color.WHITE, 0.7))
	m.set_shader_parameter("deep_dist", deep_dist)
	m.set_shader_parameter("flow_speed", speed)
	m.set_shader_parameter("sparkle_amount", sparkle)
	m.set_shader_parameter("glow_amount", glow)
	m.set_shader_parameter("glow_color", shallow.lerp(Color(0.3, 1.0, 0.5), 0.5))
	m.set_shader_parameter("alpha_base", alpha)
	m.set_shader_parameter("shore_max", SHORE_MAX)
	m.set_shader_parameter("ripples", _ripples)
	m.set_shader_parameter("fx_clock", _clock)
	if _shore_tex:
		_set_shore(m)
	if key in ["icewater", "soulwater", "bile"]:
		natural = false
	_mats[key] = m
	return m

func _set_shore(m: ShaderMaterial) -> void:
	m.set_shader_parameter("shore_tex", _shore_tex)
	m.set_shader_parameter("shore_origin", _origin)
	m.set_shader_parameter("shore_size", _extent)

# ---------------------------------------------------------------------------
# Margem: distância até a borda mais próxima das malhas de água, num mapa de bytes (0 = na margem, 255 = SHORE_MAX).

## Pega as arestas de borda (usadas por um só triângulo) das malhas de água do GLB, em coordenadas do mapa.
func _collect_segments(node: Node, model: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in range(mi.mesh.get_surface_count()):
			var src := mi.mesh.surface_get_material(i)
			var mname := src.resource_name if src else ""
			if not is_water(mname) or mname.begins_with("agua_funda"):
				continue
			_add_edges(mi, i, _xform_to(mi, model))
	for c in node.get_children():
		_collect_segments(c, model)

static func _xform_to(n: Node3D, root: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf

func _add_edges(mi: MeshInstance3D, surf: int, xf: Transform3D) -> void:
	var arrays := mi.mesh.surface_get_arrays(surf)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if idx.is_empty():
		idx.resize(verts.size())
		for k in range(verts.size()):
			idx[k] = k
	var ids: Dictionary = {}            # posição (1 cm) -> id: o glTF repete vértices
	var pos := PackedVector2Array()
	var map_to: PackedInt32Array = PackedInt32Array()
	map_to.resize(verts.size())
	for k in range(verts.size()):
		var p := xf * verts[k]
		var key := Vector2i(roundi(p.x * 100.0), roundi(p.z * 100.0))
		if not ids.has(key):
			ids[key] = pos.size()
			pos.push_back(Vector2(p.x, p.z))
		map_to[k] = ids[key]
	var count: Dictionary = {}
	for t in range(0, idx.size() - 2, 3):
		var a := map_to[idx[t]]
		var b := map_to[idx[t + 1]]
		var c := map_to[idx[t + 2]]
		for e in [[a, b], [b, c], [c, a]]:
			if e[0] == e[1]:
				continue
			var lo := mini(e[0], e[1])
			var hi := maxi(e[0], e[1])
			var ek := lo * 4194304 + hi
			count[ek] = int(count.get(ek, 0)) + 1
	for ek in count:
		if count[ek] == 1:
			_segs.push_back(pos[int(ek) / 4194304])
			_segs.push_back(pos[int(ek) % 4194304])

func _start_bake() -> void:
	if _segs.is_empty():
		return
	var half := def.size * 0.5 + Vector2(30, 30)
	_origin = -half
	_extent = half * 2.0
	_bake_size = Vector2i(ceili(_extent.x / CELL), ceili(_extent.y / CELL))
	_task = WorkerThreadPool.add_task(_bake_job, false, "water_shore")

## Roda em thread: só dados puros (PackedArrays). Cada borda carimba a distância nos texels vizinhos.
func _bake_job() -> void:
	_bake_bytes = bake_bytes(_segs, _origin, _bake_size)

## Mapa de bytes da distância à margem (público para o teste).
static func bake_bytes(segs: PackedVector2Array, origin: Vector2, size: Vector2i) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(size.x * size.y)
	bytes.fill(255)
	var reach := int(ceil(SHORE_MAX / CELL))
	for s in range(0, segs.size() - 1, 2):
		var a := (segs[s] - origin) / CELL
		var b := (segs[s + 1] - origin) / CELL
		var ab := b - a
		var len2 := maxf(ab.length_squared(), 0.0001)
		var x0 := maxi(0, int(minf(a.x, b.x)) - reach)
		var x1 := mini(size.x - 1, int(maxf(a.x, b.x)) + reach)
		var y0 := maxi(0, int(minf(a.y, b.y)) - reach)
		var y1 := mini(size.y - 1, int(maxf(a.y, b.y)) + reach)
		for y in range(y0, y1 + 1):
			var row := y * size.x
			var py := y + 0.5 - a.y
			for x in range(x0, x1 + 1):
				var px := x + 0.5 - a.x
				var u := clampf((px * ab.x + py * ab.y) / len2, 0.0, 1.0)
				var dx := px - ab.x * u
				var dy := py - ab.y * u
				var dm := sqrt(dx * dx + dy * dy) * CELL       # metros
				if dm < SHORE_MAX:
					var v := int(dm / SHORE_MAX * 255.0)
					if v < bytes[row + x]:
						bytes[row + x] = v
	return bytes

func _finish_bake() -> void:
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	var img := Image.create_from_data(_bake_size.x, _bake_size.y, false, Image.FORMAT_L8, _bake_bytes)
	_shore_tex = ImageTexture.create_from_image(img)
	for k in _mats:
		_set_shore(_mats[k])

## Espera a medição acabar (testes e capturas).
func finish_now() -> void:
	if _task >= 0:
		_finish_bake()

func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1

# ---------------------------------------------------------------------------
# Formas da água (dos dados do mapa) e animações

func _prepare_shapes() -> void:
	_bridges = MapGeometry.water_crossings(def)
	var rocks: Array = []
	for ob in def.obstacles:
		if ob.get("kind", "") != "rock" or not ob.get("visible", true):
			continue
		var q: Vector3 = ob["pos"]
		var p := Vector2(q.x, q.z)
		var edge := _edge_info(p)
		if edge.x > -0.5 and edge.x < 2.4:             # pedra na beirada, do lado de fora (ou quase na linha)
			rocks.push_back(Vector3(p.x, p.y, edge.y))
	_rocks = PackedVector3Array(rocks)
	_rock_next.resize(_rocks.size())
	for i in range(_rocks.size()):
		_rock_next[i] = _rng.randf_range(0.0, 4.0)
	_fish_mesh = _make_fish_mesh()

## (distância da margem de fora para dentro: < 0 é dentro da água; ângulo em rad do ponto para a água) da água mais próxima.
func _edge_info(p: Vector2) -> Vector2:
	var best := Vector2(1e9, 0.0)
	for w in def.water:
		var d: float
		var toward: Vector2
		if w["kind"] == "lake":
			var c: Vector2 = w["pos"]
			d = p.distance_to(c) - float(w["r"])
			toward = (c - p).normalized()
		else:
			var pts: PackedVector2Array = w["pts"]
			var bd := 1e9
			var bp := Vector2.ZERO
			for i in range(pts.size() - 1):
				var q := Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])
				var dd := p.distance_to(q)
				if dd < bd:
					bd = dd
					bp = q
			d = bd - float(w["w"]) * 0.5
			toward = (bp - p).normalized()
		if d < best.x:
			best = Vector2(d, toward.angle())
	return best

func _on_bridge(p: Vector2) -> bool:
	for b in _bridges:
		var rel: Vector2 = p - b["pos"]
		if absf(rel.dot(b["dir"])) < float(b["half"]) and rel.length() < float(b["w"]) * 0.5 + float(b["half"]) + 4.0:
			return true
	return false

func _in_water(p: Vector2, margin: float) -> bool:
	return _edge_info(p).x < -margin

func _ripple(p: Vector2, amp: float) -> void:
	_ripples[_rip_i] = Vector4(p.x, p.y, _clock, amp)
	_rip_i = (_rip_i + 1) % MAX_RIPPLES
	_ripples_live = 1.9

func _push_ripples() -> void:
	for k in _mats:
		var m: ShaderMaterial = _mats[k]
		m.set_shader_parameter("ripples", _ripples)
		m.set_shader_parameter("fx_clock", _clock)

func _process(delta: float) -> void:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		_finish_bake()
	var player := Sim.player
	if player == null or player.map_id != def.id or _mats.is_empty():
		return
	var pp := Vector2(player.position.x, player.position.z)
	_clock += delta
	_scan_t -= delta
	var near := _edge_info(pp).x < NEAR
	if near:
		if _scan_t <= 0.0:
			_scan_t = 0.18
			_scan_entities(pp)
			_scan_bridges_rocks(pp)
		_update_fish(delta, pp)
		_update_leaves(delta, pp)
	elif _ripples_live <= 0.0 and _fish.is_empty() and _leaves.is_empty():
		return
	_ripples_live = maxf(0.0, _ripples_live - delta)
	if near or _ripples_live > 0.0:
		_push_ripples()          # só enquanto há onda viva ou jogador perto

## Passos: criaturas andando em água rasa (até 0,5 m da margem) fora de ponte deixam ondas.
func _scan_entities(pp: Vector2) -> void:
	var n := 0
	for e in Sim.map_entities(def.id):
		var dx: float = e.position.x - pp.x
		var dz: float = e.position.z - pp.y
		if dx * dx + dz * dz > NEAR * NEAR:
			continue
		var p := Vector2(e.position.x, e.position.z)
		var last: Vector2 = _last_pos.get(e.id, p)
		_last_pos[e.id] = p
		if last.distance_squared_to(p) < 0.0016:
			continue                                        # parado: sem onda
		if _edge_info(p).x < 0.15 and not _on_bridge(p) and e.jump_h < 0.3:
			_ripple(p, 0.65)
			n += 1
			if n >= 4:
				break

## Pontes: ondas ao longo das bordas do tabuleiro; pedras da beirada: respingo de vez em quando.
func _scan_bridges_rocks(pp: Vector2) -> void:
	_bridge_t -= 0.18
	if _bridge_t <= 0.0:
		_bridge_t = 0.9
		for b in _bridges:
			var bp: Vector2 = b["pos"]
			if bp.distance_to(pp) > NEAR:
				continue
			var dir: Vector2 = b["dir"]
			var side := Vector2(-dir.y, dir.x)
			var sgn := 1.0 if _rng.randf() < 0.5 else -1.0
			_ripple(bp + dir * float(b["half"]) * sgn + side * _rng.randf_range(-0.3, 0.3) * float(b["w"]), 0.4)
	for i in range(_rocks.size()):
		var r := _rocks[i]
		if absf(r.x - pp.x) > 32.0 or absf(r.y - pp.y) > 32.0:
			continue
		_rock_next[i] -= 0.18
		if _rock_next[i] <= 0.0:
			_rock_next[i] = _rng.randf_range(2.5, 6.0)
			_ripple(Vector2(r.x, r.y) + Vector2.from_angle(r.z) * 1.1, 0.5)

func _make_fish_mesh() -> Mesh:
	var s := SphereMesh.new()
	s.radius = 0.12
	s.height = 0.24
	s.radial_segments = 8
	s.rings = 4
	return s

func _random_water_point(pp: Vector2, rmin: float, rmax: float, margin: float) -> Variant:
	for _i in range(10):
		var p := pp + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(rmin, rmax)
		if _in_water(p, margin):
			return p
	return null

## Peixe: pula num arco curto, com onda na saída e na volta. Pool fixo de FISH_POOL; só em água natural.
func _update_fish(delta: float, pp: Vector2) -> void:
	if not natural:
		return
	_fish_t -= delta
	if _fish_t <= 0.0 and _fish.size() < FISH_POOL:
		_fish_t = _rng.randf_range(3.5, 8.0)
		var p = _random_water_point(pp, 5.0, 20.0, 2.5)
		if p != null:
			var node := MeshInstance3D.new()
			node.mesh = _fish_mesh
			node.material_override = Materials.toon(Color(0.95, 0.62, 0.38), false)
			node.scale = Vector3(0.7, 0.8, 2.0)
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(node)
			var to: Vector2 = p + Vector2.from_angle(_rng.randf() * TAU) * 1.4
			_fish.push_back({"node": node, "t": 0.0, "from": p, "to": to})
			_ripple(p, 0.8)
	var i := _fish.size() - 1
	while i >= 0:
		var f: Dictionary = _fish[i]
		f["t"] += delta / 0.75
		var u: float = f["t"]
		var node: MeshInstance3D = f["node"]
		if u >= 1.0:
			_ripple(f["to"], 0.9)
			node.queue_free()
			_fish.remove_at(i)
		else:
			var p2: Vector2 = f["from"].lerp(f["to"], u)
			node.position = Vector3(p2.x, WATER_Y + 0.75 * 4.0 * u * (1.0 - u), p2.y)
			var vel := Vector3(f["to"].x - f["from"].x, 0.75 * 4.0 * (1.0 - 2.0 * u) * 1.3, f["to"].y - f["from"].y)
			node.look_at(node.position + vel, Vector3.UP)
		i -= 1

## Folhas e gravetos à deriva (águas naturais): sobem de escala, andam com a correnteza e somem.
func _update_leaves(delta: float, pp: Vector2) -> void:
	if not natural:
		return
	_leaf_t -= delta
	if _leaf_t <= 0.0 and _leaves.size() < LEAF_POOL:
		_leaf_t = _rng.randf_range(1.0, 2.5)
		var p = _random_water_point(pp, 3.0, 24.0, 1.2)
		if p != null:
			var node := MeshInstance3D.new()
			var q := PlaneMesh.new()
			q.size = Vector2(0.32, 0.2)
			node.mesh = q
			var cols := [Color(0.5, 0.68, 0.28), Color(0.84, 0.66, 0.26), Color(0.4, 0.58, 0.3)]
			node.material_override = Materials.toon(cols[_rng.randi() % 3], false)
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.rotation.y = _rng.randf() * TAU
			add_child(node)
			var flow := _flow_at(p)
			_leaves.push_back({"node": node, "t": 0.0, "pos": p, "vel": flow})
	var i := _leaves.size() - 1
	while i >= 0:
		var l: Dictionary = _leaves[i]
		l["t"] += delta
		var t: float = l["t"]
		var p: Vector2 = l["pos"] + (l["vel"] as Vector2) * delta
		l["pos"] = p
		var node: MeshInstance3D = l["node"]
		var far := Vector2(p.x - pp.x, p.y - pp.y).length() > NEAR
		if t > LEAF_LIFE or far or (int(t * 4.0) % 5 == 0 and not _in_water(p, 0.3)):
			node.queue_free()
			_leaves.remove_at(i)
		else:
			var grow := minf(minf(t / 1.5, (LEAF_LIFE - t) / 1.5), 1.0)
			node.scale = Vector3.ONE * clampf(grow, 0.01, 1.0)
			node.position = Vector3(p.x, WATER_Y + 0.02 + 0.015 * sin(t * 2.2 + p.x), p.y)
			node.rotation.y += delta * 0.4
			node.rotation.x = 0.12 * sin(t * 1.7 + p.y)
		i -= 1

## Correnteza no ponto: ao longo do rio mais próximo; em lago, uma deriva lenta.
func _flow_at(p: Vector2) -> Vector2:
	var best := 1e9
	var flow := Vector2.from_angle(_rng.randf() * TAU) * 0.12
	for w in def.water:
		if w["kind"] != "river":
			continue
		var pts: PackedVector2Array = w["pts"]
		for i in range(pts.size() - 1):
			var q := Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])
			var d := p.distance_to(q)
			if d < best:
				best = d
				flow = (pts[i + 1] - pts[i]).normalized() * 0.55
	return flow
