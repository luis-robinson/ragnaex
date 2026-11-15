class_name CharList
extends Control
## Tela Personagens (design/ux/start-flow.md §3-§5): faixa de 5 cards no terço de baixo, sobre o cenário 3D, e a barra
## [← Voltar] ... [Excluir] [Novo] [Jogar]. Card ok = retrato (ou ícone da classe), nome, "Classe · Nível N", mapa;
## vazio = "+ Novo personagem"; danificado = "Save danificado", só Excluir (com confirmação, `DeleteDialog`).
## Teclado: ←/→ e Tab/Shift+Tab entre os cards, Home/End, Enter joga/cria, Delete exclui, Esc volta ao Título.
## Mouse: passar destaca, clique seleciona, duplo clique = Enter.
##
## Os espaços vêm de `CharList.slots()` (fonte trocável, ver `Slots`):
## - padrão: `SaveSlots.new(0)` = os espaços reais do SaveSystem (save_0..4);
## - `-- --menu_saves=<n>` (dev, fotos): `FakeSlots` só na memória, n personagens falsos; ou um padrão por espaço com
##   `o` (ok), `c` (danificado), `-` (vazio): `--menu_saves=oc` = 1 ok + 1 danificado + 3 vazios. Os ids de espaço dos
##   falsos são 90+i (o TEST_SLOT dos testes): Jogar/Novo/Excluir num card falso nunca chegam a save_0..4;
##   o retrato do card falso i é `user://portrait_<90+i>.png`, se existir;
## - `-- --menu_delete` (dev, foto): abre a confirmação de exclusão do card selecionado;
## - testes: `CharList.source = CharList.SaveSlots.new(90)` (espaços 90-94 em disco) e `CharList.source = null` no fim.

## Jogar o personagem do espaço `slot` (card ocupado; Enter / duplo clique).
signal play_requested(slot: int)
## Criar personagem no espaço livre `slot` (card vazio / "Novo").
signal create_requested(slot: int)
## Esc / [Voltar]: volta ao Título.
signal back_requested
## O card selecionado mudou (espaço do card; gancho do boneco no pedestal do cenário).
signal selection_changed(slot: int)

const KIND_OK := "ok"
const KIND_EMPTY := "empty"
const KIND_CORRUPT := "corrupt"
const CARD_SIZE := Vector2(260, 340)
const CARD_GAP := 16
const ROW_W := 1364                      # 5 × 260 + 4 × 16 (< 1600: cabe na base)
const BAR_H := 48
const BOTTOM_PAD := 26
const PORTRAIT_H := 196
const DANGER := Color(0.92, 0.36, 0.3)
const DEV_SLOT_BASE := 90                # = TEST_SLOT: espaços dos saves falsos (nunca 0..4)
const FULL_TEXT := "Todos os %d espaços ocupados: exclua um para criar outro."

# ---------------------------------------------------------------------------
## Fonte dos espaços da lista (o card i mostra o espaço `slot_of(i)`).
class Slots:
	extends RefCounted
	func count() -> int:
		return SaveSystem.SLOTS
	func slot_of(i: int) -> int:
		return i
	func state(_i: int) -> String:
		return KIND_EMPTY
	func summary(_i: int) -> Dictionary:
		return {}
	func delete(_i: int) -> void:
		pass
	func portrait(i: int) -> Texture2D:
		return Portrait.texture(slot_of(i))
	## Nome do arquivo (texto do card danificado).
	func file_name(i: int) -> String:
		return SaveSystem.path_of(slot_of(i)).get_file()

## Espaços do SaveSystem a partir de `base` (0 = os do jogador; 90 = os dos testes).
class SaveSlots:
	extends Slots
	var base := 0
	func _init(first: int = 0) -> void:
		base = first
	func slot_of(i: int) -> int:
		return base + i
	func state(i: int) -> String:
		return SaveSystem.slot_state(base + i)
	func summary(i: int) -> Dictionary:
		return SaveSystem.slot_summary(base + i)
	func delete(i: int) -> void:
		SaveSystem.delete_slot(base + i)          # apaga também o retrato

## Saves falsos só na memória (dev `--menu_saves`): nada é lido nem gravado em disco.
class FakeSlots:
	extends Slots
	const CHARS := [["Aldric", "paladin", 12, "city_aldara"], ["Lyra", "druid", 24, "field_forest"],
		["Brann", "berserker", 33, "city_port"], ["Seraphine", "bishop", 18, "elf_city"], ["Kael", "ranger", 41, "field_coast"]]
	var states: Array[String] = []
	var sums: Array[Dictionary] = []
	## `spec`: número (n ok) ou padrão por espaço (`o` ok, `c` danificado, `-` vazio).
	func _init(spec: String = "") -> void:
		var pattern := ""
		if spec.is_valid_int():
			pattern = "o".repeat(clampi(int(spec), 0, SaveSystem.SLOTS))
		else:
			pattern = spec
		for i in range(SaveSystem.SLOTS):
			var ch := pattern[i] if i < pattern.length() else "-"
			var c: Array = CHARS[i % CHARS.size()]
			states.append(KIND_OK if ch == "o" else (KIND_CORRUPT if ch == "c" else KIND_EMPTY))
			sums.append({"name": c[0], "class": c[1], "level": c[2], "map": c[3]} if ch == "o" else {})
	func slot_of(i: int) -> int:
		return DEV_SLOT_BASE + i
	func state(i: int) -> String:
		return states[i]
	func summary(i: int) -> Dictionary:
		return sums[i]
	func delete(i: int) -> void:
		states[i] = KIND_EMPTY
		sums[i] = {}

## Fonte em uso (null = decide na próxima chamada de `slots()`).
static var source: Slots = null

## Fonte dos espaços: a de `source`, ou (primeira vez) os saves falsos de `--menu_saves`, ou os espaços reais.
static func slots() -> Slots:
	if source == null:
		source = FakeSlots.new(DevArgs.value("--menu_saves")) if DevArgs.flag("--menu_saves") else SaveSlots.new(0)
	return source

## Há algum personagem na lista (ok ou danificado)? Fora do dev é o `SaveSystem.has_save()`.
static func has_any() -> bool:
	var s := slots()
	for i in range(s.count()):
		if s.state(i) != KIND_EMPTY:
			return true
	return false

# ---------------------------------------------------------------------------
var _src: Slots
var _row: HBoxContainer
var _cards: Array[PanelContainer] = []
var _kinds: Array[String] = []
var _colors: Array[Color] = []
var _sel := -1
var _hover := -1
var _want_slot := -1                     # select_slot antes de montar
var _notice: Label
var _error := ""
var _back_btn: Button
var _delete_btn: Button
var _create_btn: Button
var _play_btn: Button
var _dialog: DeleteDialog = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_src = slots()
	var head := UiKit.label("Personagens", 26, UiKit.GOLD)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.anchor_left = 0.5
	head.anchor_right = 0.5
	head.offset_left = -300
	head.offset_right = 300
	head.offset_top = 28
	head.offset_bottom = 64
	add_child(head)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.anchor_left = 0.5            # centrado por âncoras: 16:9 e 21:9 iguais, o cenário aparece em volta
	col.anchor_right = 0.5
	col.anchor_top = 1.0
	col.anchor_bottom = 1.0
	col.offset_left = -ROW_W * 0.5
	col.offset_right = ROW_W * 0.5
	col.offset_bottom = -BOTTOM_PAD
	col.offset_top = -BOTTOM_PAD - CARD_SIZE.y - 14 - BAR_H
	col.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(col)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", CARD_GAP)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_row)
	col.add_child(_action_bar())
	_build_cards()
	var start := _index_of(_want_slot)
	if start < 0:
		start = _kinds.find(KIND_OK)
	if start < 0:
		start = 0
	_set_selected(start)
	if DevArgs.has("--menu_delete"):
		request_delete.call_deferred()
	focus_default()

func _action_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(ROW_W, BAR_H)
	bar.add_theme_constant_override("separation", 12)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back_btn = _bar_button("←  Voltar", back_requested.emit, 150, 44, UiKit.TEXT)
	bar.add_child(_back_btn)
	_notice = UiKit.label("", 14, UiKit.MUTED)
	_notice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bar.add_child(_notice)
	_delete_btn = _bar_button("Excluir", request_delete, 140, 44, DANGER)
	bar.add_child(_delete_btn)
	_create_btn = _bar_button("+  Novo", _on_create_pressed, 150, 44, UiKit.TEXT)
	bar.add_child(_create_btn)
	_play_btn = _bar_button("▶  Jogar", _on_play_pressed, 210, BAR_H, UiKit.GOLD)
	_play_btn.add_theme_font_size_override("font_size", 20)
	var gold := UiKit.panel_style(Color(0.3, 0.24, 0.12, 0.95), UiKit.GOLD, 4, 2)
	gold.set_content_margin_all(6)
	_play_btn.add_theme_stylebox_override("normal", gold)
	bar.add_child(_play_btn)
	return bar

func _bar_button(text: String, on_pressed: Callable, w: int, h: int, color: Color) -> Button:
	var b := UiKit.button(text, on_pressed, w)     # FOCUS_NONE: o foco fica nos cards
	b.custom_minimum_size.y = h
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", color.lightened(0.3))
	return b

# ---------------------------------------------------------------------------
# cards
func _build_cards() -> void:
	for c in _cards:
		if is_instance_valid(c):
			_row.remove_child(c)
			c.queue_free()
	_cards.clear()
	_kinds.clear()
	_colors.clear()
	_hover = -1
	for i in range(_src.count()):
		var kind := _src.state(i)
		var card := _card_shell(i)
		match kind:
			KIND_OK:
				_fill_ok(card, i)
			KIND_CORRUPT:
				_fill_corrupt(card, i)
			_:
				kind = KIND_EMPTY
				_fill_empty(card)
		_kinds.append(kind)
		_row.add_child(card)
		_cards.append(card)
	# ordem do teclado/gamepad explícita: esquerda→direita, Tab dá a volta; ↑/↓ não saem da faixa
	var n := _cards.size()
	for i in range(n):
		var c := _cards[i]
		c.focus_neighbor_left = c.get_path_to(_cards[maxi(0, i - 1)])
		c.focus_neighbor_right = c.get_path_to(_cards[mini(n - 1, i + 1)])
		c.focus_next = c.get_path_to(_cards[(i + 1) % n])
		c.focus_previous = c.get_path_to(_cards[(i - 1 + n) % n])
		c.focus_neighbor_top = c.get_path_to(c)
		c.focus_neighbor_bottom = c.get_path_to(c)
	if _sel >= n:
		_sel = n - 1

func _card_shell(i: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	card.focus_mode = Control.FOCUS_ALL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())     # a borda do selecionado já mostra
	card.gui_input.connect(_on_card_input.bind(i))
	card.focus_entered.connect(_set_selected.bind(i))
	card.mouse_entered.connect(_set_hover.bind(i, true))
	card.mouse_exited.connect(_set_hover.bind(i, false))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	return card

func _box(card: PanelContainer) -> VBoxContainer:
	return card.get_child(0) as VBoxContainer

## Moldura do retrato (fundo escuro na cor da classe).
func _frame(bg: Color, edge: Color) -> PanelContainer:
	var f := PanelContainer.new()
	var st := UiKit.panel_style(bg, edge, 6, 1)
	st.set_content_margin_all(0)
	f.add_theme_stylebox_override("panel", st)
	f.custom_minimum_size = Vector2(0, PORTRAIT_H)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return f

func _center_label(text: String, size: int, color: Color) -> Label:
	var l := UiKit.label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l

func _fill_ok(card: PanelContainer, i: int) -> void:
	var d := _src.summary(i)
	var cls: ClassDef = GameData.classes.get(str(d.get("class", "")), GameData.classes["paladin"])   # classe que saiu: a padrão
	_colors.append(cls.color)
	var v := _box(card)
	var fr := _frame(cls.color.darkened(0.72), cls.color.darkened(0.35))
	v.add_child(fr)
	var tex := _src.portrait(i)
	if tex:
		var t := TextureRect.new()
		t.texture = tex
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fr.add_child(t)
	else:                                    # sem retrato: ícone da classe
		var cc := CenterContainer.new()
		cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cc.add_child(UiKit.class_icon(cls, 112))
		fr.add_child(cc)
	var pad := Control.new()
	pad.custom_minimum_size.y = 6
	v.add_child(pad)
	v.add_child(_center_label(str(d.get("name", "?")), 18, UiKit.GOLD))
	v.add_child(_center_label("%s  ·  Nível %d" % [cls.name, int(d.get("level", 1))], 14, UiKit.TEXT))
	var md: MapDef = GameData.maps.get(str(d.get("map", "")))
	v.add_child(_center_label(md.name if md else "?", 12, UiKit.MUTED))

func _fill_empty(card: PanelContainer) -> void:
	_colors.append(UiKit.SLOT_EDGE)
	var v := _box(card)
	var fr := _frame(Color(0.04, 0.035, 0.06, 0.55), UiKit.SLOT_EDGE)
	v.add_child(fr)
	var plus := _center_label("+", 72, UiKit.MUTED)
	plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fr.add_child(plus)
	var pad := Control.new()
	pad.custom_minimum_size.y = 6
	v.add_child(pad)
	v.add_child(_center_label("Novo personagem", 18, UiKit.TEXT))
	v.add_child(_center_label("Espaço livre", 12, UiKit.MUTED))

func _fill_corrupt(card: PanelContainer, i: int) -> void:
	_colors.append(DANGER)
	var v := _box(card)
	var fr := _frame(Color(0.18, 0.05, 0.05, 0.7), DANGER.darkened(0.3))
	v.add_child(fr)
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fr.add_child(cc)
	var mark := PanelContainer.new()                 # aviso: "!" num disco vermelho
	var st := UiKit.panel_style(DANGER.darkened(0.45), DANGER, 40, 3)
	st.set_content_margin_all(0)
	mark.add_theme_stylebox_override("panel", st)
	mark.custom_minimum_size = Vector2(80, 80)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ex := _center_label("!", 48, Color(1, 0.85, 0.8))
	ex.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.add_child(ex)
	cc.add_child(mark)
	var pad := Control.new()
	pad.custom_minimum_size.y = 6
	v.add_child(pad)
	v.add_child(_center_label("Save danificado", 18, DANGER.lightened(0.15)))
	v.add_child(_center_label(_src.file_name(i), 12, UiKit.MUTED))
	v.add_child(_center_label("Só dá para excluir.", 12, UiKit.MUTED))

func _card_style(i: int) -> StyleBoxFlat:
	var kind := _kinds[i]
	var sel := i == _sel
	var hov := i == _hover
	var edge: Color = _colors[i].darkened(0.1)
	var bg := Color(0.07, 0.06, 0.1, 0.9)
	if kind == KIND_EMPTY:
		edge = UiKit.SLOT_EDGE.lightened(0.2)
		bg = Color(0.06, 0.055, 0.09, 0.72)
	if hov:
		edge = edge.lightened(0.35)
		bg = bg.lightened(0.05)
	if sel:
		edge = Color(1.0, 0.93, 0.72)
		bg = Color(0.15, 0.13, 0.19, 0.96)
	var s := UiKit.panel_style(bg, edge, 10, 3 if sel else 2)
	s.set_content_margin_all(12)
	if sel:
		s.shadow_color = Color(1.0, 0.85, 0.4, 0.35)
		s.shadow_size = 12
	return s

func _restyle() -> void:
	for i in range(_cards.size()):
		_cards[i].add_theme_stylebox_override("panel", _card_style(i))

func _set_hover(i: int, on: bool) -> void:
	if on:
		_hover = i
	elif _hover == i:
		_hover = -1
	if i < _cards.size():
		_restyle()

func _set_selected(i: int) -> void:
	if i < 0 or i >= _cards.size():
		return
	var changed := i != _sel
	_sel = i
	_restyle()
	_update_actions()
	if changed:
		selection_changed.emit(_src.slot_of(i))

func _update_actions() -> void:
	var kind := _kinds[_sel] if _sel >= 0 and _sel < _kinds.size() else KIND_EMPTY
	_play_btn.disabled = kind != KIND_OK
	_delete_btn.disabled = kind == KIND_EMPTY
	_create_btn.disabled = _free_index() < 0
	var txt := _error
	var col := DANGER
	if txt == "":
		col = UiKit.MUTED
		if _free_index() < 0:
			txt = FULL_TEXT % _cards.size()
		elif kind == KIND_CORRUPT:
			txt = "Save danificado: não dá para jogar, só excluir."
	_notice.text = txt
	_notice.add_theme_color_override("font_color", col)

func _free_index() -> int:
	if _sel >= 0 and _sel < _kinds.size() and _kinds[_sel] == KIND_EMPTY:
		return _sel
	return _kinds.find(KIND_EMPTY)

func _index_of(slot: int) -> int:
	if slot < 0 or _src == null:
		return -1
	for i in range(_src.count()):
		if _src.slot_of(i) == slot:
			return i
	return -1

# ---------------------------------------------------------------------------
# ações
## Enter / duplo clique no card `i`: joga (ok) ou cria (vazio); danificado não faz nada.
func _activate(i: int) -> void:
	if i < 0 or i >= _kinds.size():
		return
	if _kinds[i] == KIND_OK:
		play_requested.emit(_src.slot_of(i))
	elif _kinds[i] == KIND_EMPTY:
		create_requested.emit(_src.slot_of(i))

func _on_play_pressed() -> void:
	_activate(_sel)

func _on_create_pressed() -> void:
	var i := _free_index()
	if i >= 0:
		create_requested.emit(_src.slot_of(i))

## Abre a confirmação de exclusão do card selecionado (ok ou danificado).
func request_delete() -> void:
	if _dialog != null or _sel < 0 or _sel >= _kinds.size() or _kinds[_sel] == KIND_EMPTY:
		return
	_dialog = DeleteDialog.new()
	_dialog.setup(delete_text(_sel))
	_dialog.confirmed.connect(_on_delete_confirmed.bind(_sel))
	_dialog.cancelled.connect(_close_dialog)
	add_child(_dialog)

## Pergunta da exclusão do card `i` (§5).
func delete_text(i: int) -> String:
	if _kinds[i] == KIND_CORRUPT:
		return "Excluir o save danificado (%s)? Isso não pode ser desfeito." % _src.file_name(i)
	var d := _src.summary(i)
	var cls: ClassDef = GameData.classes.get(str(d.get("class", "")), GameData.classes["paladin"])
	return "Excluir %s (%s, Nível %d)? Isso não pode ser desfeito." % [str(d.get("name", "?")), cls.name, int(d.get("level", 1))]

func _on_delete_confirmed(i: int) -> void:
	_src.delete(i)
	_close_dialog()
	refresh()
	if not _kinds.has(KIND_OK) and not _kinds.has(KIND_CORRUPT):     # excluiu o último: a lista nunca fica vazia (§5)
		create_requested.emit(_src.slot_of(_kinds.find(KIND_EMPTY)))

func _close_dialog() -> void:
	if _dialog and is_instance_valid(_dialog):
		remove_child(_dialog)
		_dialog.queue_free()
	_dialog = null
	focus_default()

## Diálogo de exclusão aberto (null = nenhum).
func dialog() -> DeleteDialog:
	return _dialog

# ---------------------------------------------------------------------------
# entrada
## Tecla da lista; true = tratada. ←/→ param nas pontas, Tab/Shift+Tab dão a volta.
func _key(k: InputEventKey) -> bool:
	if _dialog != null or not k.pressed or (k.echo and k.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_DELETE, KEY_ESCAPE]):
		return false
	var n := _cards.size()
	match k.keycode:
		KEY_RIGHT:
			_move_to(mini(n - 1, _sel + 1))
		KEY_LEFT:
			_move_to(maxi(0, _sel - 1))
		KEY_TAB:
			_move_to((_sel + (n - 1 if k.shift_pressed else 1)) % n)
		KEY_HOME:
			_move_to(0)
		KEY_END:
			_move_to(n - 1)
		KEY_ENTER, KEY_KP_ENTER:
			_activate(_sel)
		KEY_DELETE:
			request_delete()
		KEY_ESCAPE:
			back_requested.emit()
		_:
			return false
	return true

func _move_to(i: int) -> void:
	_set_selected(i)
	if is_inside_tree() and is_visible_in_tree():
		_cards[i].grab_focus()

## Testes: aperta uma tecla na lista (o mesmo caminho do teclado).
func press_key(keycode: Key, shift: bool = false) -> bool:
	var k := InputEventKey.new()
	k.keycode = keycode
	k.pressed = true
	k.shift_pressed = shift
	return _key(k)

func _on_card_input(event: InputEvent, i: int) -> void:
	var k := event as InputEventKey
	if k:
		if _key(k):
			accept_event()
		return
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_move_to(i)
		if mb.double_click:
			_activate(i)
		accept_event()

func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and _key(k):
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# interface do start.gd (P1)
## Seleciona o card do espaço `slot` (volta do jogo: o personagem que acabou de sair).
func select_slot(slot: int) -> void:
	_want_slot = slot
	var i := _index_of(slot)
	if i >= 0 and i < _cards.size():
		_set_selected(i)

## Espaço do card selecionado (-1 = nenhum).
func selected_slot() -> int:
	if _sel < 0 or _src == null:
		return _want_slot
	return _src.slot_of(_sel)

## Relê os espaços e refaz os cards (depois de excluir), mantendo o card selecionado.
func refresh() -> void:
	if _row == null:
		return
	var keep := maxi(0, _sel)
	_build_cards()
	_sel = -1
	_set_selected(mini(keep, _cards.size() - 1))
	focus_default()

## Foco no card selecionado (adiado: a reconstrução por queue_free derruba o foco).
func focus_default() -> void:
	_grab_selected.call_deferred()

func _grab_selected() -> void:
	if _dialog == null and is_inside_tree() and is_visible_in_tree() and _sel >= 0 and _sel < _cards.size():
		_cards[_sel].grab_focus()

## Faixa vermelha de erro sobre a barra (ex.: "Não foi possível carregar. Tente de novo."; "" apaga).
func show_error(text: String) -> void:
	_error = text
	if _notice:
		_update_actions()

# ---------------------------------------------------------------------------
# testes
func card_count() -> int:
	return _cards.size()

func card_kind(i: int) -> String:
	return _kinds[i]

## Textos do card `i` juntos (testes).
func card_text(i: int) -> String:
	var out: Array[String] = []
	for l in _cards[i].find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return " | ".join(out)

## Botões da barra: {play, delete, create} = habilitado.
func action_state() -> Dictionary:
	return {"play": not _play_btn.disabled, "delete": not _delete_btn.disabled, "create": not _create_btn.disabled}

func notice_text() -> String:
	return _notice.text

## Card que tem o foco (-1 = nenhum).
func focused_index() -> int:
	var f := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	return _cards.find(f)

## Vizinho de foco do card `i` na direção `side` ("left", "right", "next", "previous") como índice (testes).
func neighbor_index(i: int, side: String) -> int:
	var p: NodePath = _cards[i].get("focus_neighbor_" + side) if side in ["left", "right"] else _cards[i].get("focus_" + side)
	return _cards.find(_cards[i].get_node_or_null(p))
