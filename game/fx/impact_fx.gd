class_name ImpactFx
extends Node3D
## Impacto por material (V3) e clarão de soltura (V5), pacotes do plano production/qa/spell-attack-anim-research-2026-11-23.md.
## Só apresentação: ouve Events (damage_dealt, skill_effect, skill_cast) e desenha com UM material (shaders/impact_mark.gdshader)
## em dois pools fixos (nada de nó novo por golpe):
##  - faíscas: maça/martelo = anel de poeira no chão; lança = risco reto; arco/pistola/rifle = fumaça curta no alvo. Lâmina
##    (espada, machado, adaga, garra, foice) já tem faísca em WeaponArcs: aqui nada.
##  - marcas do chão de skill pesada (raio >= MARK_MIN_RADIUS, não aviso de monstro): rachadura, queimado, geada, selo, mancha,
##    1,5-4 s, tons rebaixados do chão (vermelho cheio é aviso de golpe: nunca), teto MARK_POOL vivas.
##  - soltura: brilho da corda no arco, cone de boca na pistola/rifle (básico e tiros sem clarão próprio).
## Efeito do grupo só com AccessSettings.ally_fx = Tudo (e a 55% de opacidade); o seu sempre.

const SPARK_POOL := 20
const MARK_POOL := 10
const MARK_MIN_RADIUS := 2.5
const MARK_MAX_RADIUS := 6.0
const MARK_LIFE_MIN := 1.5
const MARK_LIFE_MAX := 4.0
const MARK_ALPHA := 0.55
const MARK_Y := 0.03              # acima da pilha de planos do chão (Zone.patch 5 mm, lugares 6+ mm)
const ALLY_ALPHA := 0.55
const NEAR_RANGE := 30.0          # longe do jogador ninguém vê
const BLUNT := ["mace", "mace2h"]
const PIERCE := ["spear"]
const PUFF := ["bow", "pistol", "rifle"]
const SMOKE_PHYS := Color(0.78, 0.74, 0.66)           # poeira/fumaça quente
const SMOKE_CORE := Color(1.0, 0.93, 0.78)
## tema da skill -> [tipo no shader, cor, cor2]; tons rebaixados do chão (S < 0,45), sem vermelho saturado
const MARKS := {
	"fire": [4, Color(0.30, 0.22, 0.18), Color(1.0, 0.55, 0.2)],
	"lightning": [4, Color(0.26, 0.27, 0.34), Color(0.7, 0.75, 1.0)],
	"ice": [5, Color(0.62, 0.82, 0.92), Color(0.95, 1.0, 1.0)],
	"holy": [6, Color(0.93, 0.84, 0.55), Color(1.0, 0.97, 0.8)],
	"shadow": [7, Color(0.27, 0.18, 0.36), Color(0.5, 0.35, 0.65)],
	"poison": [7, Color(0.34, 0.45, 0.2), Color(0.6, 0.8, 0.35)],
	"nature": [7, Color(0.28, 0.42, 0.22), Color(0.6, 0.8, 0.4)],
	"blood": [7, Color(0.30, 0.18, 0.17), Color(0.5, 0.3, 0.28)],
	"bone": [3, Color(0.35, 0.33, 0.29), Color(0.8, 0.78, 0.7)],
	"earth": [3, Color(0.30, 0.25, 0.20), Color(0.7, 0.6, 0.45)],
	"physical": [3, Color(0.32, 0.30, 0.28), Color(0.8, 0.78, 0.74)],
}

var fx                                  # FxManager (main, _own, _mine)
static var _shader: Shader = null
static var _mesh: PlaneMesh = null
var _mat: ShaderMaterial
var _sparks: Array = []                 # {mi, t, life, on}
var _marks: Array = []
var _spark_next := 0
var _mark_next := 0
var _seed := 0.0
var _caster_theme: Dictionary = {}

func _ready() -> void:
	if _shader == null:
		_shader = load("res://shaders/impact_mark.gdshader")
		_mesh = PlaneMesh.new()
		_mesh.size = Vector2(1, 1)
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	_mat.render_priority = 1
	Events.damage_dealt.connect(_on_damage)
	Events.skill_effect.connect(_on_effect)
	Events.skill_cast.connect(_on_cast)

# ------------------------------------------------------------------ puros (o teste chama sem cena)
## Tipo de faísca da arma: "blunt" | "pierce" | "puff" | "" (lâmina/outras: nada aqui).
static func spark_kind(weapon_type: String) -> String:
	if weapon_type in BLUNT:
		return "blunt"
	if weapon_type in PIERCE:
		return "pierce"
	if weapon_type in PUFF:
		return "puff"
	return ""

## Marca do chão do tema: [tipo, cor, cor2]; tema sem linha = rachadura de aço.
static func mark_for(theme: String) -> Array:
	return MARKS.get(theme, MARKS["physical"])

## Vida da marca (s) pelo raio: 1,5 s no menor, 4 s no teto.
static func mark_life(radius: float) -> float:
	var k := clampf((radius - MARK_MIN_RADIUS) / (MARK_MAX_RADIUS - MARK_MIN_RADIUS), 0.0, 1.0)
	return lerpf(MARK_LIFE_MIN, MARK_LIFE_MAX, k)

## A skill deixa marca? (pesada: raio, no chão ou em volta, dano; nunca golpe de monstro, buff ou cura).
static func leaves_mark(s: SkillDef, skill_id: String, radius: float) -> bool:
	if s == null or skill_id.begins_with("mob_") or skill_id.begins_with("basic_"):
		return false
	if s.kind == SkillDef.Kind.HEAL or s.kind == SkillDef.Kind.BUFF or s.ultimate:
		return false
	if s.target != SkillDef.Target.GROUND and s.target != SkillDef.Target.SELF:
		return false
	return radius >= MARK_MIN_RADIUS

# ------------------------------------------------------------------ gating
## 1.0 = efeito pleno, ALLY_ALPHA = do grupo, 0 = não desenha.
func _weight(id: int) -> float:
	if fx == null or fx.main == null or Sim.player == null:
		return 0.0
	if fx._own(id):
		return 1.0
	if fx._mine(id) and AccessSettings.ally_fx == AccessSettings.Density.ALL:
		return ALLY_ALPHA
	return 0.0

func _near(pos: Vector3) -> bool:
	return Sim.player != null and pos.distance_squared_to(Sim.player.position) <= NEAR_RANGE * NEAR_RANGE

# ------------------------------------------------------------------ eventos
func _on_cast(entity_id: int, skill_id: String, phase: String) -> void:
	if phase != "active":
		return
	var e: SimEntity = Sim.get_entity(entity_id)
	if e == null or e.stats == null or fx == null or fx.main == null or e.map_id != fx.main.current_map_id:
		return
	var w := e.stats.weapon_type
	if w != "bow" and w != "pistol" and w != "rifle":
		return
	var s: SkillDef = GameData.skill_or_basic(skill_id)
	if s == null or (s.effects.get("shot", false) and not skill_id.begins_with("basic_")):
		return                              # tiro de pistola de skill já tem o clarão próprio (FxManager._pistol_fx)
	var wt := _weight(entity_id)
	if wt <= 0.0 or not _near(e.position):
		return
	var fwd := e.forward()
	var side := Vector3.UP.cross(fwd)
	if w == "bow":
		_puff(e.position + Vector3(0, 1.15, 0) + fwd * 0.45 + side * 0.28, 0.32, Color(1.0, 1.0, 1.0), SMOKE_CORE, 0.12, wt)   # estalo da corda
	else:
		var at := e.position + Vector3(0, 1.1, 0) + fwd * 0.7 + side * 0.22
		_streak(at, fwd, 1.5, 0.45, Color(1.0, 0.7, 0.3), SMOKE_CORE, 0.1, wt)       # cone da boca
		_puff(at, 0.55, SMOKE_PHYS, SMOKE_CORE, 0.22, wt)

func _on_damage(attacker_id: int, target_id: int, amount: int, crit: bool, blocked: bool, kind: String) -> void:
	if amount <= 0 or blocked or (kind != "physical" and kind != "shot"):
		return
	var a: SimEntity = Sim.get_entity(attacker_id)
	var t: SimEntity = Sim.get_entity(target_id)
	if a == null or t == null or a.stats == null or a.kind == SimEntity.Kind.MONSTER or a.form != "":
		return
	if fx == null or fx.main == null or t.map_id != fx.main.current_map_id:
		return
	var sk := spark_kind(a.stats.weapon_type)
	if sk == "":
		return
	var wt := _weight(attacker_id)
	if wt <= 0.0 or not _near(t.position):
		return
	var k := 1.35 if crit else 1.0
	var rel := t.position - a.position
	rel.y = 0.0
	var dir := rel.normalized() if rel.length() > 0.01 else a.forward()
	var hit := t.position + Vector3(0, 0.85 * t.scale, 0) - dir * t.radius * 0.6
	match sk:
		"blunt":
			_ring(Vector3(t.position.x, MARK_Y + 0.01, t.position.z), (1.7 if a.stats.weapon_type == "mace2h" else 1.3) * k * t.scale, SMOKE_PHYS, 0.34, wt)
		"pierce":
			_streak(hit - dir * 0.6, dir, 1.6 * k, 0.16, Color(0.9, 0.93, 1.0), Color(1, 1, 1), 0.14, wt)
		"puff":
			_puff(hit, 0.5 * k, SMOKE_PHYS, SMOKE_CORE, 0.2, wt)

func _on_effect(skill_id: String, origin: Vector3, aim: Vector3, radius: float) -> void:
	if fx == null or fx.main == null or (Sim.ticking_map != "" and Sim.ticking_map != fx.main.current_map_id):
		return
	var s: SkillDef = GameData.skill_or_basic(skill_id)
	if not leaves_mark(s, skill_id, radius):
		return
	var at := aim if s.target == SkillDef.Target.GROUND else origin
	if not _near(at):
		return
	var att: SimEntity = fx.arcs._attacker(skill_id, origin) if fx.arcs else null
	var wt := _weight(att.id) if att != null else 1.0
	if wt <= 0.0:
		return
	var th := FxManager.theme_of(s)
	var m := mark_for(th)
	var r := minf(radius, MARK_MAX_RADIUS)
	_mark(Vector3(at.x, MARK_Y, at.z), r * 1.75, int(m[0]), m[1], m[2], mark_life(r), wt * MARK_ALPHA)

# ------------------------------------------------------------------ desenho
func _take(pool: Array, cap: int, next: int) -> Array:
	# devolve [slot, próximo índice]; cria até o teto, depois reaproveita em roda (o mais velho)
	var slot: Dictionary
	if pool.size() < cap:
		var mi := MeshInstance3D.new()
		mi.mesh = _mesh
		mi.material_override = _mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.top_level = true
		mi.visible = false
		add_child(mi)
		slot = {"mi": mi, "t": 0.0, "life": 1.0, "on": false}
		pool.append(slot)
		return [slot, next]
	slot = pool[next % cap]
	return [slot, (next + 1) % cap]

func _start(slot: Dictionary, xf: Transform3D, kind: int, c: Color, c2: Color, life: float, alpha: float) -> void:
	var mi: MeshInstance3D = slot["mi"]
	mi.global_transform = xf
	mi.visible = true
	slot["t"] = 0.0
	slot["life"] = life
	slot["on"] = true
	_seed += 1.0
	mi.set_instance_shader_parameter("kind", kind)
	mi.set_instance_shader_parameter("progress", 0.0)
	mi.set_instance_shader_parameter("col", c.srgb_to_linear())
	mi.set_instance_shader_parameter("col2", c2.srgb_to_linear())
	mi.set_instance_shader_parameter("alpha", alpha)
	mi.set_instance_shader_parameter("seed", fmod(_seed * 7.31, 97.0))

func _mark(at: Vector3, size: float, kind: int, c: Color, c2: Color, life: float, alpha: float) -> void:
	var r := _take(_marks, MARK_POOL, _mark_next)
	_mark_next = r[1]
	var ang := fmod(_seed * 2.399, TAU)             # giro variado por marca (sem sorteio da sim)
	_start(r[0], Transform3D(Basis(Vector3.UP, ang).scaled(Vector3(size, 1.0, size)), at), kind, c, c2, life, alpha)

func _ring(at: Vector3, size: float, c: Color, life: float, alpha: float) -> void:
	var r := _take(_sparks, SPARK_POOL, _spark_next)
	_spark_next = r[1]
	_start(r[0], Transform3D(Basis.IDENTITY.scaled(Vector3(size, 1.0, size)), at), 0, c, c, life, alpha)

## Plano virado para a câmera (fumaça, brilho).
func _facing(at: Vector3, size: float) -> Transform3D:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var n := Vector3(0, 0.6, 0.8)
	if cam:
		n = (cam.global_position - at).normalized()
	var x := Vector3.UP.cross(n).normalized()
	var z := x.cross(n).normalized()
	return Transform3D(Basis(x * size, n, z * size), at)

func _puff(at: Vector3, size: float, c: Color, c2: Color, life: float, alpha: float) -> void:
	var r := _take(_sparks, SPARK_POOL, _spark_next)
	_spark_next = r[1]
	_start(r[0], _facing(at, size), 2, c, c2, life, alpha)

## Risco no ar de `at` na direção `dir` (comprimento len, largura w), virado para a câmera.
func _streak(at: Vector3, dir: Vector3, len: float, w: float, c: Color, c2: Color, life: float, alpha: float) -> void:
	var r := _take(_sparks, SPARK_POOL, _spark_next)
	_spark_next = r[1]
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var n := Vector3(0, 0.6, 0.8)
	if cam:
		n = (cam.global_position - at).normalized()
	var x := dir.normalized()
	var z := x.cross(n).normalized()
	var up := z.cross(x).normalized()
	_start(r[0], Transform3D(Basis(x * len, up, z * w), at + x * len * 0.5), 1, c, c2, life, alpha)

func _process(delta: float) -> void:
	_tick(_sparks, delta)
	_tick(_marks, delta)

func _tick(pool: Array, delta: float) -> void:
	for slot in pool:
		if not slot["on"]:
			continue
		slot["t"] = float(slot["t"]) + delta
		var k := float(slot["t"]) / float(slot["life"])
		var mi: MeshInstance3D = slot["mi"]
		if k >= 1.0:
			slot["on"] = false
			mi.visible = false
		else:
			mi.set_instance_shader_parameter("progress", k)

## Quantos nós existem / vivos (check de teto).
func pool_count() -> int:
	return _sparks.size() + _marks.size()

func live_marks() -> int:
	var n := 0
	for slot in _marks:
		if slot["on"]:
			n += 1
	return n

## Teste/bancada: marca direto (sem evento).
func debug_mark(theme: String, at: Vector3, radius: float) -> void:
	var m := mark_for(theme)
	_mark(Vector3(at.x, MARK_Y, at.z), minf(radius, MARK_MAX_RADIUS) * 1.75, int(m[0]), m[1], m[2], mark_life(radius), MARK_ALPHA)

func debug_spark(kind: String, at: Vector3, dir: Vector3) -> void:
	match kind:
		"blunt": _ring(Vector3(at.x, MARK_Y + 0.01, at.z), 1.3, SMOKE_PHYS, 0.34, 1.0)
		"pierce": _streak(at, dir, 1.6, 0.16, Color(0.9, 0.93, 1.0), Color.WHITE, 0.14, 1.0)
		_: _puff(at, 0.5, SMOKE_PHYS, SMOKE_CORE, 0.2, 1.0)
