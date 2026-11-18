class_name LockMarker
extends Node3D
## Marca do chefe travado (Tab, BossLock): mira dourada girando nos pés + losango branco-dourado sobre a cabeça.
## Dourado/branco de propósito: vermelho/laranja no chão são avisos de golpe (FxManager.DANGER*).

const GOLD := Color(1.0, 0.84, 0.32, 0.95)
const WHITE := Color(1.0, 0.97, 0.85, 0.95)
const SPIN := 1.4            # rad/s da mira
const BOB := 0.12            # m do sobe-desce do losango

var main: Node = null
var target_id: int = -1
var _ring: Node3D
var _gem: MeshInstance3D
var _t := 0.0

func _ready() -> void:
	_ring = Node3D.new()
	add_child(_ring)
	var arc := _arc_mesh(0.92, 1.0, deg_to_rad(54.0), 10)
	var mat := Materials.glow(GOLD, 1.8)
	mat.no_depth_test = true            # aparece por cima do chão e dos avisos
	mat.render_priority = 2
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in range(4):
		var mi := MeshInstance3D.new()
		mi.mesh = arc
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.rotation.y = TAU * float(i) / 4.0
		_ring.add_child(mi)
		var tick := MeshInstance3D.new()     # dente apontando para o centro
		var pm := PrismMesh.new(); pm.size = Vector3(0.16, 0.22, 0.02)
		tick.mesh = pm
		tick.material_override = mat
		tick.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := TAU * float(i) / 4.0 + PI * 0.25
		tick.position = Vector3(sin(a) * 0.86, 0.0, cos(a) * 0.86)
		tick.rotation = Vector3(-PI * 0.5, a, 0.0)
		_ring.add_child(tick)
	_gem = MeshInstance3D.new()
	_gem.mesh = _down_mark(0.22, 0.32)      # triângulo de ponta para baixo, sempre de frente para a câmera
	var gmat := Materials.glow(WHITE, 2.2)
	gmat.no_depth_test = true
	gmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	gmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_gem.material_override = gmat
	_gem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_gem)
	visible = false

func set_target(id: int) -> void:
	target_id = id
	if id < 0:
		visible = false

func _process(delta: float) -> void:
	if target_id < 0 or main == null:
		visible = false
		return
	var e: SimEntity = Sim.get_entity(target_id)
	var views: Dictionary = main.views
	if e == null or not views.has(target_id):
		visible = false
		return
	var v: Node3D = views[target_id]
	visible = v.visible
	_t += delta
	var at := v.global_position
	_ring.global_position = Vector3(at.x, at.y + 0.05, at.z)
	var s := maxf(1.0, e.radius + 0.45)
	_ring.scale = Vector3(s, 1.0, s)
	_ring.rotation.y += delta * SPIN
	var top := at.y + 2.6
	var plate: Label3D = v.get("nameplate")
	if plate:
		top = plate.global_position.y + 0.75
	_gem.global_position = Vector3(at.x, top + sin(_t * 3.0) * BOB, at.z)

## Faixa de arco deitada no chão (raios r0..r1, abertura `span`, centrada em +Z).
static func _arc_mesh(r0: float, r1: float, span: float, segs: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	for i in range(segs + 1):
		var a := -span * 0.5 + span * float(i) / float(segs)
		verts.append(Vector3(sin(a) * r0, 0.0, cos(a) * r0))
		verts.append(Vector3(sin(a) * r1, 0.0, cos(a) * r1))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arr)
	return m

## Seta de ponta para baixo (meia largura `w`, meia altura `h`) no plano XY: o billboard a vira para a câmera.
static func _down_mark(w: float, h: float) -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-w, h, 0), Vector3(w, h, 0), Vector3(0, -h, 0)])
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m
