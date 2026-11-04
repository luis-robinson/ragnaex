class_name MapBuilder
extends RefCounted
## Constrói o visual de um MapDef: chão, obstáculos (blockout low-poly), decoração, portais, luz.
## Se existir assets/models/<map.model>.glb ele é carregado por cima do chão (os obstáculos
## continuam valendo para colisão, mas ficam invisíveis se o GLB existir).

static func build(def: MapDef) -> Node3D:
	_moss = def.ground_color.lerp(Color(0.42, 0.6, 0.32), 0.35)      # musgo das props puxa a grama da zona
	var root := Node3D.new()
	root.name = "Map_" + def.id

	# --- luz e ambiente ---
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = def.sun_energy * (DUNGEON_SUN if is_dungeon(def) else 0.75)
	sun.light_color = def.ambient.lerp(Color(0.7, 0.75, 1.0), 0.4) if is_dungeon(def) else Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.6                     # borda suave (fixa: igual nas duas cascatas)
	sun.shadow_bias = 0.08
	sun.shadow_normal_bias = 1.5
	sun.directional_shadow_max_distance = 90.0
	sun.directional_shadow_fade_start = 0.9
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_blend_splits = true
	root.add_child(sun)
	root.add_child(_environment(def))

	# --- chão pintado (shader) + grama/flores (MultiMesh) ---
	var ground := _ground(def)
	root.add_child(ground)
	if def.interior:
		_interior_lights(def, root)
	else:
		root.add_child(_grass(def))

	var has_model := ResourceLoader.exists("res://assets/models/%s.glb" % def.model) if def.model != "" else false
	var zone := not def.roads.is_empty()        # zona do Blender: GLB (terreno/muralha/água) + props do JSON
	if has_model:
		var scene: PackedScene = load("res://assets/models/%s.glb" % def.model)
		var model := scene.instantiate()
		if zone:
			_zone_materials(model, def)
		root.add_child(model)
		set_vis_range(model)
	if zone or not has_model:
		var obs_nodes: Array = []
		for ob in def.obstacles:
			if ob.get("hidden", false):
				continue
			var n := _obstacle(ob)
			if n:
				root.add_child(n)
				set_vis_range(n)
				var size: Vector3 = ob.get("size", Vector3.ONE)
				if size.y > 1.6:
					n.set_meta("occluder_h", size.y)
					obs_nodes.append(n)
		root.set_meta("occluders", obs_nodes)
	for d in def.decor:
		var n := _decor(d)
		if n:
			root.add_child(n)
			set_vis_range(n)
	for p in def.portals:
		root.add_child(_portal(p))
	return root

## Dungeon (mapa com parent_map): subterrâneo escuro, sem céu, névoa densa; o jogador leva a própria luz (main.gd).
const DUNGEON_SUN := 0.5
const DUNGEON_FOG := 0.007
const TORCH_COLOR := Color(1.0, 0.72, 0.42)

static func is_dungeon(def: MapDef) -> bool:
	return def.parent_map != "" and not def.interior

## Céu procedural (luz ambiente e reflexo vêm dele), AO + luz indireta em tela, brilho suave,
## névoa de profundidade e correção de cor. Cores derivam do `ambient` do mapa.
static func _environment(def: MapDef) -> WorldEnvironment:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = def.ambient.lerp(Color(0.32, 0.52, 0.86), 0.65)
	sky_mat.sky_horizon_color = def.ambient.lerp(Color(0.82, 0.87, 0.95), 0.5)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color.darkened(0.1)
	sky_mat.ground_bottom_color = def.ground_color.darkened(0.35)
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.75
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.0
	e.tonemap_white = 6.0
	e.ssao_enabled = true
	e.ssao_radius = 1.4
	e.ssao_intensity = 1.8
	e.ssao_power = 1.4
	e.ssao_light_affect = 0.15
	e.ssil_enabled = false
	e.ssil_radius = 3.0
	e.ssil_intensity = 0.6
	e.glow_enabled = true
	e.glow_intensity = 0.45
	e.glow_strength = 0.9
	e.glow_bloom = 0.04
	e.glow_hdr_threshold = 1.0
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	e.fog_enabled = true
	e.fog_light_color = sky_mat.sky_horizon_color
	e.fog_density = 0.0012
	e.fog_aerial_perspective = 0.15
	e.fog_sky_affect = 0.4
	e.adjustment_enabled = true
	e.adjustment_brightness = 1.06
	e.adjustment_contrast = 1.1
	e.adjustment_saturation = 1.2
	if is_dungeon(def):
		var dark := def.ambient.darkened(0.88)
		e.background_mode = Environment.BG_COLOR
		e.background_color = dark
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = def.ambient.darkened(0.15)
		e.ambient_light_energy = 0.9
		e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		e.fog_light_color = dark
		e.fog_density = DUNGEON_FOG
		e.fog_aerial_perspective = 0.0
		e.fog_sky_affect = 1.0
		e.glow_intensity = 0.7
		e.adjustment_saturation = 1.1
	if def.interior:                       # dentro de casa: fundo escuro, luz quente, sem névoa nem céu
		e.background_mode = Environment.BG_COLOR
		e.background_color = Color(0.05, 0.035, 0.03)
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = def.ambient
		e.ambient_light_energy = 0.55
		e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		e.fog_enabled = false
		e.glow_intensity = 0.6
	var env := WorldEnvironment.new()
	env.environment = e
	return env

## Luz de dentro de casa: lampiões no teto (cor do `ambient`) e a lareira acesa.
static func _interior_lights(def: MapDef, root: Node3D) -> void:
	var h := def.half()
	for x in [-h.x * 0.5, h.x * 0.5]:
		var l := OmniLight3D.new()
		l.light_color = def.ambient
		l.light_energy = 1.6
		l.omni_range = maxf(h.x, h.y) * 1.6
		l.position = Vector3(x, 3.2, 0.0)
		root.add_child(l)
	for ob in def.obstacles:
		if ob.get("kind", "") in ["fireplace", "cauldron"]:
			var f := OmniLight3D.new()
			f.light_color = Color(1.0, 0.55, 0.25) if ob["kind"] == "fireplace" else Color(0.45, 1.0, 0.5)
			f.light_energy = 2.2
			f.omni_range = 6.0
			f.position = (ob["pos"] as Vector3) + Vector3(0, 0.9, 0.8)
			root.add_child(f)

## Porta de casa: capacho iluminado no chão e o nome por cima (sem o arco azul dos portais de zona).
static func _door_marker(p: Dictionary) -> Node3D:
	var n := Node3D.new()
	n.name = "Door_" + p["id"]
	n.position = p["pos"]
	var r: float = p.get("radius", 0.8)
	var mat := _cyl(r, r, 0.04, Color(1.0, 0.85, 0.5), 20)
	mat.position.y = 0.03
	mat.material_override = Materials.glow(Color(1.0, 0.82, 0.45, 0.45), 1.2)
	n.add_child(mat)
	var label := Label3D.new()
	label.text = p.get("label", "")
	label.position.y = 2.9
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.pixel_size = 0.01
	label.outline_size = 10
	label.modulate = Color(1.0, 0.9, 0.65)
	n.add_child(label)
	return n

## stones: 0 = sem calçamento, 0..1 = manchas de lajes, 1 = calçado inteiro (ruas).
static func _ground_material(a: Color, b: Color, dirt: Color, dirt_amount: float, seed: float,
		stones: float = 0.0, stone_size: float = 1.2, stone_color: Color = Color(0.72, 0.7, 0.65)) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/ground.gdshader")
	m.set_shader_parameter("color_a", a)
	m.set_shader_parameter("color_b", b)
	m.set_shader_parameter("color_dirt", dirt)
	m.set_shader_parameter("dirt_amount", dirt_amount)
	m.set_shader_parameter("seed", seed)
	m.set_shader_parameter("stones", stones)
	m.set_shader_parameter("stone_size", stone_size)
	m.set_shader_parameter("stone_color", stone_color)
	return m

static func _dirt_color(def: MapDef) -> Color:
	var dry := def.ground_color.s < 0.25
	return def.ground_color.darkened(0.12).lerp(Color(0.6, 0.54, 0.46), 0.45) if dry else def.ground_color.lerp(Color(0.62, 0.5, 0.36), 0.7)

static func _ground(def: MapDef) -> Node3D:
	var n := Node3D.new()
	n.name = "Ground"
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = def.size + (Vector2(0.6, 0.6) if def.interior else Vector2(90, 90))     # passa da borda: o mapa "continua" (casa: só a sala)
	pm.subdivide_width = 8
	pm.subdivide_depth = 8
	mi.mesh = pm
	var dry := def.ground_color.s < 0.25
	mi.material_override = _ground_material(def.ground_color.lightened(0.1), def.ground_color_alt.darkened(0.14 if dry else 0.08),
		_dirt_color(def), 0.12 if def.is_town and def.town_radius <= 0.0 else (0.38 if dry else 0.2), float(def.id.hash() % 97),
		0.55 if dry else 0.0, 1.3, def.ground_color.lightened(0.18))   # ruínas: restos de calçamento
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # sem auto-sombra (acne)
	n.add_child(mi)
	return n

## Grama e flores espalhadas por ruído (manchas), longe de obstáculos, caminhos e portais.
static func _grass(def: MapDef) -> Node3D:
	var n := Node3D.new()
	n.name = "Grass"
	var rng := RandomNumberGenerator.new()
	rng.seed = def.id.hash()
	var noise := FastNoiseLite.new()
	noise.seed = def.id.hash()
	noise.frequency = 0.045
	var h := def.half()
	var dry := def.ground_color.s < 0.25        # ruínas: grama seca e rala
	var density := 0.35 if def.is_town else (0.45 if dry else 0.9)
	var mask := _zone_mask(def) if not def.roads.is_empty() else {}
	if not mask.is_empty():
		density = 0.62
	var count := int(def.size.x * def.size.y * density)
	var blocked := func(p: Vector3) -> bool:
		if not mask.is_empty():
			return _mask_blocked(mask, p)
		for ob in def.obstacles:
			var op: Vector3 = ob["pos"]
			var sz: Vector3 = ob.get("size", Vector3.ONE)
			if absf(p.x - op.x) < sz.x * 0.5 + 0.4 and absf(p.z - op.z) < sz.z * 0.5 + 0.4:
				return true
		for d in def.decor:
			if d.get("kind", "") == "path":
				var dp: Vector3 = d["pos"]
				var ds: Vector3 = d.get("size", Vector3.ONE)
				if absf(p.x - dp.x) < ds.x * 0.5 + 0.2 and absf(p.z - dp.z) < ds.z * 0.5 + 0.2:
					return true
		for pt in def.portals:
			if p.distance_to(pt["pos"]) < float(pt.get("radius", 2.0)) + 1.0:
				return true
		return false
	var xforms: Array = []
	var colors: Array = []
	var flowers: Array = []
	var flower_cols: Array = []
	var palette := [Color(1, 0.85, 0.35), Color(1, 0.55, 0.65), Color(0.85, 0.75, 1), Color(1, 1, 1)]
	var tries := 0
	while xforms.size() < count and tries < count * 4:
		tries += 1
		var p := Vector3(rng.randf_range(-h.x, h.x), 0, rng.randf_range(-h.y, h.y))
		var nv := noise.get_noise_2d(p.x, p.z)       # -1..1: manchas densas e clareiras
		if rng.randf() > clampf(0.55 + nv * 0.9, 0.08, 1.0) or blocked.call(p):
			continue
		var s := rng.randf_range(0.7, 1.35) * (0.75 if dry else 1.0)
		var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.3), s)), p)
		xforms.append(t)
		colors.append(Color(1, 1, 1).lerp(Color(0.85, 0.95, 0.75), rng.randf()))
		if not dry and nv > 0.1 and rng.randf() < 0.05:
			flowers.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * rng.randf_range(0.8, 1.2)), p + Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))))
			flower_cols.append(palette[rng.randi() % palette.size()])
	var gm := ShaderMaterial.new()
	gm.shader = load("res://shaders/grass.gdshader")
	gm.set_shader_parameter("base_color", def.ground_color_alt.darkened(0.06))
	gm.set_shader_parameter("tip_color", def.ground_color.lightened(0.3) if not dry else Color(0.78, 0.74, 0.56))
	n.add_child(_multimesh(_tuft_mesh(), gm, xforms, colors))
	if flowers.size() > 0:
		var fm := Materials.toon(Color.WHITE, false, 0.15)
		n.add_child(_multimesh(_flower_mesh(), fm, flowers, flower_cols))
	return n

## Grade de 1 m marcando onde NÃO nasce grama: estradas, água, vila murada, obstáculos e fora do vale.
static func _zone_mask(def: MapDef) -> Dictionary:
	var h := def.half()
	var w := int(def.size.x)
	var d := int(def.size.y)
	var cells := PackedByteArray()
	cells.resize(w * d)
	var mark := func(cx: float, cz: float, r: float) -> void:
		for ix in range(int(floor(cx - r + h.x)), int(ceil(cx + r + h.x)) + 1):
			for iz in range(int(floor(cz - r + h.y)), int(ceil(cz + r + h.y)) + 1):
				if ix >= 0 and iz >= 0 and ix < w and iz < d and Vector2(ix - h.x + 0.5 - cx, iz - h.y + 0.5 - cz).length() <= r:
					cells[iz * w + ix] = 1
	var lines: Array = def.roads + def.water
	for l in lines:
		if l.has("pts"):
			var pts: PackedVector2Array = l["pts"]
			var half_w: float = float(l.get("w", 4.0)) * 0.5 + (1.6 if l.get("kind", "") == "river" else 0.4)
			if pts.size() == 1:
				mark.call(pts[0].x, pts[0].y, float(l.get("r", half_w)))
			for i in range(pts.size() - 1):
				var seg := pts[i + 1] - pts[i]
				var steps := maxi(1, int(seg.length() / 0.8))
				for k in range(steps + 1):
					var q := pts[i] + seg * (float(k) / steps)
					mark.call(q.x, q.y, half_w)
		elif l.get("kind", "") == "lake":
			var lp: Vector2 = l["pos"]
			mark.call(lp.x, lp.y, float(l["r"]) + 2.2)
	for ob in def.obstacles:
		var op: Vector3 = ob["pos"]
		var sz: Vector3 = ob.get("size", Vector3.ONE)
		if ob.get("kind", "") in ["cliff", "wall"]:
			continue          # colisão fina/fora do vale: tratada abaixo
		mark.call(op.x, op.z, minf(maxf(sz.x, sz.z) * 0.5 + 0.3, 14.0))
	return {"cells": cells, "w": w, "d": d, "h": h, "town_c": def.town_center, "town_r": def.town_radius + 1.5,
		"rim": _rim_radius(def)}

## Raio aproximado do andável (o anel de penhascos vem como obstáculos "cliff").
static func _rim_radius(def: MapDef) -> float:
	var r := 0.0
	var n := 0
	for ob in def.obstacles:
		if ob.get("kind", "") == "cliff":
			var op: Vector3 = ob["pos"]
			r += Vector2(op.x, op.z).length()
			n += 1
	return r / n if n > 0 else INF

static func _mask_blocked(mask: Dictionary, p: Vector3) -> bool:
	var h: Vector2 = mask["h"]
	var ix := int(p.x + h.x)
	var iz := int(p.z + h.y)
	if ix < 0 or iz < 0 or ix >= mask["w"] or iz >= mask["d"]:
		return true
	if Vector2(p.x, p.z).length() > float(mask["rim"]) - 2.0:
		return true
	var tc: Vector3 = mask["town_c"]
	if Vector2(p.x - tc.x, p.z - tc.z).length() < float(mask["town_r"]):
		return true
	return mask["cells"][iz * int(mask["w"]) + ix] == 1

## Troca os materiais do GLB da zona pelos do jogo (toon, chão de terra/paralelepípedo, água).
static func _zone_materials(node: Node, def: MapDef) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for i in range(mi.mesh.get_surface_count()):
			var src := mi.mesh.surface_get_material(i)
			var mname := src.resource_name if src else ""
			var base := (src as BaseMaterial3D).albedo_color if src is BaseMaterial3D else Color.GRAY
			var mat: Material
			if mname.begins_with("pave_") or mname.begins_with("patch_"):
				# manchas de região (Blender: zone_lib.patch): calçamento ou chão pintado na cor do material
				var paved := mname.begins_with("pave_")
				var c := base.srgb_to_linear()      # o import do glTF clareia a cor; volta ao tom escolhido no Blender
				mi.set_surface_override_material(i, _ground_material(c.lightened(0.05), c.darkened(0.05), c.darkened(0.14),
					0.0 if paved else 0.25, float(mname.hash() % 97), 1.0 if paved else 0.0, 1.0, c))
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				continue
			match mname:
				"road":
					mat = _ground_material(_dirt_color(def).lightened(0.08), _dirt_color(def), _dirt_color(def).darkened(0.1), 0.0, 3.0)
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				"street":
					mat = _ground_material(Color(0.74, 0.7, 0.62), Color(0.68, 0.64, 0.56), Color(0.6, 0.55, 0.47), 0.0, 5.0, 1.0, 0.9, Color(0.8, 0.77, 0.7))
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				"water", "water_dark":
					mat = Materials.toon(base.lerp(Color(0.4, 0.66, 0.86), 0.25), false, 0.25)
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				"fire":
					mat = Materials.glow(Color(1.0, 0.6, 0.2), 2.5)
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				"cliff_grass", "hill_grass":
					mat = Materials.toon(def.ground_color.lerp(base, 0.4), false)
				"cliff_rock", "cliff_rock_d", "stone_ruin", "wheat", "hay", "snow":
					mat = Materials.toon(base, false)
				"roof":
					mat = Materials.toon(base, false)
				_:
					mat = Materials.toon(base)
			mi.set_surface_override_material(i, mat)
	for c in node.get_children():
		_zone_materials(c, def)

static func _multimesh(mesh: Mesh, material: Material, xforms: Array, colors: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi

## Tufo: 7 lâminas finas em leque (UV.y = 0 na base, 1 na ponta).
static func _tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(7):
		var a := TAU * i / 7.0 + rng.randf_range(-0.3, 0.3)
		var dir := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-dir.z, 0, dir.x) * rng.randf_range(0.035, 0.05)
		var base := dir * rng.randf_range(0.0, 0.12)
		var height := rng.randf_range(0.28, 0.5)
		var tip := base + dir * rng.randf_range(0.08, 0.18) + Vector3.UP * height
		st.set_color(Color.WHITE)
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0, 0)); st.add_vertex(base - side)
		st.set_uv(Vector2(1, 0)); st.add_vertex(base + side)
		st.set_uv(Vector2(0.5, 1)); st.add_vertex(tip)
	return st.commit()

## Flor: haste curta + miolo amarelo + 5 pétalas (cor da instância).
static func _flower_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var top := Vector3(0, 0.32, 0)
	for i in range(5):
		var a0 := TAU * i / 5.0
		var a1 := a0 + TAU / 10.0
		var a2 := a0 - TAU / 10.0
		st.set_color(Color.WHITE)
		st.add_vertex(top)
		st.add_vertex(top + Vector3(cos(a1), 0.02, sin(a1)) * 0.09)
		st.add_vertex(top + Vector3(cos(a0), 0.05, sin(a0)) * 0.13)
		st.add_vertex(top)
		st.add_vertex(top + Vector3(cos(a0), 0.05, sin(a0)) * 0.13)
		st.add_vertex(top + Vector3(cos(a2), 0.02, sin(a2)) * 0.09)
	# miolo
	for i in range(6):
		var a0 := TAU * i / 6.0
		var a1 := TAU * (i + 1) / 6.0
		st.set_color(Color(1.4, 1.1, 0.2))
		st.add_vertex(top + Vector3(0, 0.03, 0))
		st.add_vertex(top + Vector3(cos(a1) * 0.035, 0.025, sin(a1) * 0.035))
		st.add_vertex(top + Vector3(cos(a0) * 0.035, 0.025, sin(a0) * 0.035))
	return st.commit()

static func _box(size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = Materials.toon(color)
	return mi

static func _cyl(top: float, bottom: float, height: float, color: Color, sides: int = 8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = height
	cm.radial_segments = sides
	mi.mesh = cm
	mi.material_override = Materials.toon(color)
	return mi

static func _sphere(radius: float, color: Color, segments: int = 8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = segments
	sm.rings = max(4, segments / 2)
	mi.mesh = sm
	mi.material_override = Materials.toon(color)
	return mi

static var _prop_cache: Dictionary = {}
## Props somem além disto (medido da câmera, que fica ~19 m acima do chão); grandes vão mais longe.
const PROP_VIS_RANGE := 78.0
const BIG_VIS_RANGE := 150.0

## Distância de desenho em toda malha de um nó (props e peças do GLB da zona). Terreno, água e penhascos
## (malhas enormes) ficam sempre visíveis.
static func set_vis_range(n: Node, big_at: float = 8.0) -> void:
	for gi in n.find_children("*", "GeometryInstance3D", true, false):
		var g := gi as GeometryInstance3D
		if g is MultiMeshInstance3D:
			continue
		var sz: Vector3 = g.get_aabb().size * (g as Node3D).global_transform.basis.get_scale() if g.is_inside_tree() else g.get_aabb().size
		var span := maxf(sz.x, sz.z)
		if span > 40.0:
			continue
		g.visibility_range_end = BIG_VIS_RANGE if span > big_at or sz.y > 6.0 else PROP_VIS_RANGE
		g.visibility_range_end_margin = 6.0
		g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
static var _moss := Color(0.45, 0.62, 0.34)

## Lona da barraca: a cor do obstáculo clareada (lados) e um tom mais escuro no fundo.
static func tent_cloth(c: Color, back: bool) -> Color:
	return c.darkened(0.18) if back else c.lightened(0.25)

## Instancia assets/models/prop_<kind>.glb ajustado ao tamanho do obstáculo.
## Materiais com nome especial recebem as cores do MapDef: "tint" = cor do obstáculo, "roof" = cor do telhado.
static func _prop_model(kind: String, size: Vector3, ob: Dictionary = {}) -> Node3D:
	var path := "res://assets/models/prop_%s.glb" % kind
	if not _prop_cache.has(kind):
		_prop_cache[kind] = load(path) if ResourceLoader.exists(path) else null
	var scene: PackedScene = _prop_cache[kind]
	if scene == null:
		return null
	var inst: Node3D = scene.instantiate()
	# AABB total para escalar ao tamanho do MapDef
	var aabb := AABB()
	var first := true
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (mi as MeshInstance3D).get_aabb()
		b = (mi as Node3D).transform * b
		aabb = b if first else aabb.merge(b)
		first = false
		var m := mi as MeshInstance3D
		for i in range(m.get_surface_override_material_count()):
			var base := m.get_active_material(i)
			var col: Color = base.albedo_color if base is BaseMaterial3D else Color(0.8, 0.8, 0.8)
			var mname := base.resource_name if base else ""
			if mname == "tint" and ob.has("color"):
				col = ob["color"]
			elif mname == "p_moss":
				col = _moss
			elif mname == "tint_l" and ob.has("color"):
				col = (ob["color"] as Color).lightened(0.22)
			elif mname == "roof" and ob.has("roof"):
				col = ob["roof"]
			elif kind == "tent" and ob.has("color") and mname in ["p_cloth_w", "p_cloth_r"]:
				col = tent_cloth(ob["color"], mname == "p_cloth_r")     # cada acampamento com a sua lona
			var emission: float = base.emission_energy_multiplier if (base is BaseMaterial3D and base.emission_enabled) else 0.0
			# telhas não levam contorno: o casco invertido desenharia uma borda preta em cada telha
			m.set_surface_override_material(i, Materials.toon(col, kind != "path" and mname != "roof", minf(emission, 2.0)))
	if first or aabb.size.x < 0.001 or aabb.size.y < 0.001 or aabb.size.z < 0.001:
		return inst
	var holder := Node3D.new()
	holder.add_child(inst)
	var sz := size
	# props compridos são modelados ao longo de X: obstáculo "fundo" (z > x) gira 90°
	if kind in ["wall", "fence", "ruin", "bench", "stall", "tent", "log", "iwall", "bed", "counter", "shelf", "table", "rug", "fireplace", "door"] and size.z > size.x * 1.2:
		inst.rotation.y = PI * 0.5
		sz = Vector3(size.z, size.y, size.x)
	if kind in ["tree", "pine", "dead_tree", "lamp", "statue"]:
		# escala só pela altura: a copa pode passar da área de colisão (o tronco é o obstáculo)
		inst.scale = Vector3.ONE * (sz.y / aabb.size.y)
		# variação por posição: árvores não ficam todas iguais
		var h := absi(hash(ob.get("pos", Vector3.ZERO)))
		inst.rotation.y = float(h % 360) * PI / 180.0
		inst.scale *= 0.9 + float(h % 21) / 100.0
	elif kind in ["rock", "pillar", "well", "fountain", "bush", "stump", "flowers", "reeds"]:
		var u := maxf(sz.x, sz.z) / maxf(aabb.size.x, aabb.size.z)
		inst.scale = Vector3(u, sz.y / aabb.size.y, u)
		if kind in ["rock", "bush", "stump", "flowers", "reeds"]:
			inst.rotation.y = float(absi(hash(ob.get("pos", Vector3.ZERO))) % 360) * PI / 180.0
	else:
		inst.scale = Vector3(sz.x / aabb.size.x, sz.y / aabb.size.y, sz.z / aabb.size.z)
	return holder

static func _obstacle(ob: Dictionary) -> Node3D:
	var kind: String = ob.get("kind", "house")
	var pos: Vector3 = ob["pos"]
	var size: Vector3 = ob.get("size", Vector3.ONE)
	var color: Color = ob.get("color", Color.GRAY)
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = deg_to_rad(float(ob.get("rot", 0.0)))
	var prop := _prop_model(kind, size, ob)
	if prop:
		n.add_child(prop)
		return n
	match kind:
		"house":
			var body := _box(Vector3(size.x, size.y * 0.72, size.z), color)
			body.position.y = size.y * 0.36
			n.add_child(body)
			var roof := _cyl(0.0, maxf(size.x, size.z) * 0.72, size.y * 0.5, ob.get("roof", Color(0.8, 0.42, 0.34)), 4)
			roof.rotation.y = PI * 0.25
			roof.position.y = size.y * 0.72 + size.y * 0.25
			roof.scale = Vector3(size.x / maxf(size.x, size.z), 1.0, size.z / maxf(size.x, size.z)) * 1.02
			n.add_child(roof)
			var door := _box(Vector3(0.9, 1.5, 0.15), Color(0.4, 0.28, 0.18))
			door.position = Vector3(0, 0.75, size.z * 0.5 + 0.05)
			n.add_child(door)
			var win := _box(Vector3(0.7, 0.6, 0.12), Color(0.55, 0.75, 0.9))
			win.position = Vector3(size.x * 0.3, 1.6, size.z * 0.5 + 0.05)
			n.add_child(win)
		"tent":
			var t := _cyl(0.0, size.x * 0.7, size.y, color, 4)
			t.rotation.y = PI * 0.25
			t.position.y = size.y * 0.5
			n.add_child(t)
		"tree":
			var r := size.x * 0.5
			var trunk := _cyl(r * 0.22, r * 0.3, size.y * 0.45, Color(0.45, 0.32, 0.2), 6)
			trunk.position.y = size.y * 0.22
			n.add_child(trunk)
			var crown := _sphere(r * 1.15, color, 7)
			crown.position.y = size.y * 0.72
			crown.scale = Vector3(1.0, 1.15, 1.0)
			n.add_child(crown)
			var crown2 := _sphere(r * 0.8, color.lightened(0.12), 6)
			crown2.position = Vector3(r * 0.4, size.y * 0.9, r * 0.2)
			n.add_child(crown2)
		"rock":
			var rk := _sphere(size.x * 0.55, color, 5)
			rk.position.y = size.y * 0.35
			rk.scale = Vector3(1.0, size.y / size.x, size.z / size.x)
			n.add_child(rk)
		"pillar":
			var p := _cyl(size.x * 0.4, size.x * 0.5, size.y, color, 8)
			p.position.y = size.y * 0.5
			n.add_child(p)
			var cap := _box(Vector3(size.x * 1.1, 0.3, size.x * 1.1), color.lightened(0.1))
			cap.position.y = size.y + 0.15
			n.add_child(cap)
		"wall", "ruin", "fence":
			var w := _box(size, color)
			w.position.y = size.y * 0.5
			n.add_child(w)
			if kind == "wall":
				for i in range(int(size.x / 1.0)):
					var m := _box(Vector3(0.5, 0.5, size.z), color.lightened(0.08))
					m.position = Vector3(-size.x * 0.5 + 0.5 + i * 1.0, size.y + 0.25, 0)
					n.add_child(m)
		"well":
			var base := _cyl(size.x * 0.5, size.x * 0.55, size.y * 0.6, color, 8)
			base.position.y = size.y * 0.3
			n.add_child(base)
			var roof := _cyl(0.0, size.x * 0.7, 0.8, Color(0.6, 0.35, 0.3), 4)
			roof.position.y = size.y * 0.6 + 1.6
			n.add_child(roof)
		"fountain":
			var base := _cyl(size.x * 0.5, size.x * 0.55, 0.6, color, 10)
			base.position.y = 0.3
			n.add_child(base)
			var water := _cyl(size.x * 0.42, size.x * 0.42, 0.1, Color(0.5, 0.75, 0.95), 10)
			water.position.y = 0.62
			water.material_override = Materials.glow(Color(0.5, 0.75, 0.95, 0.9), 0.6)
			n.add_child(water)
			var col := _cyl(0.25, 0.35, 1.6, color, 8)
			col.position.y = 1.2
			n.add_child(col)
			var top := _sphere(0.45, Color(0.5, 0.75, 0.95), 8)
			top.position.y = 2.1
			n.add_child(top)
		"statue":
			var ped := _box(Vector3(size.x, size.y * 0.35, size.z), color)
			ped.position.y = size.y * 0.17
			n.add_child(ped)
			var fig := _sphere(size.x * 0.35, color.lightened(0.15), 6)
			fig.position.y = size.y * 0.7
			fig.scale = Vector3(0.8, 1.6, 0.8)
			n.add_child(fig)
		"lamp":
			var post := _cyl(0.06, 0.09, size.y, color, 6)
			post.position.y = size.y * 0.5
			n.add_child(post)
			var light := _sphere(0.22, Color(1, 0.85, 0.5), 6)
			light.position.y = size.y
			light.material_override = Materials.glow(Color(1, 0.85, 0.5), 2.0)
			n.add_child(light)
			var ol := OmniLight3D.new()
			ol.position.y = size.y
			ol.light_color = Color(1, 0.85, 0.5)
			ol.light_energy = 1.2
			ol.omni_range = 6.0
			n.add_child(ol)
		"stall", "crate", "bench":
			var b := _box(size, color)
			b.position.y = size.y * 0.5
			n.add_child(b)
			if kind == "stall":
				var canopy := _box(Vector3(size.x * 1.3, 0.12, size.z * 1.4), Color(0.85, 0.3, 0.3))
				canopy.position.y = size.y + 1.1
				n.add_child(canopy)
				for sx in [-1.0, 1.0]:
					var pole := _cyl(0.05, 0.05, size.y + 1.1, Color(0.4, 0.3, 0.2), 4)
					pole.position = Vector3(sx * size.x * 0.6, (size.y + 1.1) * 0.5, size.z * 0.6)
					n.add_child(pole)
		_:
			var b := _box(size, color)
			b.position.y = size.y * 0.5
			n.add_child(b)
	return n

static func _decor(d: Dictionary) -> Node3D:
	var kind: String = d.get("kind", "grass")
	var pos: Vector3 = d["pos"]
	var size: Vector3 = d.get("size", Vector3.ONE)
	var color: Color = d.get("color", Color.GREEN)
	var n := Node3D.new()
	n.position = pos
	match kind:
		"path":
			# caminho de terra batida com o mesmo shader pintado do chão (sem bordas de caixa)
			var mi := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(size.x + 0.6, size.z + 0.6)
			mi.mesh = pm
			mi.position.y = 0.012
			mi.material_override = _ground_material(color.lightened(0.04), color.darkened(0.12), color.darkened(0.25), 0.25, 3.0,
				1.0, 0.42, color.lightened(0.1))   # rua de paralelepípedos
			n.add_child(mi)
		"grass", "flower":
			return null   # grama/flores agora vêm do MultiMesh (_grass)
		_:
			return null
	return n

static func _portal(p: Dictionary) -> Node3D:
	if p.get("door", false):
		return _door_marker(p)
	var n := Node3D.new()
	n.name = "Portal_" + p["id"]
	n.position = p["pos"]
	var r: float = p.get("radius", 1.8)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r - 0.25
	tm.outer_radius = r
	tm.rings = 24
	tm.ring_segments = 6
	ring.mesh = tm
	ring.position.y = 0.08
	ring.material_override = Materials.glow(Color(0.5, 0.8, 1.0), 2.0)
	n.add_child(ring)
	var disc := _cyl(r - 0.3, r - 0.3, 0.05, Color(0.5, 0.8, 1.0), 16)
	disc.position.y = 0.04
	disc.material_override = Materials.glow(Color(0.5, 0.8, 1.0, 0.35), 0.8)
	n.add_child(disc)
	var arch := MeshInstance3D.new()
	var am := TorusMesh.new()
	am.inner_radius = r * 0.8
	am.outer_radius = r * 0.95
	arch.mesh = am
	arch.rotation.x = PI * 0.5
	arch.position.y = r * 0.9
	arch.material_override = Materials.toon(Color(0.85, 0.8, 0.68))
	n.add_child(arch)
	var label := Label3D.new()
	label.text = p.get("label", "")
	label.position.y = r * 1.9 + 0.3
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.pixel_size = 0.012
	label.outline_size = 12
	label.modulate = Color(0.8, 0.95, 1.0)
	n.add_child(label)
	var light := OmniLight3D.new()
	light.light_color = Color(0.5, 0.8, 1.0)
	light.light_energy = 2.0
	light.omni_range = 7.0
	light.position.y = 1.0
	n.add_child(light)
	return n
