class_name DeleteDialog
extends Control
## Confirmação de exclusão de personagem (design/ux/start-flow.md §4, §5): modal sobre a lista, fundo escurecido.
## [Cancelar] tem o foco (Enter cancela por padrão), [Excluir] em vermelho; Esc cancela; ←/→/Tab trocam o botão.
## Quem abre liga `confirmed`/`cancelled` e fecha o diálogo (o diálogo não se libera sozinho).

## Excluir confirmado.
signal confirmed
## Cancelar / Esc / clique fora.
signal cancelled

const DANGER := Color(0.92, 0.36, 0.3)

var _text := ""
var _msg: Label
var _cancel_btn: Button
var _ok_btn: Button

## Texto da pergunta (ex.: "Excluir Lyra (Druida, Nível 12)? Isso não pode ser desfeito.").
func setup(text: String) -> void:
	_text = text
	if _msg:
		_msg.text = text

## Texto mostrado (testes).
func message() -> String:
	return _text

## Botão que recebe o foco ao abrir (Cancelar).
func default_button() -> Button:
	return _cancel_btn

func confirm() -> void:
	confirmed.emit()

func cancel() -> void:
	cancelled.emit()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP           # modal: nada atrás recebe o mouse
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := UiKit.panel(UiKit.BG, DANGER.darkened(0.25))
	(panel.get_theme_stylebox("panel") as StyleBoxFlat).set_content_margin_all(20)
	panel.custom_minimum_size.x = 540
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	v.add_child(UiKit.label("Excluir personagem", 20, UiKit.GOLD))
	_msg = UiKit.para(_text, 15, UiKit.TEXT)
	v.add_child(_msg)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	_cancel_btn = _button("Cancelar", cancel, UiKit.TEXT)
	_ok_btn = _button("Excluir", confirm, DANGER)
	row.add_child(_cancel_btn)
	row.add_child(_ok_btn)
	for pair in [[_cancel_btn, _ok_btn], [_ok_btn, _cancel_btn]]:
		var a: Button = pair[0]
		var b: Button = pair[1]
		a.focus_neighbor_left = a.get_path_to(b)
		a.focus_neighbor_right = a.get_path_to(b)
		a.focus_next = a.get_path_to(b)
		a.focus_previous = a.get_path_to(b)
		a.focus_neighbor_top = a.get_path_to(a)
		a.focus_neighbor_bottom = a.get_path_to(a)
	_focus_default.call_deferred()

func _focus_default() -> void:
	if is_inside_tree() and _cancel_btn:
		_cancel_btn.grab_focus()

func _button(text: String, on_pressed: Callable, color: Color) -> Button:
	var b := UiKit.button(text, on_pressed, 150)
	b.custom_minimum_size.y = 44
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_focus_color", color.lightened(0.25))
	b.add_theme_color_override("font_hover_color", color.lightened(0.25))
	var f := UiKit.panel_style(Color(0, 0, 0, 0), UiKit.GOLD, 4, 2)
	f.draw_center = false
	b.add_theme_stylebox_override("focus", f)
	return b

func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:      # clique no fundo escuro = cancelar
		accept_event()
		cancel()

func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		cancel()
	elif k.keycode in [KEY_ENTER, KEY_KP_ENTER]:             # sem botão em foco: Enter = Cancelar (o seguro)
		get_viewport().set_input_as_handled()
		cancel()
