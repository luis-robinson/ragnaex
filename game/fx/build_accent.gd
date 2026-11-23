class_name BuildAccent
extends RefCounted
## Acento por build (pacote V4, decisão D3 de 2026-11-23): a cor do ELEMENTO continua a principal (SkillFx.PALETTE);
## cada build soma UMA cor de destaque e UMA forma de partícula, sempre no ar (mão de quem lança, projétil, impacto),
## nunca pintada no chão (o chão saturado é da gramática de aviso, FxManager.DANGER*).
## Chave "<classe>_<build>" (ClassDef.id + id da build). Regras (check `_check_build_accents`): toda build tem entrada,
## irmãs da mesma classe diferem na forma E na cor, e nenhuma cor cai perto da paleta reservada (RESERVED / SAFE_TONES).

## [cor de destaque, forma] por build. Cores pouco saturadas perto de ouro/laranja/carmim/roxo (ver RESERVED).
const ACCENTS := {
	"paladin_guardiao": [Color(0.5, 0.68, 0.95), "spark"],          # faíscas de aço azulado
	"paladin_cruzado": [Color(0.9, 0.93, 1.0), "feather"],          # penas prateadas
	"paladin_templario": [Color(0.8, 0.52, 0.45), "ember"],         # brasas cor de cobre (escuras: leem sobre o ouro sagrado)
	"berserker_carniceiro": [Color(0.85, 0.88, 0.95), "spark"],     # lascas de aço dos dois machados
	"berserker_executor": [Color(0.32, 0.3, 0.31), "chip"],         # cascalho de ferro preto
	"berserker_punhos": [Color(0.98, 0.75, 0.8), "glint"],          # estrela rosa do soco
	"bishop_sacerdote": [Color(0.6, 0.85, 1.0), "mote"],            # motas de céu
	"bishop_inquisidor": [Color(0.86, 0.8, 1.0), "rune"],           # anéis branco-violeta
	"bishop_batalha": [Color(0.78, 0.7, 0.62), "glint"],            # brilho de bronze fosco
	"druid_guardiao_verde": [Color(0.7, 0.62, 0.48), "leaf"],       # folha seca / casca
	"druid_fera": [Color(0.78, 0.8, 0.86), "spark"],                # riscos prateados de garra
	"druid_xama": [Color(1.0, 0.72, 0.92), "petal"],               # pétalas lilás
	"ranger_cacador": [Color(0.75, 0.85, 0.55), "feather"],         # penas de flecha cor de sálvia
	"ranger_atirador": [Color(0.7, 0.7, 0.68), "smoke"],            # fumaça de pólvora
	"ranger_lanceiro": [Color(0.55, 0.75, 0.9), "shard"],           # lascas azuis da lança
	"assassin_laminas": [Color(0.55, 0.95, 0.35), "drip"],          # gotas de veneno
	"assassin_duelista": [Color(0.95, 0.82, 0.88), "feather"],      # pluma rosa-prata do chapéu
	"assassin_corsario": [Color(0.45, 0.78, 0.85), "spray"],        # respingo de mar
	"elementalist_fogo": [Color(0.3, 0.27, 0.27), "smoke"],         # fumaça escura do fogo
	"elementalist_gelo": [Color(0.92, 0.97, 1.0), "glint"],         # floco/estrela de gelo
	"elementalist_raio": [Color(0.68, 0.7, 1.0), "spark"],          # faíscas azul-violeta
	"necromancer_invocador": [Color(0.88, 0.95, 0.78), "bone"],     # lascas de osso
	"necromancer_ceifador": [Color(0.6, 0.6, 0.62), "ash"],         # cinza
	"necromancer_pestilento": [Color(0.6, 0.65, 0.85), "mote"],     # motas frias das sombras
}

## Forma da partícula: malha (streak/box/quad/star/ring/sphere/flat), tamanho, gravidade y, velocidade, vida, se soma
## a luz (aditivo: só a estrela; o resto mistura para a matiz ler sobre chão/armadura claros), `face` = de frente para
## a câmera, `align` = estica no sentido do voo, `spin` = gira no eixo y, `grow` = cresce.
const SHAPES := {
	"spark": {"mesh": "box", "size": Vector3(0.04, 0.3, 0.04), "g": -3.0, "v": [3.0, 5.5], "life": 0.35, "add": false, "align": true},
	"shard": {"mesh": "box", "size": Vector3(0.07, 0.28, 0.07), "g": -9.0, "v": [2.5, 4.5], "life": 0.55, "add": false, "align": true},
	"chip": {"mesh": "box", "size": Vector3(0.13, 0.09, 0.1), "g": -11.0, "v": [2.5, 4.5], "life": 0.6, "add": false, "spin": true},
	"bone": {"mesh": "box", "size": Vector3(0.065, 0.19, 0.065), "g": -9.0, "v": [2.0, 4.0], "life": 0.6, "add": false, "spin": true},
	"feather": {"mesh": "quad", "size": Vector3(0.12, 0.36, 0.0), "g": -0.6, "v": [1.0, 2.2], "life": 1.0, "add": false, "spin": true},
	"leaf": {"mesh": "quad", "size": Vector3(0.22, 0.15, 0.0), "g": -1.2, "v": [1.0, 2.4], "life": 0.9, "add": false, "spin": true},
	"ash": {"mesh": "quad", "size": Vector3(0.12, 0.12, 0.0), "g": -0.5, "v": [0.5, 1.5], "life": 1.1, "add": false, "spin": true},
	"petal": {"mesh": "flat", "size": Vector3(0.1, 0.035, 0.0), "g": -0.8, "v": [0.8, 2.0], "life": 1.0, "add": false},
	"ember": {"mesh": "soft", "size": Vector3(0.12, 0.12, 0.0), "g": 2.0, "v": [0.8, 2.0], "life": 0.8, "add": false, "face": true},
	"mote": {"mesh": "soft", "size": Vector3(0.15, 0.15, 0.0), "g": 0.4, "v": [0.5, 1.4], "life": 1.1, "add": false, "face": true},
	"smoke": {"mesh": "soft", "size": Vector3(0.4, 0.4, 0.0), "g": 0.5, "v": [0.3, 0.9], "life": 0.9, "add": false, "face": true, "grow": true},
	"glint": {"mesh": "star", "size": Vector3(0.34, 0.34, 0.0), "g": 0.0, "v": [1.0, 2.5], "life": 0.32, "add": true, "face": true},
	"rune": {"mesh": "ring", "size": Vector3(0.3, 0.3, 0.0), "g": 0.8, "v": [0.4, 1.0], "life": 0.9, "add": false, "face": true},
	"drip": {"mesh": "sphere", "size": Vector3(0.06, 0.18, 0.0), "g": -7.0, "v": [1.0, 2.5], "life": 0.7, "add": false, "align": true},
	"spray": {"mesh": "sphere", "size": Vector3(0.05, 0.1, 0.0), "g": -6.0, "v": [2.5, 4.5], "life": 0.45, "add": false, "align": true},
}

## Paleta de aviso: [cor, faixa de matiz em graus]; acento a menos disso precisa de saturação <= RESERVED_MAX_SAT.
const RESERVED := {
	"danger_carmine": [Color(0.9, 0.08, 0.16), 22.0],     # FxManager.DANGER
	"lava_orange": [Color(1.0, 0.5, 0.12), 18.0],         # lava / brilho quente de aviso
	"split_gold": [Color(1.0, 0.78, 0.22), 18.0],         # dividir (BossSigView)
	"control_purple": [Color(0.5, 0.26, 0.72), 22.0],     # FxManager.DANGER_CONTROL
}
const RESERVED_MAX_SAT := 0.45
## Tons "seguros" claros (menta fria, areia): acento claro (valor > SAFE_MIN_V) com matiz e saturação próximos lê como zona segura.
const SAFE_TONES := {"safe_mint": Color(0.8, 1.0, 0.92), "safe_sand": Color(0.98, 0.92, 0.7)}
const SAFE_HUE_DEG := 20.0
const SAFE_SAT_GAP := 0.15
const SAFE_MIN_V := 0.85
## Irmãs da mesma classe: distância mínima de cor (RGB) além da forma diferente.
const SIBLING_MIN_DIST := 0.2
## Orçamento: no máximo isso de partículas por evento de acento (um CPUParticles3D = 1 draw call).
const PARTICLES_MAX := 14

static var _star: Texture2D = null
static var _ring: Texture2D = null

static func key_of(class_id: String, build: String) -> String:
	return "%s_%s" % [class_id, build]

## Acento de uma skill: a build escrita na skill; skill geral (build "") usa a build de quem lançou. "" = sem acento.
static func of_skill(s: SkillDef, caster: SimEntity = null) -> String:
	if s == null:
		return ""
	var cid := s.class_id
	var b := s.build
	if caster != null:
		if b == "":
			b = caster.build_id
		if cid == "" and caster.class_def != null:
			cid = caster.class_def.id
	if cid == "" or b == "":
		return ""
	var k := key_of(cid, b)
	return k if ACCENTS.has(k) else ""

static func color(key: String) -> Color:
	return ACCENTS[key][0] if ACCENTS.has(key) else Color.WHITE

static func shape(key: String) -> String:
	return str(ACCENTS[key][1]) if ACCENTS.has(key) else ""

## Nome da cor reservada com que `c` colide ("" = livre). Usado pelo check.
static func reserved_clash(c: Color) -> String:
	for nm in RESERVED:
		var ref: Color = RESERVED[nm][0]
		if _hue_gap(c, ref) <= float(RESERVED[nm][1]) and c.s > RESERVED_MAX_SAT:
			return nm
	for nm in SAFE_TONES:
		var ref: Color = SAFE_TONES[nm]
		if c.v > SAFE_MIN_V and _hue_gap(c, ref) < SAFE_HUE_DEG and absf(c.s - ref.s) < SAFE_SAT_GAP:
			return nm
	return ""

static func _hue_gap(a: Color, b: Color) -> float:
	var d := absf(a.h - b.h) * 360.0
	return minf(d, 360.0 - d)

static func rgb_dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()

# ---------------------------------------------------------------------------
## Rajada pequena da forma/cor da build em `pos` (por cima do efeito do tema). `amount` é cortado em PARTICLES_MAX.
static func burst(root: Node, pos: Vector3, key: String, amount: int = 8, up: Vector3 = Vector3.UP, box: float = 0.25, scale: float = 1.0) -> void:
	if not ACCENTS.has(key):
		return
	var p := _emitter(key, mini(amount, PARTICLES_MAX), scale)
	p.one_shot = true
	p.explosiveness = 0.85
	p.direction = up
	p.spread = 60.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(box, box * 0.5, box)
	p.position = pos
	root.add_child(p)
	p.emitting = true
	root.get_tree().create_timer(p.lifetime + 0.2).timeout.connect(p.queue_free)

## Rastro do acento atrás de um projétil (filho do nó do projétil; some com ele).
static func trail(key: String, size: float = 0.2) -> CPUParticles3D:
	var p := _emitter(key, 8, clampf(size * 3.0, 0.6, 1.2))
	p.local_coords = false
	p.spread = 180.0
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.6
	return p

static func _emitter(key: String, amount: int, scale: float) -> CPUParticles3D:
	var sh: Dictionary = SHAPES[shape(key)]
	var c := color(key)
	var p := CPUParticles3D.new()
	p.amount = maxi(1, amount)
	p.lifetime = float(sh["life"])
	p.initial_velocity_min = float(sh["v"][0]) * scale
	p.initial_velocity_max = float(sh["v"][1]) * scale
	p.gravity = Vector3(0, float(sh["g"]), 0)
	p.scale_amount_min = 0.75 * scale
	p.scale_amount_max = 1.25 * scale
	var curve := Curve.new()
	if sh.get("grow", false):
		curve.add_point(Vector2(0, 0.5))
		curve.add_point(Vector2(1, 1.4))
	else:
		curve.add_point(Vector2(0, 1))
		curve.add_point(Vector2(1, 0.3))
	p.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(c, 0.95))
	grad.set_color(1, Color(c, 0.0))
	p.color_ramp = grad
	if sh.get("align", false):
		p.particle_flag_align_y = true
	if sh.get("spin", false):
		p.particle_flag_rotate_y = true
		p.angle_min = 0.0
		p.angle_max = 360.0
		p.angular_velocity_min = -360.0
		p.angular_velocity_max = 360.0
	var sz: Vector3 = sh["size"]
	var m := SkillFx._mat(Color.WHITE, bool(sh["add"]), true)
	match str(sh["mesh"]):
		"box":
			var bm := BoxMesh.new()
			bm.size = sz
			p.mesh = bm
		"sphere", "flat":
			var sm := SphereMesh.new()
			sm.radius = sz.x
			sm.height = sz.y
			sm.radial_segments = 6
			sm.rings = 3
			p.mesh = sm
		_:
			var qm := QuadMesh.new()
			qm.size = Vector2(sz.x, sz.y)
			p.mesh = qm
			match str(sh["mesh"]):
				"star":
					m.albedo_texture = star()
				"ring":
					m.albedo_texture = ring()
				_:
					m.albedo_texture = SkillFx.soft()
	if sh.get("face", false):
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	p.material_override = m
	return p

## Estrela de 4 pontas (brilho de impacto/gelo): desenhada uma vez numa imagem 64x64.
static func star() -> Texture2D:
	if _star == null:
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var u := absf((x + 0.5) / n * 2.0 - 1.0)
				var v := absf((y + 0.5) / n * 2.0 - 1.0)
				var arm := maxf(exp(-v * 18.0) * (1.0 - u), exp(-u * 18.0) * (1.0 - v))
				var core := clampf(1.0 - sqrt(u * u + v * v) * 3.0, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, clampf(maxf(arm, core), 0.0, 1.0)))
		_star = ImageTexture.create_from_image(img)
	return _star

## Anel fino (runa): degradê radial com a faixa clara perto da borda.
static func ring() -> Texture2D:
	if _ring == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.6, Color(1, 1, 1, 0))
		g.add_point(0.78, Color(1, 1, 1, 1))
		g.add_point(0.92, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_ring = t
	return _ring
