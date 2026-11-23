class_name WindupGlint
extends Node3D
## Antecipação sem atraso (pacote V2, 2026-11-23; production/qa/spell-attack-anim-research-2026-11-23.md): durante o
## preparo das skills rápidas, um brilho na arma (golpe físico) ou uma fagulha do tema na mão (magia) cresce até o
## impacto e some logo depois. Não muda tempo nenhum da sim; segue o osso da mão do kit (sem kit: na frente do peito).
## Skills mais lentas já têm o que ler: magia >= 0,2 s junta partículas (SkillFx.gather), golpe >= 0,3 s mostra o aro.

const PHYS_COLOR := Color(1.0, 0.9, 0.72)      # aço morno: o miolo branco fica pequeno (teto de branco do pacote V1)
const SIZE_PHYS := 0.55                        # m do brilho no impacto
const SIZE_MAGIC := 0.6
const ALPHA_MAX := 0.9
const START_SCALE := 0.3                       # fração do tamanho no 1º quadro (cresce até 1 no impacto)
const REACH := 0.3                             # m do osso da mão até o brilho (meio da lâmina / cabeça do cajado)
const OUT_S := 0.09                            # s do sumiço depois do impacto (abre um pouco e apaga)
const PHYS_MAX_STARTUP := 0.3                  # golpe com preparo >= isto já tem o aro de aviso
const MAGIC_MAX_STARTUP := 0.2                 # magia com preparo >= isto já tem o gather
const HAND_BONE := "hand.R"

static var _star: Texture2D = null

var _view: Node3D
var _skel: Skeleton3D
var _bone := -1
var _t := 0.0
var _dur := 0.1
var _size := SIZE_PHYS
var _mat: StandardMaterial3D
var _quad: MeshInstance3D

## A skill ganha o brilho? Só personagem (monstro tem o aviso de perigo), nunca o básico, preparo curto.
static func wants(e: SimEntity, s: SkillDef) -> bool:
	if e == null or s == null or e.kind == SimEntity.Kind.MONSTER or s.id.begins_with("basic_"):
		return false
	if s.kind == SkillDef.Kind.PHYSICAL:
		return s.startup < PHYS_MAX_STARTUP
	if s.kind == SkillDef.Kind.MAGICAL:
		return s.startup < MAGIC_MAX_STARTUP
	return false

## Cria o brilho em `root` seguindo a mão do boneco `view` (EntityView) por `startup` s.
static func spawn(root: Node, view: Node3D, s: SkillDef, theme: String) -> WindupGlint:
	var g := WindupGlint.new()
	g._view = view
	g._dur = maxf(0.05, s.startup)
	var physical := s.kind == SkillDef.Kind.PHYSICAL
	g._size = SIZE_PHYS if physical else SIZE_MAGIC
	var kit = view.get("kit")
	if kit is KitModel and (kit as KitModel).skeleton:
		g._skel = (kit as KitModel).skeleton
		g._bone = g._skel.find_bone(HAND_BONE)
	var c: Color = PHYS_COLOR if physical or theme in ["physical", ""] else SkillFx.col(theme, 0).lerp(SkillFx.col(theme, 1), 0.35)
	g._mat = StandardMaterial3D.new()
	g._mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	g._mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	g._mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	g._mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	g._mat.billboard_keep_scale = true          # o tamanho vem da escala do nó
	g._mat.no_depth_test = true                 # brilho por cima da própria arma (some atrás do corpo sem isso)
	g._mat.disable_fog = true
	g._mat.albedo_texture = star() if physical else SkillFx.soft()
	g._mat.albedo_color = Color(c, 0.0)
	g._quad = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE
	g._quad.mesh = qm
	g._quad.material_override = g._mat
	g._quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(g._quad)
	root.add_child(g)
	g._follow()
	g.scale = Vector3.ONE * g._size * START_SCALE
	return g

## Estrela de 4 pontas (o "tlim" da lâmina), desenhada uma vez.
static func star() -> Texture2D:
	if _star == null:
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var u := (float(x) + 0.5) / n * 2.0 - 1.0
				var v := (float(y) + 0.5) / n * 2.0 - 1.0
				var r := sqrt(u * u + v * v)
				var ray := maxf(maxf(0.0, 1.0 - absf(u) * 9.0) * (1.0 - absf(v)), maxf(0.0, 1.0 - absf(v) * 9.0) * (1.0 - absf(u)))
				var core := clampf(1.0 - r * 2.6, 0.0, 1.0)
				var a := clampf(maxf(ray, core * core), 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_star = ImageTexture.create_from_image(img)
	return _star

func _follow() -> void:
	if not is_instance_valid(_view):
		return
	if _skel and _bone >= 0 and is_instance_valid(_skel):
		var bx := _skel.global_transform * _skel.get_bone_global_pose(_bone)
		global_position = bx.origin + bx.basis.y.normalized() * REACH
	else:
		global_position = _view.global_position + Vector3(0, 1.0, 0) - _view.global_transform.basis.z * 0.4

func _process(delta: float) -> void:
	if not is_instance_valid(_view):
		queue_free()
		return
	_t += delta
	_follow()
	var a: float
	var k: float
	if _t <= _dur:
		var p := _t / _dur
		k = lerpf(START_SCALE, 1.0, p * p)
		a = ALPHA_MAX * minf(1.0, 0.35 + p)
	else:
		var q := (_t - _dur) / OUT_S
		if q >= 1.0:
			queue_free()
			return
		k = 1.0 + 0.3 * q
		a = ALPHA_MAX * (1.0 - q)
	scale = Vector3.ONE * _size * k
	_mat.albedo_color.a = a
