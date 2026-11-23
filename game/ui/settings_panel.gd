class_name SettingsPanel
extends VBoxContainer
## Configurações compartilhadas (spec `design/ux/start-flow.md` §3 "Configurações", §6): abas Geral (Gráficos, volumes, Dicas) e
## Acessibilidade (tremor, clarões, avisos com padrão, efeitos dos aliados: `AccessSettings`).
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
	for i in 2:
		var tb := UiKit.button(["Geral", "Acessibilidade"][i], show_tab.bind(i), WIDTH / 2 - 2)
		tb.name = ["TabGeneral", "TabAccess"][i]
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
	show_tab(0)

## Mostra a aba `i` (0 = Geral, 1 = Acessibilidade).
func show_tab(i: int) -> void:
	general_box.visible = i == 0
	access_box.visible = i == 1
	for k in tab_buttons.size():
		tab_buttons[k].set_pressed_no_signal(k == i)

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
