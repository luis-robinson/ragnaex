extends Control
## Janelas estilo MMORPG: Bolsa (I), Personagem (C), Árvore de Skills (K), Quests (L), Grupo (P).
## Várias abertas ao mesmo tempo, cada uma arrastável pela barra de título e lembrando a posição.
## Conteúdo reconstruído ao abrir e a cada mudança relevante (simples e robusto).

var hud
var open_name := ""                     # última janela aberta (compatibilidade: smoke / NPC)
var wins: Dictionary = {}               # nome -> {"panel": PanelContainer, "scroll": ScrollContainer}
var tooltip: PanelContainer
var tip_rtl: RichTextLabel
var _pos: Dictionary = {}               # nome -> posição escolhida arrastando
var _drag := ""
var _preview_model: Node3D = null       # prévia 3D da janela de personagem
var _preview_yaw := 0.0
var _preview_drag := 0.0

const TITLES := {"inventory": "Bolsa", "character": "Personagem", "skills": "Teia de Skills", "quests": "Quests", "party": "Grupo"}
const KEYS := {"inventory": "I", "character": "C", "skills": "K", "quests": "L", "party": "P"}
## tamanho do conteúdo (a moldura soma título e bordas); base 1600×900
const SIZES := {"inventory": Vector2(392, 470), "character": Vector2(470, 790), "skills": Vector2(1110, 720), "quests": Vector2(620, 600), "party": Vector2(430, 480)}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip = UiKit.panel(Color(0.06, 0.05, 0.09, 0.96))
	tooltip.visible = false
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.z_index = 50
	tip_rtl = RichTextLabel.new()
	tip_rtl.bbcode_enabled = true
	tip_rtl.fit_content = true
	tip_rtl.custom_minimum_size = Vector2(260, 10)
	tip_rtl.add_theme_font_size_override("normal_font_size", 12)
	tip_rtl.add_theme_font_size_override("bold_font_size", 13)
	tip_rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.add_child(tip_rtl)
	add_child(tooltip)
	Events.item_gained.connect(func(id, _i, _c): _maybe_refresh(id, ["inventory"]))
	Events.item_removed.connect(func(id, _i, _c): _maybe_refresh(id, ["inventory"]))
	Events.equipment_changed.connect(func(id): _maybe_refresh(id, ["inventory", "character"]))
	Events.mastery_changed.connect(func(id, _s, _l): _maybe_refresh(id, ["skills", "character"]))
	Events.level_up.connect(func(id, _l): _maybe_refresh(id, ["skills", "character"]))
	Events.quest_accepted.connect(func(id, _q): _maybe_refresh(id, ["quests"]))
	Events.quest_completed.connect(func(id, _q): _maybe_refresh(id, ["quests"]))
	Events.quest_abandoned.connect(func(id, _q): _maybe_refresh(id, ["quests"]))
	Events.party_changed.connect(func(_p): _maybe_refresh(Sim.player.id if Sim.player else -1, ["party"]))

func _maybe_refresh(entity_id: int, names: Array) -> void:
	if Sim.player and entity_id == Sim.player.id:
		for n in names:
			if wins.has(n):
				_rebuild(n)

func _process(_delta: float) -> void:
	# prévia do personagem: gira devagar (pausa um pouco depois de arrastar)
	if _preview_model and is_instance_valid(_preview_model) and wins.has("character"):
		_preview_drag = maxf(0.0, _preview_drag - _delta)
		if _preview_drag <= 0.0:
			_preview_yaw += _delta * 0.5
			_preview_model.rotation.y = _preview_yaw
	if tooltip.visible:
		var mp := get_viewport().get_mouse_position()
		var sz := get_viewport().get_visible_rect().size
		tooltip.position = Vector2(minf(mp.x + 16, sz.x - tooltip.size.x - 8), minf(mp.y + 16, sz.y - tooltip.size.y - 8))

func is_open(name: String = "") -> bool:
	return wins.has(name) if name != "" else not wins.is_empty()

func toggle(name: String) -> void:
	if wins.has(name):
		close(name)
	else:
		open_name = name
		_rebuild(name)

func close(name: String) -> void:
	if wins.has(name):
		wins[name]["panel"].queue_free()
		wins.erase(name)
	if name == "character":
		_preview_model = null
	tooltip.visible = false
	if open_name == name:
		open_name = wins.keys().back() if not wins.is_empty() else ""

func close_all() -> void:
	for n in wins.keys():
		close(n)
	open_name = ""

## Posição padrão de cada janela (como num MMO: personagem à esquerda, bolsa à direita, árvore no centro).
func _default_pos(name: String, size: Vector2) -> Vector2:
	var vp := get_viewport_rect().size
	var top := 150.0                     # logo abaixo do quadro do personagem (cresce com a barra de buffs)
	if hud and hud.player_frame:
		top = maxf(top, hud.player_frame.get_global_rect().end.y + 10.0)
	match name:
		"character": return Vector2(28, top)
		"quests": return Vector2(28, top)
		"party": return Vector2(340, top)
		"inventory": return Vector2(vp.x - size.x - 28, vp.y - size.y - 230)
	return ((vp - size) * 0.5).floor()

func _rebuild(name: String) -> void:
	# mantém a rolagem ao reconstruir (comprar um nó não volta pro topo)
	var keep_scroll := 0
	var pos := Vector2(-1, -1)
	if wins.has(name):
		var old: Dictionary = wins[name]
		if is_instance_valid(old["scroll"]):
			keep_scroll = old["scroll"].scroll_vertical
		pos = old["panel"].position
		old["panel"].queue_free()
		wins.erase(name)
	tooltip.visible = false
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.07, 0.06, 0.1, 0.96), UiKit.BORDER, 8, 2))
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	# barra de título: arrasta a janela; ✕ fecha
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.16, 0.12, 0.2, 1), Color(0, 0, 0, 0), 5, 0))
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.mouse_default_cursor_shape = Control.CURSOR_MOVE
	bar.gui_input.connect(_on_title_input.bind(name))
	v.add_child(bar)
	var hb := HBoxContainer.new()
	bar.add_child(hb)
	var t := UiKit.label("%s  [%s]" % [TITLES.get(name, name), KEYS.get(name, "")], 15, UiKit.GOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(t)
	var x := UiKit.button("✕", func(): close(name), 30)
	hb.add_child(x)
	var size: Vector2 = SIZES.get(name, Vector2(520, 440))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	scroll.add_child(body)
	wins[name] = {"panel": panel, "scroll": scroll}
	match name:
		"inventory": _inventory(body)
		"character": _character(body)
		"skills": _skills(body)
		"quests": _quests(body)
		"party": _party(body)
	panel.reset_size()
	if pos.x < 0:
		pos = _pos.get(name, _default_pos(name, panel.size))
	panel.position = _clamp_pos(pos, panel.size)
	if keep_scroll > 0:
		scroll.set_deferred("scroll_vertical", keep_scroll)

func _clamp_pos(p: Vector2, size: Vector2) -> Vector2:
	var vp := get_viewport_rect().size
	return Vector2(clampf(p.x, 0, maxf(0, vp.x - size.x)), clampf(p.y, 0, maxf(0, vp.y - 60)))

func _on_title_input(ev: InputEvent, name: String) -> void:
	if not wins.has(name):
		return
	var panel: PanelContainer = wins[name]["panel"]
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_drag = name if ev.pressed else ""
		if ev.pressed:
			move_child(panel, get_child_count() - 1)        # janela clicada vem pra frente
			move_child(tooltip, get_child_count() - 1)
	elif ev is InputEventMouseMotion and _drag == name:
		panel.position = _clamp_pos(panel.position + ev.relative, panel.size)
		_pos[name] = panel.position

## Dica flutuante compartilhada (janelas, NPCs): segue o mouse por cima de tudo.
func show_tip(text: String) -> void:
	tip_rtl.text = text
	tooltip.visible = true
	tooltip.reset_size()

func hide_tip() -> void:
	tooltip.visible = false

# ---------------------------------------------------------------------------
## Bolsa: grade de slots com ícone, quantidade e borda da raridade; ouro embaixo.
## Clique: equipar/usar · Shift+clique: poção em F1-F3 ou arma de 1 mão na mão secundária.
const BAG_COLS := 6
const BAG_MIN_SLOTS := 36
const SLOT_PX := 56

func _inventory(body: VBoxContainer) -> void:
	var p: SimEntity = Sim.player
	var grid := GridContainer.new()
	grid.columns = BAG_COLS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.mouse_filter = Control.MOUSE_FILTER_STOP
	grid.set_drag_forwarding(Callable(), _can_drop_on_bag, _drop_on_bag)
	body.add_child(grid)
	var ids := p.inventory.keys()
	# equipamento primeiro (raridade maior antes), depois consumíveis, depois materiais
	ids.sort_custom(func(a, b): return _bag_key(a) < _bag_key(b))
	var n := 0
	for item_id in ids:
		var it: ItemDef = GameData.items.get(item_id)
		if it == null:
			continue
		grid.add_child(_bag_slot(it, int(p.inventory[item_id])))
		n += 1
	for i in range(maxi(0, maxi(BAG_MIN_SLOTS, int(ceil(n / float(BAG_COLS))) * BAG_COLS) - n)):
		grid.add_child(_bag_slot(null, 0))
	body.add_child(UiKit.hsep(4))
	var foot := HBoxContainer.new()
	body.add_child(foot)
	var g := UiKit.label("◉ %d ouro" % p.gold, 15, UiKit.GOLD)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(g)
	foot.add_child(UiKit.label("%d itens" % p.inventory_weight(), 12, UiKit.MUTED))
	body.add_child(UiKit.para("Arraste: equipamento para o boneco (C), poção para F1-F3  ·  clique: equipar / usar  ·  Shift+clique: arma na mão secundária", 11, UiKit.MUTED))

func _bag_key(item_id: String) -> String:
	var it: ItemDef = GameData.items.get(item_id)
	if it == null:
		return "9"
	var group := 0 if it.is_equipment() else (1 if it.type == ItemDef.Type.CONSUMABLE else 2)
	return "%d%d%s" % [group, 9 - it.rarity, it.name]

func _bag_slot(it: ItemDef, count: int) -> Control:
	var box := PanelContainer.new()
	var border: Color = UiKit.rarity_color(it.rarity) if it and it.is_equipment() else Color(0.28, 0.25, 0.33)
	var sb := UiKit.panel_style(Color(0.05, 0.045, 0.07, 0.95), border, 5, 2 if it and it.rarity > 0 else 1)
	sb.set_content_margin_all(4)
	box.add_theme_stylebox_override("panel", sb)
	box.custom_minimum_size = Vector2(SLOT_PX, SLOT_PX)
	if it == null:
		box.set_drag_forwarding(Callable(), _can_drop_on_bag, _drop_on_bag)     # quadrado vazio também recebe
		return box
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(holder)
	var icon := UiKit.item_icon(it, SLOT_PX - 8)
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(icon)
	if icon is ColorRect:            # sem ícone: sigla curta por cima da cor
		var tag := UiKit.label(_bag_glyph(it), 12, Color(0.08, 0.06, 0.1), false)
		tag.set_anchors_preset(Control.PRESET_FULL_RECT)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		holder.add_child(tag)
	if count > 1:
		var c := UiKit.label(str(count), 12, UiKit.TEXT)
		c.anchor_left = 1.0; c.anchor_right = 1.0; c.anchor_top = 1.0; c.anchor_bottom = 1.0
		c.offset_left = -30; c.offset_right = 0; c.offset_top = -18; c.offset_bottom = 0
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		holder.add_child(c)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.mouse_entered.connect(func(): show_tip(UiKit.item_tooltip(it) + "\n[color=#9f9]%s[/color]" % _bag_hint(it)))
	box.mouse_exited.connect(hide_tip)
	box.gui_input.connect(_on_bag_input.bind(it))
	box.set_drag_forwarding(_drag_from_bag.bind(it), _can_drop_on_bag, _drop_on_bag)
	drag_sources[it.id] = box              # revisão (--hotbar_drag_check): onde está cada item na tela
	return box

# --- arrastar e soltar: bolsa -> slot do boneco equipa; slot -> bolsa desequipa ----------------
var _dragging := false           # o clique (soltar o botão) não vale se virou arrasto
var drag_sources := {}           # id de item/skill -> quadrado que se arrasta (só para a revisão com mouse simulado)

## Clique = apertar e soltar sem arrastar (no aperto ainda pode virar arrasto).
func _on_bag_input(ev: InputEvent, it: ItemDef) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_dragging = false
		elif not _dragging:
			_on_item_click(it)

func _drag_preview(it: ItemDef) -> Control:
	var wrap := Control.new()
	var ic := UiKit.item_icon(it, 52)
	ic.position = Vector2(-26, -26)
	ic.modulate.a = 0.9
	wrap.add_child(ic)
	return wrap

func _drag_from_bag(_at: Vector2, it: ItemDef) -> Variant:
	if not it.is_equipment() and not (it.type == ItemDef.Type.CONSUMABLE and not it.consume.has("bag")):
		return null             # equipamento vai para o boneco; consumível vai para F1-F3 da barra
	_dragging = true
	hide_tip()
	set_drag_preview(_drag_preview(it))
	return {"rx_drag": "bag", "item": it.id}

func _drag_from_slot(_at: Vector2, slot: int) -> Variant:
	var it: ItemDef = Sim.player.equipment.get(slot)
	if it == null:
		return null
	_dragging = true
	hide_tip()
	set_drag_preview(_drag_preview(it))
	return {"rx_drag": "slot", "slot": slot}

func _can_drop_on_bag(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("rx_drag") == "slot"

func _drop_on_bag(_at: Vector2, data: Variant) -> void:
	Sim.unequip(Sim.player, int(data["slot"]))

## O item cabe nesse slot do boneco? (mesmo slot; anel em qualquer dos dois; arma de 1 mão na secundária se a classe usa)
func _fits_slot(it: ItemDef, slot: int) -> bool:
	if it == null or not it.is_equipment():
		return false
	if it.slot == ItemDef.Slot.RING and slot in [ItemDef.Slot.RING, ItemDef.Slot.RING2]:
		return Sim.equip_error(Sim.player, it) == ""
	if slot == ItemDef.Slot.OFFHAND and it.slot == ItemDef.Slot.WEAPON:
		return Sim.equip_error(Sim.player, it, true) == ""
	return it.slot == slot and Sim.equip_error(Sim.player, it) == ""

func _can_drop_on_slot(_at: Vector2, data: Variant, slot: int) -> bool:
	if not (data is Dictionary) or data.get("rx_drag") != "bag":
		return false
	return _fits_slot(GameData.items.get(str(data["item"])), slot)

func _drop_on_slot(_at: Vector2, data: Variant, slot: int) -> void:
	var it: ItemDef = GameData.items.get(str(data["item"]))
	if it == null:
		return
	Sim.equip(Sim.player, it.id, slot == ItemDef.Slot.OFFHAND and it.slot == ItemDef.Slot.WEAPON, slot)

func _bag_glyph(it: ItemDef) -> String:
	if it.is_equipment():
		return _slot_glyph(it)
	if it.type == ItemDef.Type.CONSUMABLE:
		return "POÇ" if it.id.begins_with("potion") else "USO"
	return it.name.substr(0, 3).to_upper()

func _bag_hint(it: ItemDef) -> String:
	if it.is_equipment():
		return "Clique: equipar" + ("  ·  Shift: mão secundária" if it.weapon_type in ItemDef.ONE_HANDED_MELEE else "")
	if it.type == ItemDef.Type.CONSUMABLE:
		return "Clique: usar  ·  arraste para F1-F3 (ou Shift+clique)"
	return "Material (venda no mercador ou use na forja)"

func _on_item_click(it: ItemDef) -> void:
	var p: SimEntity = Sim.player
	if Input.is_key_pressed(KEY_SHIFT) and it.type == ItemDef.Type.CONSUMABLE:
		# coloca no primeiro slot vazio (ou substitui o F1)
		var slot := 0
		for i in range(3):
			if p.potion_slots[i] == "" or p.potion_slots[i] == it.id:
				slot = i
				break
		Sim.set_potion_slot(p, slot, it.id)
		Events.notification.emit("%s → F%d" % [it.name, slot + 1])
		_rebuild("inventory")
		return
	if it.is_equipment():
		# Shift+clique numa arma de 1 mão: mão secundária (empunhar duas)
		Sim.equip(p, it.id, Input.is_key_pressed(KEY_SHIFT) and it.weapon_type in ItemDef.ONE_HANDED_MELEE)
	elif it.consume.has("bag"):
		Sim.use_bag_upgrade(p, it.id)
		_rebuild("inventory")
	elif it.type == ItemDef.Type.CONSUMABLE:
		for i in range(3):
			if p.potion_slots[i] == it.id:
				Sim.use_potion(p, i)
				return
		Sim.set_potion_slot(p, 2, it.id)
		Sim.use_potion(p, 2)

# ---------------------------------------------------------------------------
## Janela C estilo MMORPG: boneco 3D com o equipamento no meio, slots dos lados, stats à direita.
func _character(body: VBoxContainer) -> void:
	var p: SimEntity = Sim.player
	var s := p.stats
	body.add_child(UiKit.label("%s — %s Lv.%d  (%s)" % [p.name, p.class_def.name, p.level, p.class_def.role], 16, UiKit.GOLD))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(row)
	# boneco: slots à esquerda e à direita da prévia 3D; atributos e stats embaixo (janela estreita, cabe com a bolsa)
	row.add_child(_slot_column(p, [ItemDef.Slot.HEAD, ItemDef.Slot.BODY, ItemDef.Slot.LEGS, ItemDef.Slot.BOOTS]))
	row.add_child(_preview(p))
	row.add_child(_slot_column(p, [ItemDef.Slot.WEAPON, ItemDef.Slot.OFFHAND, ItemDef.Slot.GLOVES, ItemDef.Slot.CAPE]))
	var jewels := _slot_column(p, [ItemDef.Slot.AMULET, ItemDef.Slot.RING, ItemDef.Slot.RING2], true)
	jewels.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(jewels)
	# stats
	var st := VBoxContainer.new()
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(st)
	st.add_child(UiKit.label("Atributos (vêm do equipamento):", 13))
	var g := GridContainer.new()
	g.columns = 2
	st.add_child(g)
	var desc := {
		"FOR": "+ATK físico · bloqueio",
		"AGI": "+arco/adaga · +crit físico",
		"VIT": "+HP · +DEF física",
		"WILL": "+cura · +MP · +DEF mágica",
		"INT": "+dano mágico · +crit mágico",
	}
	for a in Balance.ATTRS:
		g.add_child(UiKit.label("%s %d" % [a, s.attrs[a]], 13, UiKit.GOLD))
		g.add_child(UiKit.label(desc[a], 11, UiKit.MUTED))
	st.add_child(UiKit.hsep())
	var g2 := GridContainer.new()
	g2.columns = 4
	st.add_child(g2)
	var rows := [
		["HP", "%d/%d" % [int(p.hp), int(s.max_hp)]], ["MP", "%d/%d" % [int(p.mp), int(s.max_mp)]],
		["ATK", "%.0f" % s.patk], ["MATK", "%.0f" % s.matk],
		["DEF", "%.0f" % s.pdef], ["MDEF", "%.0f" % s.mdef],
		["Crít.", "%.1f%%" % s.crit_phys], ["Crít. mág.", "%.1f%%" % s.crit_mag],
		["Cura", "x%.2f" % s.heal_power], ["Veloc.", "%.1f" % s.move_speed],
		["Bloqueio", "%.0f%%" % s.block_chance if s.has_shield else "—"], ["Redução", "%.0f%%" % s.block_reduction],
		["Pontos", str(p.mastery_points)], ["Quests", str(p.quests_completed.size())],
	]
	for r in rows:
		g2.add_child(UiKit.label(r[0], 12, UiKit.MUTED))
		g2.add_child(UiKit.label(r[1], 12))
	st.add_child(UiKit.hsep())
	st.add_child(UiKit.label("Conjuntos:", 13))
	if s.active_sets.is_empty():
		st.add_child(UiKit.para("Nenhuma peça de conjunto. Lendários caem a cada 5 níveis (chefes dropam mais).", 11, UiKit.MUTED))
	for set_id in s.active_sets:
		var rt := RichTextLabel.new()
		rt.bbcode_enabled = true
		rt.fit_content = true
		rt.custom_minimum_size.x = 440
		rt.add_theme_font_size_override("normal_font_size", 11)
		rt.add_theme_font_size_override("bold_font_size", 11)
		rt.text = UiKit.set_block(set_id).strip_edges()
		st.add_child(rt)

## Coluna de slots do boneco: quadrado com a cor do item e borda da raridade; clique desequipa.
func _slot_column(p: SimEntity, slots: Array, horizontal: bool = false) -> BoxContainer:
	var col: BoxContainer = HBoxContainer.new() if horizontal else VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	for slot in slots:
		var it: ItemDef = p.equipment.get(slot)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 1)
		col.add_child(v)
		var box := PanelContainer.new()
		var border: Color = UiKit.rarity_color(it.rarity) if it else Color(0.3, 0.28, 0.35)
		var sb := UiKit.panel_style(Color(0.06, 0.05, 0.08, 0.95), border, 6, 3 if it and it.is_legendary() else 2)
		sb.set_content_margin_all(6)
		box.add_theme_stylebox_override("panel", sb)
		box.custom_minimum_size = Vector2(76, 76)
		v.add_child(box)
		if it:
			var icon := UiKit.item_icon(it, 64)
			box.add_child(icon)
			if icon is ColorRect:            # sem ícone: sigla por cima da cor
				var tag := UiKit.label(_slot_glyph(it), 15, Color(0.08, 0.06, 0.1), false)
				tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
				box.add_child(tag)
			box.mouse_entered.connect(func(): show_tip(UiKit.item_tooltip(it) + "\n[color=#9f9]Clique ou arraste para a bolsa: desequipar[/color]"))
			box.mouse_exited.connect(hide_tip)
			box.gui_input.connect(_on_slot_input.bind(slot))
		box.mouse_filter = Control.MOUSE_FILTER_STOP
		box.set_drag_forwarding(_drag_from_slot.bind(slot) if it else Callable(), _can_drop_on_slot.bind(slot), _drop_on_slot.bind(slot))
		var nm := UiKit.label(UiKit.slot_name(slot), 10, UiKit.rarity_color(it.rarity) if it else UiKit.MUTED)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.custom_minimum_size.x = 76
		v.add_child(nm)
	return col

func _on_slot_input(ev: InputEvent, slot: int) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_dragging = false
		elif not _dragging:
			Sim.unequip(Sim.player, slot)

## Sigla curta do item no quadrado do slot (tipo de arma ou estilo da armadura).
func _slot_glyph(it: ItemDef) -> String:
	if it.weapon_type != "":
		return GearCatalog.WEAPON_NAMES.get(it.weapon_type, it.weapon_type).substr(0, 3).to_upper()
	return {"plate": "PLA", "leather": "CRO", "cloth": "TEC", "cape": "CAP"}.get(it.armor_style, "PLA" if it.armor_style != "" else "JOI")

## Prévia 3D do personagem com o equipamento atual (SubViewport com mundo próprio).
## Gira devagar sozinho; arrastar com o mouse gira na mão.
func _preview(p: SimEntity) -> Control:
	var cont := UiKit.preview_stage(Vector2(250, 360), Vector3(0, 1.25, 4.9), Vector3(0, 0.86, 0), true)
	var vp: SubViewport = cont.get_child(0)
	# chão: disco escuro suave sob os pés
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.65
	cm.bottom_radius = 0.65
	cm.height = 0.02
	disc.mesh = cm
	disc.material_override = Materials.flat(Color(0.0, 0.0, 0.0, 0.35), true)
	vp.add_child(disc)
	var k := KitModel.create(str(p.look.get("sex", p.class_def.body_type)), p.class_def.hair_color, 0.012, p.class_def.id)
	if k:
		vp.add_child(k)
		k.apply_look(p.look)
		k.apply_equipment(p.equipment)
		k.rotation.y = _preview_yaw
		var idle := k.resolve("idle")
		if idle != "":
			k.anim.play(idle)
	_preview_model = k
	cont.gui_input.connect(_on_preview_input)
	cont.mouse_filter = Control.MOUSE_FILTER_STOP
	return cont

func _on_preview_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) and _preview_model:
		_preview_drag = 2.0
		_preview_yaw += ev.relative.x * 0.012
		_preview_model.rotation.y = _preview_yaw

# ---------------------------------------------------------------------------
## Janela K: teia de skills (estilo Path of Exile) — braços por ramo (Geral + builds) saindo do início, skills
## quadradas no braço, maestria (círculo) e evoluções (losango) ao lado, atributos (bolinhas) e notáveis (círculos com
## pedra) entre elas, anéis ligando os braços. Dourado = comprado, verde = dá pra comprar agora, cinza = bloqueado.
const TREE_PX := Vector2(840, 620)
const NODE_PX := {"start": 48, "skill": 40, "talent": 26, "mastery": 24, "notable": 30, "stat": 16}
const TREE_ROW_PX := 72.0       # px por unidade da árvore na vertical: ramo comprido rola em vez de apertar as linhas
const TREE_TOP := 126.0         # espaço do nó inicial (e dos rótulos das evoluções do dash) e dos títulos dos painéis
const C_OWNED := Color(1.0, 0.8, 0.35)
const C_CAN := Color(0.45, 1.0, 0.5)
const C_LOCK := Color(0.32, 0.3, 0.36)
const C_TALENT_TAG := Color(0.86, 0.72, 1.0)
const STAT_COLORS := {"def": Color(0.55, 0.75, 1.0), "atk": Color(1.0, 0.62, 0.38), "mag": Color(0.78, 0.6, 1.0),
	"heal": Color(0.5, 0.95, 0.6), "move": Color(0.45, 0.9, 0.9)}

var _skills_tab := "tree"          # "tree" (árvore por ramo) | "picks" (talentos de escolha)

func _skills(body: VBoxContainer) -> void:
	var p: SimEntity = Sim.player
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	body.add_child(top)
	var pts := UiKit.label("Pontos de skill: %d" % p.mastery_points, 16, UiKit.GOLD)
	top.add_child(pts)
	var gap := Control.new()
	gap.custom_minimum_size.x = 18
	top.add_child(gap)
	var open_picks := _picks_open(p)
	for t in [["tree", "Teia"], ["picks", "Talentos" + (" (%d)" % open_picks if open_picks > 0 else "")]]:
		var tb := UiKit.button(t[1], _set_skills_tab.bind(t[0]), 110)
		tb.toggle_mode = true
		tb.button_pressed = _skills_tab == t[0]
		if t[0] == "picks" and open_picks > 0 and _skills_tab != "picks":
			tb.add_theme_color_override("font_color", C_CAN)
		top.add_child(tb)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(fill)
	if _skills_tab == "tree":
		top.add_child(UiKit.label("■ skill  ◆ evolução  ● maestria  ◉ notável  · atributo    dourado = comprado  verde = disponível", 12, UiKit.MUTED))
	else:
		top.add_child(UiKit.label("Talentos de classe: um por linha (a cada 5 níveis) · grátis · trocar: na cidade", 12, UiKit.MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	body.add_child(row)
	row.add_child(_tree_view(p) if _skills_tab == "tree" else _picks_view(p))
	row.add_child(_known_skills(p))

func _set_skills_tab(t: String) -> void:
	_skills_tab = t
	_rebuild("skills")

## Linhas de talento liberadas pelo nível e ainda sem escolha (o número na aba).
func _picks_open(p: SimEntity) -> int:
	var tr: Dictionary = GameData.trees.get(p.class_def.id, {})
	if tr.is_empty():
		return 0
	var rows := {}
	var done := {}
	for nid in tr["nodes"]:
		var n: Dictionary = tr["nodes"][nid]
		if n["kind"] != "pick" or p.level < int(n["level"]):
			continue
		rows[n["group"]] = true
		if p.tree.has(nid):
			done[n["group"]] = true
	return rows.size() - done.size()

## Aba Talentos: talentos de classe (ClassTalentsCatalog), uma linha a cada 5 níveis com 3 cartões; o escolhido fica
## dourado. Grátis, um por linha, trocar na cidade.
const KIND_COLORS := {"permanente": Color(1.0, 0.8, 0.4), "aura": Color(0.45, 0.85, 1.0), "invocação": Color(0.7, 0.95, 0.55),
	"sobrevivência": Color(0.55, 0.95, 0.75), "dano": Color(1.0, 0.55, 0.45), "utilidade": Color(0.82, 0.72, 1.0)}

func _picks_view(p: SimEntity) -> Control:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.03, 0.03, 0.05, 0.95), Color(0.3, 0.26, 0.36), 6, 1))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = TREE_PX
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)
	var tr: Dictionary = GameData.trees.get(p.class_def.id, {})
	var rows := {}
	for nid in tr.get("nodes", {}):
		var n: Dictionary = tr["nodes"][nid]
		if n["kind"] == "pick":
			if not rows.has(n["group"]):
				rows[n["group"]] = []
			rows[n["group"]].append(n)
	var keys := rows.keys()
	keys.sort_custom(func(a, b): return int(str(a).get_slice("_", 1)) < int(str(b).get_slice("_", 1)))
	for g in keys:
		var opts: Array = rows[g]
		opts.sort_custom(func(a, b): return a["pos"].x < b["pos"].x)
		var lv: int = int(opts[0]["level"])
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		v.add_child(line)
		var lvl := UiKit.label("Nv %d" % lv, 14, UiKit.GOLD if p.level >= lv else Color(1.0, 0.62, 0.5))
		lvl.custom_minimum_size.x = 50
		lvl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line.add_child(lvl)
		for n in opts:
			line.add_child(_pick_card(p, n))
	return frame

func _pick_card(p: SimEntity, n: Dictionary) -> Control:
	var owned := p.tree.has(n["id"])
	var why := Sim.tree_block_reason(p, n["id"])
	var can := why == "" and not owned
	var o: Dictionary = GameData.class_talents.get(n["ref"], {})
	var kind: String = o.get("kind", "utilidade")
	var col: Color = KIND_COLORS.get(kind, UiKit.TEXT)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(250, 104)
	var border := C_OWNED if owned else (C_CAN if can else C_LOCK)
	var bg := Color(0.16, 0.13, 0.07) if owned else (Color(0.07, 0.12, 0.08) if can else Color(0.07, 0.065, 0.09))
	for state in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(state, UiKit.panel_style(bg.lightened(0.08) if state == "hover" else bg, border.lightened(0.2) if state == "hover" else border, 8, 2 if owned or can else 1))
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 1)
	tv.set_anchors_preset(Control.PRESET_FULL_RECT)
	tv.offset_left = 9; tv.offset_right = -7; tv.offset_top = 5; tv.offset_bottom = -4
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(tv)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(head)
	var nm := UiKit.label(str(n["name"]), 14, C_OWNED if owned else (UiKit.TEXT if p.level >= int(n["level"]) else UiKit.MUTED))
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.clip_text = true
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(nm)
	var tag := UiKit.label(kind, 10, col)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(tag)
	var txt := UiKit.para(str(n["desc"]), 11, UiKit.TEXT if owned or can else UiKit.MUTED)
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(txt)
	var small := UiKit.label("escolhido" if owned else ("trocar para este" if why == "" and Sim.pick_sibling(p, n["id"]) != "" else ("disponível" if can else why)), 10,
		C_OWNED if owned else (C_CAN if why == "" else UiKit.MUTED), false)
	small.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(small)
	b.mouse_entered.connect(func(): show_tip("[b]%s[/b]  [color=#%s](%s)[/color]\n%s\n[color=#aaa]Nível %d · grátis · um por linha (trocar: na cidade)[/color]" % [n["name"], col.to_html(false), kind, n["desc"], int(n["level"])]))
	b.mouse_exited.connect(hide_tip)
	b.pressed.connect(func(): if not owned and Sim.tree_allocate(p, n["id"]): _rebuild("skills"))
	return b

## Teia (estilo Path of Exile): arrastar move, a roda dá zoom, a busca acende os nós que batem. Lembra posição e zoom
## entre as recompras (a janela é refeita a cada compra).
const WEB_UNIT := 58.0           # px por unidade da teia no zoom 1
const WEB_ZOOM := Vector2(0.45, 1.6)
var _web_pan := Vector2.ZERO     # deslocamento do centro da teia em relação ao meio da tela
var _web_zoom := 0.8
var _web_query := ""
var _web_marks: Array = []       # [[anel de busca, texto do nó]]
var _web_dragging := false
var _web_moved := 0.0           # quanto o mouse andou desde o clique: arrasto não compra nó

func _tree_view(p: SimEntity) -> Control:
	var tr: Dictionary = GameData.trees.get(p.class_def.id, {})
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.03, 0.03, 0.05, 0.95), Color(0.3, 0.26, 0.36), 6, 1))
	var view := Control.new()
	view.custom_minimum_size = TREE_PX
	view.clip_contents = true
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.add_child(view)
	var web := Control.new()
	web.mouse_filter = Control.MOUSE_FILTER_IGNORE
	web.position = TREE_PX * 0.5 + _web_pan
	web.scale = Vector2.ONE * _web_zoom
	view.add_child(web)
	view.gui_input.connect(_web_input.bind(view, web))
	_web_marks.clear()
	if tr.is_empty():
		return frame
	var nodes: Dictionary = {}
	for nid in tr["nodes"]:                  # talentos de classe ficam na aba própria
		if tr["nodes"][nid]["kind"] != "pick":
			nodes[nid] = tr["nodes"][nid]
	# anéis de guia (fundo) e ligações; o caminho comprado em dourado
	web.draw.connect(func():
		for cl in tr.get("clusters", []):          # círculos (skill, notável, dash) como os do PoE
			var cc: Vector2 = (cl["center"] as Vector2) * WEB_UNIT
			var rr: float = float(cl["r"]) * WEB_UNIT
			web.draw_circle(cc, rr + 26.0, Color(0.09, 0.075, 0.11, 0.85))
			web.draw_arc(cc, rr + 26.0, 0.0, TAU, 64, Color(0.42, 0.34, 0.22, 0.75), 2.0, true)
			web.draw_arc(cc, rr, 0.0, TAU, 64, Color(0.3, 0.26, 0.34, 0.55), 1.5, true)
		for nid in nodes:
			for l in nodes[nid]["links"]:
				if nid < l and nodes.has(l):
					var a: bool = p.tree.has(nid)
					var b: bool = p.tree.has(l)
					var col := C_OWNED if a and b else (Color(C_CAN, 0.6) if a or b else Color(C_LOCK, 0.85))
					web.draw_line((nodes[nid]["pos"] as Vector2) * WEB_UNIT, (nodes[l]["pos"] as Vector2) * WEB_UNIT, col, 4.0 if a and b else 2.0, true))
	# nome de cada braço na ponta, com os pontos gastos nele
	for pane in tr.get("panes", []):
		var spent := 0
		var reach := 0.0
		for nid in nodes:
			if nodes[nid]["branch"] == pane["id"]:
				reach = maxf(reach, (nodes[nid]["pos"] as Vector2).length())
				if p.tree.has(nid):
					spent += int(nodes[nid]["cost"])
		var ang: float = pane["angle"]
		var at := Vector2(cos(ang), sin(ang)) * (reach + 1.1) * WEB_UNIT
		var role: String = {"tank": "tanque", "dps": "dano", "ranged": "distância", "caster": "magia", "healer": "cura"}.get(pane["role"], "classe")
		var lb := UiKit.label("%s\n%s · %d pts" % [pane["name"], role, spent], 18, UiKit.GOLD if spent > 0 else UiKit.TEXT)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.add_theme_constant_override("outline_size", 4)
		lb.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		lb.size = Vector2(220, 50)
		lb.position = at - lb.size * 0.5
		lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		web.add_child(lb)
	for top in [false, true]:                 # skills e notáveis por cima dos pequenos
		for nid in nodes:
			if (nodes[nid]["kind"] in ["skill", "start", "notable"]) == top:
				web.add_child(_tree_node(p, nodes[nid], (nodes[nid]["pos"] as Vector2) * WEB_UNIT))
	# barra de cima (fundo escuro): busca, centralizar e para onde vai cada braço
	var bar_bg := PanelContainer.new()
	bar_bg.position = Vector2(6, 6)
	bar_bg.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.04, 0.035, 0.06, 0.92), Color(0.3, 0.26, 0.36), 6, 1))
	view.add_child(bar_bg)
	var bar_v := VBoxContainer.new()
	bar_v.add_theme_constant_override("separation", 3)
	bar_bg.add_child(bar_v)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	bar_v.add_child(bar)
	var arms: Array = []
	for pane in tr.get("panes", []):
		var a: float = pane["angle"]
		var arrow: String = ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"][posmod(roundi(a / (PI * 0.25)), 8)]
		var spent := 0
		for nid in nodes:
			if nodes[nid]["branch"] == pane["id"] and p.tree.has(nid):
				spent += int(nodes[nid]["cost"])
		arms.append("%s %s (%d)" % [arrow, pane["name"], spent])
	bar_v.add_child(UiKit.label("Braços:  " + "   ".join(arms) + "   · arraste para mover, roda = zoom", 11, UiKit.MUTED))
	var q := LineEdit.new()
	q.placeholder_text = "procurar (crít, FOR, nome...)"
	q.custom_minimum_size.x = 220
	q.text = _web_query
	q.text_changed.connect(_web_search)
	bar.add_child(q)
	bar.add_child(UiKit.button("Centralizar", _web_center.bind(web), 100))
	_web_search(_web_query)
	return frame

func _web_input(ev: InputEvent, view: Control, web: Control) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_web_dragging = mb.pressed
			if mb.pressed:
				_web_moved = 0.0
		elif mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var z0 := _web_zoom
			_web_zoom = clampf(_web_zoom * (1.12 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12), WEB_ZOOM.x, WEB_ZOOM.y)
			var m := mb.position                      # o ponto embaixo do mouse fica parado
			web.position = m - (m - web.position) * (_web_zoom / z0)
			web.scale = Vector2.ONE * _web_zoom
			_web_pan = web.position - view.size * 0.5
			view.accept_event()
	elif ev is InputEventMouseMotion and _web_dragging and (ev as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
		web.position += (ev as InputEventMouseMotion).relative
		_web_moved += (ev as InputEventMouseMotion).relative.length()
		_web_pan = web.position - view.size * 0.5
		hide_tip()

func _web_center(web: Control) -> void:
	_web_pan = Vector2.ZERO
	_web_zoom = 0.8
	web.position = (web.get_parent() as Control).size * 0.5
	web.scale = Vector2.ONE * _web_zoom

func _web_search(t: String) -> void:
	_web_query = t
	var q := t.strip_edges().to_lower()
	for m in _web_marks:
		(m[0] as Control).visible = q.length() >= 2 and str(m[1]).contains(q)

## Nó da teia (no espaço da teia, sem zoom). Os botões deixam o mouse passar para a tela (arrastar e zoom em cima dos nós).
func _tree_node(p: SimEntity, n: Dictionary, at: Vector2) -> Control:
	var kind: String = n["kind"]
	var px: int = NODE_PX.get(kind, 16)
	var owned := p.tree.has(n["id"])
	var why := Sim.tree_block_reason(p, n["id"])
	var can := why == ""
	var col := Color(0.55, 0.55, 0.6)
	var st: Dictionary = n.get("stats", {})
	var fam: String = TreeCatalog.STAT_FAMILY.get(st.keys()[0] if not st.is_empty() else "", "atk")
	match kind:
		"skill": col = GameData.skills[n["ref"]].icon_color
		"talent": col = Color(0.78, 0.55, 1.0)
		"stat", "notable": col = STAT_COLORS[fam]
		"mastery": col = Color(0.55, 0.95, 0.6)
		"start": col = p.class_def.color
	var fill := col.darkened(0.25) if owned else (col.darkened(0.55) if can else Color(0.12, 0.11, 0.15))
	var border := C_OWNED if owned else (C_CAN if can else C_LOCK)
	var holder := Control.new()
	holder.position = at - Vector2(px, px) * 0.5
	holder.size = Vector2(px, px)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mark := Panel.new()                  # anel ciano da busca
	mark.position = Vector2(-7, -7)
	mark.size = Vector2(px + 14, px + 14)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.3, 0.9, 1.0, 0.15), Color(0.4, 0.95, 1.0), px, 3))
	mark.visible = false
	holder.add_child(mark)
	_web_marks.append([mark, ("%s %s %s" % [n["name"], n["desc"], TreeCatalog.stat_short(st)]).to_lower()])
	if can and not owned and kind != "stat":
		var glow := Panel.new()          # brilho verde atrás de quem dá pra comprar agora
		glow.position = Vector2(-4, -4)
		glow.size = Vector2(px + 8, px + 8)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.add_theme_stylebox_override("panel", UiKit.panel_style(Color(C_CAN, 0.18), Color(C_CAN, 0.0), px if kind in ["mastery", "start", "notable"] else 8, 0))
		if kind == "talent":
			glow.rotation = PI / 4
			glow.pivot_offset = Vector2(px + 8, px + 8) * 0.5
		holder.add_child(glow)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.size = Vector2(px, px)
	b.custom_minimum_size = Vector2(px, px)
	var radius := px / 2 if kind in ["stat", "mastery", "start", "notable"] else (3 if kind == "talent" else 6)
	var bw := (4 if kind == "notable" else 3) if owned or can else 2
	var stb := UiKit.panel_style(fill, border, radius, bw)
	for state in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(state, stb if state != "hover" else UiKit.panel_style(fill.lightened(0.15), border.lightened(0.25), radius, bw + 1))
	if kind == "talent":
		b.rotation = PI / 4
		b.pivot_offset = Vector2(px, px) * 0.5
	holder.add_child(b)
	if kind in ["skill", "start"]:
		var icon: Control = UiKit.skill_icon(GameData.skills[n["ref"]], px - 6) if kind == "skill" else UiKit.class_icon(p.class_def, px - 6)
		icon.position = Vector2(3, 3)
		icon.size = Vector2(px - 6, px - 6)
		icon.modulate = Color.WHITE if owned else (Color(0.85, 0.85, 0.85) if can else Color(0.4, 0.4, 0.44))
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(icon)
	elif kind in ["stat", "notable"] and n["branch"] != "ring":
		# pequeno: o bônus curto embaixo; notável: o nome (o bônus fica na dica); junção/passagem: só na dica
		var txt: String = TreeCatalog.stat_short(st) if kind == "stat" else str(n["name"])
		var tag := UiKit.label(txt, 11 if kind == "stat" else 12, STAT_COLORS[fam] if kind == "stat" else Color(1.0, 0.9, 0.62))
		tag.add_theme_constant_override("outline_size", 3)
		tag.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		var tw := tag.get_minimum_size().x
		tag.position = Vector2(px * 0.5 - tw * 0.5, px + 1)
		tag.size = Vector2(tw, 16)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.modulate.a = 1.0 if owned or can else 0.55
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(tag)
		if kind == "notable":
			var gem := Panel.new()            # pedra no meio do notável
			gem.position = Vector2(px * 0.3, px * 0.3)
			gem.size = Vector2(px * 0.4, px * 0.4)
			gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
			gem.add_theme_stylebox_override("panel", UiKit.panel_style(col.lightened(0.2) if owned else col.darkened(0.3), Color(0, 0, 0, 0), int(px * 0.2), 0))
			holder.add_child(gem)
	elif kind == "talent" and GameData.talents.has(n["ref"]):
		var parts: Array = TreeCatalog.talent_tags(GameData.talents[n["ref"]])
		var ev := UiKit.label("\n".join(parts), 10, C_TALENT_TAG)
		var w := ev.get_minimum_size().x + 4.0
		ev.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ev.add_theme_constant_override("line_spacing", -3)
		ev.add_theme_constant_override("outline_size", 3)
		ev.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		ev.position = Vector2(px * 0.5 - w * 0.5, px + 6.0)
		ev.size = Vector2(w, 24)
		ev.modulate.a = 1.0 if owned or can else 0.55
		ev.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(ev)
	elif kind == "mastery":
		var plus := UiKit.label("+1", 10, Color(0.05, 0.1, 0.05) if owned else (C_CAN if can else Color(0.55, 0.55, 0.6)))
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		plus.size = Vector2(px, px)
		plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(plus)
		var lv_m := p.mastery_of(n["ref"])
		var ring := Control.new()
		ring.size = Vector2(px, px)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.draw.connect(_mastery_ring.bind(ring, lv_m, px))
		holder.add_child(ring)
		if lv_m > 0:
			var ml := UiKit.label("M%d" % lv_m, 10, C_OWNED)
			ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ml.position = Vector2(px * 0.5 - 16, px + 4)
			ml.size = Vector2(32, 12)
			ml.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(ml)
	# nível que falta: em cima da skill bloqueada por nível
	if not owned and p.level < int(n["level"]) and kind in ["skill", "talent"]:
		var lv := UiKit.label("Nv %d" % int(n["level"]), 11, Color(1.0, 0.6, 0.5))
		lv.add_theme_constant_override("outline_size", 3)
		lv.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		lv.position = Vector2(px * 0.5 - 20, -16)
		lv.size = Vector2(40, 14)
		lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(lv)
	b.mouse_entered.connect(func(): if not _web_dragging: show_tip(_tree_tip(p, n, owned, why)))
	b.mouse_exited.connect(hide_tip)
	b.pressed.connect(_web_buy.bind(p, n["id"]))
	return holder

func _web_buy(p: SimEntity, nid: String) -> void:
	if _web_moved < 8.0 and Sim.tree_allocate(p, nid):
		_rebuild("skills")

## Anel da maestria: um segmento por nível (até MASTERY_MAX), dourado até o nível atual.
func _mastery_ring(ring: Control, lv: int, px: int) -> void:
	var c := Vector2(px, px) * 0.5
	var r := px * 0.5 + 4.0
	var n: int = Balance.MASTERY_MAX
	var gap := 0.22
	for i in range(n):
		var a0 := -PI * 0.5 + TAU * i / n + gap * 0.5
		var a1 := -PI * 0.5 + TAU * (i + 1) / n - gap * 0.5
		ring.draw_arc(c, r, a0, a1, 8, Color(0.04, 0.03, 0.06), 5.0, true)
		ring.draw_arc(c, r, a0, a1, 8, C_OWNED if i < lv else Color(0.3, 0.28, 0.34), 3.0, true)

func _tree_tip(p: SimEntity, n: Dictionary, owned: bool, why: String) -> String:
	var kinds := {"skill": "Skill", "talent": "Evolução", "stat": "Passivo", "notable": "Notável", "mastery": "Maestria", "start": "Início"}
	var t := "[b][color=#ffd966]%s[/color][/b]  [color=#aaa](%s)[/color]\n" % [n["name"], kinds.get(n["kind"], "")]
	if n["kind"] == "skill":
		t += UiKit.skill_tooltip(p, GameData.skills[n["ref"]]) + "\n"
	elif n["kind"] == "mastery":
		t += "%s\n[color=#ffd966]Maestria atual: %d/%d[/color]\n" % [n["desc"], p.mastery_of(n["ref"]), Balance.MASTERY_MAX]
	else:
		t += "%s\n" % n["desc"]
	t += "[color=#aaa]Nível %d · custo %d ponto(s)[/color]\n" % [int(n["level"]), int(n["cost"])]
	if owned and not (n["kind"] == "mastery" and why == ""):
		t += "[color=#9f9]✔ Comprado[/color]"
	elif why == "":
		t += "[color=#9f9]Clique para comprar[/color]"
	else:
		t += "[color=#f99]%s[/color]" % why.capitalize()
	return t

## Coluna direita: barra 1-6 e skills conhecidas (clique num número = põe a skill nesse slot; só na cidade).
func _known_skills(p: SimEntity) -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 300
	col.add_theme_constant_override("separation", 6)
	col.add_child(UiKit.label("Barra (1-6)", 14, UiKit.GOLD))
	var bar := GridContainer.new()
	bar.columns = 3
	col.add_child(bar)
	for i in range(Balance.SKILL_SLOTS):
		var sk: SkillDef = p.skills[i] if i < p.skills.size() else null
		var b := UiKit.button("%d  %s" % [i + 1, sk.name if sk else "—"], func(): Sim.set_skill_slot(p, i, ""), 96)
		b.add_theme_font_size_override("font_size", 11)
		b.clip_text = true
		b.disabled = sk == null
		b.tooltip_text = "Clique para tirar da barra · solte uma skill aqui"
		b.set_drag_forwarding(Callable(), _can_drop_skill, _drop_skill.bind(i))
		drag_sources["bar_%d" % i] = b
		bar.add_child(b)
	col.add_child(UiKit.para("Arraste uma skill para a barra 1-6 (aqui ou no HUD); botão direito na barra tira. Trocar a barra: só na cidade. ✖ = a arma equipada não serve.", 11, UiKit.MUTED))
	col.add_child(UiKit.hsep(4))
	col.add_child(UiKit.label("Skills conhecidas", 14, UiKit.GOLD))
	for sid in p.class_def.skill_ids:
		if not p.knows(sid):
			continue
		var sk: SkillDef = GameData.skills[sid]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.BG_LIGHT, Color(0.3, 0.28, 0.35), 5, 1))
		card.mouse_entered.connect(func(): show_tip(UiKit.skill_tooltip(p, sk)))
		card.mouse_exited.connect(hide_tip)
		card.set_drag_forwarding(_drag_skill.bind(sk), Callable(), Callable())     # arrastar para a barra 1-6 do HUD
		drag_sources[sid] = card
		col.add_child(card)
		var v := VBoxContainer.new()
		card.add_child(v)
		var h := HBoxContainer.new()
		v.add_child(h)
		h.add_child(UiKit.skill_icon(sk, 24))
		var nm := UiKit.label("%s  · M%d" % [sk.name, p.mastery_of(sid)], 12, UiKit.TEXT)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		h.add_child(nm)
		var slots := HBoxContainer.new()
		v.add_child(slots)
		var cur := p.slot_of(sid)
		for i in range(Balance.SKILL_SLOTS):
			var sb := UiKit.button(str(i + 1), func(): Sim.set_skill_slot(p, i, sid), 26)
			sb.add_theme_font_size_override("font_size", 11)
			if i == cur:
				sb.add_theme_color_override("font_color", UiKit.GOLD)
				sb.add_theme_stylebox_override("normal", UiKit.panel_style(Color(0.35, 0.28, 0.12), UiKit.GOLD, 4, 1))
			slots.add_child(sb)
	return col

func _drag_skill(_at: Vector2, sk: SkillDef) -> Variant:
	hide_tip()
	var wrap := Control.new()
	var ic := UiKit.skill_icon(sk, 48)
	ic.position = Vector2(-24, -24)
	ic.modulate.a = 0.9
	wrap.add_child(ic)
	set_drag_preview(wrap)
	return {"rx_drag": "skill", "skill": sk.id}

func _can_drop_skill(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("rx_drag") == "skill"

func _drop_skill(_at: Vector2, data: Variant, i: int) -> void:
	Sim.set_skill_slot(Sim.player, i, str(data["skill"]))

# ---------------------------------------------------------------------------
var _quests_tab := "quests"         # "quests" (ativas/concluídas) | "roteiro" (guia de cada andar, docs/roteiro_*.md)
var _roteiro_band := ""             # "1_10" | "10_20" | "20_30" (vazio: o do nível do personagem)
const ROTEIROS := [["1_10", "1-10 Aldara"], ["10_20", "10-20 Floresta"], ["20_30", "20-30 Bastião"]]

func _set_quests_tab(t: String) -> void:
	_quests_tab = t
	_rebuild("quests")

func _set_roteiro_band(b: String) -> void:
	_roteiro_band = b
	_rebuild("quests")

## Roteiro (debug/guia): o markdown de docs/roteiro_<faixa>.md em texto rico; abre na faixa do nível do personagem.
func _roteiro(body: VBoxContainer, p: SimEntity) -> void:
	var band := _roteiro_band
	if band == "":
		band = "1_10" if p.level < 10 else ("10_20" if p.level < 20 else "20_30")
	var row := HBoxContainer.new()
	body.add_child(row)
	for b in ROTEIROS:
		var bb := UiKit.button(b[1], _set_roteiro_band.bind(b[0]), 150)
		bb.toggle_mode = true
		bb.button_pressed = band == b[0]
		row.add_child(bb)
	var path := "res://docs/roteiro_%s.md" % band
	var md := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	if md == "":
		body.add_child(UiKit.para("Roteiro não encontrado (%s)." % path, 12, UiKit.MUTED))
		return
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.custom_minimum_size.x = 560
	rt.add_theme_font_size_override("normal_font_size", 13)
	rt.add_theme_font_size_override("bold_font_size", 13)
	rt.text = roteiro_bbcode(md)
	body.add_child(rt)

## Markdown simples -> BBCode: títulos, tabelas (uma linha por item, 1ª coluna em destaque), listas, **negrito** e `código`.
static func roteiro_bbcode(md: String) -> String:
	var out := PackedStringArray()
	var gold := UiKit.GOLD.to_html(false)
	var muted := UiKit.MUTED.to_html(false)
	var header_seen := false
	for raw in md.split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("|---") or line.begins_with("| ---") or line.begins_with("|:"):
			continue
		line = _inline_md(line)
		if line.begins_with("# "):
			out.append("[font_size=18][color=#%s][b]%s[/b][/color][/font_size]" % [gold, line.substr(2)])
		elif line.begins_with("## "):
			out.append("\n[font_size=15][color=#%s][b]%s[/b][/color][/font_size]" % [gold, line.substr(3)])
			header_seen = false
		elif line.begins_with("|"):
			var cells := Array(line.trim_prefix("|").trim_suffix("|").split("|")).map(func(c): return str(c).strip_edges())
			if not header_seen:
				header_seen = true                # cabeçalho da tabela: os nomes das colunas não precisam aparecer
				continue
			var rest := " — ".join(PackedStringArray(cells.slice(1)))
			out.append("• [b]%s[/b]%s" % [cells[0], (" — " + rest) if rest != "" else ""])
		elif line.begins_with("- "):
			out.append("• " + line.substr(2))
		elif line == "":
			header_seen = false
			out.append("")
		else:
			out.append("[color=#%s]%s[/color]" % [muted, line] if line.begins_with("Tema") or line.begins_with("Os níveis") else line)
	return "\n".join(out)

static func _inline_md(s: String) -> String:
	var r := s
	while r.count("**") >= 2:
		r = _swap_once(r, "**", "[b]", "[/b]")
	while r.count("`") >= 2:
		r = _swap_once(r, "`", "[i]", "[/i]")
	return r

static func _swap_once(s: String, mark: String, a: String, b: String) -> String:
	var i := s.find(mark)
	var j := s.find(mark, i + mark.length())
	if i < 0 or j < 0:
		return s
	return s.substr(0, i) + a + s.substr(i + mark.length(), j - i - mark.length()) + b + s.substr(j + mark.length())

func _quests(body: VBoxContainer) -> void:
	var p: SimEntity = Sim.player
	var top := HBoxContainer.new()
	body.add_child(top)
	for t in [["quests", "Quests"], ["roteiro", "Roteiro"]]:
		var tb := UiKit.button(t[1], _set_quests_tab.bind(t[0]), 110)
		tb.toggle_mode = true
		tb.button_pressed = _quests_tab == t[0]
		top.add_child(tb)
	if _quests_tab == "roteiro":
		_roteiro(body, p)
		return
	body.add_child(UiKit.label("Ativas:", 13, UiKit.GOLD))
	if p.quests_active.is_empty():
		body.add_child(UiKit.label("Nenhuma quest ativa. Procure NPCs marcados com [Quest].", 12, UiKit.MUTED))
	for qid in p.quests_active:
		var q: QuestDef = GameData.quests[qid]
		var prog := QuestSystem.progress(p, q)
		var card := UiKit.panel(UiKit.BG_LIGHT, Color(0.3, 0.28, 0.35))
		body.add_child(card)
		var v := VBoxContainer.new()
		card.add_child(v)
		v.add_child(UiKit.label("%s   %d/%d%s" % [q.title, prog, q.count, "  ✔" if prog >= q.count else ""], 14, Color(0.6, 1, 0.6) if prog >= q.count else UiKit.TEXT))
		if q.repeatable:
			v.add_child(UiKit.repeat_label(q, 11))
		v.add_child(UiKit.para(q.description, 11))
		v.add_child(UiKit.para("Onde: %s · Entregar para: %s · Recompensa: %s" % [q.map_hint, _npc_name(q.turnin()), _reward_text(q)], 11, UiKit.MUTED))
		v.add_child(UiKit.button("Desistir", func(): QuestSystem.abandon(p, q), 90))
	body.add_child(UiKit.hsep())
	var once: Array = p.quests_completed.filter(func(id): return GameData.quests.has(id) and not GameData.quests[id].repeatable)
	var again: Array = p.quests_completed.filter(func(id): return GameData.quests.has(id) and GameData.quests[id].repeatable)
	body.add_child(UiKit.label("Concluídas: %d" % once.size(), 13, UiKit.MUTED))
	for qid in once:
		body.add_child(UiKit.label("✔ " + GameData.quests[qid].title, 11, UiKit.MUTED))
	if not again.is_empty():
		body.add_child(UiKit.label("Repetíveis já feitas (pegue de novo):", 13, UiKit.QUEST_REPEAT))
		for qid in again:
			var rq: QuestDef = GameData.quests[qid]
			var l := UiKit.label("↻ %s  —  %s" % [rq.title, QuestSystem.npc_name(rq.giver_npc)], 11, UiKit.QUEST_REPEAT)
			l.add_theme_font_override("font", UiKit.mark_font())
			body.add_child(l)

func _reward_text(q: QuestDef) -> String:
	var parts: Array = ["%d XP" % q.reward_xp, "%d ouro" % q.reward_gold]
	for item_id in q.reward_items:
		parts.append("%dx %s" % [int(q.reward_items[item_id]), GameData.items[item_id].name])
	if q.reward_gear_tier >= 0:
		parts.append("1 peça de equipamento")
	return ", ".join(parts)

func _npc_name(npc_id: String) -> String:
	for mid in GameData.maps:
		for n in GameData.maps[mid].npcs:
			if n["id"] == npc_id:
				return n["name"]
	return npc_id

# ---------------------------------------------------------------------------

## Grupo: membros (líder pode promover/expulsar), sair, e quem está por perto para convidar.
func _party(body: VBoxContainer) -> void:
	var p: SimEntity = Sim.player
	var members: Array = Sim.party_members(p)
	var leader: SimEntity = Sim.party_leader(p)
	var i_lead := leader == null or leader == p
	body.add_child(UiKit.label("Membros  %d/%d" % [members.size(), Balance.PARTY_MAX], 14, UiKit.GOLD))
	if p.party_id < 0:
		body.add_child(UiKit.para("Você está sozinho. Convide alguém abaixo ou digite /convidar nome no chat.", 12, UiKit.MUTED))
	else:
		for m in members:
			body.add_child(_party_row(p, m, m == leader, i_lead))
		body.add_child(UiKit.button("Sair do grupo", func(): Sim.party_leave(p), 150))
	body.add_child(UiKit.para("XP de abates dividida com quem estiver a até %dm (+%d%% por membro, nível até %d de diferença). Curas e buffs em área só valem para o grupo." % [int(Balance.PARTY_SHARE_RANGE), int(Balance.PARTY_XP_BONUS * 100), Balance.PARTY_LEVEL_GAP], 11, UiKit.MUTED))
	body.add_child(UiKit.hsep())
	var h := HBoxContainer.new()
	body.add_child(h)
	var t := UiKit.label("Por perto", 14, UiKit.GOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	h.add_child(UiKit.button("Atualizar", func(): _rebuild("party")))
	# só quem dá para convidar agora (sem grupo, sem convite pendente, nível compatível)
	var blocked: String = Sim.party_invite_blocked(p)
	var near: Array = Sim.party_invitable_near(p)
	if blocked != "":
		body.add_child(UiKit.label(blocked, 12, UiKit.MUTED))
	elif near.is_empty():
		body.add_child(UiKit.label("Ninguém por perto para formar grupo (até %dm, nível até %d de diferença)." % [int(Balance.PARTY_NEARBY_RANGE), Balance.PARTY_LEVEL_GAP], 12, UiKit.MUTED))
	for e in near.slice(0, 10):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		body.add_child(row)
		row.add_child(UiKit.class_icon(e.class_def, 22))
		var l := UiKit.label("%s  ·  %s %d" % [e.name, e.class_def.name, e.level], 12, UiKit.TEXT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(UiKit.button("Convidar", _invite.bind(e.id), 96))

func _party_row(p: SimEntity, m: SimEntity, is_leader: bool, i_lead: bool) -> Control:
	var card := UiKit.panel(UiKit.BG_LIGHT, m.class_def.color.darkened(0.3))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	var where := "" if m.map_id == p.map_id else "  · " + Sim.map_def(m.map_id).name
	v.add_child(UiKit.label("%s%s%s" % ["♛ " if is_leader else "", m.name, "  (você)" if m == p else ""], 13, Color(0.6, 1.0, 0.65) if m != p else UiKit.GOLD))
	v.add_child(UiKit.label("%s Lv.%d  ·  HP %d%%%s%s" % [m.class_def.name, m.level, int(100.0 * m.hp / maxf(1.0, m.stats.max_hp)), where, "  ✝" if not m.is_alive() else ""], 11, UiKit.MUTED))
	if i_lead and m != p:
		row.add_child(UiKit.button("Líder", func(): Sim.party_promote(p, m)))
		row.add_child(UiKit.button("Expulsar", func(): Sim.party_kick(p, m)))
	return card

func _invite(target_id: int) -> void:
	var t: SimEntity = Sim.get_entity(target_id)
	if t:
		Sim.party_invite(Sim.player, t)
	_rebuild("party")

