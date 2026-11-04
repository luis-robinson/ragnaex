extends Node
## Ícones dos escudos fotografados do próprio modelo: ícone e escudo nunca divergem.
##   godot --path . tools/icons/shield_icons.tscn   (com janela; depois rode --import)

const TURN := 88.1     # iguais a chibi_kit SHIELD_TURN/SHIELD_TILT/SHIELD_SPIN
const TILT := -12.2
const SPIN := -86.4
const SIZE := 128
var NORMAL: Vector3
var UP: Vector3

## Eixos do Blender (Z para cima) para os do Godot.
func _godot(v: Vector3) -> Vector3:
	return Vector3(v.x, v.z, -v.y)

## Centra o enquadramento nos vértices vistos pela câmera, com margem, e devolve o centro.
func _frame(mesh: Mesh, cam: Camera3D) -> Vector3:
	var up := UP.normalized()
	var n := NORMAL.normalized()
	var right := up.cross(n).normalized()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var depth := 0.0
	for s in range(mesh.get_surface_count()):
		if s >= mesh.get_surface_count() - 1:
			continue                # último material é o contorno
		for v in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			var p := Vector2(v.dot(right), v.dot(up))
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
			depth = v.dot(n)
	var mid := (lo + hi) * 0.5
	cam.size = maxf(hi.x - lo.x, hi.y - lo.y) * 1.1
	return right * mid.x + up * mid.y + n * depth

func _ready() -> void:
	await get_tree().process_frame
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE * 3, SIZE * 3)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.95, 0.93, 0.9)
	env.ambient_light_energy = 0.7
	var world := WorldEnvironment.new()
	world.environment = env
	vp.add_child(world)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.1
	vp.add_child(sun)
	for iid in GameData.items:
		var it: ItemDef = GameData.items[iid]
		if it.shield_style == "":
			continue
		var kit := KitModel.create("male", Color.WHITE, 0.025, "bishop" if it.shield_style.begins_with("bis") else "paladin")     # escudo de conjunto fica no kit da classe
		add_child(kit)
		kit.apply_equipment({ItemDef.Slot.OFFHAND: it})
		var found := kit.find_children("wpn_off_shield_" + it.shield_style, "MeshInstance3D", true, false)
		var src: MeshInstance3D = found[0]
		var mi := MeshInstance3D.new()
		mi.mesh = src.mesh
		for s in range(src.mesh.get_surface_count()):
			mi.set_surface_override_material(s, src.get_active_material(s))
		vp.add_child(mi)
		var b := Basis(Vector3(0, 0, 1), deg_to_rad(TURN)) * Basis(Vector3(1, 0, 0), deg_to_rad(TILT)) * Basis(Vector3(0, 1, 0), deg_to_rad(SPIN))
		NORMAL = _godot(b * Vector3(0, -1, 0))
		UP = _godot(b * Vector3(0, 0, 1))
		var c := _frame(mi.mesh, cam)
		cam.look_at_from_position(c + NORMAL * 6.0, c, UP)
		sun.look_at_from_position(c + NORMAL * 4.0 + UP * 3.0, c, Vector3.UP)
		for i in range(4):
			await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
		img.save_png("res://assets/icons/%s.png" % it.icon)
		print("icone ", it.icon)
		mi.queue_free()
		kit.queue_free()
	get_tree().quit()
