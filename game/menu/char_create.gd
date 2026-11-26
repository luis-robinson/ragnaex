class_name CharCreate
extends Control
## Tela Criação (design/ux/start-flow.md §3-§5): o boneco fica no pedestal do cenário (MenuSet, `CAM_create`) à esquerda;
## à direita (~55%) o painel com os passos "1 Classe" (grade + descrição) e "2 Visual" (abas Corpo / Cabelo / Rosto);
## embaixo à esquerda Nome + sorteio e "Visual aleatório". Rodapé: [← Personagens|← Classe] ... [Próximo: visual →|Começar aventura].
## Classe em ação: ao escolher uma classe o boneco toca UMA vez o clipe da skill-assinatura (só animação, sem efeito, sem sim;
## clipe por `EntityView.clip_for_skill`) e volta ao idle. No Visual: idle, de frente, sem chapéu.
## Teclado: Enter = Próximo / Começar aventura (também no Nome, `text_submitted`); Esc volta um passo (Visual -> Classe ->
## `back_requested`); Tab/Shift+Tab nos controles. Arrastar nos 40% da esquerda gira o boneco; a roda aproxima.
## Começos rápidos (StartCatalog.PRESETS) só em dev: `--preset=N` vale aqui; `--dev_presets` mostra o seletor.
## `--look=<classe>:<sexo>:<cabelo>:<barba>:<olhos>:<cor cabelo>:<cor olhos>` abre no Visual com esse visual.
## API de teste/revisão: `select_class(id)`, `show_step(step)`, `show_tab(tab)`, `build_request()`, `go_back()`.

## "Começar aventura": pedido pronto (personagem novo no espaço `setup`).
signal create_confirmed(request: StartRequest)
## Esc no 1º passo / [← Personagens]: volta à lista (ou ao Título com 0 personagens; quem decide é o start.gd).
signal back_requested

const STEP_CLASS := "class"
const STEP_LOOK := "look"
const TABS := [["body", "Corpo"], ["hair", "Cabelo"], ["face", "Rosto"]]
const NAMES := ["Aiden", "Lúcia", "Brann", "Sora", "Kaito", "Mira", "Dante", "Elara", "Tamsin", "Oren", "Lyra", "Bastian", "Nyx", "Rurik"]
const DEFAULT_NAME := "Herói"
const NAME_MAX := 16
const LOOK_KEYS := ["sex", "skin", "hair", "beard", "eyes", "eye_color", "hair_color", "beard_color", "brows", "mouth", "marks", "mark_color"]
# layout (base 1600x900; tudo por âncora)
const PANEL_X := Vector2(0.43, 0.98)
const PANEL_Y := Vector2(0.05, 0.95)
const LEFT_X := Vector2(0.04, 0.36)
const LEFT_BOTTOM := 0.95
const DRAG_ZONE := 0.4               # arrastar/roda só nos 40% da esquerda
const DRAG_SPEED := 0.012
const ZOOM_STEP := 0.06              # fração do FOV por clique da roda
const ZOOM_MIN := 0.65               # FOV mínimo = 65% do da câmera
const DEMO_FADE := 0.12
const IDLE_FADE := 0.25

var target_slot := -1                # espaço onde o personagem nasce (-1 = o primeiro livre na hora)
var selected: ClassDef = null
var look: Dictionary = {}
var step := STEP_CLASS
var tab := "body"
var preset := 1
var demo_clip := ""                  # clipe lógico da última demonstração ("" = nenhuma)
var menu_set: MenuSet = null
var preview: PedestalPreview = null
var kit: KitModel = null
var name_edit: LineEdit
var knows_box: CheckBox                 # "Já conheço o jogo" (GDD introducao-de-sistemas §9.4): por personagem

var _rng := RandomNumberGenerator.new()
var _title: Label
var _step_btns: Dictionary = {}
var _content: VBoxContainer
var _back_btn: Button
var _primary_btn: Button
var _cards: Dictionary = {}          # id -> Button
var _desc: Label
var _sig_row: HBoxContainer
var _tab_btns: Dictionary = {}
var _rows: Dictionary = {}           # campo -> [Label do valor, opções]
var _swatch_btns: Dictionary = {}    # campo -> [[hex, Button]]
var _beard_box: Control
var _preset_box: Control = null
var _preset_btns: Dictionary = {}
var _yaw := 0.0
var _dragging := false
var _kit_key := ""
var _eq_key := ""
var _demo_left := 0.0
var _base_fov := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()
	if DevArgs.flag("--preset") and StartCatalog.PRESETS.has(int(DevArgs.value("--preset"))):
		preset = int(DevArgs.value("--preset"))
	_build()
	if selected == null:
		selected = GameData.class_list()[0]
	look = LooksCatalog.default_look(selected)
	_select(selected, true)
	_build_step()
	if DevArgs.flag("--look"):
		_apply_dev_look(DevArgs.value("--look"))
	focus_default()

## Espaço onde o personagem novo vai nascer.
func setup(slot: int) -> void:
	target_slot = slot

## Liga o cenário: o boneco vai para o pedestal do `menu_set` pelos kits guardados do `preview` (um boneco vivo só).
func attach(set_: MenuSet, preview_: PedestalPreview) -> void:
	menu_set = set_
	preview = preview_
	if is_inside_tree():
		_rebuild_model(true)

## Foco no controle padrão: a classe escolhida (passo Classe) ou "Começar aventura" (Visual). Adiado: vale depois de reconstruir.
func focus_default() -> void:
	_focus_default.call_deferred()

func _focus_default() -> void:
	if not is_inside_tree():
		return
	var c: Control = _cards.get(selected.id if selected else "") if step == STEP_CLASS else _primary_btn
	if c and is_instance_valid(c) and c.is_visible_in_tree():
		c.grab_focus()

# ---------------------------------------------------------------------------
# API de teste / revisão
## Escolhe a classe pelo id (como clicar no card; toca a demonstração).
func select_class(id: String) -> void:
	if GameData.classes.has(id):
		_select(GameData.classes[id])

## Vai ao passo `class` ou `look`.
func show_step(st: String) -> void:
	if st not in [STEP_CLASS, STEP_LOOK]:
		return
	step = st
	if st == STEP_LOOK:
		_stop_demo()
		_yaw = 0.0                       # de frente no Visual
	_build_step()
	_rebuild_model()
	focus_default()

## Abre a aba `body`, `hair` ou `face` (vai ao Visual se precisar).
func show_tab(t: String) -> void:
	if not TABS.any(func(x: Array) -> bool: return x[0] == t):
		return
	tab = t
	if step != STEP_LOOK:
		show_step(STEP_LOOK)
	else:
		_build_step()
		var b: Button = _tab_btns.get(t)
		if b:
			b.grab_focus.call_deferred()

## Esc: Visual -> Classe -> `back_requested`.
func go_back() -> void:
	if step == STEP_LOOK:
		show_step(STEP_CLASS)
	else:
		back_requested.emit()

## Nome que vai no pedido: o do campo (até 16 letras) ou "Herói" se vazio.
func chosen_name() -> String:
	var n := name_edit.text.strip_edges() if name_edit else ""
	return n.left(NAME_MAX) if n != "" else DEFAULT_NAME

## "Já conheço o jogo" começa marcado quando já existe outro personagem (§9.4).
static func default_knows_game() -> bool:
	return SaveSystem.has_save()

## Pedido de personagem novo (null se não há espaço livre nem classe).
func build_request() -> StartRequest:
	var slot := target_slot if target_slot >= 0 else SaveSystem.first_free_slot()
	if selected == null or slot < 0:
		return null
	return StartRequest.new_character(selected.id, chosen_name(), look.duplicate(), preset, slot, knows_box.button_pressed if knows_box else true)

## Skill-assinatura que a classe mostra: a da build da arma inicial (senão a 1ª build; senão a 1ª skill inicial).
static func signature_skill(cls: ClassDef) -> SkillDef:
	if cls == null:
		return null
	var w0 := ""
	for iid in cls.starting_equipment:
		var it: ItemDef = GameData.items.get(iid)
		if it and it.slot == ItemDef.Slot.WEAPON:
			w0 = it.weapon_type
			break
	var pick: Dictionary = {}
	for b in cls.builds:
		if pick.is_empty():
			pick = b
		if w0 != "" and w0 in b.get("main", []):
			pick = b
			break
	var sig: Variant = pick.get("signature", {})
	var sid: String = str((sig as Dictionary).get("skill", "")) if sig is Dictionary else ""
	if GameData.skills.has(sid):
		return GameData.skills[sid]
	for s in cls.starting_skills:
		if GameData.skills.has(s):
			return GameData.skills[s]
	return null

## Equipamento inicial da classe (slot -> ItemDef); `head = false` tira chapéu/capuz (Visual).
static func starter_equipment(cls: ClassDef, head := true) -> Dictionary:
	var eq := cls.starting_slots()
	if not head:
		eq.erase(ItemDef.Slot.HEAD)
	return eq

## Clipe lógico da demonstração da classe (a mesma regra do jogo, com a arma inicial).
static func signature_clip(cls: ClassDef) -> String:
	var s := signature_skill(cls)
	if s == null:
		return ""
	var eq := starter_equipment(cls)
	var w: ItemDef = eq.get(ItemDef.Slot.WEAPON)
	var o: ItemDef = eq.get(ItemDef.Slot.OFFHAND)
	return EntityView.clip_for_skill(s, w.weapon_type if w else "", o.weapon_type if o else "")

# ---------------------------------------------------------------------------
# montagem
func _btn(text: String, cb: Callable, w: int = 0, h: int = 40) -> Button:
	var b := UiKit.button(text, cb, w)
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size.y = h
	var f := UiKit.panel_style(Color(0, 0, 0, 0), UiKit.GOLD, 4, 2)
	f.draw_center = false
	b.add_theme_stylebox_override("focus", f)
	return b

func _build() -> void:
	# painel da direita
	var panel := UiKit.panel(Color(0.07, 0.06, 0.1, 0.9), UiKit.BORDER)
	panel.name = "Panel"
	panel.anchor_left = PANEL_X.x
	panel.anchor_right = PANEL_X.y
	panel.anchor_top = PANEL_Y.x
	panel.anchor_bottom = PANEL_Y.y
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	_title = UiKit.label("Novo personagem", 22, UiKit.GOLD)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	for st in [[STEP_CLASS, "1  Classe"], [STEP_LOOK, "2  Visual"]]:
		var b := _btn(st[1], show_step.bind(st[0]), 150)
		_step_btns[st[0]] = b
		head.add_child(b)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_content)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	v.add_child(foot)
	_back_btn = _btn("← Personagens", go_back, 180, 44)
	foot.add_child(_back_btn)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sp)
	_primary_btn = _btn("Próximo: visual →", _primary, 240, 48)
	_primary_btn.add_theme_color_override("font_color", UiKit.GOLD)
	_primary_btn.add_theme_font_size_override("font_size", 17)
	foot.add_child(_primary_btn)
	# embaixo à esquerda: nome, sorteio, visual aleatório
	var lp := UiKit.panel(Color(0.07, 0.06, 0.1, 0.82), Color(0.4, 0.34, 0.26))
	lp.name = "NameBox"
	lp.anchor_left = LEFT_X.x
	lp.anchor_right = LEFT_X.y
	lp.anchor_top = LEFT_BOTTOM
	lp.anchor_bottom = LEFT_BOTTOM
	lp.grow_vertical = Control.GROW_DIRECTION_BEGIN
	lp.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(lp)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 8)
	lp.add_child(lv)
	var nh := HBoxContainer.new()
	nh.add_theme_constant_override("separation", 8)
	lv.add_child(nh)
	nh.add_child(UiKit.label("Nome", 15, UiKit.MUTED))
	name_edit = LineEdit.new()
	name_edit.name = "Name"
	name_edit.max_length = NAME_MAX
	name_edit.text = NAMES[_rng.randi() % NAMES.size()]
	name_edit.placeholder_text = DEFAULT_NAME
	name_edit.custom_minimum_size = Vector2(0, 40)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.add_theme_font_size_override("font_size", 17)
	name_edit.text_submitted.connect(func(_t: String) -> void: _primary())
	nh.add_child(name_edit)
	var dice := _btn("🎲", _random_name, 44)
	dice.tooltip_text = "Sortear nome"
	nh.add_child(dice)
	lv.add_child(_btn("🎲  Visual aleatório", _random_look))
	lv.add_child(UiKit.label("Arraste o personagem para girar · roda do mouse aproxima", 12, UiKit.MUTED))
	knows_box = CheckBox.new()
	knows_box.name = "KnowsGame"
	knows_box.text = "Já conheço o jogo"
	knows_box.tooltip_text = "Marcado: todos os sistemas abertos desde o nível 1.
Desmarcado: cada sistema chega na hora certa, com uma tarefa curta de um NPC."
	knows_box.add_theme_font_size_override("font_size", 14)
	knows_box.button_pressed = default_knows_game()
	lv.add_child(knows_box)
	# começos rápidos: botão "Debug" sempre na tela (playtest 2026-11-18); `--dev_presets` já abre o seletor
	var dbg := _btn("Debug", _toggle_debug, 0, 30)
	dbg.name = "DebugToggle"
	dbg.tooltip_text = "Modo debug: começar no nível 10, 16, 20 ou 30 com grupo completo e Moedas Lendárias de sobra"
	dbg.add_theme_font_size_override("font_size", 12)
	lv.add_child(dbg)
	_preset_box = _presets()
	_preset_box.visible = DevArgs.has("--dev_presets")
	lv.add_child(_preset_box)

func _presets() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.add_child(UiKit.label("Começo", 12, UiKit.MUTED))
	for pid in StartCatalog.PRESETS:
		var b := _btn(StartCatalog.PRESETS[pid]["label"], _set_preset.bind(pid), 76)
		b.tooltip_text = StartCatalog.PRESETS[pid]["hint"]
		_preset_btns[pid] = b
		h.add_child(b)
	_set_preset(preset)
	return h

## Mostra/esconde o seletor de começo rápido; ao esconder, volta ao começo normal (nível 1).
func _toggle_debug() -> void:
	_preset_box.visible = not _preset_box.visible
	if not _preset_box.visible:
		_set_preset(1)

func _set_preset(pid: int) -> void:
	preset = pid
	for k in _preset_btns:
		_preset_btns[k].modulate = Color(1, 1, 1) if k == pid else Color(0.6, 0.6, 0.6)

func _clear(c: Node) -> void:
	for ch in c.get_children():
		c.remove_child(ch)
		ch.queue_free()

func _build_step() -> void:
	if _content == null:
		return
	_clear(_content)
	_cards.clear()
	_rows.clear()
	_swatch_btns.clear()
	_tab_btns.clear()
	_beard_box = null
	_desc = null
	_sig_row = null
	for k in _step_btns:
		_step_btns[k].modulate = Color(1, 1, 1) if k == step else Color(0.62, 0.62, 0.62)
	_back_btn.text = "← Personagens" if step == STEP_CLASS else "← Classe"
	_primary_btn.text = "Próximo: visual →" if step == STEP_CLASS else "Começar aventura"
	if step == STEP_CLASS:
		_build_class_step()
	else:
		_build_look_step()
	_refresh()

func _build_class_step() -> void:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_content.add_child(grid)
	for cls in GameData.class_list():
		grid.add_child(_class_card(cls))
	var dp := PanelContainer.new()
	dp.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.05, 0.045, 0.08, 0.92), Color(0.25, 0.22, 0.3), 6, 1))
	dp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(dp)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 12)
	dp.add_child(dv)
	_desc = UiKit.para("", 14)
	dv.add_child(_desc)
	_sig_row = HBoxContainer.new()
	_sig_row.add_theme_constant_override("separation", 10)
	dv.add_child(_sig_row)
	_update_cards()

func _class_card(cls: ClassDef) -> Button:
	var card := _btn("", _select.bind(cls), 0, 92)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.name = "Class_" + cls.id
	var cv := VBoxContainer.new()
	cv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	cv.add_theme_constant_override("separation", 0)
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := UiKit.class_icon(cls, 44)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(ic)
	cv.add_child(cc)
	var nl := UiKit.label(cls.name, 15)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(nl)
	var rl := UiKit.label("%s · %d builds" % [cls.role, cls.builds.size()], 12, UiKit.MUTED)
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(rl)
	card.add_child(cv)
	_cards[cls.id] = card
	return card

func _update_cards() -> void:
	for id in _cards:
		var b: Button = _cards[id]
		var on: bool = selected != null and id == selected.id
		var cls: ClassDef = GameData.classes[id]
		var st := UiKit.panel_style(Color(0.2, 0.16, 0.24, 1.0) if on else UiKit.BG_LIGHT, cls.color.lightened(0.2) if on else UiKit.BORDER.darkened(0.3), 4, 3 if on else 1)
		st.set_content_margin_all(6)
		b.add_theme_stylebox_override("normal", st)
		b.modulate = Color(1, 1, 1) if on else Color(0.72, 0.72, 0.72)
	if _desc == null or selected == null:
		return
	var cls := selected
	var txt := "%s — %s\n%s\n\n%d skills (você equipa 6) · builds:\n" % [cls.name, cls.role, cls.description, cls.skill_ids.size()]
	for b in cls.builds:
		var w: Array = []
		for t in b["main"]:
			w.append(GearCatalog.WEAPON_NAMES.get(t, t))
		var arms := " / ".join(w)
		if b["off"].size() > 0:
			arms += " + " + " ou ".join(b["off"].map(func(o): return GearCatalog.WEAPON_NAMES.get(o, o)))
		txt += "   • %s (%s): %s\n" % [b["name"], b["role"], arms]
	_desc.text = txt.strip_edges()
	if _sig_row:
		_clear(_sig_row)
		var sig := signature_skill(cls)
		if sig:
			_sig_row.add_child(UiKit.skill_icon(sig, 48))
			var sv := VBoxContainer.new()
			sv.add_theme_constant_override("separation", 0)
			sv.add_child(UiKit.label("Em ação", 12, UiKit.MUTED))
			sv.add_child(UiKit.label(sig.name, 16, UiKit.GOLD))
			_sig_row.add_child(sv)

func _build_look_step() -> void:
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	_content.add_child(tabs)
	for t in TABS:
		var b := _btn(t[1], show_tab.bind(t[0]), 130)
		b.modulate = Color(1, 1, 1) if t[0] == tab else Color(0.62, 0.62, 0.62)
		_tab_btns[t[0]] = b
		tabs.add_child(b)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_content.add_child(box)
	match tab:
		"body":
			box.add_child(_choice_row("Sexo", "sex", LooksCatalog.SEXES))
			box.add_child(_section("Pele", _swatches("skin", LooksCatalog.SKIN_COLORS, 9)))
		"hair":
			box.add_child(_choice_row("Cabelo", "hair", LooksCatalog.HAIR))
			box.add_child(_section("Cor", _swatches("hair_color", LooksCatalog.HAIR_COLORS, 7)))
			_beard_box = VBoxContainer.new()
			_beard_box.add_theme_constant_override("separation", 10)
			_beard_box.add_child(_choice_row("Barba", "beard", LooksCatalog.BEARDS))
			_beard_box.add_child(_section("Cor", _swatches("beard_color", LooksCatalog.HAIR_COLORS, 7)))
			box.add_child(_beard_box)
		"face":
			box.add_child(_choice_row("Olhos", "eyes", LooksCatalog.EYES))
			box.add_child(_section("Cor", _swatches("eye_color", LooksCatalog.EYE_COLORS, 10)))
			box.add_child(_choice_row("Sobrancelha", "brows", LooksCatalog.BROWS))
			box.add_child(_choice_row("Boca", "mouth", LooksCatalog.MOUTHS))
			box.add_child(_choice_row("Marcas", "marks", LooksCatalog.MARKS))
			box.add_child(_section("Cor", _swatches("mark_color", LooksCatalog.MARK_COLORS, 7)))

func _section(title: String, content: Control) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var t := UiKit.label(title, 15, UiKit.MUTED)
	t.custom_minimum_size.x = 120
	h.add_child(t)
	h.add_child(content)
	return h

## Linha "◀ valor ▶" que percorre as opções de um campo do look.
func _choice_row(title: String, key: String, options: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var t := UiKit.label(title, 15, UiKit.MUTED)
	t.custom_minimum_size.x = 120
	row.add_child(t)
	row.add_child(_btn("◀", _cycle.bind(key, options, -1), 44))
	var val := UiKit.label("", 16)
	val.custom_minimum_size.x = 200
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(val)
	row.add_child(_btn("▶", _cycle.bind(key, options, 1), 44))
	_rows[key] = [val, options]
	return row

## Paleta de cores clicáveis (a escolhida ganha borda dourada; troca de estilo, sem reconstruir).
func _swatches(key: String, colors: Array, cols: int) -> Control:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	var list: Array = []
	for hexc in colors:
		var b := Button.new()
		b.custom_minimum_size = Vector2(44, 40)
		b.focus_mode = Control.FOCUS_ALL
		var sh := UiKit.panel_style(Color.html(hexc).lightened(0.15), UiKit.GOLD, 5, 2)
		b.add_theme_stylebox_override("hover", sh)
		b.add_theme_stylebox_override("pressed", sh)
		b.add_theme_stylebox_override("focus", UiKit.panel_style(Color(0, 0, 0, 0), Color(1, 1, 1), 5, 2))
		b.pressed.connect(_set_look.bind(key, hexc))
		g.add_child(b)
		list.append([hexc, b])
	_swatch_btns[key] = list
	return g

func _cycle(key: String, options: Dictionary, dir: int) -> void:
	var keys: Array = options.keys()
	var i := keys.find(look.get(key, keys[0]))
	_set_look(key, keys[(i + dir + keys.size()) % keys.size()])

func _set_look(key: String, value: String) -> void:
	look[key] = value
	if key == "hair_color" and look.get("beard", "none") == "none":
		look["beard_color"] = value          # barba acompanha o cabelo até alguém escolher outra
	if key == "sex" and value == "female":
		look["beard"] = "none"
	_refresh()

func _random_look() -> void:
	var keep_sex: String = look.get("sex", "male")
	var r := LooksCatalog.random_look(_rng)
	r["sex"] = keep_sex
	if keep_sex == "female":
		r["beard"] = "none"
	look = LooksCatalog.normalized(r, selected)
	_refresh()

func _random_name() -> void:
	name_edit.text = NAMES[_rng.randi() % NAMES.size()]

func _refresh() -> void:
	for key in _rows:
		var val: Label = _rows[key][0]
		val.text = str(_rows[key][1].get(look.get(key, ""), "—"))
	for key in _swatch_btns:
		for pair in _swatch_btns[key]:
			var chosen := str(look.get(key, "")).to_lower() == str(pair[0]).to_lower()
			(pair[1] as Button).add_theme_stylebox_override("normal", UiKit.panel_style(Color.html(pair[0]), UiKit.GOLD if chosen else Color(0.1, 0.08, 0.06), 5, 3 if chosen else 2))
	if _beard_box:
		_beard_box.visible = look.get("sex", "male") == "male"
	_rebuild_model()

func _select(cls: ClassDef, quiet := false) -> void:
	var keep := look.duplicate()
	var changed := selected != cls or quiet
	selected = cls
	look = LooksCatalog.default_look(cls)
	for k in LOOK_KEYS:                       # trocar de classe mantém o visual escolhido
		if keep.has(k):
			look[k] = keep[k]
	_update_cards()
	_refresh()
	demo_clip = signature_clip(cls)
	if not quiet and step == STEP_CLASS:
		_play_demo()                          # repete ao clicar de novo na mesma classe
	elif changed:
		_play_idle()

func _primary() -> void:
	if step == STEP_CLASS:
		show_step(STEP_LOOK)
	else:
		_confirm()

func _confirm() -> void:
	var req := build_request()
	if req:
		create_confirmed.emit(req)

func _apply_dev_look(spec: String) -> void:
	var f := spec.split(":")
	if f.size() < 7 or not GameData.classes.has(f[0]):
		return
	_select(GameData.classes[f[0]], true)
	for i in range(5):
		look[["sex", "hair", "beard", "eyes", "hair_color"][i]] = f[i + 1]
	look["beard_color"] = f[5]
	look["eye_color"] = f[6]
	show_step(STEP_LOOK)

# ---------------------------------------------------------------------------
# boneco no pedestal
func _rebuild_model(force := false) -> void:
	if preview == null or selected == null or not is_instance_valid(preview):
		return
	var eq := starter_equipment(selected, step == STEP_CLASS)      # Visual: sem chapéu/capuz
	var key := "%s_%s" % [selected.id, look.get("sex", selected.body_type)]
	var k := preview.show_create(selected, look, eq)
	var fresh := force or k != kit or key != _kit_key
	kit = k
	_kit_key = key
	if kit and fresh:
		_play_idle()

func _weapon_type() -> String:
	var w: ItemDef = starter_equipment(selected).get(ItemDef.Slot.WEAPON) if selected else null
	return w.weapon_type if w else ""

func _play_idle() -> void:
	_demo_left = 0.0
	if kit and is_instance_valid(kit):
		PedestalPreview.play_idle(kit, _weapon_type(), IDLE_FADE)

func _stop_demo() -> void:
	if _demo_left > 0.0:
		_play_idle()

## Toca uma vez o clipe da skill-assinatura e agenda a volta ao idle.
func _play_demo() -> void:
	_demo_left = 0.0
	if kit == null or not is_instance_valid(kit) or kit.anim == null or demo_clip == "":
		return
	var clip := kit.resolve(demo_clip)
	if clip == "":
		var s := signature_skill(selected)
		clip = kit.resolve("cast" if s and s.kind != SkillDef.Kind.PHYSICAL else "attack")
	if clip == "":
		return
	kit.anim.play(clip, DEMO_FADE, 1.0)
	kit.anim.seek(0.0, true)
	_demo_left = maxf(kit.anim.get_animation(clip).length, 0.2)

func _process(delta: float) -> void:
	if kit and is_instance_valid(kit):
		kit.rotation.y = lerp_angle(kit.rotation.y, _yaw, minf(1.0, delta * 10.0))
	if _demo_left > 0.0:
		_demo_left -= delta
		if _demo_left <= 0.0:
			_play_idle()

# ---------------------------------------------------------------------------
# entradas
## Esc antes da GUI (o LineEdit do nome engoliria); Enter num card de classe = Próximo.
func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or not is_visible_in_tree():
		return
	if k.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		go_back()
	elif k.keycode in [KEY_ENTER, KEY_KP_ENTER] and step == STEP_CLASS:
		var f := get_viewport().gui_get_focus_owner()
		if f != null and _cards.values().has(f):
			get_viewport().set_input_as_handled()
			var id: String = _cards.keys()[_cards.values().find(f)]
			if selected == null or id != selected.id:
				_select(GameData.classes[id], true)
			show_step(STEP_LOOK)

## Arrastar gira o boneco e a roda aproxima, só nos 40% da esquerda (o resto é dos Controls).
func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	var in_zone := get_local_mouse_position().x < size.x * DRAG_ZONE
	if mb:
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed and in_zone
		elif mb.pressed and in_zone and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_zoom(-1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0)
			get_viewport().set_input_as_handled()
	var mm := event as InputEventMouseMotion
	if mm and _dragging and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_yaw += mm.relative.x * DRAG_SPEED
		get_viewport().set_input_as_handled()

func _zoom(dir: float) -> void:
	if menu_set == null or menu_set.camera == null or menu_set.is_moving():
		return
	if _base_fov <= 0.0:
		_base_fov = menu_set.camera.fov
	menu_set.camera.fov = clampf(menu_set.camera.fov * (1.0 + dir * ZOOM_STEP), _base_fov * ZOOM_MIN, _base_fov)
