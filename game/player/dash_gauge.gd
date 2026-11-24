class_name DashGauge
extends Node3D
## Cargas do dash (Shift) nos pés do SEU personagem: um gomo em arco por carga, virado para a câmera, que enche
## como um leque enquanto a recarga corre. Só aparece enquanto algo recarrega (entra e sai em fade); quando o dash
## volta de uma recarga de verdade, brilho rápido nos gomos + "tic" baixo (Sfx dash_ready). Só lê a sim.
## Cor fria e fraca de propósito: vermelho/laranja no chão são avisos de golpe (FxManager.DANGER*).

const COOL := Color(0.74, 0.88, 1.0)          # gomo cheio: branco-azulado
const TRACK := Color(0.55, 0.62, 0.72)        # trilho do gomo gasto
const ALPHA := 0.85                           # opacidade máxima (fica atrás do resto do mundo na leitura)
const FADE_IN := 14.0                         # peso/s do fade
const FADE_OUT := 6.0
const LINGER := 0.45                          # s que os gomos ficam depois de prontos (o brilho aparece nesse tempo)
const GLINT_S := 0.35                         # s do brilho de pronto
const MAX_PIPS := 4
const PIP_SPAN := 56.0                        # graus do gomo único; com 2+ cargas cada um tem MULTI_SPAN
const MULTI_SPAN := 40.0
const PIP_GAP := 9.0                          # graus entre gomos
const RING_IN := 0.7                         # faixa do arco (fração do raio do quadro)
const RING_OUT := 0.9

var main: Node = null
var _mesh: MeshInstance3D
var _mat: ShaderMaterial
var _alpha := 0.0
var _hold := 0.0
var _glint := 0.0
var _prev_cd := 0.0
var _player_id := -1
var _dp: Dictionary = {}
var _dp_t := 0.0

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled;
uniform int count = 1;
uniform float fills[4];
uniform float alpha = 0.0;
uniform float glint = 0.0;
uniform float span = 0.98;
uniform float gap = 0.157;
uniform float r_in = 0.74;
uniform float r_out = 0.96;
uniform vec4 full_col : source_color = vec4(0.74, 0.88, 1.0, 1.0);
uniform vec4 track_col : source_color = vec4(0.55, 0.62, 0.72, 1.0);
uniform vec4 rim_col : source_color = vec4(0.06, 0.08, 0.14, 1.0);
varying vec2 lp;
void vertex() { lp = VERTEX.xz; }
void fragment() {
	float r = length(lp);
	float aa = fwidth(r) * 1.2;
	float band = smoothstep(r_in - aa, r_in + aa, r) * (1.0 - smoothstep(r_out - aa, r_out + aa, r));
	float rim = 0.05;                                   // contorno escuro: lê sobre chão claro (Lumeria, neve)
	float band_o = smoothstep(r_in - rim - aa, r_in - rim + aa, r) * (1.0 - smoothstep(r_out + rim - aa, r_out + rim + aa, r));
	float ang = atan(lp.x, lp.y);                       // 0 = +Z (lado da câmera)
	float step_a = span + gap;
	float first = -0.5 * step_a * float(count - 1);
	float a = 0.0;
	float a_o = 0.0;
	vec3 col = vec3(0.0);
	for (int i = 0; i < 4; i++) {
		if (i >= count) { break; }
		float c = first + step_a * float(i);
		float t = (ang - (c - 0.5 * span)) / span;       // 0..1 dentro do gomo
		float ea = fwidth(ang) * 1.2 / span;
		float pad = rim / span;
		float outer = smoothstep(-pad - ea, -pad + ea, t) * (1.0 - smoothstep(1.0 + pad - ea, 1.0 + pad + ea, t));
		a_o = max(a_o, outer);
		float inside = smoothstep(-ea, ea, t) * (1.0 - smoothstep(1.0 - ea, 1.0 + ea, t));
		if (inside <= 0.0) { continue; }
		float f = fills[i];
		float lit = 1.0 - smoothstep(f - ea, f + ea, t); // leque: enche da ponta esquerda para a direita
		vec3 c_col = mix(track_col.rgb, full_col.rgb, lit);
		float c_a = mix(0.35, 1.0, lit);
		col = mix(c_col, vec3(1.0), glint * 0.8);
		a = max(a, inside * c_a);
	}
	float fg = band * a;
	float bg = band_o * a_o * 0.55;
	ALBEDO = mix(rim_col.rgb, col, fg / max(fg + bg * (1.0 - fg), 0.001));
	ALPHA = clamp(max(fg, bg) * alpha * (1.0 + glint * 0.4), 0.0, 1.0);
}
"""

func _ready() -> void:
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	_mat.shader = sh
	_mat.render_priority = 1
	_mat.set_shader_parameter("full_col", COOL)
	_mat.set_shader_parameter("track_col", TRACK)
	_mat.set_shader_parameter("r_in", RING_IN)
	_mat.set_shader_parameter("r_out", RING_OUT)
	_mesh = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2.0, 2.0)
	_mesh.mesh = pm
	_mesh.material_override = _mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	visible = false

## Estado das cargas para desenhar (puro). `fills[i]`: 0 = gasta, 1 = pronta; `ready` = dashes que saem agora;
## `have` = cargas que você tem (a do intervalo entre cargas conta); `left` = quanto falta da recarga (leque da barra);
## `cycle` = "full" (recarga cheia, depois de gastar todas), "gap" (intervalo entre cargas) ou "".
## Espelha WorldSim (dash): com 2+ cargas, gastar uma = intervalo de DASH_CHARGE_WINDOW × 0,25; gastar a última = recarga cheia.
static func pip_state(dash_cd: float, used: int, charges: int, cooldown_mult: float) -> Dictionary:
	var n := clampi(charges, 1, MAX_PIPS)
	var u := clampi(used, 0, n - 1)
	var fills: Array = []
	if dash_cd <= 0.0:
		for i in range(n):
			fills.append(1.0 if i < n - u else 0.0)
		return {"fills": fills, "ready": n - u, "have": n - u, "left": 0.0, "cycle": ""}
	var full := u == 0
	var total: float = Balance.DASH_COOLDOWN * cooldown_mult if full else Balance.DASH_CHARGE_WINDOW * 0.25
	var f := clampf(1.0 - dash_cd / maxf(total, 0.01), 0.0, 1.0)
	for i in range(n):
		fills.append(f if (full or i < n - u) else 0.0)
	return {"fills": fills, "ready": 0, "have": 0 if full else n - u, "left": 1.0 - f, "cycle": "full" if full else "gap"}

## Pista de "dash de volta" (pura): só na passagem de recarga CHEIA para pronto (nunca no nascer, nem no intervalo entre cargas).
static func ready_cue(prev_cd: float, dash_cd: float, used: int) -> bool:
	return prev_cd > 0.0 and dash_cd <= 0.0 and used == 0

## Parâmetros do dash do jogador (evoluções), relidos a cada 0,5 s (Sim.dash_params percorre os talentos).
func params_of(p: SimEntity, delta: float) -> Dictionary:
	_dp_t -= delta
	if _dp.is_empty() or _dp_t <= 0.0:
		_dp_t = 0.5
		_dp = Sim.dash_params(p)
	return _dp

func _process(delta: float) -> void:
	var p: SimEntity = Sim.player
	if p == null or main == null or not p.is_alive():
		visible = false
		_alpha = 0.0
		_player_id = -1 if p == null else p.id
		_prev_cd = p.dash_cd if p else 0.0
		return
	if p.id != _player_id:             # personagem novo / mundo novo: nada de pista no nascer
		_player_id = p.id
		_prev_cd = p.dash_cd
	var dp := params_of(p, delta)
	var st := pip_state(p.dash_cd, p.dash_charges_used, int(dp["charges"]), float(dp["cooldown_mult"]))
	if ready_cue(_prev_cd, p.dash_cd, p.dash_charges_used):
		_glint = GLINT_S
		var sfx: Node = main.get_node_or_null("Sfx")
		if sfx:
			sfx.play_ui("dash_ready")
	_prev_cd = p.dash_cd
	if p.dash_cd > 0.0:
		_hold = LINGER
	else:
		_hold = maxf(0.0, _hold - delta)
	_glint = maxf(0.0, _glint - delta)
	var want := 1.0 if (p.dash_cd > 0.0 or _hold > 0.0) else 0.0
	_alpha = lerpf(_alpha, want, minf(1.0, delta * (FADE_IN if want > _alpha else FADE_OUT)))
	var views: Dictionary = main.views
	if _alpha < 0.01 or not views.has(p.id):
		visible = false
		return
	var v: Node3D = views[p.id]
	visible = v.visible
	var at := v.global_position
	global_position = Vector3(at.x, at.y + 0.04, at.z)
	var r := maxf(0.8, p.radius + 0.4)
	scale = Vector3(r, 1.0, r)
	var cam := get_viewport().get_camera_3d()
	if cam:
		rotation.y = cam.global_rotation.y            # gomos sempre do lado da câmera (não somem atrás do corpo)
	var fills: Array = st["fills"]
	var n := fills.size()
	var arr := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	for i in range(n):
		arr[i] = float(fills[i])
	_mat.set_shader_parameter("count", n)
	_mat.set_shader_parameter("fills", arr)
	_mat.set_shader_parameter("span", deg_to_rad(PIP_SPAN if n == 1 else MULTI_SPAN))
	_mat.set_shader_parameter("gap", deg_to_rad(PIP_GAP))
	_mat.set_shader_parameter("alpha", _alpha * ALPHA)
	_mat.set_shader_parameter("glint", (_glint / GLINT_S) * AccessSettings.flash)     # clarão respeita a Acessibilidade
