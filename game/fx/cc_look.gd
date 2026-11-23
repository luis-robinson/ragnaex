class_name CcLook
extends RefCounted
## Controle no corpo (plano de combate 2026-11-23, C3c): o que o boneco mostra enquanto está preso ou lento.
## Formas e cores em BuffLooks.CC_LOOKS; quem liga/desliga é o EntityView._update_status (só apresentação).
## - roots: raízes curvas saindo do chão em volta dos pés + mancha de terra (preso);
## - drag:  rastro de poeira fria que fica para trás nos pés (lento sem gelo; o lento de gelo é o anel de gelo).
## As estrelas do atordoado e o anel de gelo continuam no EntityView (_make_stars / _make_frost_ring).

const ROOT_COUNT := 7
const ROOT_H := 0.65          # m de altura de cada raiz (× escala do boneco; 0,55 sumia na câmera de 24 m)

## Raízes em volta dos pés de quem tem raio `radius`. Nó pronto (o chamador põe na árvore e liga `visible`).
static func roots(radius: float, scale: float) -> Node3D:
	var row: Array = BuffLooks.cc_look("root")
	var col: Color = row[1]
	var n := Node3D.new()
	n.name = "CcRoots"
	var r := maxf(0.4, radius + 0.1)
	var bark := Materials.toon(col)
	var tip := Materials.toon(col.lerp(Color(0.45, 0.7, 0.25), 0.6))
	for i in ROOT_COUNT:
		var a := TAU * (float(i) + 0.35 * float(i % 2)) / float(ROOT_COUNT)
		var arm := Node3D.new()
		arm.position = Vector3(cos(a) * r, 0.0, sin(a) * r)
		arm.rotation.y = -a
		n.add_child(arm)
		var h := ROOT_H * scale * (0.75 + 0.25 * float((i * 7) % 3))
		var parts := [[0.09, 0.065, h * 0.55, 0.0, bark], [0.065, 0.0, h * 0.55, h * 0.5, tip]]
		for k in parts.size():
			var pr: Array = parts[k]
			var seg := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.bottom_radius = float(pr[0]) * scale
			cm.top_radius = float(pr[1]) * scale
			cm.height = float(pr[2])
			cm.radial_segments = 5
			cm.rings = 1
			seg.mesh = cm
			seg.material_override = pr[4]
			seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# curva para dentro: a ponta aponta para o boneco
			seg.rotation.z = deg_to_rad(18.0 + 22.0 * k)
			seg.position = Vector3(-sin(deg_to_rad(18.0)) * float(pr[3]) * 0.6, float(pr[3]) + float(pr[2]) * 0.5, 0.0)
			arm.add_child(seg)
	var soil := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = r + 0.2
	dm.bottom_radius = r + 0.2
	dm.height = 0.01
	dm.radial_segments = 18
	soil.mesh = dm
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(col.darkened(0.3), 0.55)
	soil.material_override = sm
	soil.position.y = 0.03
	soil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(soil)
	return n

## Rastro de lentidão nos pés: partículas no espaço do mundo (ficam para trás quando o boneco anda).
static func drag(radius: float, scale: float) -> CPUParticles3D:
	var row: Array = BuffLooks.cc_look("slow")
	var col: Color = row[1]
	var p := CPUParticles3D.new()
	p.name = "CcDrag"
	p.amount = 14
	p.lifetime = 0.9
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = maxf(0.3, radius) * 0.8
	p.emission_ring_inner_radius = 0.0
	p.emission_ring_height = 0.0
	p.position.y = 0.12
	p.direction = Vector3.UP
	p.spread = 25.0
	p.gravity = Vector3(0, -0.4, 0)
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.25
	p.scale_amount_min = 0.8 * scale
	p.scale_amount_max = 1.5 * scale
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = SkillFx.soft()
	var q := QuadMesh.new()
	q.size = Vector2(0.28, 0.28)
	q.material = m
	p.mesh = q
	var g := Gradient.new()
	g.set_color(0, Color(col, 0.75))
	g.set_color(1, Color(col.darkened(0.25), 0.0))
	p.color_ramp = g
	p.emitting = false
	return p
