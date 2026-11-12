class_name FalconView
extends Node3D
## Falcão do Caçador ascendido (Falcoeiro). Só desenho: na sim o falcão é estado do dono (SimEntity.falcon, sem
## entidade). Plana em círculo sobre o caçador e, a cada mergulho anotado pela sim (falcon_dive_time/_pos), desce
## até o alvo e volta. Na Revoada aparecem os outros falcões só durante o mergulho.
## Uso: `FalconView.new()` como filho do EntityView do dono; chamar `follow(entity, centro, delta)` todo quadro.

const ORBIT_R := 1.5                  # m: raio do círculo sobre o dono
const ORBIT_SPEED := 1.5              # rad/s
const BODY := Color(0.52, 0.36, 0.22)
const WING := Color(0.4, 0.27, 0.17)
const CHEST := Color(0.93, 0.86, 0.7)
const BEAK := Color(0.95, 0.75, 0.2)

var _birds: Array = []                # [{root, wings: [esq, dir]}]; o 0 é o falcão do dono
var _phase := 0.0
var _seen_dive := -1000.0
var _dive_t := 1.0                    # 0..1 do mergulho em curso (1 = planando)
var _dive_to: Array = []              # alvo de cada falcão neste mergulho
var _spot := Vector3.ZERO             # onde o falcão principal está (planando)

func _init() -> void:
	top_level = true                  # posição no mundo: não herda giro/escala do boneco
	_birds.append(_make_bird())

func _make_bird() -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	var body := SphereMesh.new(); body.radius = 0.5; body.height = 1.0; body.radial_segments = 8; body.rings = 4
	var b := _part(root, body, BODY); b.scale = Vector3(0.3, 0.24, 0.62)
	var chest := _part(root, body, CHEST); chest.scale = Vector3(0.24, 0.18, 0.4); chest.position = Vector3(0, -0.05, 0.1)
	var head := _part(root, body, BODY.lightened(0.12)); head.scale = Vector3(0.2, 0.19, 0.22); head.position = Vector3(0, 0.07, 0.33)
	var beak := PrismMesh.new(); beak.size = Vector3(0.07, 0.12, 0.06)
	var bk := _part(root, beak, BEAK); bk.position = Vector3(0, 0.04, 0.47); bk.rotation.x = PI * 0.5
	var tail := BoxMesh.new(); tail.size = Vector3(0.2, 0.025, 0.3)
	var tl := _part(root, tail, WING); tl.position = Vector3(0, 0.0, -0.4)
	var wings: Array = []
	for sx in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(sx * 0.1, 0.05, 0.02)
		root.add_child(pivot)
		var inner := BoxMesh.new(); inner.size = Vector3(0.42, 0.03, 0.3)
		var w1 := _part(pivot, inner, BODY); w1.position = Vector3(sx * 0.2, 0, 0)
		var outer := BoxMesh.new(); outer.size = Vector3(0.36, 0.025, 0.22)
		var w2 := _part(pivot, outer, WING); w2.position = Vector3(sx * 0.56, 0, -0.07); w2.rotation.y = -sx * 0.3
		wings.append(pivot)
	return {"root": root, "wings": wings}

func _part(parent: Node3D, mesh: Mesh, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Materials.toon(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

## Quadro a quadro: `center` = posição desenhada do dono (chão).
func follow(e: SimEntity, center: Vector3, delta: float) -> void:
	_phase += delta
	if e.falcon_dive_time != _seen_dive:
		_seen_dive = e.falcon_dive_time
		if not e.falcon_dive_pos.is_empty():
			_dive_to = e.falcon_dive_pos.duplicate()
			_dive_t = 0.0
			while _birds.size() < _dive_to.size():
				_birds.append(_make_bird())
	var ang := _phase * ORBIT_SPEED
	var hover := center + Vector3(cos(ang) * ORBIT_R, Balance.FALCON_HOVER + sin(_phase * 2.1) * 0.12, sin(ang) * ORBIT_R)
	var ahead := Vector3(-sin(ang), 0.0, cos(ang))          # tangente do círculo
	var diving := _dive_t < 1.0
	if diving:
		_dive_t = minf(1.0, _dive_t + delta / Balance.FALCON_DIVE_SHOW)
	for i in range(_birds.size()):
		var bird: Dictionary = _birds[i]
		var root: Node3D = bird["root"]
		root.visible = i == 0 or (diving and i < _dive_to.size())
		if not root.visible:
			continue
		var pos := hover
		var dir := ahead
		var pitch := 0.0
		var flap := sin(_phase * 5.0 + i) * 0.22                # planando: bate devagar
		if diving and i < _dive_to.size():
			var to: Vector3 = (_dive_to[i] as Vector3) + Vector3(0, 0.9, 0)
			var from := hover + Vector3(0, 0.0, 0.6 * i)
			var k := _dive_t / 0.45 if _dive_t < 0.45 else 1.0 - (_dive_t - 0.45) / 0.55     # desce rápido, sobe mais devagar
			k = k * k * (3.0 - 2.0 * k)
			pos = from.lerp(to, k)
			var d := (to - from) * (1.0 if _dive_t < 0.45 else -1.0)
			if Vector2(d.x, d.z).length() > 0.05:
				dir = Vector3(d.x, 0.0, d.z).normalized()
			pitch = clampf(atan2(-d.y, Vector2(d.x, d.z).length()), -1.1, 1.1) * (1.0 - absf(k - 0.5) * 0.6)
			flap = -0.9 if _dive_t < 0.45 else sin(_phase * 16.0) * 0.6     # asas fechadas na descida, batendo forte na subida
		root.global_position = pos
		root.rotation = Vector3(pitch, atan2(dir.x, dir.z), 0.0 if diving else -0.3)     # planando: inclinado para dentro da curva
		var wings: Array = bird["wings"]
		(wings[0] as Node3D).rotation.z = -flap
		(wings[1] as Node3D).rotation.z = flap
	_spot = (_birds[0]["root"] as Node3D).global_position

## Onde o falcão principal está agora (capturas/efeitos).
func spot() -> Vector3:
	return _spot
