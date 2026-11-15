class_name TitleScreen
extends Control
## Tela de Título (design/ux/start-flow.md §3 "Título", §4): logo no terço de cima, coluna Jogar / Configurações / Sair
## no centro-baixo (280x48), versão no canto de baixo à direita (12 px, MUTED). Entra com um fade curto (pulável).
## Teclado: ↑/↓ (dão a volta) e Enter no botão em foco; Sair pede confirmação (Esc / Cancelar fecham).
## Mouse: passar o mouse põe o foco no botão (teclado e mouse nunca destacam dois botões).
## Configurações quem abre é o `start.gd` (SettingsPanel sobreposto); enquanto ele está aberto o start chama
## `set_interactive(false)`.

## Jogar (Enter no foco inicial).
signal play_requested
## Configurações (o start abre o SettingsPanel por cima).
signal settings_requested
## Sair confirmado.
signal quit_requested

const LOGO := "res://assets/ui/logo_ragnaex.png"
const SUBTITLE := "res://assets/ui/logo_subtitle_ato2.png"
const LOGO_W := 680.0                    # px na base 1600x900 (o PNG tem 1600x600)
const LOGO_TOP := 24.0
const SUBTITLE_W := 390.0                # PNG 900x150
const SUBTITLE_OVERLAP := 30.0           # a faixa do subtítulo encosta na base do logo (como na prévia do B1)
const BUTTON_SIZE := Vector2(280, 48)
const BUTTON_GAP := 12
const COLUMN_TOP := 0.53                 # fração da altura: centro-baixo, acima do pedestal
const FADE_IN := 0.6                     # = MenuSet.TRANSITION (a spec não dá número para o fade)
const VERSION_FALLBACK := "Ato II — protótipo"
const DANGER := Color(0.92, 0.36, 0.3)

var _play_btn: Button
var _cfg_btn: Button
var _quit_btn: Button
var _buttons: Array[Button] = []
var _version: Label
var _fade: Tween = null
var _confirm: Control = null             # confirmação de Sair aberta
var _confirm_cancel: Button
var _last_focus: Button = null
var _interactive := true

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_logo()
	_build_column()
	_version = UiKit.label(version_text(), 12, UiKit.MUTED)
	_version.name = "Version"
	_version.add_theme_constant_override("outline_size", 6)          # lê sobre a grama clara do cenário
	_version.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.12, 0.9))
	_version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_version.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_version.offset_left = -420
	_version.offset_top = -30
	_version.offset_right = -16
	_version.offset_bottom = -10
	_version.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_version)
	if DisplayServer.get_name() != "headless":
		modulate.a = 0.0
		_fade = create_tween()
		_fade.tween_property(self, "modulate:a", 1.0, FADE_IN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	focus_default()

## Logo e subtítulo centrados por âncora (16:9 e 21:9 iguais), no terço de cima.
func _build_logo() -> void:
	var logo_tex := load(LOGO) as Texture2D if ResourceLoader.exists(LOGO) else null
	if logo_tex == null:                     # sem a arte: o nome em texto (nunca tela vazia)
		var l := UiKit.label("RAGNAEX", 64, UiKit.GOLD)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_center_top(l, 600.0, LOGO_TOP + 60.0, 90.0)
		return
	var h := LOGO_W * logo_tex.get_height() / maxf(1.0, logo_tex.get_width())
	var logo := _tex_rect(logo_tex, "Logo")
	_center_top(logo, LOGO_W, LOGO_TOP, h)
	if ResourceLoader.exists(SUBTITLE):
		var st := load(SUBTITLE) as Texture2D
		var sh := SUBTITLE_W * st.get_height() / maxf(1.0, st.get_width())
		var sub := _tex_rect(st, "Subtitle")
		_center_top(sub, SUBTITLE_W, LOGO_TOP + h - SUBTITLE_OVERLAP, sh)

func _tex_rect(t: Texture2D, n: String) -> TextureRect:
	var r := TextureRect.new()
	r.name = n
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

## Âncora no meio de cima: largura `w`, de `top` a `top + h`.
func _center_top(c: Control, w: float, top: float, h: float) -> void:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.offset_left = -w * 0.5
	c.offset_right = w * 0.5
	c.offset_top = top
	c.offset_bottom = top + h
	add_child(c)

func _build_column() -> void:
	var col := VBoxContainer.new()
	col.name = "Buttons"
	col.add_theme_constant_override("separation", BUTTON_GAP)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.anchor_left = 0.5
	col.anchor_right = 0.5
	col.anchor_top = COLUMN_TOP
	col.anchor_bottom = COLUMN_TOP
	col.offset_left = -BUTTON_SIZE.x * 0.5
	col.offset_right = BUTTON_SIZE.x * 0.5
	add_child(col)
	_play_btn = _big_button("Jogar", "Play", play_requested.emit, UiKit.GOLD)
	var gold := UiKit.panel_style(Color(0.3, 0.24, 0.12, 0.95), UiKit.GOLD, 4, 2)
	gold.set_content_margin_all(6)
	_play_btn.add_theme_stylebox_override("normal", gold)
	_cfg_btn = _big_button("Configurações", "Settings", settings_requested.emit, UiKit.TEXT)
	_quit_btn = _big_button("Sair", "Quit", request_quit, UiKit.TEXT)
	for b in [_play_btn, _cfg_btn, _quit_btn]:
		col.add_child(b)
		_buttons.append(b)
	for i in _buttons.size():                # ↑/↓ e Tab dão a volta na coluna
		var b := _buttons[i]
		var up := _buttons[(i + _buttons.size() - 1) % _buttons.size()]
		var down := _buttons[(i + 1) % _buttons.size()]
		b.focus_neighbor_top = b.get_path_to(up)
		b.focus_neighbor_bottom = b.get_path_to(down)
		b.focus_previous = b.get_path_to(up)
		b.focus_next = b.get_path_to(down)
		b.focus_neighbor_left = b.get_path_to(b)
		b.focus_neighbor_right = b.get_path_to(b)

func _big_button(text: String, n: String, on_pressed: Callable, color: Color) -> Button:
	var b := UiKit.button(text, on_pressed, int(BUTTON_SIZE.x))
	b.name = n
	b.custom_minimum_size.y = BUTTON_SIZE.y
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_focus_color", UiKit.GOLD.lightened(0.2))
	b.add_theme_color_override("font_hover_color", UiKit.GOLD.lightened(0.2))
	b.add_theme_color_override("font_pressed_color", UiKit.GOLD)
	var f := UiKit.panel_style(Color(1.0, 0.85, 0.4, 0.08), UiKit.GOLD, 4, 2)    # foco: borda dourada por cima
	f.expand_margin_left = 3
	f.expand_margin_right = 3
	f.expand_margin_top = 3
	f.expand_margin_bottom = 3
	b.add_theme_stylebox_override("focus", f)
	b.mouse_entered.connect(_on_hover.bind(b))
	b.focus_entered.connect(func() -> void: _last_focus = b)
	return b

func _on_hover(b: Button) -> void:
	if _interactive and _confirm == null and not b.disabled:
		b.grab_focus()

## Foco adiado só se o botão ainda estiver na árvore (a tela pode ter saído no mesmo quadro).
func _grab(b: Control) -> void:
	if is_instance_valid(b) and b.is_inside_tree() and b.focus_mode != Control.FOCUS_NONE:
		b.grab_focus()

## Foco no controle padrão da tela (Jogar). Chamado ao abrir/voltar a esta tela.
func focus_default() -> void:
	if _play_btn:
		_grab.call_deferred(_play_btn)

## false = outro painel por cima (Configurações): os botões saem do foco e do mouse; true volta o foco ao último botão.
func set_interactive(on: bool) -> void:
	_interactive = on
	for b in _buttons:
		b.focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE
		b.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	if on:
		var b := _last_focus if _last_focus and is_instance_valid(_last_focus) else _play_btn
		_grab.call_deferred(b)

## Linha da versão: `application/config/version` do projeto (vazio = texto de reserva).
static func version_text() -> String:
	var v := str(ProjectSettings.get_setting("application/config/version", ""))
	return "RagnaEx " + (("v" + v) if v != "" else VERSION_FALLBACK)

## Botões na ordem (testes): Jogar, Configurações, Sair.
func buttons() -> Array[Button]:
	return _buttons

## Termina o fade de entrada agora (clique/tecla durante a entrada).
func skip_fade() -> void:
	if _fade and _fade.is_running():
		_fade.custom_step(FADE_IN)

# ------------------------------------------------------------------ Sair (confirmação)
## Abre "Sair do jogo?" com [Cancelar] (foco) e [Sair]. Esc/Cancelar/clique fora fecham.
func request_quit() -> void:
	if _confirm != null:
		return
	_confirm = Control.new()
	_confirm.name = "QuitConfirm"
	_confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm.gui_input.connect(_on_confirm_bg)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm.add_child(center)
	var panel := UiKit.panel()
	(panel.get_theme_stylebox("panel") as StyleBoxFlat).set_content_margin_all(20)
	panel.custom_minimum_size.x = 380
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)
	var t := UiKit.label("Sair do jogo?", 20, UiKit.GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	_confirm_cancel = _small_button("Cancelar", "Cancel", cancel_quit, UiKit.TEXT)
	var ok := _small_button("Sair", "ConfirmQuit", confirm_quit, DANGER)
	row.add_child(_confirm_cancel)
	row.add_child(ok)
	for pair in [[_confirm_cancel, ok], [ok, _confirm_cancel]]:
		var a: Button = pair[0]
		var b: Button = pair[1]
		for side in ["focus_neighbor_left", "focus_neighbor_right", "focus_next", "focus_previous"]:
			a.set(side, a.get_path_to(b))
		a.focus_neighbor_top = a.get_path_to(a)
		a.focus_neighbor_bottom = a.get_path_to(a)
	add_child(_confirm)
	for b in _buttons:
		b.focus_mode = Control.FOCUS_NONE
	_grab.call_deferred(_confirm_cancel)

func _small_button(text: String, n: String, on_pressed: Callable, color: Color) -> Button:
	var b := UiKit.button(text, on_pressed, 140)
	b.name = n
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

func _on_confirm_bg(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		cancel_quit()

func cancel_quit() -> void:
	if _confirm == null:
		return
	remove_child(_confirm)
	_confirm.queue_free()
	_confirm = null
	set_interactive(_interactive)
	_grab.call_deferred(_quit_btn)

func confirm_quit() -> void:
	if _confirm == null:
		return
	cancel_quit()
	quit_requested.emit()

## Confirmação de Sair aberta (testes).
func quit_confirm_open() -> bool:
	return _confirm != null

func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if _confirm != null and k.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		cancel_quit()
