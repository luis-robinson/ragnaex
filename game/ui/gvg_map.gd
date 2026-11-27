class_name GvgMap
extends Control
## Mapinha do campo da guerra (gvg_field, contrato wave6 §1) na tela de preparação: dois castelos, rio com as pontes,
## morro dos canhões, portões e cristais, e o plano do comandante em setas, uma cor por papel. Só desenho.
## As rotas são ilustração do plano (não a rota da IA): escritas para "atacante no Sul" / "defensor no Norte" e
## espelhadas por (x, z) -> (-x, -z) quando o lado é o outro.

const FIELD := Rect2(-100, -60, 200, 120)          # x, z do campo
const GATES := {"main_N": Vector2(0, -30), "side_N": Vector2(-38, -40), "main_S": Vector2(0, 30), "side_S": Vector2(38, 40)}
const CRYSTALS := {"N": Vector2(0, -48), "S": Vector2(0, 48)}
const HILL := Vector2(0, 0)
const BRIDGES := [Vector2(-45, 0), Vector2(45, 0)]
## Rotas do ATACANTE vindo do Sul contra o Norte.
const A_WEST := [Vector2(-6, 20), Vector2(-45, 6), Vector2(-45, -6), Vector2(-4, -27)]
const A_EAST := [Vector2(6, 20), Vector2(45, 6), Vector2(45, -6), Vector2(4, -27)]
const A_SIDE := [Vector2(-12, 22), Vector2(-46, 7), Vector2(-46, -8), Vector2(-38, -37)]
const A_HILL := [Vector2(0, 22), Vector2(0, 7)]
const A_BACK := [Vector2(0, 24), Vector2(0, 17)]
const A_CURE := [Vector2(-10, 24), Vector2(-42, 9)]
## Rotas do DEFENSOR no Norte.
const D_WALL_L := [Vector2(0, -42), Vector2(-14, -34)]
const D_WALL_R := [Vector2(0, -42), Vector2(14, -34)]
const D_GATE := [Vector2(0, -44), Vector2(0, -33)]
const D_OUT := [Vector2(0, -33), Vector2(42, -8), Vector2(42, 6), Vector2(8, 16)]
const D_STAIR := [Vector2(0, -36), Vector2(0, -44)]
const D_SIDE := [Vector2(-10, -44), Vector2(-34, -41)]
## plano -> [[papel, rota], ...]
const PLAN_ROUTES := {
	"martelo": [["muro", A_WEST], ["ponta", A_EAST], ["cura", A_CURE], ["artilharia", A_HILL], ["batedor", A_EAST]],
	"pinca": [["muro", A_WEST], ["ponta", A_EAST], ["batedor", A_SIDE], ["cura", A_CURE], ["artilharia", A_HILL]],
	"bateria": [["artilharia", A_HILL], ["muro", [Vector2(-8, 22), Vector2(-4, 8)]], ["ponta", [Vector2(8, 22), Vector2(5, 8)]], ["cura", A_BACK]],
	"cerco_lento": [["artilharia", A_HILL], ["muro", A_BACK], ["cura", A_BACK], ["batedor", A_SIDE]],
	"muralha": [["muro", D_GATE], ["artilharia", D_WALL_L], ["artilharia", D_WALL_R], ["cura", D_STAIR], ["batedor", D_SIDE]],
	"surtida": [["ponta", D_OUT], ["muro", D_OUT], ["artilharia", D_WALL_L], ["cura", D_GATE]],
	"recuo": [["muro", D_STAIR], ["cura", D_STAIR], ["ponta", D_STAIR], ["artilharia", D_WALL_R]],
}

var plan := ""
var attacker := "S"
var player_side := "S"
var gates: Dictionary = {}          # chave -> 0..1 (status.gates)

## Rota já no lado certo (espelha quando o atacante é o Norte ou o defensor é o Sul).
static func oriented(route: Array, atk_side: String) -> Array:
	var out: Array = []
	for p in route:
		var v: Vector2 = p
		out.append(-v if atk_side == "N" else v)      # base: atacante no Sul, defensor no Norte (vale para os dois tipos de plano)
	return out

func _to_px(v: Vector2) -> Vector2:
	return Vector2((v.x - FIELD.position.x) / FIELD.size.x * size.x, (v.y - FIELD.position.y) / FIELD.size.y * size.y)

func _draw() -> void:
	var k := size.x / FIELD.size.x
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.32, 0.42, 0.26))
	# rio e pontes
	draw_rect(Rect2(_to_px(Vector2(-100, -3)), Vector2(size.x, 6 * k)), Color(0.28, 0.45, 0.7))
	for b in BRIDGES:
		draw_rect(Rect2(_to_px(b + Vector2(-4, -5)), Vector2(8, 10) * k), Color(0.55, 0.42, 0.28))
	draw_circle(_to_px(HILL), 11 * k, Color(0.42, 0.5, 0.3))
	for c in [Vector2(-6, -4), Vector2(6, 4)]:
		draw_circle(_to_px(c), 1.6 * k, Color(0.15, 0.15, 0.15))
	# castelos
	for s in GvgUi.SIDES:
		var z := -1.0 if s == "N" else 1.0
		var col := GvgUi.SIDE_COLORS[s] as Color
		var r := Rect2(_to_px(Vector2(-44, 28.0 if z > 0.0 else -58.0)), Vector2(88, 30) * k)
		draw_rect(r, Color(0.5, 0.48, 0.45))
		draw_rect(r, col.darkened(0.2), false, 2.0)
		draw_circle(_to_px(CRYSTALS[s]), 2.4 * k, col.lightened(0.4))
		for g in ["main", "side"]:
			var key := "%s_%s" % [g, s]
			var hp := float(gates.get(key, 1.0))
			var gc := Color(0.2, 0.15, 0.1) if hp > 0.0 else Color(1.0, 0.45, 0.2)
			var gw := (6.0 if g == "main" else 4.0) * k
			draw_rect(Rect2(_to_px(GATES[key]) - Vector2(gw * 0.5, 1.5 * k), Vector2(gw, 3 * k)), gc)
	# plano
	for item in PLAN_ROUTES.get(plan, []):
		var role := str(item[0])
		var col: Color = GvgUi.ROLES[role][2]
		_arrow(oriented(item[1], attacker), col)
	# você
	var you := Vector2(0, 54) if player_side == "S" else Vector2(0, -54)
	draw_circle(_to_px(you), 2.2 * k, Color(1, 1, 1))

func _arrow(route: Array, col: Color) -> void:
	var pts := PackedVector2Array()
	for p in route:
		pts.append(_to_px(p))
	if pts.size() < 2:
		return
	draw_polyline(pts, Color(0, 0, 0, 0.5), 5.0, true)
	draw_polyline(pts, col, 3.0, true)
	var a := pts[pts.size() - 1]
	var d := (a - pts[pts.size() - 2]).normalized()
	var n := Vector2(-d.y, d.x)
	draw_colored_polygon(PackedVector2Array([a + d * 7.0, a - d * 5.0 + n * 6.0, a - d * 5.0 - n * 6.0]), col)
