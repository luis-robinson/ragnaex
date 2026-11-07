class_name RecallFx
extends Node3D
## Efeito da volta à cidade (G) em quem está conjurando no mapa do jogador: círculo de runas girando no chão,
## coluna de luz que sobe e engrossa com a conjuração e fagulhas em espiral. Lido de `SimEntity.recall_left`
## (estado da sim) + `Events.recall_cast` (fim: clarão; interrompido: estilhaço e "Interrompido" sobre a cabeça).

const COL := Color(0.62, 0.84, 1.0)
const GOLD := Color(1.0, 0.88, 0.5)
const SPARKS := 7

var _fx: Dictionary = {}      # entity_id -> {root, disc, inner, column, sparks: Array, t}

func _ready() -> void:
	Events.recall_cast.connect(_on_recall)

func _process(delta: float) -> void:
	var p: SimEntity = Sim.player
	if p == null or not Sim.maps.has(p.map_id):
		_clear()
		return
	var seen := {}
	for e in Sim.maps[p.map_id]["entities"]:
		if e.recall_left > 0.0 and e.is_alive():
			seen[e.id] = true
			if not _fx.has(e.id):
				_fx[e.id] = _make(e)
			_update(_fx[e.id], e, delta)
	for id in _fx.keys():
		if not seen.has(id):
			(_fx[id]["root"] as Node3D).queue_free()
			_fx.erase(id)

func _clear() -> void:
	for id in _fx:
		(_fx[id]["root"] as Node3D).queue_free()
	_fx.clear()

func _make(e: SimEntity) -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	root.position = e.position
	var disc := _ring_mesh(1.05, 0.08, COL, 2.4)
	root.add_child(disc)
	var inner := _ring_mesh(0.62, 0.05, GOLD, 2.0)
	root.add_child(inner)
	# runas: quatro losangos no anel de fora, giram com ele
	for i in range(6):
		var r := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.16, 0.02, 0.16)
		r.mesh = b
		r.material_override = Materials.glow(GOLD, 2.2)
		var a := TAU * i / 6.0
		r.position = Vector3(cos(a) * 0.84, 0.05, sin(a) * 0.84)
		r.rotation.y = PI * 0.25 - a
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		disc.add_child(r)
	var column := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.38
	cm.bottom_radius = 0.62
	cm.height = 1.0
	cm.radial_segments = 16
	cm.cap_top = false
	cm.cap_bottom = false
	column.mesh = cm
	var m := Materials.glow(COL, 1.6)
	m.albedo_color.a = 0.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	column.material_override = m
	column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(column)
	var sparks: Array = []
	for i in range(SPARKS):
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.07
		sm.height = 0.14
		sm.radial_segments = 6
		sm.rings = 3
		s.mesh = sm
		s.material_override = Materials.glow(GOLD if i % 2 == 0 else Color(1, 1, 1), 3.0)
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(s)
		sparks.append(s)
	return {"root": root, "disc": disc, "inner": inner, "column": column, "mat": m, "sparks": sparks, "t": 0.0}

func _ring_mesh(r: float, w: float, col: Color, energy: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = r - w
	t.outer_radius = r
	t.rings = 32
	t.ring_segments = 4
	mi.mesh = t
	mi.scale = Vector3(1, 0.2, 1)
	mi.position.y = 0.04
	mi.material_override = Materials.glow(col, energy)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _update(fx: Dictionary, e: SimEntity, delta: float) -> void:
	fx["t"] = float(fx["t"]) + delta
	var t: float = fx["t"]
	var prog := Sim.recall_progress(e)
	var root: Node3D = fx["root"]
	root.position = e.position
	(fx["disc"] as Node3D).rotation.y = t * 1.6
	(fx["inner"] as Node3D).rotation.y = -t * 2.4
	var pulse := 1.0 + sin(t * 6.0) * 0.04
	(fx["inner"] as Node3D).scale = Vector3(pulse, 0.2, pulse)
	# coluna: nasce baixa e fina, sobe até 4,5 m e clareia no fim
	var col: MeshInstance3D = fx["column"]
	var h := lerpf(0.6, 4.5, ease(prog, 0.6))
	col.scale = Vector3(lerpf(0.55, 1.0, prog), h, lerpf(0.55, 1.0, prog))
	col.position.y = h * 0.5
	(fx["mat"] as StandardMaterial3D).albedo_color.a = lerpf(0.1, 0.3, prog) + sin(t * 9.0) * 0.03
	var sparks: Array = fx["sparks"]
	for i in range(sparks.size()):
		var k := fmod(t * 0.55 + float(i) / sparks.size(), 1.0)       # cada fagulha sobe e recomeça
		var a := t * 3.2 + TAU * i / sparks.size()
		var rad := lerpf(0.85, 0.3, k)
		var s: MeshInstance3D = sparks[i]
		s.position = Vector3(cos(a) * rad, 0.15 + k * lerpf(1.6, 3.6, prog), sin(a) * rad)
		s.scale = Vector3.ONE * (1.0 - k * 0.7)

func _on_recall(id: int, phase: String) -> void:
	var e: SimEntity = Sim.get_entity(id)
	if e == null or Sim.player == null or e.map_id != Sim.player.map_id:
		return
	if phase == "done":
		_flash(e.position, COL)
	elif phase == "interrupted":
		_flash(e.position, Color(1.0, 0.45, 0.4), 0.35)
		_float_text(e.position + Vector3(0, 2.6, 0), "Interrompido", Color(1.0, 0.5, 0.45))

## Clarão: coluna larga que some subindo.
func _flash(at: Vector3, col: Color, dur: float = 0.6) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.7
	cm.bottom_radius = 0.9
	cm.height = 5.0
	cm.cap_top = false
	cm.cap_bottom = false
	mi.mesh = cm
	var m := Materials.glow(col, 2.4)
	m.albedo_color.a = 0.7
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at + Vector3(0, 2.5, 0)
	add_child(mi)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(0.15, 1.4, 0.15), dur).set_ease(Tween.EASE_IN)
	tw.tween_property(m, "albedo_color:a", 0.0, dur)
	tw.chain().tween_callback(mi.queue_free)

func _float_text(pos: Vector3, text: String, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.modulate = color
	l.outline_size = 14
	l.font_size = 40
	l.pixel_size = 0.012
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos
	add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position", pos + Vector3(0, 1.0, 0), 1.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.6)
	tw.chain().tween_callback(l.queue_free)
