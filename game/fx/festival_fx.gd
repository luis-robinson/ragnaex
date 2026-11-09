class_name FestivalFx
extends Node3D
## Fogos de artifício da vitória (fim do Ato I): depois que o Lich cai (MapsCatalog.VICTORY_QUEST), as praças de
## Aldara e do Bastião (MapsCatalog.FESTIVAL) soltam um foguete a cada poucos segundos sobre o centro da vila.
## Só apresentação: lê a quest feita do jogador e o mapa atual.

const EVERY := Vector2(0.9, 2.2)       # s entre foguetes
const SPREAD := 16.0                   # m em volta do centro da vila
const HEIGHT := Vector2(6.0, 9.0)      # altura da explosão (a câmera alta ainda vê)
const RISE := 0.55                     # s de subida (o som tem o assobio desse tempo)
const COLORS := [Color(1.0, 0.35, 0.3), Color(1.0, 0.85, 0.3), Color(0.45, 0.8, 1.0), Color(0.6, 1.0, 0.5), Color(0.95, 0.5, 1.0), Color(1.0, 1.0, 0.9)]

var main
var _t := 1.0
var _mat: StandardMaterial3D

func _ready() -> void:
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.vertex_color_use_as_albedo = true
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

## Vale festa no mapa atual?
func active() -> bool:
	var p: SimEntity = Sim.player
	if p == null or main == null or not MapsCatalog.FESTIVAL.has(main.current_map_id):
		return false
	return p.quests_completed.has(MapsCatalog.VICTORY_QUEST)

func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = randf_range(EVERY.x, EVERY.y)
	if active():
		launch()

## Um foguete: sobe do chão da praça e explode numa esfera de faíscas de uma cor.
func launch() -> void:
	var def: MapDef = GameData.maps[main.current_map_id]
	var a := randf() * TAU
	var r := sqrt(randf()) * SPREAD
	var base := def.town_center + Vector3(cos(a) * r, 0.0, sin(a) * r)
	var top := base + Vector3(0, randf_range(HEIGHT.x, HEIGHT.y), 0)
	var col: Color = COLORS[randi() % COLORS.size()]
	var rocket := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	rocket.mesh = sm
	var rm := _mat.duplicate() as StandardMaterial3D
	rm.vertex_color_use_as_albedo = false
	rm.albedo_color = col.lightened(0.5)
	rocket.material_override = rm
	rocket.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rocket)
	rocket.global_position = base
	var tw := rocket.create_tween()
	tw.tween_property(rocket, "global_position", top, RISE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func(): _explode(top, col); rocket.queue_free())
	var sfx: Sfx = main.get_node_or_null("Sfx")
	if sfx:
		sfx.play_at("firework", top, true)

func _explode(at: Vector3, col: Color) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 140
	p.lifetime = 1.4
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 9.0
	p.damping_min = 2.5
	p.damping_max = 3.5
	p.gravity = Vector3(0, -2.5, 0)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.32
	sm.radial_segments = 6
	sm.rings = 3
	p.mesh = sm
	p.material_override = _mat
	var grad := Gradient.new()
	grad.set_color(0, col)
	grad.set_color(1, Color(col, 0.0))
	grad.add_point(0.6, col.darkened(0.1))         # segura a cor até 60% da vida, depois apaga
	p.color_ramp = grad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	p.global_position = at
	p.emitting = true
	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 8.0
	light.omni_range = 18.0
	add_child(light)
	light.global_position = at
	var tw := light.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.6)
	tw.tween_callback(light.queue_free)
	get_tree().create_timer(p.lifetime + 0.2).timeout.connect(p.queue_free)
