extends Node
## Ícones dos conjuntos lendários fotografados do próprio kit (como os escudos): ícone e peça nunca divergem.
##   godot --path . tools/icons/set_icons.tscn [-- --only=<estilo>]   (com janela; depois rode --import)
## Só conjuntos de GearCatalog.SET_VISUALS com "icon" igual ao estilo (o pal1 tem arte desenhada à mão).
## Peças: head/body/gloves/boots = malhas arm_<estilo>_<peça>_*; weapon = a espada do conjunto. Escudo: shield_icons.tscn.

const SIZE := 128
## direção da câmera por peça (de onde olha; eixos do Godot: +Z é a frente do boneco, o -Y do Blender) e margem
## Armas: a direção sai da própria malha (olha a face larga, comprimento na diagonal). Luvas: só uma mão (a outra fica fora do quadro).
## Cabeça: de cima em 3/4 (aros e coroas aparecem como anel, não como risco).
const VIEWS := {
	"head": [Vector3(0.45, 0.8, 1.0), 1.12], "body": [Vector3(0.45, 0.25, 1.0), 1.06],
	"gloves": [Vector3(0.9, 0.35, 1.0), 1.12], "boots": [Vector3(0.5, 0.5, 1.0), 1.08],
	"weapon": [Vector3.ZERO, 1.08], "mace": [Vector3.ZERO, 1.08], "mace2h": [Vector3.ZERO, 1.08], "offhand": [Vector3.ZERO, 1.08],
}

func _ready() -> void:
	await get_tree().process_frame
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="): only = a.get_slice("=", 1)
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
	var made := 0
	for set_id in GearCatalog.SET_VISUALS:
		var vis: Dictionary = GearCatalog.SET_VISUALS[set_id]
		if vis.get("icon", "") != vis["style"] or (only != "" and vis["style"] != only):
			continue
		var sd: SetDef = GameData.sets[set_id]
		var eq := {}
		for iid in sd.pieces:
			var it: ItemDef = GameData.items[iid]
			eq[ItemDef.Slot.OFFHAND if iid.ends_with("_offhand") else it.slot] = it
		for iid in sd.pieces + sd.alt_pieces:
			var it: ItemDef = GameData.items[iid]
			var piece: String = iid.get_slice("_", iid.get_slice_count("_") - 1)
			var shot_eq := eq.duplicate()
			if iid.ends_with("_offhand") and it.slot == ItemDef.Slot.WEAPON:
				shot_eq[ItemDef.Slot.OFFHAND] = it   # segunda arma (machado gêmeo): vai na mão esquerda
			else:
				shot_eq[it.slot] = it                # variante (maça): empunhada no lugar da espada
			if it.shield_style != "":
				continue          # escudo: tools/icons/shield_icons.tscn fotografa de frente (aqui sairia no ângulo do braço)
			var kit := KitModel.create("male", GameData.classes[sd.class_id].hair_color, 0.025, sd.class_id)        # cabelo sob chapéu na cor da classe
			vp.add_child(kit)
			kit.apply_equipment(shot_eq)
			if kit.anim:
				kit.anim.stop()
			await get_tree().process_frame
			var keep := _keep_prefix(vis["style"], piece, it)
			var pts := PackedVector3Array()
			for mi in kit.find_children("*", "MeshInstance3D", true, false):
				var m := mi as MeshInstance3D
				var want := m.visible and m.name.begins_with(keep) and m.name != "wpn_off_grip"
				# cabeça: o rosto do boneco fica como manequim (aro, coroa e chapéu aparecem "vestidos")
				var mannequin := piece == "head" and (m.name == "base_head" or m.name == "base_eyes_round")
				m.visible = want or mannequin
				if want or mannequin:
					pts.append_array(_points(m))
			if pts.is_empty():
				push_warning("sem malha para %s (%s)" % [iid, keep])
				kit.queue_free()
				continue
			var view: Array = VIEWS[piece]
			var dir: Vector3 = (view[0] as Vector3).normalized()
			var up_hint := Vector3.UP
			if piece == "gloves":
				pts = _one_side(pts)                 # uma luva só, grande no quadro
			if dir == Vector3.ZERO:                  # arma: face larga para a câmera, comprimento na diagonal (ponta para cima/direita)
				var axes := _axes(pts)
				var a1: Vector3 = axes[0]
				dir = axes[2]
				if dir.dot(Vector3(0.3, 0.5, 1.0)) < 0.0:
					dir = -dir
				var hand := _hand_pos(kit, piece == "offhand")
				var mean := _mean(pts)
				if a1.dot(mean - hand) < 0.0:
					a1 = -a1                         # do cabo para a ponta
				var side := dir.cross(a1).normalized()
				up_hint = (a1 - side).normalized()   # na tela, a1 fica a 45°
			_frame(cam, pts, dir, up_hint, float(view[1]))
			var ctr := _mean(pts)
			sun.look_at_from_position(ctr + dir * 4.0 + Vector3(1.5, 3.0, 0.0), ctr, Vector3.UP)
			for i in range(4):
				await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			img.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
			img.save_png("res://assets/icons/%s_%s.png" % [vis["icon"], piece])
			made += 1
			kit.queue_free()
	print("SET_ICONS_OK ", made)
	get_tree().quit()

## Vértices (posição de mundo) de uma malha, amostrados.
func _points(m: MeshInstance3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	if m.mesh == null:
		return out
	for si in range(m.mesh.get_surface_count()):
		var verts: PackedVector3Array = m.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
		var step := maxi(1, verts.size() / 600)
		for i in range(0, verts.size(), step):
			out.append(m.global_transform * verts[i])
	return out

func _mean(pts: PackedVector3Array) -> Vector3:
	var c := Vector3.ZERO
	for p in pts:
		c += p
	return c / float(pts.size())

## Só os vértices de um lado do boneco (luva da mão direita).
func _one_side(pts: PackedVector3Array) -> PackedVector3Array:
	var cx := _mean(pts).x
	var out := PackedVector3Array()
	for p in pts:
		if p.x <= cx:
			out.append(p)
	return out if out.size() > 8 else pts

## Eixos principais (maior, médio, menor) por iteração de potência na covariância.
func _axes(pts: PackedVector3Array) -> Array:
	var c := _mean(pts)
	var cov := [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]
	for p in pts:
		var d := p - c
		for i in range(3):
			for j in range(3):
				cov[i][j] += d[i] * d[j]
	var found: Array = []
	for k in range(2):
		var v := Vector3(0.3, 1.0, 0.2).normalized() if k == 0 else Vector3(1.0, 0.1, 0.3).normalized()
		for it in range(40):
			var nv := Vector3(cov[0][0] * v.x + cov[0][1] * v.y + cov[0][2] * v.z, cov[1][0] * v.x + cov[1][1] * v.y + cov[1][2] * v.z, cov[2][0] * v.x + cov[2][1] * v.y + cov[2][2] * v.z)
			for f in found:
				nv -= f * nv.dot(f)
			if nv.length() < 1e-9:
				break
			v = nv.normalized()
		found.append(v)
	found.append(found[0].cross(found[1]).normalized())
	return found

func _hand_pos(kit: KitModel, left: bool) -> Vector3:
	if kit.skeleton:
		var idx := kit.skeleton.find_bone("hand.L" if left else "hand.R")
		if idx < 0:
			idx = kit.skeleton.find_bone("hand_L" if left else "hand_R")
		if idx >= 0:
			return kit.skeleton.global_transform * kit.skeleton.get_bone_global_pose(idx).origin
	return Vector3.ZERO

## Câmera ortográfica justa: projeta os pontos no plano da câmera e enquadra o retângulo (quadrado).
func _frame(cam: Camera3D, pts: PackedVector3Array, dir: Vector3, up_hint: Vector3, margin: float) -> void:
	var fwd := -dir
	var right := fwd.cross(up_hint).normalized()
	if right.length() < 0.01:
		right = fwd.cross(Vector3.FORWARD).normalized()
	var up := right.cross(fwd).normalized()
	var u0 := INF
	var u1 := -INF
	var v0 := INF
	var v1 := -INF
	var depth := 0.0
	for p in pts:
		var u := p.dot(right)
		var v := p.dot(up)
		u0 = minf(u0, u); u1 = maxf(u1, u)
		v0 = minf(v0, v); v1 = maxf(v1, v)
		depth += p.dot(fwd)
	depth /= float(pts.size())
	var ctr := right * (u0 + u1) * 0.5 + up * (v0 + v1) * 0.5 + fwd * depth
	cam.size = maxf(u1 - u0, v1 - v0) * margin
	cam.look_at_from_position(ctr - fwd * 6.0, ctr, up)

## Prefixo das malhas que entram na foto da peça.
func _keep_prefix(style: String, piece: String, it: ItemDef) -> String:
	match piece:
		"weapon", "mace", "mace2h": return "wpn_main_"
		"offhand": return "wpn_off_"
	return "arm_%s_%s_" % [style, piece]
