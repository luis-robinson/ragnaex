class_name AmbientLife
extends Node3D
## Vida de ambiente do mapa atual, só apresentação (a sim não sabe que existe):
## - bichos (MapsCatalog.AMBIENT_LIFE): gaivotas, gaviões, urubus, corvos, morcegos, mariposas e caranguejos. Cada tipo do
##   grupo é UM MultiMesh (1 draw call); asas = dois quads por bicho que batem. Grupo longe da câmera fica escondido e parado.
## - barks: fala curta sobre a cabeça do NPC (`npc_data["barks"]`) quando o jogador passa perto. Lê a sim no _process
##   (já sincronizada pelo SimSync), nunca escreve nela. Ritmo em Balance.BARK_*.

## Aparência por tipo: cor, envergadura (m), altura [mín, máx], velocidade angular (rad/s), batida (Hz), voa?
const KINDS := {
	"gull": {"color": Color(0.96, 0.96, 0.94), "span": 0.9, "h": [6.0, 11.0], "w": 0.45, "flap": 2.2, "fly": true},
	"hawk": {"color": Color(0.5, 0.36, 0.24), "span": 1.4, "h": [16.0, 21.0], "w": 0.22, "flap": 0.6, "fly": true},
	"vulture": {"color": Color(0.22, 0.2, 0.2), "span": 1.6, "h": [11.0, 15.0], "w": 0.28, "flap": 0.5, "fly": true},
	"crow": {"color": Color(0.1, 0.1, 0.12), "span": 0.7, "h": [5.0, 8.0], "w": 0.7, "flap": 3.2, "fly": true},
	"bat": {"color": Color(0.24, 0.18, 0.28), "span": 0.55, "h": [2.6, 4.6], "w": 1.3, "flap": 7.0, "fly": true},
	"moth": {"color": Color(0.98, 0.92, 0.7), "span": 0.18, "h": [0.5, 1.6], "w": 0.9, "flap": 9.0, "fly": true},
	"crab": {"color": Color(0.9, 0.42, 0.26), "span": 0.4, "h": [0.0, 0.0], "w": 0.0, "flap": 0.0, "fly": false},
}
const BARK_Y := 3.7              # altura da fala sobre o chão (acima do nome e da marca de quest)

var map_id := ""
var _groups: Array = []          # {mm: MultiMesh, node, center: Vector3, radius, kind, beasts: [{a, r, h, w, ph, ...}]}
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _bark_scan := 0.0
var _bark_next: Dictionary = {}  # id da entidade -> tempo (s) em que pode falar de novo
var _bubbles: Array = []         # {label: Label3D, eid: int, left: float}

static func create(id: String) -> AmbientLife:
	var v := AmbientLife.new()
	v.name = "AmbientLife"
	v.map_id = id
	return v

func _ready() -> void:
	_rng.seed = hash(map_id)
	for g in MapsCatalog.AMBIENT_LIFE.get(map_id, []):
		_build_group(str(g[0]), Vector3(float(g[1][0]), 0.0, float(g[1][1])), float(g[2]), int(g[3]))
	for i in Balance.BARK_MAX_ACTIVE:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.font_size = 44
		l.pixel_size = 0.004
		l.outline_size = 12
		l.outline_modulate = Color(0.12, 0.1, 0.08, 0.9)
		l.modulate = Color(1.0, 0.97, 0.86)
		l.width = 420.0
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.visible = false
		add_child(l)
		_bubbles.append({"label": l, "eid": -1, "left": 0.0})

## Quantos bichos o mapa tem (testes/auditoria).
static func count_for(id: String) -> int:
	var n := 0
	for g in MapsCatalog.AMBIENT_LIFE.get(id, []):
		n += int(g[3])
	return n

func _build_group(kind: String, center: Vector3, radius: float, n: int) -> void:
	var k: Dictionary = KINDS.get(kind, {})
	if k.is_empty() or n <= 0:
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var fly: bool = k["fly"]
	mm.mesh = _wing_mesh(float(k["span"]) * 0.5) if fly else _crab_mesh(float(k["span"]))
	mm.instance_count = n * (2 if fly else 1)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = k["color"]
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if fly else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	var beasts: Array = []
	for i in n:
		var h: Array = k["h"]
		beasts.append({"a": _rng.randf() * TAU, "r": radius * _rng.randf_range(0.35, 1.0), "h": _rng.randf_range(float(h[0]), float(h[1])),
			"w": float(k["w"]) * _rng.randf_range(0.75, 1.25) * (1.0 if _rng.randf() < 0.7 else -1.0), "ph": _rng.randf() * TAU,
			"pos": center + Vector3(_rng.randf_range(-radius, radius), 0.0, _rng.randf_range(-radius, radius)) * 0.7,
			"goal": center, "wait": _rng.randf_range(0.0, 3.0)})
	_groups.append({"mm": mm, "node": node, "center": center, "radius": radius, "kind": kind, "k": k, "beasts": beasts})

## Asa: quad fino de 0 a `half` em x (a outra asa é a mesma com escala -1).
func _wing_mesh(half: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := half * 0.35
	for v in [Vector3(0, 0, -c), Vector3(half, 0, 0), Vector3(0, 0, c), Vector3(0, 0, -c * 0.4), Vector3(half * 0.9, 0, c * 0.1), Vector3(half, 0, 0)]:
		st.add_vertex(v)
	return st.commit()

func _crab_mesh(span: float) -> Mesh:
	var b := BoxMesh.new()
	b.size = Vector3(span, span * 0.28, span * 0.65)
	return b

func _process(delta: float) -> void:
	_t += delta
	var cam := get_viewport().get_camera_3d()
	var eye: Vector3 = cam.global_position if cam else Vector3.ZERO
	for g in _groups:
		var c: Vector3 = g["center"]
		var near := Vector2(eye.x - c.x, eye.z - c.z).length() < float(g["radius"]) + Balance.AMBIENT_CULL
		(g["node"] as Node3D).visible = near
		if near:
			_animate(g, delta)
	_update_barks(delta)

func _animate(g: Dictionary, delta: float) -> void:
	var mm: MultiMesh = g["mm"]
	var k: Dictionary = g["k"]
	var c: Vector3 = g["center"]
	var beasts: Array = g["beasts"]
	if k["fly"]:
		var flap_hz: float = k["flap"]
		var erratic: bool = g["kind"] in ["bat", "moth"]
		for i in beasts.size():
			var b: Dictionary = beasts[i]
			b["a"] = float(b["a"]) + float(b["w"]) * delta
			var a: float = b["a"]
			var r: float = b["r"]
			var y: float = b["h"] + sin(_t * 0.7 + float(b["ph"])) * 0.6
			if erratic:
				r *= 0.8 + 0.2 * sin(_t * 1.7 + float(b["ph"]))
				y += sin(_t * 3.1 + float(b["ph"]) * 2.0) * 0.4
			var p := c + Vector3(cos(a) * r, y, sin(a) * r)
			var fwd := Vector3(-sin(a), 0.0, cos(a)) * signf(float(b["w"]))
			var basis := Basis.looking_at(fwd, Vector3.UP).rotated(fwd.normalized(), signf(float(b["w"])) * -0.25)     # inclina na curva
			var flap := sin(_t * TAU * flap_hz + float(b["ph"])) * 0.55
			mm.set_instance_transform(i * 2, Transform3D(basis * Basis(Vector3.BACK, flap), p))
			mm.set_instance_transform(i * 2 + 1, Transform3D(basis * Basis(Vector3.BACK, -flap) * Basis.from_scale(Vector3(-1, 1, 1)), p))
	else:
		# caranguejo: anda de lado até um ponto perto, para, escolhe outro
		var rad: float = g["radius"]
		for i in beasts.size():
			var b: Dictionary = beasts[i]
			var pos: Vector3 = b["pos"]
			if float(b["wait"]) > 0.0:
				b["wait"] = float(b["wait"]) - delta
				if float(b["wait"]) <= 0.0:
					b["goal"] = c + Vector3(_rng.randf_range(-rad, rad), 0.0, _rng.randf_range(-rad, rad))
			else:
				var to: Vector3 = (b["goal"] as Vector3) - pos
				if to.length() < 0.1:
					b["wait"] = _rng.randf_range(1.0, 4.0)
				else:
					pos += to.normalized() * minf(to.length(), 1.1 * delta)
					b["pos"] = pos
					b["ph"] = atan2(to.x, to.z) + PI * 0.5      # de lado
			var bob := absf(sin(_t * 14.0 + i)) * 0.03 if float(b["wait"]) <= 0.0 else 0.0
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, float(b["ph"])), pos + Vector3(0, 0.06 + bob, 0)))

# --- barks ---------------------------------------------------------------------------------------------------------------
func _update_barks(delta: float) -> void:
	for bb in _bubbles:
		if int(bb["eid"]) < 0:
			continue
		bb["left"] = float(bb["left"]) - delta
		var l: Label3D = bb["label"]
		var e: SimEntity = Sim.entities.get(int(bb["eid"]))
		if float(bb["left"]) <= 0.0 or e == null or e.map_id != map_id:
			l.visible = false
			bb["eid"] = -1
			continue
		l.global_position = e.position + Vector3(0, BARK_Y, 0)
		l.modulate.a = clampf(float(bb["left"]) / 0.5, 0.0, 1.0)
	_bark_scan -= delta
	if _bark_scan > 0.0:
		return
	_bark_scan = Balance.BARK_SCAN
	var p: SimEntity = Sim.player
	if p == null or p.map_id != map_id or not Sim.maps.has(map_id):
		return
	var free: Dictionary = {}
	for bb in _bubbles:
		if int(bb["eid"]) < 0:
			free = bb
			break
	if free.is_empty():
		return
	var r2 := Balance.BARK_RANGE * Balance.BARK_RANGE
	for e: SimEntity in Sim.maps[map_id]["entities"]:
		if e.kind != SimEntity.Kind.NPC or e.position.distance_squared_to(p.position) > r2:
			continue
		var lines: Array = e.npc_data.get("barks", [])
		if lines.is_empty() or e.npc_hold > 0.0 or _t < float(_bark_next.get(e.id, 0.0)) or _speaking(e.id):
			continue
		if _rng.randf() > Balance.BARK_CHANCE:
			_bark_next[e.id] = _t + Balance.BARK_SCAN * 4.0
			continue
		_bark_next[e.id] = _t + _rng.randf_range(Balance.BARK_COOLDOWN_MIN, Balance.BARK_COOLDOWN_MAX)
		var l: Label3D = free["label"]
		l.text = str(lines[_rng.randi() % lines.size()])
		l.global_position = e.position + Vector3(0, BARK_Y, 0)
		l.modulate.a = 1.0
		l.visible = true
		free["eid"] = e.id
		free["left"] = Balance.BARK_TIME
		return

func _speaking(eid: int) -> bool:
	for bb in _bubbles:
		if int(bb["eid"]) == eid:
			return true
	return false

## Falas ativas agora (smoke/teste): [[nome, texto], ...].
func active_barks() -> Array:
	var out: Array = []
	for bb in _bubbles:
		var e: SimEntity = Sim.entities.get(int(bb["eid"]))
		if e != null:
			out.append([e.name, (bb["label"] as Label3D).text])
	return out
