class_name GvgWheel
extends Control
## Roda de ordens da guerra (segurar `gvg_orders`, V por padrão): 8 ordens do contrato + assumir/devolver o comando,
## em setores em volta do meio da tela. Soltar a tecla (ou clicar) escolhe o setor sob o mouse; no meio = nada.
## Ordem que o seu lado não pode dar (atacante x defensor) fica cinza. Só emite `chosen(id)`; quem chama a sim é o GvgHud.

signal chosen(id: String)

const RADIUS := 170.0
const INNER := 52.0
const DEAD := 28.0

var ids: Array = []
var enabled: Array = []
var commanding := false
var hover := -1

func _init() -> void:
	name = "GvgWheel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

func open(attacker: bool, is_commander: bool) -> void:
	ids = GvgUi.wheel_ids()
	commanding = is_commander
	enabled = []
	for id in ids:
		var ok := true
		for o in GvgUi.ORDERS:
			if o[0] == id:
				ok = GvgUi.order_ok(o, attacker)
		enabled.append(ok)
	hover = -1
	visible = true
	queue_redraw()

func close() -> void:
	visible = false
	hover = -1

func center() -> Vector2:
	return size * 0.5

## Escolhe o setor sob o mouse (ou `idx` direto, testes/fotos) e fecha.
func confirm(idx: int = -2) -> void:
	var i := hover if idx == -2 else idx
	close()
	if i >= 0 and i < ids.size() and bool(enabled[i]):
		chosen.emit(str(ids[i]))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := GvgUi.wheel_index((event as InputEventMouseMotion).position - center(), ids.size(), DEAD)
		if h != hover:
			hover = h
			queue_redraw()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			hover = GvgUi.wheel_index(mb.position - center(), ids.size(), DEAD)
			confirm()
		else:
			close()
		accept_event()

func _draw() -> void:
	var c := center()
	var n := ids.size()
	if n == 0:
		return
	draw_circle(c, RADIUS + 8.0, Color(0.03, 0.03, 0.05, 0.72))
	var step := TAU / n
	var font := get_theme_default_font()
	for i in n:
		var a0 := -PI * 0.5 + (i - 0.5) * step
		var pts := PackedVector2Array()
		for j in 13:
			var a := a0 + step * j / 12.0
			pts.append(c + Vector2(cos(a), sin(a)) * RADIUS)
		for j in range(12, -1, -1):
			var a := a0 + step * j / 12.0
			pts.append(c + Vector2(cos(a), sin(a)) * INNER)
		var on: bool = enabled[i]
		var col := Color(0.16, 0.13, 0.1, 0.92)
		if i == hover and on:
			col = GvgUi.WAR_COLOR.darkened(0.25)
		elif not on:
			col = Color(0.1, 0.1, 0.1, 0.8)
		draw_colored_polygon(pts, col)
		draw_polyline(pts, GvgUi.WAR_COLOR.darkened(0.4), 1.5, true)
		var mid := -PI * 0.5 + i * step
		var lp := c + Vector2(cos(mid), sin(mid)) * (INNER + RADIUS) * 0.5
		var txt := GvgUi.order_label(str(ids[i]))
		if str(ids[i]) == GvgUi.TAKE_COMMAND:
			txt = "Devolver o comando" if commanding else "Assumir o comando"
		_text(font, lp, txt, UiKit.TEXT if on else Color(0.5, 0.5, 0.5))
	draw_circle(c, INNER - 4.0, Color(0.08, 0.06, 0.05, 0.95))
	_text(font, c, "Ordens", UiKit.GOLD)

## Texto centrado em até duas linhas.
func _text(font: Font, at: Vector2, txt: String, col: Color) -> void:
	var fs := 13
	var words := txt.split(" ")
	var lines: Array = [txt]
	if words.size() > 1 and txt.length() > 10:
		var half := int(ceil(words.size() / 2.0))
		lines = [" ".join(words.slice(0, half)), " ".join(words.slice(half))]
	for li in lines.size():
		var s := str(lines[li])
		var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var y := at.y + (li - (lines.size() - 1) * 0.5) * (fs + 2) + fs * 0.35
		draw_string_outline(font, Vector2(at.x - w * 0.5, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.9))
		draw_string(font, Vector2(at.x - w * 0.5, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
