class_name SiegeFx
extends Node3D
## Fumaça e fogo do Cerco Vivo no mapa atual (só apresentação; a sim não sabe que existe). Lê os marcadores do JSON da zona
## (MapDef.fx: {kind, pos, if/unless}) e o estado do cerco (SiegeSystem.status):
## - `smoke`: coluna de fumaça no horizonte (fora do vale), enquanto a condição do marcador vale;
## - `smoke_low`: fumaça fina das casas queimadas;
## - `fire`: as Chamas (leva chegou e não foi repelida), só os primeiros Balance.SIEGE_FIRE_SPOTS, até a próxima repelida.
## No máximo MAX_EMITTERS emissores por mapa (AC-15), os de perto com distância de desenho. Sons: Events.siege_event.

const MAX_EMITTERS := 6
const NEAR_RANGE := 90.0                 # m: fogo e fumaça baixa somem além disto
const POLL := 1.0
## tipo -> [quantas partículas, vida s, raio da bola m, velocidade m/s, espalhamento graus, cor inicial, cor final, escala final]
const LOOKS := {
	"smoke": [22, 9.0, 2.6, 3.4, 9.0, Color(0.2, 0.19, 0.2, 0.85), Color(0.42, 0.4, 0.4, 0.0), 2.6],
	"smoke_low": [10, 4.5, 0.7, 1.5, 14.0, Color(0.26, 0.24, 0.24, 0.6), Color(0.5, 0.48, 0.47, 0.0), 2.0],
	"fire": [26, 1.0, 0.62, 3.0, 26.0, Color(1.0, 0.62, 0.18, 0.95), Color(0.9, 0.2, 0.05, 0.0), 0.5],
}
const EVENT_SOUND := {"harass": "war_drum", "horn": "wolf_howl", "scorch": "fire"}

var map_id := ""
var _items: Array = []                   # [{node, marker}]
var _t := 0.0

static func create(id: String) -> SiegeFx:
	var fx := SiegeFx.new()
	fx.map_id = id
	fx.name = "SiegeFx"
	return fx

func _ready() -> void:
	var def: MapDef = GameData.maps.get(map_id)
	if def == null or def.fx.is_empty():
		set_process(false)
		return
	var fires := 0
	for mk in def.fx:
		if _items.size() >= MAX_EMITTERS:
			break
		var kind := str(mk["kind"])
		if not LOOKS.has(kind):
			continue
		if kind == "fire":
			fires += 1
			if fires > Balance.SIEGE_FIRE_SPOTS:
				continue
		var node := emitter(kind)
		node.position = mk["pos"] + Vector3(0, 2.2 if kind == "fire" else (2.6 if kind == "smoke_low" else 4.0), 0)
		node.visible = false
		add_child(node)
		if kind == "fire":                   # fumaça baixa junto do fogo, no mesmo nó (liga e desliga com ele)
			var sm := emitter("smoke_low")
			sm.position = Vector3(0, 1.0, 0)
			node.add_child(sm)
		_items.append({"node": node, "marker": mk})
	Events.siege_event.connect(_on_siege_event)
	_refresh()

## Emissor de bolas chapadas que sobem e somem (CPUParticles3D: poucas partículas, sem sombra).
static func emitter(kind: String) -> CPUParticles3D:
	var look: Array = LOOKS[kind]
	var p := CPUParticles3D.new()
	p.amount = int(look[0])
	p.lifetime = float(look[1])
	p.preprocess = float(look[1])
	p.direction = Vector3.UP
	p.spread = float(look[4])
	p.gravity = Vector3(0.35, 0.25, 0.0)         # vento fraco de oeste, sobe devagar
	p.initial_velocity_min = float(look[3]) * 0.8
	p.initial_velocity_max = float(look[3]) * 1.2
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = float(look[2]) * 0.6
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.45))
	curve.add_point(Vector2(1.0, float(look[7])))
	p.scale_amount_curve = curve
	var sm := SphereMesh.new()
	sm.radius = float(look[2])
	sm.height = float(look[2]) * 2.0
	sm.radial_segments = 7
	sm.rings = 4
	p.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p.material_override = mat
	var grad := Gradient.new()
	grad.set_color(0, look[5])
	grad.set_color(1, look[6])
	p.color_ramp = grad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if kind != "smoke":
		p.visibility_range_end = NEAR_RANGE
		p.visibility_range_end_margin = 8.0
	return p

func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = POLL
		_refresh()

## Quais emissores valem agora (pura; os testes chamam): marcador ativo e, no fogo, mapa em Chamas.
static func wanted(marker: Dictionary, scorch: bool) -> bool:
	if str(marker["kind"]) == "fire":
		return scorch
	return WorldState.active(Sim, marker)

func _refresh() -> void:
	var ss: Dictionary = SiegeSystem.status(Sim, map_id)
	var scorch: bool = ss.get("scorch", false)
	for it in _items:
		var node: CPUParticles3D = it["node"]
		var on := wanted(it["marker"], scorch)
		if node.visible != on:
			node.visible = on
			node.emitting = on

func _on_siege_event(mid: String, kind: String) -> void:
	if mid != map_id:
		return
	_refresh()
	if EVENT_SOUND.has(kind):
		Sfx.ui(EVENT_SOUND[kind])
