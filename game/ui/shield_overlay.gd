class_name ShieldOverlay
extends Control
## Vida temporária (barreira: `SimEntity.shield_hp`) por cima de uma barra de HP, estilo MMO:
## faixa azul-clara listrada logo depois da vida atual; se vida + barreira passa do máximo, a faixa encosta no fim
## da barra (por cima da vida) e ganha um filete branco na ponta. Fica entre o preenchimento e o texto da barra.

const COLOR := Color(0.78, 0.92, 1.0, 0.82)
const EDGE := Color(1, 1, 1, 0.95)

var span := Vector2.ZERO          # [de, até] em fração da barra (0..1); vazio = sem barreira
var over := false                 # vida + barreira > máximo

## Onde desenhar a barreira: x = início, y = fim (frações da barra), z = 1 se passa do máximo.
static func span_of(hp: float, shield: float, max_hp: float) -> Vector3:
	if shield <= 0.0 or max_hp <= 0.0:
		return Vector3.ZERO
	var h := clampf(hp / max_hp, 0.0, 1.0)
	var s := clampf(shield / max_hp, 0.0, 1.0)
	if h + s <= 1.0:
		return Vector3(h, h + s, 0.0)
	return Vector3(1.0 - s, 1.0, 1.0)

## Texto da barra: "540 / 800" ou "540 / 800 (+120)" com barreira.
static func hp_text(hp: float, max_hp: float, shield: float) -> String:
	var t := "%d / %d" % [int(hp), int(max_hp)]
	if int(shield) > 0:
		t += " (+%d)" % int(shield)
	return t

## Põe a camada dentro de uma ProgressBar, logo atrás do texto (se houver um filho de texto).
static func attach(bar: Control) -> ShieldOverlay:
	var o := ShieldOverlay.new()
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(o)
	bar.move_child(o, 0)
	return o

func set_values(hp: float, shield: float, max_hp: float) -> void:
	var sp := span_of(hp, shield, max_hp)
	var ns := Vector2(sp.x, sp.y)
	if ns.distance_to(span) > 0.002 or (sp.z > 0.5) != over:
		span = ns
		over = sp.z > 0.5
		queue_redraw()

func _draw() -> void:
	if span.y - span.x <= 0.0:
		return
	var inset := 1.0
	var w := size.x - inset * 2.0
	var x0 := inset + w * span.x
	var x1 := inset + w * span.y
	var r := Rect2(x0, inset, maxf(2.0, x1 - x0), size.y - inset * 2.0)
	draw_rect(r, COLOR)
	draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.4)), Color(1, 1, 1, 0.3))
	# listras diagonais finas: lê como "temporário" e não como vida
	var step := 6.0
	var hgt := maxf(r.size.y, 1.0)
	var x := r.position.x - hgt
	while x < r.end.x:
		var t0 := maxf(0.0, (r.position.x - x) / hgt)
		var t1 := minf(1.0, (r.end.x - x) / hgt)
		if t0 < t1:
			draw_line(Vector2(x + t0 * hgt, r.end.y - t0 * hgt), Vector2(x + t1 * hgt, r.end.y - t1 * hgt), Color(0.45, 0.7, 0.95, 0.55), 1.5)
		x += step
	draw_line(Vector2(r.position.x, r.position.y), Vector2(r.position.x, r.end.y), Color(1, 1, 1, 0.8), 1.5)
	if over:
		draw_rect(Rect2(r.end.x - 3.0, r.position.y - 1.0, 3.0, r.size.y + 2.0), EDGE)
