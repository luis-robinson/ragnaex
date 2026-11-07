class_name BuffAura
extends Node3D
## Buffs ativos no boneco (um por EntityView, criado quando o primeiro buff chega). Lê SimEntity.buffs e mostra,
## pelo BuffLooks de cada um: borda/padrão na pele (uniform buff_rim do toon: sem malha nem draw call a mais),
## casca (bolha de escudo / cristal de gelo / chama de fúria), auréola, e até 2 emissores de partículas. Tudo reaproveitado:
## nós criados uma vez e ligados/desligados; materiais e malhas compartilhados entre todos os bonecos
## (cor/força por instância). Entrada = "estouro" curto; saída = esmaece.
## Buffs de talento permanente (ct) e de aura recebida (aura_from) aparecem fracos: só a borda.

const SCAN_EVERY := 0.1
static var enabled := true  # --no_buff_fx (medir o custo)
const STRONG := 1.0        # força da borda de um buff lançado
const SUBTLE := 0.32        # permanente / aura do grupo
const FADE_TAIL := 0.6      # s finais em que o buff esmaece

var view: EntityView
var _poll := 0.0
var _pop := 0.0
var _seen: Dictionary = {}
var _seen_b: Dictionary = {}

# alvo (scan) e mostrado (suavizado por quadro)
var _rim_col := Color.WHITE
var _rim_style := 0
var _rim_t := 0.0
var _rim := 0.0
var _rim_sent := Color(0, 0, 0, 0)
var _style_sent := -1
var _shell_t := 0.0
var _shell := 0.0
var _shell_col := Color.WHITE
var _shell_facets := 0.0
var _shell_sent := Color(-1, -1, -1, -1)
var _halo_t := 0.0
var _halo := 0.0
var _halo_col := Color.WHITE
var active := false          # algo à mostra (o EntityView para de chamar quando some tudo)

var _shell_mi: MeshInstance3D = null
var _halo_mi: MeshInstance3D = null
var _emit: Array = [null, null]
var _emit_key: Array = ["", ""]
var _emit_off: Array = [0.0, 0.0]

static var _shell_mat: ShaderMaterial = null
static var _glow_mat: ShaderMaterial = null
static var _shell_mesh: Mesh = null
static var _crystal_mesh: Mesh = null
static var _halo_mesh: Mesh = null
static var _pmats: Dictionary = {}      # "preset:tema" -> ParticleProcessMaterial
static var _pmeshes: Dictionary = {}    # "malha:add" -> Mesh com material

## Partículas por preset: onde nascem (centro, forma, raio), para onde vão, quanto vivem e o tamanho.
## Tamanho = multiplicador da malha de 0,1 m. Unidades de boneco humano (1.9 m até o alto da cabeça); a BuffAura escala para monstros grandes.
const PRESETS := {
	"snow": {"at": Vector3(0, 1.0, 0), "r": 0.6, "dir": Vector3.DOWN, "v": [0.05, 0.25], "spread": 180.0, "g": -0.5, "life": 1.6, "size": [0.8, 1.6], "mesh": "soft", "add": true, "ratio": 0.75, "ramp": "accent"},
	"dust": {"at": Vector3(0, 0.7, 0), "r": 0.5, "dir": Vector3.UP, "v": [0.3, 0.8], "spread": 60.0, "g": -2.0, "life": 0.9, "size": [0.4, 0.7], "mesh": "box", "add": false, "ratio": 0.6, "ramp": "color"},
	"bone": {"at": Vector3(0, 0.8, 0), "r": 0.5, "dir": Vector3.UP, "v": [0.2, 0.6], "spread": 80.0, "g": -1.5, "life": 1.0, "size": [0.4, 0.7], "mesh": "box", "add": false, "ratio": 0.6, "ramp": "color"},
	"leaves": {"at": Vector3(0, 1.1, 0), "r": 0.6, "dir": Vector3.DOWN, "v": [0.1, 0.3], "spread": 180.0, "g": -0.6, "life": 1.6, "size": [1.12, 1.92], "mesh": "soft", "add": false, "ratio": 0.6, "ramp": "color", "spin": true},
	"motes": {"at": Vector3(0, 0.2, 0), "ring": 0.5, "dir": Vector3.UP, "v": [0.5, 1.0], "spread": 8.0, "g": 0.3, "life": 1.5, "size": [0.96, 1.6], "mesh": "soft", "add": true, "ratio": 0.7, "ramp": "accent"},
	"embers": {"at": Vector3(0, 0.85, 0.1), "r": 0.42, "dir": Vector3.UP, "v": [0.7, 1.5], "spread": 25.0, "g": 1.2, "life": 0.6, "size": [1.0, 1.8], "mesh": "soft", "add": true, "ratio": 1.0, "ramp": "fire"},
	"sparks": {"at": Vector3(0, 0.9, 0.1), "r": 0.45, "dir": Vector3.UP, "v": [1.2, 2.6], "spread": 180.0, "g": 0.0, "life": 0.22, "size": [0.64, 1.12], "mesh": "soft", "add": true, "ratio": 0.9, "ramp": "accent"},
	"streaks": {"at": Vector3(0, 0.06, -0.15), "box": Vector3(0.35, 0.02, 0.2), "dir": Vector3.BACK, "v": [2.0, 3.5], "spread": 4.0, "g": 0.0, "life": 0.32, "size": [0.8, 1.2], "mesh": "streak", "add": true, "ratio": 1.0, "ramp": "color"},
	"smoke": {"at": Vector3(0, 0.1, 0), "ring": 0.45, "dir": Vector3.UP, "v": [0.2, 0.5], "spread": 20.0, "g": 0.2, "life": 1.4, "size": [4, 7.2], "mesh": "soft", "add": false, "ratio": 0.8, "ramp": "smoke"},
	"drip": {"at": Vector3(-0.34, 0.8, 0.22), "r": 0.08, "dir": Vector3.DOWN, "v": [0.0, 0.2], "spread": 20.0, "g": -5.0, "life": 0.45, "size": [0.6, 0.9], "mesh": "sphere", "add": false, "ratio": 1.0, "ramp": "color"},
	"shadow": {"at": Vector3(0, 0.7, 0), "r": 0.45, "dir": Vector3.UP, "v": [0.3, 0.7], "spread": 30.0, "g": 0.4, "life": 1.2, "size": [3.2, 5.6], "mesh": "soft", "add": false, "ratio": 0.8, "ramp": "smoke"},
}

func setup(v: EntityView) -> void:
	view = v
	name = "BuffAura"

## Chamado pelo EntityView a cada quadro enquanto há buff ou algo à mostra.
func update(delta: float) -> void:
	_poll -= delta
	if _poll <= 0.0:
		_poll = SCAN_EVERY if view._is_player else SCAN_EVERY * 2.5     # os outros: 4x/s basta (o estouro vem do FxManager)
		_scan()
	_blend(delta)

func _scan() -> void:
	var e := view.entity
	var hide := not e.is_alive() or e.stealth_left > 0.0 or view._ghost_on
	_seen_b.clear()
	var rim_t := 0.0
	var rim_col := _rim_col
	var rim_style := _rim_style
	var shell_t := 0.0
	var shield_t := 0.0
	var shield_col := _shell_col
	var flame_t := 0.0
	var flame_col := _shell_col
	var crystal_t := 0.0
	var crystal_col := _shell_col
	var strong := false
	var halo_t := 0.0
	var p1 := ""
	var p1_th := ""
	var p2 := ""
	var p2_th := ""
	var popped := false
	var moving := e.state == SimEntity.State.MOVING or e.state == SimEntity.State.DASHING
	if not hide:
		for b in e.buffs:
			var id: String = b.get("id", "")
			var lk: Dictionary = BuffLooks.look(id, e)
			if lk.is_empty():
				continue
			var fam: String = lk["family"]
			if fam == "form":
				continue
			var rem: float = b.get("remaining", 0.0)
			if rem <= 0.0:
				continue
			var fade := 1.0 if rem == INF else clampf(rem / FADE_TAIL, 0.0, 1.0)
			var subtle: bool = b.get("ct", false) or b.has("aura_from")
			_seen_b[id] = true
			if not subtle and not _seen.has(id):
				popped = true
			var strength := (SUBTLE if subtle else STRONG) * fade
			if fam == "shield":
				var sr := clampf(e.shield_hp / maxf(1.0, e.stats.max_hp * 0.2), 0.0, 1.0)
				if sr > 0.0 and (0.35 + 0.65 * sr) * fade > shield_t:
					shield_t = (0.35 + 0.65 * sr) * fade
					shield_col = lk["color"]
				continue                  # o escudo é a bolha; a borda fica para o buff do lado
			if not subtle:
				strong = true
				rim_t = strength          # o mais recente lançado manda na borda
				rim_col = lk["color"]
				rim_style = lk["rim_style"]
			elif not strong and strength > rim_t:
				rim_t = strength
				rim_col = lk["color"]
				rim_style = lk["rim_style"]
			if subtle:
				continue
			if int(lk["shell"]) == 2:
				crystal_t = maxf(crystal_t, 0.9 * fade)
				crystal_col = lk["color"]
			elif int(lk["shell"]) == 3:
				flame_t = 1.0 * fade        # o mais recente manda na cor
				flame_col = lk["color"]
			if lk["halo"]:
				halo_t = maxf(halo_t, fade)
				_halo_col = lk["accent"] if lk["theme"] == "holy" else lk["color"]
			var parts: String = lk["parts"]
			if parts != "" and parts != p1:
				p2 = p1
				p2_th = p1_th
				p1 = parts
				p1_th = lk["theme"]
	if crystal_t > 0.0:              # gelo: a casca de cristal também conta o escudo
		shell_t = maxf(crystal_t, shield_t)
		_shell_col = crystal_col
		_shell_facets = 1.0
	elif shield_t > 0.0:
		shell_t = shield_t
		_shell_col = shield_col
		_shell_facets = 0.0
	elif flame_t > 0.0:
		shell_t = flame_t
		_shell_col = flame_col
		_shell_facets = 2.0
	# troca o conjunto de ids vistos (sem alocar: dois dicionários que se alternam)
	var tmp := _seen
	_seen = _seen_b
	_seen_b = tmp
	if popped:
		_pop = 1.0
	_rim_t = rim_t
	_rim_col = rim_col
	_rim_style = rim_style
	_shell_t = shell_t
	_halo_t = halo_t
	var f := maxf(0.4, view._status_head() / 1.9)
	scale = Vector3.ONE * f
	position.y = view.model_root.position.y + (EntityView.SADDLE_Y if e.mounted else 0.0)
	rotation.y = view.model_root.rotation.y
	_set_emitter(0, p1, p1_th, moving)
	_set_emitter(1, p2, p2_th, moving)
	active = rim_t > 0.0 or shell_t > 0.0 or halo_t > 0.0 or _rim > 0.005 or _shell > 0.005 or _halo > 0.005 or p1 != ""

func _blend(delta: float) -> void:
	if _emit_key[0] != "" or _emit_key[1] != "":
		rotation.y = view.model_root.rotation.y     # rastros/gotas acompanham a frente do boneco
	# parado no alvo (o caso comum: buff longo, permanente): nada a mandar para a GPU neste quadro
	if _pop == 0.0 and _shell_col == _shell_sent and absf(_rim - _rim_t) < 0.003 and absf(_shell - _shell_t) < 0.003 and absf(_halo - _halo_t) < 0.003 			and _rim_style == _style_sent and not _emitter_fading():
		return
	_pop = maxf(0.0, _pop - delta / 0.4)
	var k := minf(1.0, delta * 7.0)
	_rim = lerpf(_rim, _rim_t, k)
	_shell = lerpf(_shell, _shell_t, k)
	_halo = lerpf(_halo, _halo_t, k)
	if absf(_rim - _rim_t) < 0.003:
		_rim = _rim_t
	if absf(_shell - _shell_t) < 0.003:
		_shell = _shell_t
	if absf(_halo - _halo_t) < 0.003:
		_halo = _halo_t
	_shell_sent = _shell_col
	# borda na pele (só manda o uniform quando muda)
	var ra := _rim + _pop * 0.7 * (1.0 if _rim_t > 0.0 else 0.0)
	if ra < 0.004:
		ra = 0.0
	var rc := Color(_rim_col.r, _rim_col.g, _rim_col.b, minf(1.0, ra))
	if absf(rc.a - _rim_sent.a) > 0.004 or rc.r != _rim_sent.r or rc.g != _rim_sent.g or rc.b != _rim_sent.b or _rim_style != _style_sent:
		_rim_sent = rc
		_style_sent = _rim_style
		view.set_buff_rim(rc, _rim_style)
	# casca
	if _shell > 0.004 or _shell_t > 0.0:
		if _shell_mi == null:
			_shell_mi = _make_shell()
		_shell_mi.visible = true
		_shell_mi.mesh = _crystal_mesh if is_equal_approx(_shell_facets, 1.0) else _shell_mesh
		_shell_mi.set_instance_shader_parameter("shell_amount", _shell + _pop * 0.5)
		_shell_mi.set_instance_shader_parameter("shell_color", _shell_col)
		_shell_mi.set_instance_shader_parameter("facets", _shell_facets)
		var s := 1.0 + 0.25 * _pop
		_shell_mi.scale = Vector3(0.7, 0.98, 0.7) * s
	elif _shell_mi and _shell_mi.visible:
		_shell_mi.visible = false
	# auréola
	if _halo > 0.004 or _halo_t > 0.0:
		if _halo_mi == null:
			_halo_mi = _make_halo()
		_halo_mi.visible = true
		_halo_mi.set_instance_shader_parameter("glow_amount", _halo * 0.9 + _pop * 0.5)
		_halo_mi.set_instance_shader_parameter("glow_color", _halo_col)
		_halo_mi.scale = Vector3.ONE * (1.0 + 0.4 * _pop)
	elif _halo_mi and _halo_mi.visible:
		_halo_mi.visible = false
	# emissores desligados somem de vez depois que as últimas partículas morrem
	for i in 2:
		var em: GPUParticles3D = _emit[i]
		if em and not em.emitting and em.visible:
			_emit_off[i] = float(_emit_off[i]) + delta
			if _emit_off[i] > em.lifetime + 0.2:
				em.visible = false

func _emitter_fading() -> bool:
	for i in 2:
		var em: GPUParticles3D = _emit[i]
		if em and not em.emitting and em.visible:
			return true
	return false

func _set_emitter(i: int, preset: String, theme: String, moving: bool) -> void:
	var key := "" if preset == "" else preset + ":" + theme
	var em: GPUParticles3D = _emit[i]
	if key == "":
		if em and em.emitting:
			em.emitting = false
			_emit_off[i] = 0.0
		_emit_key[i] = ""
		return
	if em == null:
		em = GPUParticles3D.new()
		em.amount = 24
		em.local_coords = true
		em.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		em.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 4, 4))
		add_child(em)
		_emit[i] = em
	var pr: Dictionary = PRESETS[preset]
	if _emit_key[i] != key:
		_emit_key[i] = key
		em.process_material = _pmat(preset, theme)
		em.draw_pass_1 = _pmesh(str(pr["mesh"]), bool(pr["add"]))
		em.lifetime = float(pr["life"])
		em.position = Vector3.ZERO
		em.visible = true
		em.emitting = true
		em.restart()
	elif not em.emitting:
		em.visible = true
		em.emitting = true
	var ratio := float(pr["ratio"])
	if preset == "streaks" and not moving:
		ratio *= 0.3                      # parado: só um fiapo de vento
	if not is_equal_approx(em.amount_ratio, ratio):
		em.amount_ratio = ratio

# --- recursos compartilhados ------------------------------------------------------------------------------------
func _make_shell() -> MeshInstance3D:
	if _shell_mat == null:
		_shell_mat = ShaderMaterial.new()
		_shell_mat.shader = preload("res://shaders/buff_shell.gdshader")
		var sm := SphereMesh.new()
		sm.radius = 1.0; sm.height = 2.0; sm.radial_segments = 20; sm.rings = 10
		_shell_mesh = sm
		var cm := SphereMesh.new()        # poucas faces: lê como cristal lapidado
		cm.radius = 1.0; cm.height = 2.0; cm.radial_segments = 7; cm.rings = 4
		_crystal_mesh = cm
	var mi := MeshInstance3D.new()
	mi.mesh = _shell_mesh
	mi.material_override = _shell_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = 0.95
	add_child(mi)
	return mi

func _make_halo() -> MeshInstance3D:
	if _glow_mat == null:
		_glow_mat = ShaderMaterial.new()
		_glow_mat.shader = preload("res://shaders/buff_glow.gdshader")
		var tm := TorusMesh.new()
		tm.inner_radius = 0.24; tm.outer_radius = 0.31; tm.rings = 24; tm.ring_segments = 6
		_halo_mesh = tm
	var mi := MeshInstance3D.new()
	mi.mesh = _halo_mesh
	mi.material_override = _glow_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = 2.02
	add_child(mi)
	return mi

static func _ramp(kind: String, c: Color, a: Color) -> GradientTexture1D:
	var g := Gradient.new()
	match kind:
		"accent":
			g.set_color(0, Color(a, 0.0)); g.add_point(0.2, Color(a, 1.0)); g.set_color(1, Color(c, 0.0))
		"fire":
			g.set_color(0, Color(c.lerp(a, 0.5), 0.9)); g.add_point(0.4, Color(c, 0.8)); g.set_color(1, Color(c.darkened(0.5), 0.0))
		"smoke":
			g.set_color(0, Color(c, 0.0)); g.add_point(0.25, Color(c, 0.55)); g.set_color(1, Color(c.darkened(0.3), 0.0))
		_:
			g.set_color(0, Color(c, 1.0)); g.add_point(0.7, Color(c, 0.9)); g.set_color(1, Color(c, 0.0))
	var t := GradientTexture1D.new()
	t.gradient = g
	t.width = 32
	return t

static func _pmat(preset: String, theme: String) -> ParticleProcessMaterial:
	var key := preset + ":" + theme
	if _pmats.has(key):
		return _pmats[key]
	var pr: Dictionary = PRESETS[preset]
	var c := SkillFx.col(theme, 0)
	var a := SkillFx.col(theme, 1)
	if preset == "smoke" and theme == "shadow":
		c = Color(0.62, 0.62, 0.68)               # cortina de fumaça: cinza
	if preset == "shadow":
		c = Color(0.42, 0.18, 0.62)
	var m := ParticleProcessMaterial.new()
	var at: Vector3 = pr["at"]
	m.emission_shape_offset = at
	if pr.has("ring"):
		m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		m.emission_ring_axis = Vector3.UP
		m.emission_ring_radius = float(pr["ring"])
		m.emission_ring_inner_radius = float(pr["ring"]) * 0.75
		m.emission_ring_height = 0.05
	elif pr.has("box"):
		m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		m.emission_box_extents = pr["box"]
	else:
		m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		m.emission_sphere_radius = float(pr["r"])
	m.direction = pr["dir"]
	m.spread = float(pr["spread"])
	m.initial_velocity_min = float(pr["v"][0])
	m.initial_velocity_max = float(pr["v"][1])
	m.gravity = Vector3(0, float(pr["g"]), 0)
	m.scale_min = float(pr["size"][0])
	m.scale_max = float(pr["size"][1])
	if pr.get("spin", false):
		m.angular_velocity_min = -180.0
		m.angular_velocity_max = 180.0
		m.angle_min = 0.0
		m.angle_max = 360.0
	if preset in ["smoke", "shadow"]:
		var sc := CurveTexture.new()
		var cv := Curve.new()
		cv.add_point(Vector2(0, 0.5)); cv.add_point(Vector2(1, 1.0))
		sc.curve = cv
		m.scale_curve = sc
	m.color_ramp = _ramp(str(pr["ramp"]), c, a)
	_pmats[key] = m
	return m

static func _pmesh(kind: String, add: bool) -> Mesh:
	var key := kind + (":a" if add else ":m")
	if _pmeshes.has(key):
		return _pmeshes[key]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.disable_fog = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if add:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var mesh: Mesh
	match kind:
		"box":
			var b := BoxMesh.new()
			b.size = Vector3.ONE * 0.1
			mesh = b
		"sphere":
			var s := SphereMesh.new()
			s.radius = 0.05; s.height = 0.1; s.radial_segments = 6; s.rings = 3
			mesh = s
		"streak":                      # risco deitado no chão, no sentido do movimento (lê de cima)
			var p := PlaneMesh.new()
			p.size = Vector2(0.05, 0.5)
			mat.albedo_texture = SkillFx.soft()
			mesh = p
		_:
			var q := QuadMesh.new()
			q.size = Vector2(0.1, 0.1)
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			mat.albedo_texture = SkillFx.soft()
			mesh = q
	(mesh as PrimitiveMesh).material = mat
	_pmeshes[key] = mesh
	return mesh
