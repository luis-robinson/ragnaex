class_name GuildMissionNotice
extends Control
## Aviso único das encomendas que voltaram (banco da guilda; pedido do usuário 2026-11-27, no lugar dos cartões de
## GuildMissionCards): à esquerda do minimapa, ícone + "Lucan voltou" / "3 encomendas voltaram", pisca de leve
## (escala de AccessSettings.flash; 0 = parado). Clique = janela da Guilda na aba Missões (GuildMissionsUi).
## Some quando nada espera. Só lê a sim (Sim.guild_mission_notices).

const SIZE := Vector2(196, 40)
const BLINK_HZ := 0.8
const BORDER := Color(1.0, 0.82, 0.4)
static var src: Object = null          # fonte (testes); null = Sim

var windows: Object = null             # windows.gd do HUD (abre a janela "guild")
var panel: PanelContainer
var icon_box: Control
var text_label: Label
var _sb: StyleBoxFlat
var _sig := ""                         # ids + item desenhados (refaz só quando muda)
var _poll := 0.0
var _t := 0.0

static func _api() -> Object:
	return src if src != null else Sim

static func notices() -> Array:
	var o := _api()
	if o == null or not o.has_method("guild_mission_notices"):
		return []
	var v: Variant = o.call("guild_mission_notices")
	return v if v is Array else []

## Texto do aviso: "" (nada), "Lucan voltou" (uma) ou "3 encomendas voltaram".
static func notice_text(ns: Array) -> String:
	if ns.is_empty():
		return ""
	if ns.size() == 1:
		return "%s voltou" % str((ns[0] as Dictionary).get("name", "?"))
	return "%d encomendas voltaram" % ns.size()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sb = UiKit.panel_style(Color(0.1, 0.08, 0.14, 0.92), BORDER, 6, 2)
	panel = PanelContainer.new()
	panel.name = "Notice"
	panel.add_theme_stylebox_override("panel", _sb)
	panel.custom_minimum_size = SIZE
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -SIZE.x
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.tooltip_text = "Clique para abrir as Missões da guilda"
	panel.gui_input.connect(_on_input)
	panel.visible = false
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	icon_box = Control.new()
	icon_box.custom_minimum_size = Vector2(28, 28)
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon_box)
	text_label = UiKit.label("", 12, UiKit.GOLD)
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text_label)
	var bang := UiKit.label("!", 16, BORDER)
	bang.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bang.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bang)
	Events.guild_mission_back.connect(func(_n: Dictionary): _poll = 0.0)
	Events.guild_bank_changed.connect(func(): _poll = 0.0)
	refresh()

func _process(delta: float) -> void:
	_t += delta
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.5
		refresh()
	if panel.visible:
		var amp := 0.25 * clampf(AccessSettings.flash, 0.0, 1.0)       # pisca de leve; clarões desligados = parado
		_sb.border_color = Color(BORDER, 1.0 - amp + amp * sin(_t * TAU * BLINK_HZ))

## Refaz o aviso se a lista mudou (some sem nada esperando).
func refresh() -> void:
	var ns := notices()
	var sig := ",".join(PackedStringArray(ns.map(func(n: Dictionary): return str(n.get("id", -1)))))
	if sig == _sig and panel.visible == not ns.is_empty():
		return
	_sig = sig
	panel.visible = not ns.is_empty()
	text_label.text = notice_text(ns)
	for c in icon_box.get_children():
		c.queue_free()
	if ns.is_empty():
		return
	var it: ItemDef = GameData.items.get(str((ns[0] as Dictionary).get("item", "")))
	var ic: Control = UiKit.item_icon(it, 28) if it else UiKit.color_square(BORDER, 28)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.add_child(ic)

func _on_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		open_missions()
		panel.accept_event()

## Abre (ou traz para a aba) a janela da Guilda em Missões.
func open_missions() -> void:
	GuildUi.tab = "missions"
	GuildMissionsUi.msg = ""
	if windows == null:
		return
	if windows.is_open("guild"):
		windows.refresh_window("guild")
	else:
		windows.toggle("guild")
