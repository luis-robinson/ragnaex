class_name TelePattern
extends RefCounted
## Padrões dos avisos nos modos de contraste (AccessSettings.contrast): triângulos com cor no vértice que vão POR CIMA
## do aviso colorido de sempre, para nenhuma mecânica depender só da cor. Por mecânica (AccessSettings.PATTERNS):
## dano = borda grossa contínua + listras diagonais; seguro = borda tracejada; dividir = anéis de dentro;
## espalhar = borda em segmentos longos; controle = borda ondulada. Toda faixa tem um contorno escuro por baixo
## (lê em chão claro e escuro).
## BossSigView junta `v`/`c` na malha dele do quadro (mesma chamada de desenho); o FxManager monta uma malha por
## aviso na criação (`commit`). Os arrays são reaproveitados (`clear` não troca o objeto).

const EDGE_W := 0.16                  # m: largura das bordas de padrão
const SOLID_W := 0.3                  # m: borda grossa do dano
const OUTLINE := 0.06                 # m a mais de cada lado no contorno escuro
const DARK := Color(0.04, 0.03, 0.05, 0.85)
const HATCH_GAP := 0.75               # m entre listras
const HATCH_W := 0.14                 # m: largura da listra
const DASH_ON := 0.55                 # tracejado (seguro)
const DASH_OFF := 0.4
const SEG_ON := 1.7                   # segmentado (espalhar): traços longos, vãos curtos
const SEG_OFF := 0.45
const WAVE_AMP := 0.16                # ondulado (controle)
const WAVE_LEN := 1.1
const WAVE_STEP := 0.22
const CIRCLE_SEGS := 48
const LIFT := 0.004                   # m: o contorno escuro fica logo abaixo da faixa

static var _material: StandardMaterial3D = null

var v := PackedVector3Array()
var c := PackedColorArray()
var _pts := PackedVector2Array()      # rascunho reaproveitado (contorno do quadro)

func clear() -> void:
	v.clear()
	c.clear()

func count() -> int:
	return v.size()

## Material único dos padrões montados (FxManager): sem luz, transparente, cor no vértice.
static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = true
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_material.disable_fog = true
	return _material

## Malha pronta (FxManager: um aviso, montado uma vez). null = nada desenhado.
func commit() -> MeshInstance3D:
	if v.is_empty():
		return null
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_COLOR] = c
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.material_override = material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

# ------------------------------------------------------------------ formas prontas
## Aviso redondo (anel de `r0` a `r`; r0 = 0 = disco) com o padrão da mecânica. `edge_col` = cor da borda, `area_col` =
## cor das listras/anéis; `hatch_ok` = false tira as listras (área com setores seguros dentro). Nada se o contraste está desligado.
func circle(mech: int, center: Vector3, r: float, edge_col: Color, area_col: Color, y: float, r0: float = 0.0,
		a0: float = 0.0, a1: float = TAU, hatch_ok: bool = true) -> void:
	var pat := AccessSettings.pattern_of(mech)
	if pat.is_empty() or r <= 0.05:
		return
	var full := absf(a1 - a0) >= TAU - 0.001
	if pat["hatch"] and full and hatch_ok:
		hatch_annulus(center, r0, r, area_col, y)
	var n := maxi(8, int(CIRCLE_SEGS * absf(a1 - a0) / TAU))
	_set_arc(center, r, a0, a1, n, not full)
	_edge(str(pat["edge"]), not full, edge_col, y)
	if r0 > 0.3:
		_set_arc(center, r0, a0, a1, maxi(8, int(n * r0 / r)), not full)
		_edge(str(pat["edge"]), not full, edge_col, y)
	if not full:                                   # setor: os dois lados retos
		for t in [a0, a1]:
			var dd := Vector2(sin(t), cos(t))
			_pts.resize(2)
			_pts[0] = Vector2(center.x, center.z) + dd * r0
			_pts[1] = Vector2(center.x, center.z) + dd * r
			_edge(str(pat["edge"]), true, edge_col, y)
	if str(pat["edge"]) == "rings":
		for k: float in [0.66, 0.33]:
			_set_arc(center, r * k, a0, a1, maxi(8, int(n * k)), not full)
			_edge("solid", not full, area_col, y, EDGE_W)

## Faixa de `start` na direção `dir` (no chão), `length` × `w`, com o padrão da mecânica.
func strip(mech: int, start: Vector3, dir: Vector3, length: float, w: float, edge_col: Color, area_col: Color, y: float) -> void:
	var pat := AccessSettings.pattern_of(mech)
	if pat.is_empty() or length <= 0.05:
		return
	var d := Vector2(dir.x, dir.z).normalized()
	var s := Vector2(-d.y, d.x) * (w * 0.5)
	var a := Vector2(start.x, start.z)
	var b := a + d * length
	_pts.resize(4)
	_pts[0] = a - s
	_pts[1] = b - s
	_pts[2] = b + s
	_pts[3] = a + s
	if pat["hatch"]:
		hatch_poly(area_col, y)
	_edge(str(pat["edge"]), false, edge_col, y)

## Leque (local: ponta em 0, abrindo para +z, abertura `ang`) com o padrão da mecânica.
func fan(mech: int, r: float, ang: float, edge_col: Color, area_col: Color, y: float) -> void:
	var pat := AccessSettings.pattern_of(mech)
	if pat.is_empty() or r <= 0.05:
		return
	if ang >= TAU - 0.01:
		circle(mech, Vector3.ZERO, r, edge_col, area_col, y)
		return
	var n := maxi(6, int(CIRCLE_SEGS * ang / TAU))
	_pts.resize(n + 2)
	_pts[0] = Vector2.ZERO
	for i in range(n + 1):
		var t := -ang * 0.5 + ang * float(i) / float(n)
		_pts[i + 1] = Vector2(sin(t), cos(t)) * r
	if pat["hatch"]:
		hatch_poly(area_col, y)
	_edge(str(pat["edge"]), false, edge_col, y)

# ------------------------------------------------------------------ peças
## Listras diagonais (45° no mundo) cortadas no anel r0..r1 em volta de `center`.
func hatch_annulus(center: Vector3, r0: float, r1: float, col: Color, y: float) -> void:
	var dir := Vector3(0.70710678, 0, 0.70710678)
	var nrm := Vector3(-0.70710678, 0, 0.70710678)
	var d := -r1 + HATCH_GAP * 0.5
	while d < r1:
		var h1 := sqrt(maxf(0.0, r1 * r1 - d * d))
		var mid := Vector3(center.x, y, center.z) + nrm * d
		if absf(d) < r0:
			var h0 := sqrt(maxf(0.0, r0 * r0 - d * d))
			_hatch_seg(mid - dir * h1, mid - dir * h0, nrm, col)
			_hatch_seg(mid + dir * h0, mid + dir * h1, nrm, col)
		else:
			_hatch_seg(mid - dir * h1, mid + dir * h1, nrm, col)
		d += HATCH_GAP

## Listras diagonais cortadas no polígono convexo de `_pts`.
func hatch_poly(col: Color, y: float) -> void:
	var dir := Vector2(0.70710678, 0.70710678)
	var nrm := Vector2(-0.70710678, 0.70710678)
	var lo := INF
	var hi := -INF
	for p in _pts:
		lo = minf(lo, p.dot(nrm))
		hi = maxf(hi, p.dot(nrm))
	var d := lo + HATCH_GAP * 0.5
	while d < hi:
		var t0 := INF
		var t1 := -INF
		var n := _pts.size()
		for i in range(n):
			var a := _pts[i]
			var b := _pts[(i + 1) % n]
			var da := a.dot(nrm) - d
			var db := b.dot(nrm) - d
			if (da <= 0.0) != (db <= 0.0):
				var q := a.lerp(b, da / (da - db))
				t0 = minf(t0, q.dot(dir))
				t1 = maxf(t1, q.dot(dir))
		if t1 > t0:
			var o := nrm * d
			var pa := o + dir * t0
			var pb := o + dir * t1
			_hatch_seg(Vector3(pa.x, y, pa.y), Vector3(pb.x, y, pb.y), Vector3(nrm.x, 0, nrm.y), col)
		d += HATCH_GAP

func _hatch_seg(a: Vector3, b: Vector3, nrm: Vector3, col: Color) -> void:
	if a.distance_squared_to(b) < 0.01:
		return
	var s := nrm * (HATCH_W * 0.5)
	_quad(a - s, b - s, b + s, a + s, col)

## Contorno de `_pts` no estilo pedido (fechado salvo `open`).
func _edge(style: String, open: bool, col: Color, y: float, w: float = -1.0) -> void:
	var n := _pts.size()
	if n < 2:
		return
	var segs := n - 1 if open else n
	var width := w if w > 0.0 else (SOLID_W if style == "solid" else EDGE_W)
	var s := 0.0                                  # distância andada (tracejado e onda seguem a volta toda)
	for i in range(segs):
		var a := _pts[i]
		var b := _pts[(i + 1) % n]
		var ln := a.distance_to(b)
		if ln < 0.0001:
			continue
		match style:
			"dash", "segment":
				var on := DASH_ON if style == "dash" else SEG_ON
				var period := on + (DASH_OFF if style == "dash" else SEG_OFF)
				var u := 0.0
				while u < ln:
					var ph := fmod(s + u, period)
					var step := minf(ln - u, (on - ph) if ph < on else (period - ph))
					if ph < on:
						_band(a.lerp(b, u / ln), a.lerp(b, (u + step) / ln), width, col, y)
					u += maxf(step, 0.001)
			"wave":
				var steps := maxi(1, ceili(ln / WAVE_STEP))
				var nrm := Vector2(-(b.y - a.y), b.x - a.x) / ln
				var prev := a + nrm * (WAVE_AMP * sin(TAU * s / WAVE_LEN))
				for k in range(1, steps + 1):
					var f := float(k) / float(steps)
					var cur := a.lerp(b, f) + nrm * (WAVE_AMP * sin(TAU * (s + ln * f) / WAVE_LEN))
					_band(prev, cur, width, col, y)
					prev = cur
			_:
				_band(a, b, width, col, y)
		s += ln

## Faixa de a até b (2D no chão) com contorno escuro por baixo.
func _band(a: Vector2, b: Vector2, w: float, col: Color, y: float) -> void:
	var d := b - a
	var ln := d.length()
	if ln < 0.0001:
		return
	d /= ln
	var nrm := Vector2(-d.y, d.x)
	var ow := nrm * (w * 0.5 + OUTLINE)
	var oe := d * OUTLINE * 0.5                       # o contorno passa um pouco das pontas (junta as emendas)
	_quad(_g(a - ow - oe, y - LIFT), _g(b - ow + oe, y - LIFT), _g(b + ow + oe, y - LIFT), _g(a + ow - oe, y - LIFT), DARK)
	var iw := nrm * (w * 0.5)
	_quad(_g(a - iw, y), _g(b - iw, y), _g(b + iw, y), _g(a + iw, y), col)

static func _g(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)

## Arco de raio r em `_pts` (n divisões).
func _set_arc(center: Vector3, r: float, a0: float, a1: float, n: int, open: bool) -> void:
	var cnt := n + 1 if open else n
	_pts.resize(cnt)
	for i in range(cnt):
		var t := a0 + (a1 - a0) * float(i) / float(n)
		_pts[i] = Vector2(center.x + sin(t) * r, center.z + cos(t) * r)

func _quad(a: Vector3, b: Vector3, cc: Vector3, d: Vector3, col: Color) -> void:
	v.append(a); v.append(b); v.append(cc)
	v.append(a); v.append(cc); v.append(d)
	for i in 6:
		c.append(col)
