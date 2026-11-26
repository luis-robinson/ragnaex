class_name CardUi
extends RefCounted
## Cartas de Monstro na interface (GDD design/gdd/cartas.md): aba "Cartas" da janela C (6 encaixes, combos) e a janela
## Bestiário. Só lê a sim e chama Sim.card_socket/card_unsocket. `w` = a janela (windows.gd) para dicas e reconstruir.

const SOCKET_PX := 54
const CORE_GOLD := Color(1.0, 0.8, 0.3)

## Aba Cartas: 6 encaixes (arrastar da bolsa; clique tira), núcleos, combos e o botão do Bestiário.
static func sockets_tab(w: Control, p: SimEntity, side: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	side.add_child(grid)
	w.card_sockets.clear()
	for slot in Balance.CARD_SLOTS:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 1)
		var lb := UiKit.label(CardsCatalog.SLOT_NAMES[slot], 10, UiKit.MUTED, false)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(lb)
		col.add_child(socket(w, p, slot))
		grid.add_child(col)
	var cores := 0
	for s in p.cards:
		var cd: CardDef = GameData.cards.get(p.cards[s])
		if cd and cd.core:
			cores += 1
	side.add_child(UiKit.label("Núcleos: %d/%d" % [cores, Balance.CARD_CORE_MAX], 12, CORE_GOLD if cores > 0 else UiKit.MUTED))
	var gc := CardSystem.group_counts(p)
	for g in gc:
		var bon: Array = Balance.CARD_GROUP_BONUS.get(g, [])
		var n: int = int(gc[g])
		var txt := "%s %d/3" % [CardsCatalog.GROUP_NAMES.get(g, g), n]
		var col := UiKit.MUTED
		if n >= 2 and bon.size() >= 1:
			txt += " — " + CardsCatalog.describe_bonus(bon[0])
			col = Color(0.55, 1.0, 0.6)
		if n >= 3 and bon.size() >= 2:
			txt += "; " + CardsCatalog.describe_bonus(bon[1])
		side.add_child(UiKit.para(txt, 11, col))
	side.add_child(UiKit.para("Arraste uma carta da bolsa para o encaixe dela. Clique no encaixe: a carta volta para a bolsa (grátis).", 11, UiKit.MUTED))
	side.add_child(UiKit.button("Bestiário", func(): w.toggle("bestiary"), 120))

## Um encaixe: vazio (nome) ou a carta encaixada.
static func socket(w: Control, p: SimEntity, slot: String) -> Control:
	var cid := str(p.cards.get(slot, ""))
	var cd: CardDef = GameData.cards.get(cid)
	var box := PanelContainer.new()
	var border := (CORE_GOLD if cd.core else Color(0.7, 0.62, 0.95)) if cd else Color(0.3, 0.28, 0.35)
	var sb := UiKit.panel_style(Color(0.06, 0.05, 0.08, 0.95), border, 5, 2 if cd and cd.core else 1)
	sb.set_content_margin_all(3)
	box.add_theme_stylebox_override("panel", sb)
	box.custom_minimum_size = Vector2(SOCKET_PX, SOCKET_PX)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	if cd:
		var it: ItemDef = GameData.items[cid]
		box.add_child(UiKit.item_icon(it, SOCKET_PX - 6))
		box.mouse_entered.connect(func(): w.show_tip(UiKit.item_tooltip(it) + "\n[color=#9f9]Clique ou arraste para a bolsa: tirar (grátis)[/color]"))
		box.gui_input.connect(func(ev: InputEvent): _on_socket_input(ev, slot))
	else:
		var tag := UiKit.label("+", 18, Color(0.45, 0.42, 0.5), false)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(tag)
		box.mouse_entered.connect(func(): w.show_tip("[b]Encaixe: %s[/b]\n[color=#aaa]Vazio — arraste uma carta de %s da bolsa[/color]" % [CardsCatalog.SLOT_NAMES[slot], CardsCatalog.SLOT_NAMES[slot].to_lower()]))
	box.mouse_exited.connect(w.hide_tip)
	box.set_drag_forwarding(func(_at: Vector2) -> Variant: return _drag_from_socket(w, p, slot),
		func(_at: Vector2, data: Variant) -> bool: return can_drop(p, slot, data),
		func(_at: Vector2, data: Variant) -> void: drop(slot, data))
	w.card_sockets[slot] = box
	return box

static func _on_socket_input(ev: InputEvent, slot: String) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
		_notify(Sim.card_unsocket(Sim.player, slot))

static func _drag_from_socket(w: Control, p: SimEntity, slot: String) -> Variant:
	var cid := str(p.cards.get(slot, ""))
	if cid == "":
		return null
	w.hide_tip()
	w.set_drag_preview(w._drag_preview(GameData.items[cid]))
	return {"rx_drag": "card_slot", "slot": slot}

static func can_drop(p: SimEntity, slot: String, data: Variant) -> bool:
	return data is Dictionary and data.get("rx_drag") == "card" and Sim.card_socket_error(p, slot, str(data["item"])) == ""

static func drop(slot: String, data: Variant) -> void:
	_notify(Sim.card_socket(Sim.player, slot, str(data["item"])))

## Clique numa carta da bolsa: encaixa no encaixe dela.
static func click_card(it: ItemDef) -> void:
	var cd: CardDef = GameData.cards.get(it.id)
	if cd:
		_notify(Sim.card_socket(Sim.player, cd.slot, it.id))

static func _notify(err: String) -> void:
	if err != "":
		Events.notification.emit(err)
	else:
		Sfx.ui("ui_open")

# --- Bestiário --------------------------------------------------------------

## Linhas do bestiário por zona (pura; também usada nos checks): [{map, name, cards: [card_id], found, seen, title}]
static func zones(p: SimEntity) -> Array:
	var out: Array = []
	var seen_cards := {}
	var ids := GameData.maps.keys()
	ids.sort_custom(func(a, b): return GameData.maps[a].level_range.x < GameData.maps[b].level_range.x or (GameData.maps[a].level_range.x == GameData.maps[b].level_range.x and str(a) < str(b)))
	for mid in ids:
		var cs: Array = []
		for cid in CardSystem.cards_of_map(mid):
			if not seen_cards.has(cid):          # cada carta na 1ª zona (por nível) onde o monstro vive
				seen_cards[cid] = true
				cs.append(cid)
		if cs.is_empty():
			continue
		var found := 0
		for cid in cs:
			if int(p.bestiary.get(GameData.cards[cid].monster_id, 0)) & CardSystem.FOUND:
				found += 1
		var titled := false
		for t in CardSystem.titles(p):
			if t["map"] == mid:
				titled = true
		out.append({"map": mid, "name": GameData.maps[mid].name, "cards": cs, "found": found, "title": titled})
	var rest: Array = []                         # cartas sem mapa de nascimento (investidas)
	for cid in GameData.cards:
		if not seen_cards.has(cid):
			rest.append(cid)
	if not rest.is_empty():
		var f := 0
		for cid in rest:
			if int(p.bestiary.get(GameData.cards[cid].monster_id, 0)) & CardSystem.FOUND:
				f += 1
		out.append({"map": "", "name": "Investidas", "cards": rest, "found": f, "title": false})
	return out

static func bestiary(w: Control, body: VBoxContainer) -> void:
	var p: SimEntity = Sim.player
	var total := GameData.cards.size()
	var found := 0
	for cid in GameData.cards:
		if int(p.bestiary.get(GameData.cards[cid].monster_id, 0)) & CardSystem.FOUND:
			found += 1
	body.add_child(UiKit.label("Cartas achadas: %d/%d" % [found, total], 15, UiKit.GOLD))
	var tl := CardSystem.titles(p)
	if not tl.is_empty():
		body.add_child(UiKit.para("Títulos: " + ", ".join(tl.map(func(t): return t["title"])), 12, CORE_GOLD))
	for z in zones(p):
		var head := UiKit.label("%s  —  %d/%d%s" % [z["name"], z["found"], z["cards"].size(), "  ✦ Caçador" if z["title"] else ""], 13,
			CORE_GOLD if z["title"] else Color(0.85, 0.82, 0.95))
		body.add_child(head)
		var grid := GridContainer.new()
		grid.columns = 9
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 4)
		body.add_child(grid)
		for cid in z["cards"]:
			grid.add_child(_entry(w, p, GameData.cards[cid]))
	body.add_child(UiKit.para("Visto = abatido por você ou pelo seu grupo. Zona completa dá um título (sem poder).", 11, UiKit.MUTED))

static func _entry(w: Control, p: SimEntity, cd: CardDef) -> Control:
	var bits := int(p.bestiary.get(cd.monster_id, 0))
	var box := PanelContainer.new()
	var border := (CORE_GOLD if cd.core else Color(0.7, 0.62, 0.95)) if bits & CardSystem.FOUND else Color(0.3, 0.28, 0.35)
	var sb := UiKit.panel_style(Color(0.06, 0.05, 0.08, 0.95), border, 4, 2 if cd.core and bits & CardSystem.FOUND else 1)
	sb.set_content_margin_all(2)
	box.add_theme_stylebox_override("panel", sb)
	box.custom_minimum_size = Vector2(46, 46)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	var it: ItemDef = GameData.items[cd.id]
	if bits & CardSystem.FOUND:
		box.add_child(UiKit.item_icon(it, 40))
	elif bits & CardSystem.SEEN:
		var ic := UiKit.item_icon(it, 40)
		ic.modulate = Color(0.25, 0.25, 0.3, 1.0)          # visto, carta ainda não achada: sombra
		box.add_child(ic)
	else:
		var q := UiKit.label("?", 18, Color(0.4, 0.38, 0.45), false)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(q)
	box.mouse_entered.connect(func(): w.show_tip(_entry_tip(p, cd, bits)))
	box.mouse_exited.connect(w.hide_tip)
	return box

static func _entry_tip(_p: SimEntity, cd: CardDef, bits: int) -> String:
	var md: MonsterDef = GameData.monsters.get(cd.monster_id)
	var where: Array = CardSystem.maps_of(cd.monster_id).map(func(m): return "%s (%d-%d)" % [GameData.maps[m].name, GameData.maps[m].level_range.x, GameData.maps[m].level_range.y])
	if bits == 0:
		return "[b]???[/b]\n[color=#aaa]Nunca visto. Vive em: %s[/color]" % (", ".join(where) if not where.is_empty() else "investidas")
	var t := "[b][color=#%s]%s[/color][/b]\n%s Lv %d — %s" % [(CORE_GOLD if cd.core else Color(0.78, 0.7, 1.0)).to_html(false), cd.name,
		md.name if md else cd.monster_id, md.level if md else 0, "achada" if bits & CardSystem.FOUND else "falta"]
	t += "\n%s: %s" % [CardsCatalog.SLOT_NAMES[cd.slot], CardsCatalog.describe(cd.effect, cd.value, cd.family)]
	if cd.core:
		t += "\n[color=#ffcc55]Núcleo[/color]"
	if cd.group != "":
		var bon: Array = Balance.CARD_GROUP_BONUS.get(cd.group, [])
		t += "\nGrupo %s: 2 = %s; 3 = %s" % [CardsCatalog.GROUP_NAMES.get(cd.group, cd.group), CardsCatalog.describe_bonus(bon[0]) if bon.size() > 0 else "-",
			CardsCatalog.describe_bonus(bon[1]) if bon.size() > 1 else "-"]
	t += "\n[color=#aaa]Vive em: %s[/color]" % (", ".join(where) if not where.is_empty() else "investidas")
	return t
