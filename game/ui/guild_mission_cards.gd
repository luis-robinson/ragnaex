class_name GuildMissionCards
extends Control
## Cartões de volta das encomendas do banco da guilda (design/gdd/banco-da-guilda.md §3.7, §9.3): à esquerda do
## minimapa, um por encomenda que voltou (retrato do bot + ícone do item), piscando de leve. Clique = mensagem do bot
## + "Pôr na bolsa" (Sim.guild_mission_collect). Só lê a sim (Sim.guild_mission_notices) e age pelos métodos dela.

const CARD := Vector2(132, 56)
const BLINK_HZ := 0.8
const BORDER := Color(1.0, 0.82, 0.4)
static var src: Object = null          # fonte (testes); null = Sim

var stack: VBoxContainer
var popup: PanelContainer
var _ids: Array = []                   # ids dos avisos desenhados (refaz só quando muda)
var _poll := 0.0
var _t := 0.0
var open_id := -1
var popup_msg := ""
var _msg_for := -1                     # aviso a que o popup_msg se refere

static func _api() -> Object:
	return src if src != null else Sim

static func notices() -> Array:
	var o := _api()
	if o == null or not o.has_method("guild_mission_notices"):
		return []
	var v: Variant = o.call("guild_mission_notices")
	return v if v is Array else []

## Texto curto do cartão: "Rook voltou" / "12 Presa de Lince".
static func card_lines(n: Dictionary) -> Array:
	var it: ItemDef = GameData.items.get(str(n.get("item", "")))
	var what := ("%d %s" % [int(n.get("count", 0)), it.name]) if it and int(n.get("count", 0)) > 1 else (it.name if it else "")
	return ["%s voltou" % str(n.get("name", "?")), what]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.anchor_left = 1.0
	stack.anchor_right = 1.0
	stack.offset_left = -CARD.x
	stack.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(stack)
	Events.guild_mission_back.connect(func(_n: Dictionary): _poll = 0.0)
	Events.guild_bank_changed.connect(func(): _poll = 0.0)

func _process(delta: float) -> void:
	_t += delta
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.5
		refresh()
	var a := 0.75 + 0.25 * sin(_t * TAU * BLINK_HZ)        # pisca de leve
	for c in stack.get_children():
		var sb: StyleBoxFlat = (c as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
		if sb:
			sb.border_color = Color(BORDER, a)

## Refaz os cartões se a lista de avisos mudou.
func refresh() -> void:
	var ns := notices()
	var ids: Array = ns.map(func(n: Dictionary): return int(n.get("id", -1)))
	if ids == _ids:
		return
	_ids = ids
	for c in stack.get_children():
		c.queue_free()
	for n: Dictionary in ns:
		stack.add_child(_card(n))
	if open_id >= 0 and not (open_id in ids):
		close_popup()

func _card(n: Dictionary) -> Control:
	var sb := UiKit.panel_style(Color(0.1, 0.08, 0.14, 0.92), BORDER, 6, 2)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = CARD
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	p.name = "notice_%d" % int(n.get("id", -1))
	p.tooltip_text = "Clique para ver a mensagem"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	var cls: ClassDef = GameData.classes.get(str(n.get("class", "")))
	var face := UiKit.class_icon(cls, 40) if cls else UiKit.color_square(Color(0.3, 0.3, 0.35), 40)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(face)
	var it: ItemDef = GameData.items.get(str(n.get("item", "")))
	if it:
		var ic := UiKit.item_icon(it, 32)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ic)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(v)
	var ls := card_lines(n)
	var l1 := UiKit.label(str(ls[0]), 11, UiKit.GOLD)
	l1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l1)
	var l2 := UiKit.label("!", 16, BORDER)
	l2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l2)
	p.gui_input.connect(_on_card_input.bind(int(n.get("id", -1))))
	return p

func _on_card_input(ev: InputEvent, id: int) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		open(id)
		accept_event()

## Abre a mensagem do aviso `id` (ao lado dos cartões).
func open(id: int) -> void:
	close_popup()
	var n: Dictionary = {}
	for x: Dictionary in notices():
		if int(x.get("id", -1)) == id:
			n = x
	if n.is_empty():
		return
	if id != _msg_for:
		popup_msg = ""
	open_id = id
	popup = UiKit.panel(Color(0.08, 0.07, 0.11, 0.96), BORDER)
	popup.name = "NoticePopup"
	popup.custom_minimum_size = Vector2(300, 0)
	popup.anchor_left = 1.0
	popup.anchor_right = 1.0
	popup.offset_left = -CARD.x - 350
	popup.offset_right = -CARD.x - 40
	popup.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(popup)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	popup.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var cls: ClassDef = GameData.classes.get(str(n.get("class", "")))
	head.add_child(UiKit.class_icon(cls, 48) if cls else UiKit.color_square(Color(0.3, 0.3, 0.35), 48))
	head.add_child(UiKit.label(str(n.get("name", "?")), 16, UiKit.GOLD))
	v.add_child(UiKit.para("“%s”" % str(n.get("text", "")), 13, UiKit.TEXT))
	for pair in n.get("items", []):
		var it: ItemDef = GameData.items.get(str(pair[0]))
		if it == null:
			continue
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		r.add_child(UiKit.item_icon(it, 32))
		r.add_child(UiKit.label("%s x%d" % [it.name, int(pair[1])], 13, UiKit.rarity_color(it.rarity)))
		v.add_child(r)
	if int(n.get("gold", 0)) > 0:
		v.add_child(UiKit.label("+%d de ouro (metade da taxa)" % int(n.get("gold", 0)), 13, UiKit.GOLD))
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	v.add_child(bar)
	var b := UiKit.button(popup_msg if popup_msg != "" else "Pôr na bolsa", _collect.bind(id), 150)
	b.name = "CollectButton"
	bar.add_child(b)
	bar.add_child(UiKit.button("Fechar", close_popup, 80))

func _collect(id: int) -> void:
	var o := _api()
	var err := str(o.call("guild_mission_collect", id)) if o and o.has_method("guild_mission_collect") else "Indisponível."
	if err == "":
		popup_msg = ""
		close_popup()
		_poll = 0.0
		refresh()
	else:
		_msg_for = id
		popup_msg = err                 # bolsa cheia: o botão diz isso; o item continua reservado
		open(id)

func close_popup() -> void:
	if popup:
		popup.queue_free()
		popup = null
	open_id = -1
