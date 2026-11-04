class_name SkillFx
extends RefCounted
## Efeitos de skill por TEMA (SkillDef.vfx, preenchido em SkillsCatalog.vfx_theme) e com a FORMA real da hitbox:
## cone = leque no ângulo/raio da skill, chão = círculo do raio, linha = faixa com a largura/alcance, giro = 360°.
## Só apresentação: tudo vira nó filho de `root` (FxManager) e se apaga sozinho.

## [cor principal, cor de destaque]
const PALETTE := {
	"fire": [Color(1.0, 0.45, 0.12), Color(1.0, 0.85, 0.3)],
	"ice": [Color(0.55, 0.82, 1.0), Color(0.95, 1.0, 1.0)],
	"lightning": [Color(0.55, 0.7, 1.0), Color(1.0, 1.0, 0.7)],
	"holy": [Color(1.0, 0.85, 0.4), Color(1.0, 1.0, 0.85)],
	"lunar": [Color(0.7, 0.6, 1.0), Color(0.95, 0.95, 1.0)],
	"shadow": [Color(0.45, 0.22, 0.7), Color(0.12, 0.06, 0.18)],
	"poison": [Color(0.45, 0.9, 0.25), Color(0.2, 0.45, 0.1)],
	"bone": [Color(0.95, 0.92, 0.82), Color(0.6, 0.85, 0.75)],
	"nature": [Color(0.45, 0.85, 0.3), Color(0.95, 0.85, 0.45)],
	"earth": [Color(0.62, 0.46, 0.3), Color(0.85, 0.75, 0.6)],
	"blood": [Color(0.9, 0.12, 0.12), Color(1.0, 0.45, 0.35)],
	"wind": [Color(0.75, 1.0, 0.92), Color(1.0, 1.0, 1.0)],
	"heal": [Color(0.45, 1.0, 0.55), Color(1.0, 1.0, 0.7)],
	"summon": [Color(0.45, 0.95, 0.75), Color(0.2, 0.35, 0.3)],
	"physical": [Color(0.92, 0.94, 1.0), Color(1.0, 0.95, 0.8)],
}
## partículas por tema: gravidade (y), velocidade, vida, tamanho, malha, se brilha (aditivo) e espalhamento
const PARTS := {
	"fire": {"g": 2.5, "v": [1.5, 4.0], "life": 0.7, "size": 0.16, "mesh": "quad", "add": true, "spread": 70},
	"ice": {"g": -9.0, "v": [2.0, 5.0], "life": 0.6, "size": 0.14, "mesh": "box", "add": false, "spread": 80},
	"lightning": {"g": 0.0, "v": [4.0, 9.0], "life": 0.25, "size": 0.08, "mesh": "quad", "add": true, "spread": 180},
	"holy": {"g": 1.5, "v": [0.5, 2.0], "life": 0.9, "size": 0.12, "mesh": "quad", "add": true, "spread": 40},
	"lunar": {"g": -0.5, "v": [0.5, 2.0], "life": 0.9, "size": 0.12, "mesh": "quad", "add": true, "spread": 60},
	"shadow": {"g": 0.6, "v": [0.6, 1.8], "life": 0.9, "size": 0.38, "mesh": "quad", "add": false, "spread": 90},
	"poison": {"g": 0.8, "v": [0.4, 1.5], "life": 1.1, "size": 0.2, "mesh": "sphere", "add": false, "spread": 90},
	"bone": {"g": -9.0, "v": [2.0, 4.5], "life": 0.6, "size": 0.12, "mesh": "box", "add": false, "spread": 70},
	"nature": {"g": -1.2, "v": [1.0, 2.5], "life": 1.0, "size": 0.14, "mesh": "quad", "add": false, "spread": 90},
	"earth": {"g": -12.0, "v": [3.0, 6.0], "life": 0.7, "size": 0.18, "mesh": "box", "add": false, "spread": 50},
	"blood": {"g": -10.0, "v": [2.0, 4.5], "life": 0.5, "size": 0.09, "mesh": "sphere", "add": false, "spread": 70},
	"wind": {"g": 0.0, "v": [3.0, 6.0], "life": 0.45, "size": 0.1, "mesh": "quad", "add": true, "spread": 180},
	"heal": {"g": 2.0, "v": [0.6, 1.6], "life": 0.9, "size": 0.12, "mesh": "quad", "add": true, "spread": 30},
	"summon": {"g": 1.2, "v": [0.5, 1.6], "life": 1.0, "size": 0.14, "mesh": "quad", "add": true, "spread": 50},
	"physical": {"g": -4.0, "v": [3.0, 6.0], "life": 0.25, "size": 0.07, "mesh": "quad", "add": true, "spread": 70},
}

static var _soft: Texture2D = null

## Sprite redondo e macio para partículas (sem ele os quads viram "confete" quadrado).
static func soft() -> Texture2D:
	if _soft == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.75))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_soft = t
	return _soft

static func col(theme: String, k: int = 0) -> Color:
	return PALETTE.get(theme, PALETTE["physical"])[k]

static func _mat(c: Color, add: bool = true, unshaded: bool = true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if add:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.disable_fog = true
	return m

static func _fade_free(root: Node, n: Node3D, mats: Array, duration: float, delay: float = 0.0) -> void:
	var tw := root.create_tween()
	tw.set_parallel(true)
	for m in mats:
		tw.tween_property(m, "albedo_color:a", 0.0, duration).set_delay(delay)
	tw.chain().tween_callback(n.queue_free)

# ---------------------------------------------------------------------------
## Rajada de partículas do tema em `pos`. `up` = direção base; `amount` de partículas.
static func burst(root: Node, pos: Vector3, theme: String, amount: int = 24, up: Vector3 = Vector3.UP, box: float = 0.25, scale: float = 1.0) -> void:
	var pp: Dictionary = PARTS.get(theme, PARTS["physical"])
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = pp["life"]
	p.direction = up
	p.spread = pp["spread"]
	p.initial_velocity_min = pp["v"][0] * scale
	p.initial_velocity_max = pp["v"][1] * scale
	p.gravity = Vector3(0, pp["g"], 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(box, box * 0.5, box)
	p.scale_amount_min = 0.7 * scale
	p.scale_amount_max = 1.3 * scale
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0.15))
	p.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, col(theme, 1))
	grad.set_color(1, Color(col(theme, 0), 0.0))
	p.color_ramp = grad
	var sz: float = pp["size"]
	match pp["mesh"]:
		"box":
			var bm := BoxMesh.new()
			bm.size = Vector3(sz, sz * 1.6, sz)
			p.mesh = bm
		"sphere":
			var sm := SphereMesh.new()
			sm.radius = sz * 0.5
			sm.height = sz
			sm.radial_segments = 6
			sm.rings = 3
			p.mesh = sm
		_:
			var qm := QuadMesh.new()
			qm.size = Vector2(sz, sz)
			p.mesh = qm
	var m := _mat(Color.WHITE, pp["add"], true)
	if pp["mesh"] == "quad":
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.albedo_texture = soft()
	p.material_override = m
	p.position = pos
	root.add_child(p)
	p.emitting = true
	root.get_tree().create_timer(p.lifetime + 0.2).timeout.connect(p.queue_free)

## Partículas convergindo pra um ponto (preparação de magia).
static func gather(root: Node, pos: Vector3, theme: String, duration: float) -> void:
	var p := CPUParticles3D.new()
	p.amount = 20
	p.lifetime = maxf(0.25, duration)
	p.one_shot = true
	p.explosiveness = 0.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.9
	p.radial_accel_min = -9.0
	p.radial_accel_max = -6.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.2
	var qm := QuadMesh.new()
	qm.size = Vector2(0.1, 0.1)
	p.mesh = qm
	var grad := Gradient.new()
	grad.set_color(0, Color(col(theme, 0), 0.0))
	grad.set_color(1, col(theme, 1))
	p.color_ramp = grad
	var m := _mat(Color.WHITE)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = soft()
	p.material_override = m
	p.position = pos
	root.add_child(p)
	p.emitting = true
	root.get_tree().create_timer(p.lifetime + 0.2).timeout.connect(p.queue_free)

## Leque/anel plano na altura do golpe: raio e ângulo REAIS da skill. Abre do centro e some.
static func sector(root: Node, origin: Vector3, dir: Vector3, radius: float, angle_deg: float, theme: String, duration: float = 0.3, y: float = 0.7) -> void:
	var mesh := ImmediateMesh.new()
	var segs := maxi(8, int(angle_deg / 8.0))
	var a0 := -deg_to_rad(angle_deg) * 0.5
	var c0 := col(theme, 0)
	var c1 := col(theme, 1)
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(segs):
		var ta := a0 + deg_to_rad(angle_deg) * float(i) / segs
		var tb := a0 + deg_to_rad(angle_deg) * float(i + 1) / segs
		var inner := 0.35
		var pa_in := Vector3(sin(ta), 0, cos(ta)) * radius * inner
		var pb_in := Vector3(sin(tb), 0, cos(tb)) * radius * inner
		var pa := Vector3(sin(ta), 0, cos(ta)) * radius
		var pb := Vector3(sin(tb), 0, cos(tb)) * radius
		# borda de fora forte (o "fio" do golpe), miolo transparente
		for v in [[pa_in, Color(c0, 0.0)], [pa, Color(c1, 0.85)], [pb, Color(c1, 0.85)], [pa_in, Color(c0, 0.0)], [pb, Color(c1, 0.85)], [pb_in, Color(c0, 0.0)]]:
			mesh.surface_set_color(v[1])
			mesh.surface_add_vertex(v[0])
	mesh.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := _mat(Color.WHITE)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = origin + Vector3(0, y, 0)
	mi.rotation.y = atan2(dir.x, dir.z)
	mi.scale = Vector3.ONE * 0.55
	root.add_child(mi)
	var tw := root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE, duration * 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, duration).set_delay(duration * 0.25)
	tw.chain().tween_callback(mi.queue_free)
	# área real no chão (bem fraca) — o jogador lê o alcance
	decal_sector(root, origin, dir, radius, angle_deg, theme, duration * 1.4)

## Leque/círculo no chão do tamanho exato da hitbox.
static func decal_sector(root: Node, origin: Vector3, dir: Vector3, radius: float, angle_deg: float, theme: String, duration: float) -> void:
	var mesh := ImmediateMesh.new()
	var segs := maxi(12, int(angle_deg / 6.0))
	var a0 := -deg_to_rad(angle_deg) * 0.5
	var c0 := col(theme, 0)
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(segs):
		var ta := a0 + deg_to_rad(angle_deg) * float(i) / segs
		var tb := a0 + deg_to_rad(angle_deg) * float(i + 1) / segs
		for v in [[Vector3.ZERO, Color(c0, 0.03)], [Vector3(sin(ta), 0, cos(ta)) * radius, Color(c0, 0.2)], [Vector3(sin(tb), 0, cos(tb)) * radius, Color(c0, 0.2)]]:
			mesh.surface_set_color(v[1])
			mesh.surface_add_vertex(v[0])
	mesh.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := _mat(Color.WHITE, false)        # mistura (não soma): a área fica legível sem estourar o chão claro
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = origin + Vector3(0, 0.06, 0)
	mi.rotation.y = atan2(dir.x, dir.z)
	root.add_child(mi)
	_fade_free(root, mi, [m], duration)

## Círculo no chão (raio exato) + aro que expande até o raio.
static func circle(root: Node, pos: Vector3, radius: float, theme: String, duration: float = 0.5) -> void:
	decal_sector(root, pos, Vector3.FORWARD, radius, 360.0, theme, duration)
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.95
	tm.outer_radius = 1.0
	tm.rings = 40
	tm.ring_segments = 4
	mi.mesh = tm
	var m := _mat(col(theme, 1))
	m.albedo_color = col(theme, 1)
	mi.material_override = m
	mi.position = pos + Vector3(0, 0.1, 0)
	mi.scale = Vector3(radius * 0.3, 0.3, radius * 0.3)
	root.add_child(mi)
	var tw := root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 0.4, radius), duration * 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, duration).set_delay(duration * 0.3)
	tw.chain().tween_callback(mi.queue_free)

## Coluna de luz/energia (sagrado, invocação, cura forte).
static func column(root: Node, pos: Vector3, radius: float, theme: String, duration: float = 0.6) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius * 0.6
	cm.bottom_radius = radius
	cm.height = 3.6
	cm.radial_segments = 14
	cm.cap_top = false
	cm.cap_bottom = false
	mi.mesh = cm
	var m := _mat(col(theme, 1))
	m.albedo_color = Color(col(theme, 1), 0.38)
	mi.material_override = m
	mi.position = pos + Vector3(0, 1.8, 0)
	mi.scale = Vector3(0.2, 1.0, 0.2)
	root.add_child(mi)
	var tw := root.create_tween()
	tw.tween_property(mi, "scale", Vector3(1, 1, 1), duration * 0.2).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, duration * 0.8).set_delay(duration * 0.2)
	tw.tween_callback(mi.queue_free)

## Raio caindo do céu (zigue-zague), pisca duas vezes.
static func bolt(root: Node, pos: Vector3, theme: String = "lightning") -> void:
	var mesh := ImmediateMesh.new()
	var top := pos + Vector3(randf_range(-1.0, 1.0), 9.0, randf_range(-1.0, 1.0))
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var steps := 10
	for i in range(steps + 1):
		var t := float(i) / steps
		var q := top.lerp(pos + Vector3(0, 0.05, 0), t)
		if i > 0 and i < steps:
			q += Vector3(randf_range(-0.45, 0.45), 0, randf_range(-0.45, 0.45))
		var w := 0.16 * (1.0 - t * 0.5)
		mesh.surface_set_color(col(theme, 1))
		mesh.surface_add_vertex(q + Vector3(-w, 0, 0))
		mesh.surface_set_color(col(theme, 0))
		mesh.surface_add_vertex(q + Vector3(w, 0, 0))
	mesh.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := _mat(Color.WHITE)
	mi.material_override = m
	root.add_child(mi)
	var tw := root.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.2, 0.05)
	tw.tween_property(m, "albedo_color:a", 1.0, 0.04)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.2)
	tw.tween_callback(mi.queue_free)
	flash(root, pos + Vector3(0, 0.6, 0), theme, 2.5)

## Raio horizontal em zigue-zague de `a` até `b` (corrente elétrica, golpe de raio no alvo).
static func arc_bolt(root: Node, a: Vector3, b: Vector3, theme: String = "lightning") -> void:
	var mesh := ImmediateMesh.new()
	var steps := maxi(4, int(a.distance_to(b) / 0.6))
	var side := (b - a).cross(Vector3.UP).normalized()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in range(steps + 1):
		var t := float(i) / steps
		var q := a.lerp(b, t)
		if i > 0 and i < steps:
			q += side * randf_range(-0.35, 0.35) + Vector3(0, randf_range(-0.25, 0.25), 0)
		mesh.surface_set_color(col(theme, 1))
		mesh.surface_add_vertex(q + Vector3(0, 0.09, 0))
		mesh.surface_set_color(col(theme, 0))
		mesh.surface_add_vertex(q - Vector3(0, 0.09, 0))
	mesh.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := _mat(Color.WHITE)
	mi.material_override = m
	root.add_child(mi)
	var tw := root.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.3, 0.05)
	tw.tween_property(m, "albedo_color:a", 1.0, 0.04)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.22)
	tw.tween_callback(mi.queue_free)

## Luz rápida (explosão, raio, impacto mágico).
static func flash(root: Node, pos: Vector3, theme: String, energy: float = 3.0, rng: float = 5.0) -> void:
	var l := OmniLight3D.new()
	l.light_color = col(theme, 1)
	l.light_energy = energy
	l.omni_range = rng
	l.position = pos
	root.add_child(l)
	var tw := root.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.25)
	tw.tween_callback(l.queue_free)

## Faixa no chão que corre do caster até o alcance, na largura real (onda/feixe sem projétil).
static func wave(root: Node, origin: Vector3, dir: Vector3, length: float, width: float, theme: String, duration: float = 0.35) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, 0.5, 1.2)
	mi.mesh = bm
	var m := _mat(col(theme, 1))
	m.albedo_color = Color(col(theme, 1), 0.75)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = origin + dir * 0.6 + Vector3(0, 0.45, 0)
	mi.rotation.y = atan2(dir.x, dir.z)
	root.add_child(mi)
	var tw := root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "position", origin + dir * length + Vector3(0, 0.45, 0), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, duration).set_delay(duration * 0.5)
	tw.chain().tween_callback(mi.queue_free)
	decal_line(root, origin, dir, length, width, theme, duration * 1.3)
	for k in range(3):
		burst(root, origin + dir * length * (0.35 + 0.3 * k), theme, 8, Vector3.UP, width * 0.4)

static func decal_line(root: Node, origin: Vector3, dir: Vector3, length: float, width: float, theme: String, duration: float) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(width, length)
	mi.mesh = pm
	var m := _mat(col(theme, 0))
	m.albedo_color = Color(col(theme, 0), 0.3)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = origin + dir * length * 0.5 + Vector3(0, 0.06, 0)
	mi.rotation.y = atan2(dir.x, dir.z)
	root.add_child(mi)
	_fade_free(root, mi, [m], duration)

## Rastro de investida (dash de skill): faixa esticada ao longo do caminho.
static func streak(root: Node, origin: Vector3, dir: Vector3, length: float, theme: String) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.7, 1.2, length)
	mi.mesh = bm
	var m := _mat(col(theme, 0))
	m.albedo_color = Color(col(theme, 0), 0.45)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = origin + dir * length * 0.5 + Vector3(0, 0.75, 0)
	mi.rotation.y = atan2(dir.x, dir.z)
	root.add_child(mi)
	var tw := root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(0.15, 0.5, 1.0), 0.35)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.35)
	tw.chain().tween_callback(mi.queue_free)

## Corte em X no alvo (golpes físicos em um alvo).
static func slash_x(root: Node, pos: Vector3, theme: String, size: float = 1.4) -> void:
	for a in [PI * 0.25, -PI * 0.25]:
		var mi := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(size, 0.12)
		mi.mesh = qm
		var m := _mat(col(theme, 1))
		m.albedo_color = col(theme, 1)
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mi.material_override = m
		mi.position = pos + Vector3(0, 0.9, 0)
		mi.rotation.z = a
		root.add_child(mi)
		var tw := root.create_tween()
		tw.set_parallel(true)
		tw.tween_property(mi, "scale", Vector3(1.3, 1.0, 1.0), 0.18)
		tw.tween_property(m, "albedo_color:a", 0.0, 0.25).set_delay(0.06)
		tw.chain().tween_callback(mi.queue_free)

## Explosão: bola do tema que cresce e some (mistura normal: fica laranja em qualquer chão) + faíscas + luz.
static func explosion(root: Node, pos: Vector3, radius: float, theme: String) -> void:
	for layer in [[col(theme, 0), 1.0, false], [col(theme, 1), 0.6, true]]:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 16
		sm.rings = 8
		mi.mesh = sm
		var m := _mat(Color.WHITE, layer[2])
		m.albedo_color = Color(layer[0], 0.85)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = pos + Vector3(0, 0.35, 0)
		mi.scale = Vector3.ONE * 0.2
		root.add_child(mi)
		var r: float = radius * 0.62 * float(layer[1])
		var tw := root.create_tween()
		tw.set_parallel(true)
		tw.tween_property(mi, "scale", Vector3(r, r * 0.7, r), 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(m, "albedo_color:a", 0.0, 0.35).set_delay(0.12)
		tw.chain().tween_callback(mi.queue_free)
	burst(root, pos + Vector3(0, 0.4, 0), theme, 40, Vector3.UP, radius * 0.3, 1.5)
	flash(root, pos + Vector3(0, 1.0, 0), theme, 3.0, radius * 2.5)

## Meteoro: bola caindo do céu até o alvo, depois explosão.
static func meteor(root: Node, pos: Vector3, radius: float, theme: String, fall: float = 0.45) -> void:
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.9
	sm.height = 1.8
	ball.mesh = sm
	ball.material_override = Materials.glow(col(theme, 0), 3.0)
	ball.position = pos + Vector3(-2.0, 6.5, 1.0)        # cai na frente da câmera (lado de baixo da tela), não sai do quadro
	root.add_child(ball)
	var tail := CPUParticles3D.new()      # cauda de fogo na queda
	tail.amount = 40
	tail.lifetime = 0.4
	tail.local_coords = false
	tail.gravity = Vector3(0, 3, 0)
	tail.spread = 30.0
	tail.initial_velocity_min = 0.5
	tail.initial_velocity_max = 1.5
	var tq := QuadMesh.new()
	tq.size = Vector2(0.6, 0.6)
	tail.mesh = tq
	var tg := Gradient.new()
	tg.set_color(0, col(theme, 1))
	tg.set_color(1, Color(col(theme, 0), 0.0))
	tail.color_ramp = tg
	var tmm := _mat(Color.WHITE)
	tmm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	tmm.albedo_texture = soft()
	tail.material_override = tmm
	ball.add_child(tail)
	var tw := root.create_tween()
	tw.tween_property(ball, "position", pos + Vector3(0, 0.4, 0), fall).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func():
		ball.queue_free()
		explosion(root, pos, radius, theme)
		circle(root, pos, radius, theme, 0.7)
		flash(root, pos + Vector3(0, 1.0, 0), theme, 3.0, radius * 2.5))

## Aura no pé de quem recebe um buff (segue a view; dura o buff).
static func aura(root: Node, follow: Node3D, theme: String, duration: float, radius: float = 0.75) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.82
	tm.outer_radius = 1.0
	tm.rings = 28
	tm.ring_segments = 4
	mi.mesh = tm
	var m := _mat(col(theme, 0))
	m.albedo_color = Color(col(theme, 0), 0.7)
	mi.material_override = m
	mi.scale = Vector3(radius, 0.25, radius)
	mi.position = Vector3(0, 0.08, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	follow.add_child(mi)
	var p := CPUParticles3D.new()
	p.amount = 10
	p.lifetime = 1.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = radius
	p.emission_ring_inner_radius = radius * 0.8
	p.emission_ring_height = 0.05
	p.direction = Vector3.UP
	p.spread = 5.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.2
	var qm := QuadMesh.new()
	qm.size = Vector2(0.08, 0.08)
	p.mesh = qm
	var grad := Gradient.new()
	grad.set_color(0, col(theme, 1))
	grad.set_color(1, Color(col(theme, 0), 0.0))
	p.color_ramp = grad
	var pm := _mat(Color.WHITE)
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	pm.albedo_texture = soft()
	p.material_override = pm
	mi.add_child(p)
	var tw := root.create_tween()
	tw.tween_property(mi, "rotation:y", TAU, minf(duration, 30.0)).set_trans(Tween.TRANS_LINEAR)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.5).set_delay(maxf(0.1, duration - 0.5))
	tw.tween_callback(mi.queue_free)
