class_name MenuSet
extends Node3D
## Cenário 3D da tela inicial (spec `design/ux/start-flow.md` §3 "Cenário", §9): acampamento de fogueira na beira de Aldara
## ao entardecer. Carrega `assets/models/menu_set.glb` (gerado por `tools/blender/menu_set.py`), troca os materiais pelo toon
## do jogo, monta céu/ambiente/névoa/sol com as cores de `menu_set.DUSK`, luz da fogueira que tremula, chamas que tremem,
## fagulhas e a luz da lanterna. Câmeras por tela (`CAM_title`, `CAM_list`, `CAM_create`) com transição suave.
## Sem sim, sem `main`: só apresentação. Headless: monta tudo menos partículas e não anima.
##   var set := MenuSet.new(); add_child(set); set.set_shot(&"create", false); set.place_character(kit)

const PATH := "res://assets/models/menu_set.glb"
## Interface combinada com o `start.gd` (P1): `SHOTS`, `go_to`, `current_shot`, `pedestal`, `transition_finished`.
signal transition_finished
const SHOTS = [&"title", &"list", &"create"]
const CAM_OF := {&"title": "CAM_title", &"list": "CAM_list", &"create": "CAM_create"}
## Espelho de `menu_set.DUSK` (tools/blender/menu_set.py; cores lineares, como no Blender). Há check que confere os dois.
const DUSK := {
	"sky_top": Color(0.17, 0.17, 0.4), "sky_mid": Color(0.62, 0.4, 0.58), "sky_horizon": Color(1.0, 0.66, 0.44),
	"sun_color": Color(1.0, 0.62, 0.5), "sun_energy": 2.6, "sun_dir_from": Vector3(-0.55, 0.75, 0.36),
	"ambient": Color(0.5, 0.45, 0.66),
}
## Reserva se o GLB vier sem extras (mesmos números de `menu_set.CAMS`/`LIGHTS`).
const CAM_FOV := {"CAM_title": 42.0, "CAM_list": 46.0, "CAM_create": 36.0}
const SUBJECT_YAW := 41.9
## Ajuste de enquadramento por tela, por cima da câmera do GLB (sem reexportar): `back` = m para trás no eixo da câmera,
## `down` = m para baixo (o boneco sobe no quadro), `right` = m para a direita da câmera (o boneco vai para a esquerda). Criação: pés e borda do pedestal acima da barra do nome (embaixo à
## esquerda), cabeça/cajado com folga em 16:9 e 21:9.
const SHOT_NUDGE := {&"create": {"back": 1.5, "down": 0.42, "right": 0.35}}
const LIGHT_DEFAULTS := {"LIGHT_fire": [Color(1.0, 0.56, 0.24), 3.2, 11.0], "LIGHT_lantern": [Color(1.0, 0.8, 0.5), 1.4, 6.0]}

# ajustes do visual (apresentação; não são números de jogo)
const TRANSITION := 0.6              # s da troca de câmera
const SUN_SCALE := 0.65              # energia do sol do Blender (W/m²-ish) -> DirectionalLight3D
const OMNI_SCALE := 1.0              # energia das luzes do GLB -> OmniLight3D
const AMBIENT_ENERGY := 0.2
const SKY_STRENGTH := 0.6            # = força do fundo em `menu_set.render` (0,55): o degradê do DUSK é a cor cheia
const FIRE_FLICKER := 0.15           # ±15% na luz da fogueira
const FLAME_WOBBLE := 0.14           # quanto cada língua estica/encolhe
const FOG_DENSITY := 0.0022
const EXPOSURE := 0.88
## sombra do toon mais funda e lilás que no jogo (o fim de tarde vive do contraste lado do sol / lado da sombra)
const SHADOW_STRENGTH := 0.7
const SHADOW_TINT := Color(0.56, 0.52, 0.86)
const SPARKS := 26                   # fagulhas vivas
## materiais chapados (chão, serra do fundo, telhas): sem contorno; chão também sem sombra própria
const NO_OUTLINE := ["ms_grass", "ms_dirt", "ms_far_", "ms_roof"]
## sombra projetada é por malha (o GLB junta tudo do acampamento numa malha só): só o chão e as chamas não projetam
const NO_CAST := ["MS_ground", "MS_flame"]

var camera: Camera3D
var model: Node3D
var shot: StringName = &"title"
var fire_light: OmniLight3D
var lantern_light: OmniLight3D
var sun: DirectionalLight3D
var headless := false
var _flames: Array[Node3D] = []
var _flame_base: Array[Vector3] = []
var _fire_energy := 1.0
var _subject: Node3D = null
var _pedestal: Node3D = null         # nó no pé do pedestal (gira na criação); o boneco é filho dele
var _tween: Tween = null
var _from := Transform3D.IDENTITY
var _from_fov := 42.0
var _t := 0.0

func _init() -> void:
	name = "MenuSet"

func _ready() -> void:
	headless = DisplayServer.get_name() == "headless"
	var scene: PackedScene = load(PATH)
	model = scene.instantiate()
	add_child(model)
	_materials(model)
	add_child(_environment())
	sun = _sun()
	add_child(sun)
	fire_light = _omni("LIGHT_fire", true)
	lantern_light = _omni("LIGHT_lantern", false)
	_fire_energy = fire_light.light_energy if fire_light else 1.0
	var fl := node("MS_flames")
	if fl:
		for c in fl.get_children():
			if c is Node3D:
				_flames.append(c)
				_flame_base.append((c as Node3D).scale)
	if not headless:
		_sparks()
	_pedestal = Node3D.new()
	_pedestal.name = "Pedestal"
	add_child(_pedestal)
	camera = Camera3D.new()
	camera.name = "MenuCamera"
	camera.near = 0.05
	camera.far = 600.0
	add_child(camera)
	camera.current = true
	set_shot(shot, false)
	set_process(not headless)

## Nó do GLB pelo nome (ex.: "SPOT_pedestal", "CAM_list"); null se não existir.
func node(n: String) -> Node3D:
	if model == null:
		return null
	return model.find_child(n, true, false) as Node3D

## Extra do Blender (metadata "extras" do import glTF; alguns importadores põem a chave direto no nó).
static func extra(n: Node, key: String, default: Variant) -> Variant:
	if n == null:
		return default
	var ex: Variant = n.get_meta("extras", {})
	if ex is Dictionary and (ex as Dictionary).has(key):
		return ex[key]
	if n.has_meta(key):
		return n.get_meta(key)
	return default

# ------------------------------------------------------------------ câmera
## Troca a câmera para a tela (`&"title"`, `&"list"`, `&"create"`). `tween` = desliza em TRANSITION s (pulável com `skip_transition`).
func set_shot(name_: StringName, tween := true) -> void:
	if not CAM_OF.has(name_):
		push_warning("MenuSet: tela desconhecida %s" % name_)
		return
	shot = name_
	if camera == null:
		return                       # antes do _ready: aplica quando montar
	var cam_node := node(CAM_OF[name_])
	if cam_node == null:
		return
	var to := shot_transform(name_)
	var to_fov := float(extra(cam_node, "fov", CAM_FOV[CAM_OF[name_]]))
	if _tween:
		_tween.kill()
		_tween = null
	if not tween or not is_inside_tree() or headless:
		camera.global_transform = to
		camera.fov = to_fov
		transition_finished.emit.call_deferred()
	else:
		_from = camera.global_transform
		_from_fov = camera.fov
		_tween = create_tween()
		_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_tween.tween_method(func(k: float): _blend(to, to_fov, k), 0.0, 1.0, TRANSITION)
		_tween.finished.connect(func(): transition_finished.emit())
	_pedestal.global_transform = pedestal_transform()

## Transform final da câmera da tela: o vazio `CAM_<tela>` do GLB mais o `SHOT_NUDGE` dela.
func shot_transform(name_: StringName) -> Transform3D:
	var cam_node := node(CAM_OF.get(name_, ""))
	if cam_node == null:
		return Transform3D.IDENTITY
	var t := cam_node.global_transform.orthonormalized()
	var nudge: Dictionary = SHOT_NUDGE.get(name_, {})
	t.origin += t.basis.z * float(nudge.get("back", 0.0)) + Vector3.DOWN * float(nudge.get("down", 0.0)) \
		+ t.basis.x * float(nudge.get("right", 0.0))
	return t

## Igual a `set_shot` (nome usado pelo `start.gd`): `_instant` = sem transição.
func go_to(shot_: StringName, _instant := false) -> void:
	set_shot(shot_, not _instant)

func current_shot() -> StringName:
	return shot

## Nó no pé do pedestal, já girado para a câmera da tela atual: ponha o boneco como filho dele (ou use `place_character`).
func pedestal() -> Node3D:
	return _pedestal

func _blend(to: Transform3D, to_fov: float, k: float) -> void:
	camera.global_transform = _from.interpolate_with(to, k)
	camera.fov = lerpf(_from_fov, to_fov, k)

## Termina a transição agora (clique/Enter pula, spec §3).
func skip_transition() -> void:
	if _tween and _tween.is_running():
		_tween.custom_step(TRANSITION)

func is_moving() -> bool:
	return _tween != null and _tween.is_running()

# ------------------------------------------------------------------ pedestal
## Pé do boneco em cima do pedestal; na criação já girado (`subject_yaw`) para encarar a `CAM_create`.
func pedestal_transform() -> Transform3D:
	var spot := node("SPOT_pedestal")
	var origin := spot.global_position if spot else Vector3(0, 0.25, 0)
	var yaw := 0.0
	if shot == &"create":
		yaw = deg_to_rad(float(extra(node("CAM_create"), "subject_yaw", SUBJECT_YAW)))
	return Transform3D(Basis(Vector3.UP, yaw), origin)

## Põe o personagem (ex.: um KitModel) no pedestal: vira filho de `pedestal()` com transform local zerada, então
## acompanha as trocas de tela (gira na criação, de frente nas outras). `null` só esquece o atual.
func place_character(n: Node3D) -> void:
	_subject = n
	if n == null:
		return
	if n.get_parent() != _pedestal:
		if n.get_parent():
			n.reparent(_pedestal, false)
		else:
			_pedestal.add_child(n)
	n.transform = Transform3D.IDENTITY

func character() -> Node3D:
	return _subject if is_instance_valid(_subject) else null

# ------------------------------------------------------------------ animação
func _process(delta: float) -> void:
	_t += delta
	if fire_light:
		# soma de senos com frequências quebradas = tremor sem padrão visível; amplitude total ±FIRE_FLICKER
		var n := 0.55 * sin(_t * 9.1) + 0.3 * sin(_t * 15.7 + 1.3) + 0.15 * sin(_t * 23.3 + 2.1)
		fire_light.light_energy = _fire_energy * (1.0 + FIRE_FLICKER * n)
	for i in _flames.size():
		var f := _flames[i]
		var ph := float(i) * 2.17
		var s := 1.0 + FLAME_WOBBLE * (0.6 * sin(_t * (7.0 + i * 1.9) + ph) + 0.4 * sin(_t * (12.0 + i * 2.3) + ph * 1.7))
		var w := 1.0 - 0.4 * (s - 1.0)
		f.scale = _flame_base[i] * Vector3(w, s, w)

# ------------------------------------------------------------------ montagem
## Troca os materiais do GLB pelo toon do jogo (como `MapBuilder._zone_materials`): `glow_chama*`/`glow_brasa` = fogo,
## outros `glow_*` brilham (lanterna, janelas), o resto toon com contorno (menos chão/serra/telhas).
func _materials(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var cast := not NO_CAST.any(func(p: String): return str(mi.name).begins_with(p))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var mname := src.resource_name if src else ""
			var base := (src as BaseMaterial3D).albedo_color if src is BaseMaterial3D else Color.GRAY
			var mat: Material
			if mname.begins_with("glow_chama"):       # línguas: amarelo/laranja cheio que passa do limiar do brilho
				mat = Materials.glow(base, 3.0)
			elif mname.begins_with("glow_brasa"):     # brasa: o fogo do jogo (miolo claro, tremor)
				mat = Materials.fire(base.srgb_to_linear(), 1.6)
			elif mname.begins_with("glow_"):
				mat = Materials.glow(base.srgb_to_linear(), 1.8)
			else:
				mat = _dusk_toon(base, not NO_OUTLINE.any(func(p: String): return mname.begins_with(p)))
			mi.set_surface_override_material(i, mat)
	for c in n.get_children():
		_materials(c)

var _toon_cache: Dictionary = {}

## Toon do jogo (`Materials.toon`, mesmo shader e contorno) com a sombra do entardecer.
func _dusk_toon(c: Color, outline: bool) -> ShaderMaterial:
	var key := "%s_%s" % [c.to_html(), outline]
	if not _toon_cache.has(key):
		var m: ShaderMaterial = Materials.toon(c, outline).duplicate()
		m.set_shader_parameter("shadow_strength", SHADOW_STRENGTH)
		m.set_shader_parameter("shadow_tint", SHADOW_TINT)
		_toon_cache[key] = m
	return _toon_cache[key]

const SKY_SHADER := """shader_type sky;
uniform vec3 top;
uniform vec3 mid;
uniform vec3 horizon;
uniform vec3 ground;
void sky() {
	float h = EYEDIR.y;
	// horizonte -> lilás logo acima -> azul no alto (a câmera do título vê até ~25°: o degradê é curto)
	vec3 c = h < 0.0 ? mix(horizon, ground, clamp(-h * 4.0, 0.0, 1.0))
		: (h < 0.12 ? mix(horizon, mid, smoothstep(0.0, 0.12, h)) : mix(mid, top, smoothstep(0.12, 0.5, h)));
	COLOR = c;
}
"""

## Céu em degradê (horizonte laranja -> lilás -> azul, como `menu_set.render`), ambiente lilás, névoa do horizonte.
func _environment() -> WorldEnvironment:
	var sh := Shader.new()
	sh.code = SKY_SHADER
	var sm := ShaderMaterial.new()
	sm.shader = sh
	var horizon: Color = DUSK["sky_horizon"]
	var mid: Color = DUSK["sky_mid"]
	var top: Color = DUSK["sky_top"]
	# as cores do DUSK são lineares (Blender); o céu do Godot escreve linear direto
	var k := SKY_STRENGTH
	sm.set_shader_parameter("top", Vector3(top.r, top.g, top.b) * k)
	sm.set_shader_parameter("mid", Vector3(mid.r, mid.g, mid.b) * k)
	sm.set_shader_parameter("horizon", Vector3(horizon.r, horizon.g, horizon.b) * k)
	var gr := mid.lerp(top, 0.5)
	sm.set_shader_parameter("ground", Vector3(gr.r, gr.g, gr.b) * k)
	var sky := Sky.new()
	sky.sky_material = sm
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = (DUSK["ambient"] as Color).linear_to_srgb()
	e.ambient_light_energy = AMBIENT_ENERGY
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_white = 6.0
	e.tonemap_exposure = EXPOSURE
	e.ssao_enabled = true
	e.ssao_radius = 1.0
	e.ssao_intensity = 1.4
	e.ssao_light_affect = 0.1
	e.glow_enabled = true
	e.glow_intensity = 0.55
	e.glow_strength = 0.95
	e.glow_bloom = 0.05
	e.glow_hdr_threshold = 1.0
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	e.fog_enabled = true
	e.fog_light_color = (mid.lerp(horizon, 0.35) * k).linear_to_srgb()
	e.fog_density = FOG_DENSITY
	e.fog_aerial_perspective = 0.25
	e.fog_sky_affect = 0.0
	e.adjustment_enabled = true
	e.adjustment_brightness = 1.03
	e.adjustment_contrast = 1.18
	e.adjustment_saturation = 1.15
	var env := WorldEnvironment.new()
	env.name = "DuskEnvironment"
	env.environment = e
	return env

## Sol baixo do entardecer: `sun_dir_from` é de onde vem (Blender, Z para cima) -> Godot (x, z, -y).
func _sun() -> DirectionalLight3D:
	var s := DirectionalLight3D.new()
	s.name = "DuskSun"
	var d: Vector3 = DUSK["sun_dir_from"]
	var from := Vector3(d.x, d.z, -d.y).normalized()
	s.basis = Basis.looking_at(-from, Vector3.UP)
	s.light_color = (DUSK["sun_color"] as Color).linear_to_srgb()
	s.light_energy = float(DUSK["sun_energy"]) * SUN_SCALE
	s.shadow_enabled = not headless
	s.shadow_blur = 1.4
	s.shadow_bias = 0.05
	s.shadow_normal_bias = 1.2
	s.directional_shadow_max_distance = 60.0
	s.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	return s

## OmniLight3D no vazio `LIGHT_*` com cor/energia/alcance dos extras.
func _omni(n: String, shadow: bool) -> OmniLight3D:
	var at := node(n)
	if at == null:
		return null
	var def: Array = LIGHT_DEFAULTS[n]
	var c: Variant = extra(at, "color", def[0])
	var col: Color = def[0]
	if c is Array and (c as Array).size() >= 3:
		col = Color(float(c[0]), float(c[1]), float(c[2]))
	elif c is Color:
		col = c
	var l := OmniLight3D.new()
	l.name = n + "_omni"
	l.light_color = col.linear_to_srgb()
	l.light_energy = float(extra(at, "energy", def[1])) * OMNI_SCALE
	l.omni_range = float(extra(at, "range", def[2]))
	l.omni_attenuation = 1.2
	l.shadow_enabled = shadow and not headless
	l.shadow_bias = 0.08
	at.add_child(l)
	return l

## Fagulhas subindo da fogueira (MS_sparks): pontinhos laranja que somem no alto.
func _sparks() -> void:
	var at := node("MS_sparks")
	if at == null:
		return
	var p := GPUParticles3D.new()
	p.name = "Sparks"
	p.amount = SPARKS
	p.lifetime = 1.8
	p.randomness = 0.5
	p.visibility_aabb = AABB(Vector3(-2, -0.5, -2), Vector3(4, 5, 4))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.18
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 22.0
	pm.initial_velocity_min = 0.7
	pm.initial_velocity_max = 1.5
	pm.gravity = Vector3(0, 0.15, 0)
	pm.damping_min = 0.2
	pm.damping_max = 0.5
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 2.0
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.45, 1.0))
	g.set_color(1, Color(1.0, 0.35, 0.1, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.035, 0.035)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.emission_enabled = true
	m.emission = Color(1.0, 0.6, 0.25)
	m.emission_energy_multiplier = 2.0
	q.material = m
	p.draw_pass_1 = q
	at.add_child(p)
