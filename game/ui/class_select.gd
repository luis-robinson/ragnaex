extends CanvasLayer
## Tela inicial em passos curtos (cabe numa tela 1080p sem rolar):
##   Personagens: cartões dos salvos (Jogar / Excluir) + "Novo personagem".
##   Criar: prévia 3D, nome e "Aleatório" à esquerda; à direita os passos 1 Classe e 2 Visual (abas Corpo / Cabelo / Rosto).

var hud
var has_save := false
var selected: ClassDef = null
var name_edit: LineEdit
var desc_label: Label
var start_btn: Button
var cards: Dictionary = {}
var look: Dictionary = {}
var _vp: SubViewport
var _model: KitModel = null
var _model_key := ""            # classe + sexo do kit carregado (troca o kit só quando muda)
var _yaw := 0.4
var _rows: Dictionary = {}       # campo -> [Label do valor, opções]
var _beard_box: Control
var _page := "create"           # slots | create
var _step := "class"            # class | look
var _look_tab := "body"         # body | hair | face
var _body: VBoxContainer         # conteúdo da página (troca inteiro)
var _step_box: VBoxContainer     # conteúdo do passo à direita
var _step_btns: Dictionary = {}
var _tab_btns: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _panel: PanelContainer

const NAMES := ["Aiden", "Lúcia", "Brann", "Sora", "Kaito", "Mira", "Dante", "Elara", "Tamsin", "Oren", "Lyra", "Bastian", "Nyx", "Rurik"]
const PANEL_W := 1080
const PANEL_H := 640

func _ready() -> void:
	layer = 20
	_rng.randomize()
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.07, 0.72)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = UiKit.panel()
	center.add_child(_panel)
	var panel := _panel
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var title := UiKit.label("RAGNAEX", 30, UiKit.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	_body = VBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_body)
	look = {}
	_page = "slots" if has_save else "create"
	_build_page()
	if DevArgs.flag("--look"):     # --look=<classe>:<sexo>:<cabelo>:<barba>:<olhos>:<cor cabelo>:<cor olhos> (revisar a prévia)
		var f := DevArgs.value("--look").split(":")
		if f.size() >= 7 and GameData.classes.has(f[0]):
			_go_create()
			_select(GameData.classes[f[0]])
			for i in range(5):
				look[["sex", "hair", "beard", "eyes", "hair_color"][i]] = f[i + 1]
			look["beard_color"] = f[5]
			look["eye_color"] = f[6]
			_refresh()

func _clear(c: Node) -> void:
	for ch in c.get_children():
		ch.queue_free()

func _build_page() -> void:
	_clear(_body)
	_rows.clear()
	cards.clear()
	_vp = null
	_model = null
	_model_key = ""
	_panel.custom_minimum_size = Vector2(PANEL_W, PANEL_H) if _page == "create" else Vector2(PANEL_W, 0)
	_panel.reset_size()
	if _page == "slots":
		_build_slots()
	else:
		_build_create()

# ---------------------------------------------------------------------------
# página: personagens salvos
func _build_slots() -> void:
	var sub := UiKit.label("Seus personagens", 16, UiKit.TEXT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(sub)
	var pad := Control.new()
	pad.custom_minimum_size.y = 10
	_body.add_child(pad)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	var cc := CenterContainer.new()
	cc.add_child(grid)
	_body.add_child(cc)
	for i in range(SaveSystem.SLOTS):
		var d := SaveSystem.slot_summary(i)
		if not d.is_empty():
			grid.add_child(_slot_card(i, d))
	var free := SaveSystem.first_free_slot()
	if free >= 0:
		var nb := UiKit.button("+  Novo personagem", _go_create, 300)
		nb.custom_minimum_size = Vector2(300, 96)
		nb.add_theme_font_size_override("font_size", 17)
		grid.add_child(nb)
	else:
		_body.add_child(UiKit.para("Todos os %d espaços estão ocupados: exclua um personagem para criar outro." % SaveSystem.SLOTS, 12, Color(1, 0.6, 0.5)))

func _slot_card(i: int, d: Dictionary) -> Control:
	var cls: ClassDef = GameData.classes.get(d["class"], GameData.classes["paladin"])
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(300, 96)
	card.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.08, 0.07, 0.11, 0.95), cls.color.darkened(0.2), 8, 2))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	card.add_child(h)
	h.add_child(UiKit.class_icon(cls, 56))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	h.add_child(info)
	info.add_child(UiKit.label(str(d["name"]), 17, UiKit.GOLD))
	info.add_child(UiKit.label("%s  ·  Nível %d" % [cls.name, int(d["level"])], 12, UiKit.TEXT))
	var md: MapDef = GameData.maps.get(d["map"])
	if md:
		info.add_child(UiKit.label(md.name, 11, UiKit.MUTED))
	var btns := VBoxContainer.new()
	btns.add_theme_constant_override("separation", 4)
	h.add_child(btns)
	btns.add_child(UiKit.button("▶ Jogar", _play_slot.bind(i, cls, str(d["name"])), 86))
	var del := UiKit.button("Excluir", Callable(), 86)
	del.add_theme_font_size_override("font_size", 11)
	del.pressed.connect(_delete_slot.bind(i, del))
	btns.add_child(del)
	return card

func _go_create() -> void:
	_page = "create"
	_step = "class"
	_build_page()

func _go_slots() -> void:
	_page = "slots"
	_build_page()

# ---------------------------------------------------------------------------
# página: criar personagem
func _build_create() -> void:
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(cols)
	# esquerda: prévia, nome, aleatório
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	cols.add_child(left)
	left.add_child(_preview())
	left.add_child(UiKit.para("Arraste para girar", 10, UiKit.MUTED))
	var nh := HBoxContainer.new()
	left.add_child(nh)
	nh.add_child(UiKit.label("Nome", 13, UiKit.MUTED))
	name_edit = LineEdit.new()
	name_edit.text = NAMES[_rng.randi() % NAMES.size()]
	name_edit.custom_minimum_size.x = 190
	name_edit.max_length = 16
	nh.add_child(name_edit)
	nh.add_child(UiKit.button("🎲", _random_name, 36))
	left.add_child(UiKit.button("🎲  Visual aleatório", _random_look, 300))
	# direita: passos
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	var steps := HBoxContainer.new()
	steps.add_theme_constant_override("separation", 6)
	right.add_child(steps)
	_step_btns.clear()
	for st in [["class", "1  Classe"], ["look", "2  Visual"]]:
		var b := UiKit.button(st[1], _set_step.bind(st[0]), 170)
		_step_btns[st[0]] = b
		steps.add_child(b)
	_step_box = VBoxContainer.new()
	_step_box.add_theme_constant_override("separation", 6)
	_step_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_step_box)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 10)
	right.add_child(nav)
	if has_save:
		nav.add_child(UiKit.button("← Personagens", _go_slots, 150))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(sp)
	var nxt := UiKit.button("Próximo: visual →", _set_step.bind("look"), 170)
	nxt.name = "Next"
	nav.add_child(nxt)
	start_btn = UiKit.button("Começar aventura", _start, 190)
	start_btn.add_theme_color_override("font_color", UiKit.GOLD)
	nav.add_child(start_btn)
	if selected == null:
		selected = GameData.class_list()[0]
	_build_step()
	_select(selected)

func _set_step(st: String) -> void:
	_step = st
	_build_step()
	_refresh()

func _build_step() -> void:
	_clear(_step_box)
	_rows.clear()
	cards.clear()
	_beard_box = null
	for k in _step_btns:
		_step_btns[k].modulate = Color(1, 1, 1) if k == _step else Color(0.65, 0.65, 0.65)
	var nxt: Node = _step_box.get_parent().find_child("Next", true, false)
	if nxt:
		nxt.visible = _step == "class"
	if _step == "class":
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		_step_box.add_child(grid)
		for cls in GameData.class_list():
			grid.add_child(_class_card(cls))
		var dp := PanelContainer.new()
		dp.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.06, 0.055, 0.09, 0.9), Color(0.25, 0.22, 0.3), 6, 1))
		dp.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_step_box.add_child(dp)
		desc_label = UiKit.label("", 12)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		desc_label.custom_minimum_size = Vector2(560, 120)
		dp.add_child(desc_label)
		_update_desc()
		return
	# visual: abas Corpo / Cabelo / Rosto
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	_step_box.add_child(tabs)
	_tab_btns.clear()
	for t in [["body", "Corpo"], ["hair", "Cabelo"], ["face", "Rosto"]]:
		var b := UiKit.button(t[1], _set_look_tab.bind(t[0]), 120)
		b.modulate = Color(1, 1, 1) if t[0] == _look_tab else Color(0.65, 0.65, 0.65)
		tabs.add_child(b)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_step_box.add_child(box)
	match _look_tab:
		"body":
			box.add_child(_choice_row("Sexo", "sex", LooksCatalog.SEXES))
			box.add_child(_section("Pele", _swatches("skin", LooksCatalog.SKIN_COLORS, 9)))
		"hair":
			box.add_child(_choice_row("Cabelo", "hair", LooksCatalog.HAIR))
			box.add_child(_section("Cor", _swatches("hair_color", LooksCatalog.HAIR_COLORS, 7)))
			_beard_box = VBoxContainer.new()
			_beard_box.add_theme_constant_override("separation", 6)
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

func _set_look_tab(t: String) -> void:
	_look_tab = t
	_build_step()
	_refresh()

func _section(title: String, content: Control) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var t := UiKit.label(title, 12, UiKit.MUTED)
	t.custom_minimum_size.x = 96
	h.add_child(t)
	h.add_child(content)
	return h

func _class_card(cls: ClassDef) -> Control:
	var card := UiKit.button("", Callable(), 134)
	card.custom_minimum_size = Vector2(134, 82)
	var cv := VBoxContainer.new()
	cv.set_anchors_preset(Control.PRESET_FULL_RECT)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	cv.add_theme_constant_override("separation", 0)
	var sq := UiKit.class_icon(cls, 42)
	sq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hb := CenterContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(sq)
	cv.add_child(hb)
	var nl := UiKit.label(cls.name, 14, UiKit.TEXT)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(nl)
	var rl := UiKit.label("%s · %d builds" % [cls.role, cls.builds.size()], 10, UiKit.MUTED)
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(rl)
	card.add_child(cv)
	card.pressed.connect(_select.bind(cls))
	cards[cls.id] = card
	return card

## Linha "◀ valor ▶" que percorre as opções de um campo do look.
func _choice_row(title: String, key: String, options: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var t := UiKit.label(title, 13, UiKit.MUTED)
	t.custom_minimum_size.x = 96
	row.add_child(t)
	row.add_child(UiKit.button("◀", _cycle.bind(key, options, -1), 34))
	var val := UiKit.label("", 14)
	val.custom_minimum_size.x = 170
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(val)
	row.add_child(UiKit.button("▶", _cycle.bind(key, options, 1), 34))
	_rows[key] = [val, options]
	return row

## Paleta de cores clicáveis para um campo de cor do look (a escolhida ganha borda dourada).
func _swatches(key: String, colors: Array, cols: int = 7) -> Control:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 5)
	g.add_theme_constant_override("v_separation", 5)
	for hexc in colors:
		var b := Button.new()
		b.custom_minimum_size = Vector2(30, 24)
		b.focus_mode = Control.FOCUS_NONE
		var chosen := str(look.get(key, "")).to_lower() == str(hexc).to_lower()
		b.add_theme_stylebox_override("normal", UiKit.panel_style(Color.html(hexc), UiKit.GOLD if chosen else Color(0.1, 0.08, 0.06), 5, 3 if chosen else 2))
		var sh := UiKit.panel_style(Color.html(hexc).lightened(0.15), UiKit.GOLD, 5, 2)
		b.add_theme_stylebox_override("hover", sh)
		b.add_theme_stylebox_override("pressed", sh)
		b.pressed.connect(_set_look.bind(key, hexc))
		g.add_child(b)
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
	if key.ends_with("color") or key == "skin":
		_build_step()                        # borda dourada na cor escolhida
	_refresh()

func _random_look() -> void:
	var keep_sex: String = look.get("sex", "male")
	var r := LooksCatalog.random_look(_rng)
	r["sex"] = keep_sex
	if keep_sex == "female":
		r["beard"] = "none"
	look = LooksCatalog.normalized(r, selected)
	_build_step()
	_refresh()

func _random_name() -> void:
	name_edit.text = NAMES[_rng.randi() % NAMES.size()]

func _refresh() -> void:
	for key in _rows:
		var val: Label = _rows[key][0]
		val.text = str(_rows[key][1].get(look.get(key, ""), "—"))
	if _beard_box:
		_beard_box.visible = look.get("sex", "male") == "male"
	_rebuild_model()

func _select(cls: ClassDef) -> void:
	var keep := look.duplicate()
	selected = cls
	look = LooksCatalog.default_look(cls)
	if not keep.is_empty():                  # trocar de classe mantém o visual escolhido
		for k in ["sex", "skin", "hair", "beard", "eyes", "eye_color", "hair_color", "beard_color", "brows", "mouth", "marks", "mark_color"]:
			if keep.has(k):
				look[k] = keep[k]
	for id in cards:
		cards[id].modulate = Color(1, 1, 1) if id == cls.id else Color(0.62, 0.62, 0.62)
	_update_desc()
	if start_btn:
		start_btn.disabled = false
	_refresh()

func _update_desc() -> void:
	if desc_label == null or not is_instance_valid(desc_label) or selected == null:
		return
	var cls := selected
	# builds: arma + papel; as skills (20+) ficam na janela K dentro do jogo
	var txt := "%s — %s\n\n%s\n\n%d skills (você equipa 6) · builds:\n" % [cls.name, cls.role, cls.description, cls.skill_ids.size()]
	for b in cls.builds:
		var w: Array = []
		for t in b["main"]:
			w.append(GearCatalog.WEAPON_NAMES.get(t, t))
		var arms := " / ".join(w)
		if b["off"].size() > 0:
			arms += " + " + " ou ".join(b["off"].map(func(o): return GearCatalog.WEAPON_NAMES.get(o, o)))
		txt += "   • %s (%s): %s\n" % [b["name"], b["role"], arms]
	desc_label.text = txt

# ---------------------------------------------------------------------------
# prévia 3D
func _preview() -> Control:
	var cont := SubViewportContainer.new()
	cont.stretch = true
	cont.custom_minimum_size = Vector2(300, 400)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	cont.add_child(_vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.85, 1.0)
	e.ambient_light_energy = 0.35
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 0.9
	env.environment = e
	_vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 35, 0)
	sun.light_energy = 0.75
	_vp.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 200, 0)
	rim.light_energy = 0.3
	rim.light_color = Color(0.7, 0.8, 1.0)
	_vp.add_child(rim)
	var cam := Camera3D.new()
	cam.fov = 30.0
	_vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.15, 3.6), Vector3(0, 0.85, 0), Vector3.UP)      # corpo inteiro, rosto em destaque
	cont.gui_input.connect(_on_preview_input)
	cont.mouse_filter = Control.MOUSE_FILTER_STOP
	return cont

func _rebuild_model() -> void:
	if selected == null or _vp == null or not is_instance_valid(_vp):
		return
	var key := "%s_%s" % [selected.id, look.get("sex", "male")]
	if key != _model_key:
		if _model and is_instance_valid(_model):
			_model.queue_free()
		_model = KitModel.create(str(look.get("sex", "male")), selected.hair_color, 0.012, selected.id)
		_model_key = key
		if _model == null:
			return
		_vp.add_child(_model)
		var idle := _model.resolve("idle")
		if idle != "":
			_model.anim.play(idle)
	if _model:
		_model.apply_look(look)
		var eq := {}
		for iid in selected.starting_equipment:
			var it: ItemDef = GameData.items.get(iid)
			if it and it.slot != ItemDef.Slot.HEAD:       # sem chapéu/capuz: o cabelo é o que se está escolhendo
				eq[it.slot] = it
		_model.apply_equipment(eq)

func _on_preview_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_yaw += ev.relative.x * 0.012

func _process(delta: float) -> void:
	if _model and is_instance_valid(_model):
		_model.rotation.y = lerp_angle(_model.rotation.y, _yaw, minf(1.0, delta * 10.0))

func _start() -> void:
	if selected == null:
		return
	var free := SaveSystem.first_free_slot()
	if free < 0:
		return
	var n := name_edit.text.strip_edges()
	if n == "":
		n = "Herói"
	SaveSystem.slot = free                # personagem novo vai para um espaço livre (os outros ficam)
	hud.on_class_chosen(selected, n, false, look.duplicate())

func _play_slot(i: int, cls: ClassDef, char_name: String) -> void:
	SaveSystem.slot = i
	hud.on_class_chosen(cls, char_name, true)

func _delete_slot(i: int, btn: Button) -> void:
	if not btn.has_meta("armed"):            # 1º clique arma; 2º apaga
		btn.set_meta("armed", true)
		btn.text = "Confirmar?"
		btn.add_theme_color_override("font_color", Color(1, 0.45, 0.4))
		return
	SaveSystem.delete_slot(i)
	hud.reopen_class_select()
