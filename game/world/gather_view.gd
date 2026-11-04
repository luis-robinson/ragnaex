class_name GatherView
extends Node3D
## Pontos de colheita do mapa atual (lidos da sim): erva, minério, concha, cogumelo, relíquia, caixote, minério estelar.
## Cada ponto é um modelinho com um brilho no chão que pulsa; some quando colhido e volta quando a sim reabre o ponto.

var map_id := ""
var _nodes: Array = []          # Node3D por ponto (mesma ordem de Sim.maps[map_id]["gather"])
var _t := 0.0

static func create(id: String) -> GatherView:
	var v := GatherView.new()
	v.name = "Gather"
	v.map_id = id
	return v

func _ready() -> void:
	if not Sim.maps.has(map_id):
		return
	for g in Sim.maps[map_id].get("gather", []):
		var n := _make(str(g["kind"]))
		n.position = g["pos"]
		n.rotation.y = float(absi(hash(g["pos"])) % 360) * PI / 180.0
		add_child(n)
		_nodes.append(n)
	Events.gathered.connect(_on_gathered)
	_refresh()

func _on_gathered(mid: String, idx: int, _eid: int) -> void:
	if mid == map_id and idx >= 0 and idx < _nodes.size():
		_nodes[idx].visible = false

func _process(delta: float) -> void:
	_t += delta
	if fmod(_t, 0.5) < delta:
		_refresh()
	var pulse := 0.55 + 0.35 * sin(_t * 3.0)
	for n in _nodes:
		if n.visible:
			var glow: MeshInstance3D = n.get_node_or_null("Glow")
			if glow:
				glow.scale = Vector3.ONE * (0.9 + pulse * 0.25)

func _refresh() -> void:
	if not Sim.maps.has(map_id):
		return
	var list: Array = Sim.maps[map_id].get("gather", [])
	for i in range(mini(list.size(), _nodes.size())):
		_nodes[i].visible = float(list[i]["ready_at"]) <= Sim.time

func _mesh(m: Mesh, col: Color, pos: Vector3, scl: Vector3 = Vector3.ONE, glow := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = Materials.glow(col, 1.6) if glow else Materials.toon(col)
	mi.position = pos
	mi.scale = scl
	return mi

func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 10
	s.rings = 6
	return s

func _cyl(r_top: float, r_bot: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = 8
	return c

func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b

func _make(kind: String) -> Node3D:
	var n := Node3D.new()
	var glow_col := Color(1.0, 0.95, 0.6)
	match kind:
		"herb", "herb_blue":
			var leaf := Color(0.35, 0.72, 0.32) if kind == "herb" else Color(0.3, 0.55, 0.85)
			glow_col = Color(0.6, 1.0, 0.55) if kind == "herb" else Color(0.55, 0.8, 1.0)
			for i in range(5):
				var a := TAU * i / 5.0
				var l := _mesh(_cyl(0.0, 0.07, 0.5), leaf, Vector3(cos(a) * 0.12, 0.22, sin(a) * 0.12))
				l.rotation = Vector3(sin(a) * 0.5, 0, -cos(a) * 0.5)
				n.add_child(l)
			n.add_child(_mesh(_sphere(0.07), Color(1, 1, 0.9), Vector3(0, 0.5, 0)))
		"ore", "star":
			var rock := Color(0.5, 0.48, 0.46)
			n.add_child(_mesh(_sphere(0.42), rock, Vector3(0, 0.22, 0), Vector3(1.2, 0.7, 1.0)))
			var gem := Color(0.85, 0.5, 0.25) if kind == "ore" else Color(0.45, 0.65, 1.0)
			glow_col = Color(1.0, 0.75, 0.45) if kind == "ore" else Color(0.5, 0.7, 1.0)
			for i in range(3):
				var a := TAU * i / 3.0 + 0.4
				var c := _mesh(_cyl(0.0, 0.08, 0.32), gem, Vector3(cos(a) * 0.22, 0.42, sin(a) * 0.18), Vector3.ONE, kind == "star")
				c.rotation = Vector3(sin(a) * 0.4, 0, -cos(a) * 0.4)
				n.add_child(c)
		"shell":
			glow_col = Color(1.0, 0.75, 0.65)
			n.add_child(_mesh(_sphere(0.22), Color(0.95, 0.55, 0.45), Vector3(0, 0.06, 0), Vector3(1.2, 0.45, 1.0)))
			n.add_child(_mesh(_sphere(0.14), Color(0.98, 0.85, 0.75), Vector3(0.3, 0.04, 0.12), Vector3(1.1, 0.4, 1.0)))
		"mushroom":
			glow_col = Color(1.0, 0.6, 0.55)
			for q in [[0.0, 0.0, 1.0], [0.22, 0.1, 0.65], [-0.18, 0.14, 0.55]]:
				var s: float = q[2]
				n.add_child(_mesh(_cyl(0.05 * s, 0.07 * s, 0.3 * s), Color(0.95, 0.92, 0.85), Vector3(q[0], 0.15 * s, q[1])))
				n.add_child(_mesh(_sphere(0.18 * s), Color(0.85, 0.25, 0.22), Vector3(q[0], 0.3 * s, q[1]), Vector3(1, 0.6, 1)))
		"relic":
			glow_col = Color(1.0, 0.9, 0.55)
			var shard := _mesh(_box(Vector3(0.45, 0.1, 0.32)), Color(0.78, 0.68, 0.45), Vector3(0, 0.08, 0))
			shard.rotation = Vector3(0.35, 0.3, 0.2)
			n.add_child(shard)
			var s2 := _mesh(_box(Vector3(0.25, 0.08, 0.2)), Color(0.7, 0.58, 0.38), Vector3(0.28, 0.05, 0.15))
			s2.rotation = Vector3(-0.2, 0.8, 0.1)
			n.add_child(s2)
		_:   # caixote
			glow_col = Color(1.0, 0.85, 0.5)
			n.add_child(_mesh(_box(Vector3(0.7, 0.55, 0.55)), Color(0.6, 0.44, 0.28), Vector3(0, 0.28, 0)))
			n.add_child(_mesh(_box(Vector3(0.74, 0.08, 0.59)), Color(0.38, 0.27, 0.18), Vector3(0, 0.5, 0)))
	var g := MeshInstance3D.new()
	g.name = "Glow"
	var disc := CylinderMesh.new()
	disc.top_radius = 0.6
	disc.bottom_radius = 0.6
	disc.height = 0.02
	disc.radial_segments = 16
	g.mesh = disc
	g.position.y = 0.02
	g.material_override = Materials.glow(Color(glow_col.r, glow_col.g, glow_col.b, 0.35), 1.0)
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(g)
	return n
