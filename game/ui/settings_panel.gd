class_name SettingsPanel
extends VBoxContainer
## Configurações compartilhadas (spec `design/ux/start-flow.md` §3 "Configurações", §6): abas Geral (Gráficos, volumes, Dicas),
## Acessibilidade (tremor, clarões, avisos com padrão, efeitos dos aliados: `AccessSettings`) e Controles (trocar teclas: `KeyBindings`).
## O menu Esc do HUD põe estas linhas dentro do painel dele; a tela de título abre `SettingsPanel.overlay(...)`.
## A verdade continua em `GraphicsSettings`/`AudioSettings` (e `Tips` para as dicas): aqui só a interface.

const WIDTH := 240

## Dicas do jogo em curso (o HUD passa a dele); null = tela de título, lê/grava `settings.cfg` direto.
var tips: Tips = null
var gfx_button: Button
var tips_button: Button
var sliders: Dictionary = {}          # barramento -> HSlider

static func create(tips_: Tips = null) -> SettingsPanel:
	var p := SettingsPanel.new()
	p.tips = tips_
	return p

func _init() -> void:
	name = "SettingsPanel"
	add_theme_constant_override("separation", 8)

var general_box: VBoxContainer          # aba Geral: Gráficos, volumes, Dicas
var access_box: VBoxContainer           # aba Acessibilidade (AccessSettings)
var controls_box: VBoxContainer         # aba Controles (KeyBindings)
const TAB_NAMES := ["Geral", "Acessibilidade", "Controles"]
const TAB_IDS := ["general", "access", "controls"]        # --settings_tab=<id ou índice>
const CONTROLS_W := 330
const KEY_BUTTON_W := 130
var key_buttons: Dictionary = {}        # ação -> Button com a tecla de agora
var capturing := ""                     # ação esperando a próxima tecla/botão ("" = nenhuma)
var key_notice: Label                   # aviso curto da última troca
var tab_buttons: Array[Button] = []
var shake_slider: HSlider
var flash_slider: HSlider
var contrast_button: Button
var ally_button: Button

func _ready() -> void:
	var tabs := HBoxContainer.new()
	tabs.name = "Tabs"
	tabs.add_theme_constant_override("separation", 4)
	add_child(tabs)
	var group := ButtonGroup.new()
	for i in TAB_NAMES.size():
		var tb := UiKit.button(TAB_NAMES[i], show_tab.bind(i), 0)
		tb.name = ["TabGeneral", "TabAccess", "TabControls"][i]
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.toggle_mode = true
		tb.button_group = group
		tb.focus_mode = Control.FOCUS_ALL
		tb.add_theme_font_size_override("font_size", 13)
		tabs.add_child(tb)
		tab_buttons.append(tb)
	general_box = VBoxContainer.new()
	general_box.name = "General"
	general_box.add_theme_constant_override("separation", 8)
	add_child(general_box)
	gfx_button = UiKit.button("", Callable(), WIDTH)
	gfx_button.name = "Graphics"
	gfx_button.text = "Gráficos: " + GraphicsSettings.name()
	gfx_button.tooltip_text = "Nítido: imagem mais limpa (padrão).
FSR 2: renderiza menor e reconstrói — mais FPS em PC fraco, contorno pode tremular."
	gfx_button.pressed.connect(_cycle_graphics)
	gfx_button.add_theme_font_size_override("font_size", 13)
	general_box.add_child(gfx_button)
	for bus in AudioSettings.BUSES:
		general_box.add_child(_volume_row(bus))
	tips_button = UiKit.button("", Callable(), WIDTH)
	tips_button.name = "Tips"
	tips_button.tooltip_text = "Cartões curtos que explicam cada mecânica na primeira vez que ela aparece."
	tips_button.pressed.connect(_toggle_tips)
	tips_button.add_theme_font_size_override("font_size", 13)
	general_box.add_child(tips_button)
	_tips_text()
	_build_access()
	_build_controls()
	show_tab(0)

## Mostra a aba `i` (0 = Geral, 1 = Acessibilidade, 2 = Controles). Trocar de aba cancela a espera de tecla.
func show_tab(i: int) -> void:
	general_box.visible = i == 0
	access_box.visible = i == 1
	controls_box.visible = i == 2
	if i != 2:
		cancel_capture()
	for k in tab_buttons.size():
		tab_buttons[k].set_pressed_no_signal(k == i)

## Índice da aba por id ("general"/"access"/"controls") ou número ("2"); -1 se não existe.
static func tab_index(id: String) -> int:
	if id.is_valid_int():
		var n := int(id)
		return n if n >= 0 and n < TAB_NAMES.size() else -1
	return TAB_IDS.find(id)

# ------------------------------------------------------------------ controles
## Lista de ações (KeyBindings.ACTIONS) por grupo: nome + botão com a tecla. Clicar = "pressione uma tecla";
## a próxima tecla/botão do mouse vira a tecla (Esc cancela); tecla de outra ação = as duas trocam (aviso).
func _build_controls() -> void:
	controls_box = VBoxContainer.new()
	controls_box.name = "Controls"
	controls_box.add_theme_constant_override("separation", 6)
	add_child(controls_box)
	var scroll := ScrollContainer.new()
	scroll.name = "KeyScroll"
	scroll.custom_minimum_size = Vector2(CONTROLS_W, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	controls_box.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "KeyList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 3)
	scroll.add_child(list)
	var group := ""
	for a in KeyBindings.ACTIONS:
		if str(a[2]) != group:
			group = str(a[2])
			list.add_child(UiKit.label(group, 13, UiKit.GOLD))
		var row := HBoxContainer.new()
		row.name = "Key_" + str(a[0])
		var l := UiKit.label(str(a[1]), 12)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var b := UiKit.button("", _start_capture.bind(str(a[0])), KEY_BUTTON_W)
		b.name = "Bind"
		b.focus_mode = Control.FOCUS_ALL
		b.add_theme_font_size_override("font_size", 12)
		b.tooltip_text = "Clique e aperte a nova tecla ou botão do mouse. Esc cancela."
		row.add_child(b)
		key_buttons[str(a[0])] = b
		list.add_child(row)
	key_notice = UiKit.label("", 12, UiKit.GOLD)
	key_notice.name = "KeyNotice"
	key_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	key_notice.custom_minimum_size.x = CONTROLS_W
	controls_box.add_child(key_notice)
	var fixed := UiKit.label(KeyBindings.FIXED_NOTE, 11, UiKit.MUTED)
	fixed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fixed.custom_minimum_size.x = CONTROLS_W
	controls_box.add_child(fixed)
	var reset := UiKit.button("Restaurar padrões", _restore_keys, CONTROLS_W)
	reset.name = "RestoreKeys"
	reset.focus_mode = Control.FOCUS_ALL
	reset.add_theme_font_size_override("font_size", 13)
	controls_box.add_child(reset)
	_keys_text()

func _keys_text() -> void:
	for a in key_buttons:
		(key_buttons[a] as Button).text = "pressione uma tecla..." if a == capturing else KeyBindings.label(a)

func _start_capture(action: String) -> void:
	capturing = action
	key_notice.text = "%s: pressione uma tecla ou botão do mouse (Esc cancela)" % KeyBindings.action_name(action)
	_keys_text()

## Para de esperar tecla sem mudar nada.
func cancel_capture() -> void:
	if capturing == "":
		return
	capturing = ""
	if key_notice:
		key_notice.text = ""
	_keys_text()

## Esperando tecla: a próxima tecla/botão é da ação (o evento não segue para o jogo nem para a interface).
func _input(event: InputEvent) -> void:
	if capturing == "" or not is_visible_in_tree():
		return
	var press: bool = (event is InputEventKey and event.pressed and not event.is_echo()) or (event is InputEventMouseButton and event.pressed)
	if not press:
		return
	get_viewport().set_input_as_handled()
	if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		cancel_capture()
		key_notice.text = "Troca cancelada"
		return
	apply_capture(event)

## Liga o evento à ação que espera (usado pelo _input e pelos testes). Devolve o aviso mostrado.
func apply_capture(event: InputEvent) -> String:
	var action := capturing
	capturing = ""
	var msg := ""
	if action == "":
		return msg
	if KeyBindings.is_fixed(event):
		msg = "%s é fixa (não pode ser usada)" % KeyBindings.event_label(event)
	else:
		var other := KeyBindings.rebind(action, event)
		KeyBindings.save()
		msg = "%s → %s" % [KeyBindings.action_name(action), KeyBindings.label(action)]
		if other != "":
			msg += "  ·  trocou com %s (agora %s)" % [KeyBindings.action_name(other), KeyBindings.label(other)]
	key_notice.text = msg
	_keys_text()
	return msg

func _restore_keys() -> void:
	capturing = ""
	KeyBindings.reset_defaults()
	KeyBindings.save()
	key_notice.text = "Teclas padrão restauradas"
	_keys_text()

# ------------------------------------------------------------------ acessibilidade
func _build_access() -> void:
	access_box = VBoxContainer.new()
	access_box.name = "Access"
	access_box.add_theme_constant_override("separation", 8)
	add_child(access_box)
	shake_slider = _pct_row(access_box, "Shake", "Tremor da tela", AccessSettings.shake,
		"Quanto a câmera treme nos golpes fortes. 0% = câmera parada.", func(x: float): AccessSettings.set_shake(x))
	flash_slider = _pct_row(access_box, "Flash", "Clarões", AccessSettings.flash,
		"Brilho do personagem atingido e dos clarões de skills e Supremas. 0% = sem clarões.", func(x: float): AccessSettings.set_flash(x))
	contrast_button = UiKit.button("", _cycle_contrast, WIDTH)
	contrast_button.name = "Contrast"
	contrast_button.focus_mode = Control.FOCUS_ALL
	contrast_button.tooltip_text = "Avisos de chefe e monstro com desenho próprio por mecânica (não só a cor):
dano = borda grossa e listras · seguro = borda tracejada · dividir = anéis por dentro
espalhar = borda em segmentos · controle = borda ondulada.
Daltônico troca também as cores por laranja / azul / amarelo / roxo."
	contrast_button.add_theme_font_size_override("font_size", 13)
	access_box.add_child(contrast_button)
	ally_button = UiKit.button("", _cycle_ally, WIDTH)
	ally_button.name = "AllyFx"
	ally_button.focus_mode = Control.FOCUS_ALL
	ally_button.tooltip_text = "Efeitos e números de dano dos OUTROS personagens (grupo e bots).
Os seus e os avisos de perigo aparecem sempre."
	ally_button.add_theme_font_size_override("font_size", 13)
	access_box.add_child(ally_button)
	_access_text()

## Linha: nome + barra 0-100% + valor (salva ao mexer).
func _pct_row(box: Container, id: String, text: String, value: float, tip: String, on_change: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.name = "Row_" + id
	row.tooltip_text = tip
	var l := UiKit.label(text, 12)
	l.custom_minimum_size.x = 96
	row.add_child(l)
	var sl := HSlider.new()
	sl.name = id
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = value
	sl.tooltip_text = tip
	sl.custom_minimum_size.x = 100
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(sl)
	var pct := UiKit.label("%d%%" % roundi(value * 100.0), 12)
	pct.custom_minimum_size.x = 40
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(pct)
	sl.value_changed.connect(func(x: float): on_change.call(x); pct.text = "%d%%" % roundi(x * 100.0))
	box.add_child(row)
	return sl

func _cycle_contrast() -> void:
	AccessSettings.cycle_contrast()
	_access_text()

func _cycle_ally() -> void:
	AccessSettings.cycle_ally_fx()
	_access_text()

func _access_text() -> void:
	contrast_button.text = "Avisos: " + AccessSettings.contrast_name()
	ally_button.text = "Efeitos dos aliados: " + AccessSettings.ally_fx_name()

func _cycle_graphics() -> void:
	gfx_button.text = "Gráficos: " + GraphicsSettings.cycle(get_viewport())

## Linha: nome do barramento + barra de volume (salva ao mexer).
func _volume_row(bus: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Vol_" + bus
	var l := UiKit.label(AudioSettings.LABELS[bus], 12)
	l.custom_minimum_size.x = 96
	row.add_child(l)
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = AudioSettings.volume[bus]
	sl.custom_minimum_size.x = 140
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sl.value_changed.connect(func(x: float): AudioSettings.set_volume(bus, x))
	row.add_child(sl)
	sliders[bus] = sl
	return row

# ------------------------------------------------------------------ dicas
func tips_enabled() -> bool:
	return tips.enabled if tips else SettingsPanel.saved_tips_enabled()

func _toggle_tips() -> void:
	if tips:
		tips.set_enabled(not tips.enabled)
	else:
		SettingsPanel.save_tips_enabled(not SettingsPanel.saved_tips_enabled())
	_tips_text()

func _tips_text() -> void:
	tips_button.text = "Dicas: " + ("ligadas" if tips_enabled() else "desligadas")

## Fora do jogo (título): o mesmo `tips/enabled` que a `Tips` lê ao entrar.
static func saved_tips_enabled() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(Tips.cfg_path) != OK:
		return true
	return bool(cfg.get_value("tips", "enabled", true))

static func save_tips_enabled(on: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(Tips.cfg_path)                # mantém gráficos/áudio/dicas vistas
	cfg.set_value("tips", "enabled", on)
	cfg.save(Tips.cfg_path)

# ------------------------------------------------------------------ painel sobreposto (título)
## Painel "Configurações" sobre a tela (escurece o fundo): título, as linhas e [Fechar]. Esc também fecha
## (quem abre trata o Esc chamando `close_overlay`). Devolve o fundo escurecido (raiz do painel).
static func overlay(parent: Control, tips_: Tips = null, on_close: Callable = Callable()) -> Control:
	var dim := ColorRect.new()
	dim.name = "SettingsOverlay"
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := UiKit.panel()
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var t := UiKit.title("Configurações")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sp := SettingsPanel.create(tips_)
	v.add_child(sp)
	var close := UiKit.button("Fechar", func(): SettingsPanel.close_overlay(dim, on_close), WIDTH)
	close.name = "Close"
	close.add_theme_font_size_override("font_size", 15)
	v.add_child(close)
	sp.gfx_button.grab_focus.call_deferred()
	return dim

static func close_overlay(dim: Control, on_close: Callable = Callable()) -> void:
	if is_instance_valid(dim):
		dim.queue_free()
	if on_close.is_valid():
		on_close.call()
