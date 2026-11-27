class_name AuctionUi
extends RefCounted
## Janela do Leiloeiro (design/gdd/casa-de-leiloes.md §3/§5/§6): abas Comprar (busca e filtros), Vender (da bolsa, preço
## sugerido, faixa, taxa, setinha), Meus anúncios (cancelar) e Caixa (pegar). Montada dentro do npc_ui (modo "auction").
## Só lê e age pelos `Sim.auction_*` (contrato production/session-state/auction-contract.md); testes trocam a fonte por `src`.
## Aviso de venda/vencido: a sim já manda `Events.notification` (toast do HUD).

static var src: Object = null          # fonte da sim (null = Sim); o teste põe um espião
static var tab := "buy"                # buy | sell | mine | mail
static var msg := ""                   # resposta da última ação
static var msg_ok := false
# filtros de Comprar
static var f_text := ""
static var f_draft := ""                # texto digitado na busca e ainda não aplicado (sobrevive à reconstrução)
static var f_type := ""
static var f_slot := ""
static var f_band := -1                # índice de Balance.XP_BANDS pelo nível do ITEM (contrato: level_min/max); -1 = qualquer nível
static var f_price_max := 0            # 0 = sem teto
static var page := 0
# Vender
static var sel_item := ""
static var sel_count := 1
static var sel_price := 0
static var sel_hours := 8

const TABS := [["buy", "Comprar"], ["sell", "Vender"], ["mine", "Meus anúncios"], ["mail", "Caixa"]]
const TYPES := [["", "Tudo"], ["material", "Materiais"], ["equipment", "Equipamento"], ["card", "Cartas"], ["consumable", "Consumíveis"]]
const SLOT_NAMES := {"weapon": "Arma", "offhand": "Mão secundária", "head": "Cabeça", "chest": "Peito", "boots": "Botas", "accessory": "Acessório"}
const PAGE := 30
const ROW_ICON := 34
const CELL := 48
const COLS := 8
const WIN_W := 940
const OK_COLOR := Color(0.6, 1.0, 0.6)
const ERR_COLOR := Color(1.0, 0.6, 0.5)
const UP_COLOR := Color(0.55, 0.95, 0.55)
const DOWN_COLOR := Color(1.0, 0.55, 0.45)

# --- fonte -----------------------------------------------------------------
static func _api() -> Object:
	return src if src != null else Sim

static func api(m: String, args: Array = [], fallback: Variant = null) -> Variant:
	var o := _api()
	if o == null or not o.has_method(m):
		return fallback
	return o.callv(m, args)

static func _player() -> SimEntity:
	var o := _api()
	var p: Variant = o.get("player") if o != null else null
	return p as SimEntity if p is SimEntity else null

static func _status() -> Dictionary:
	var v: Variant = api("auction_status", [_player()], {})
	return v if v is Dictionary else {}

# --- textos (puros) ----------------------------------------------------------
## Tempo que falta: "1 h 05 min", "12 min", "< 1 min", "Vencido".
static func time_left(s: float) -> String:
	if s <= 0.0:
		return "Vencido"
	if s < 60.0:
		return "< 1 min"
	var m := int(ceil(s / 60.0))
	return "%d min" % m if m < 60 else "%d h %02d min" % [m / 60, m % 60]

## Setinha de tendência: ▲ alta, ▼ baixa, – parada.
static func trend_mark(t: int) -> String:
	return "▲" if t > 0 else ("▼" if t < 0 else "–")

static func trend_color(t: int) -> Color:
	return UP_COLOR if t > 0 else (DOWN_COLOR if t < 0 else UiKit.MUTED)

static func trend_word(t: int) -> String:
	return "em alta" if t > 0 else ("em baixa" if t < 0 else "estável")

## Quem vende: "Seu" no anúncio do jogador, senão o nome do bot.
static func seller_text(row: Dictionary) -> String:
	return "Seu" if bool(row.get("mine", false)) else str(row.get("seller", "?"))

## "12 cada" / "12" (lote de 1).
static func unit_text(row: Dictionary) -> String:
	return ("%d cada" % int(row.get("unit", 0))) if int(row.get("count", 1)) > 1 else str(int(row.get("unit", 0)))

## Faixa de nível: "Lv 10-20" (índice de Balance.XP_BANDS); -1 = "Qualquer nível".
static func band_label(b: int) -> String:
	if b < 0 or b >= Balance.XP_BANDS.size():
		return "Qualquer nível"
	return "Lv %d-%d" % [int(Balance.XP_BANDS[b][0]), int(Balance.XP_BANDS[b][1])]

## Faixa (índice de XP_BANDS) do nível.
static func band_of(level: int) -> int:
	for i in Balance.XP_BANDS.size():
		if level < int(Balance.XP_BANDS[i][1]):
			return i
	return Balance.XP_BANDS.size() - 1

## Filtros da busca no formato do contrato (só as chaves que valem).
static func filters(text: String, type: String, slot: String, band: int, price_max: int) -> Dictionary:
	var f := {}
	if text.strip_edges() != "":
		f["text"] = text.strip_edges()
	if type != "":
		f["type"] = type
	if type == "card" and slot != "":
		f["card_slot"] = slot
	if band >= 0 and band < Balance.XP_BANDS.size():
		f["level_min"] = int(Balance.XP_BANDS[band][0])
		f["level_max"] = int(Balance.XP_BANDS[band][1]) - (0 if band == Balance.XP_BANDS.size() - 1 else 1)
	if price_max > 0:
		f["price_max"] = price_max
	return f

## O que entra na caixa se vender (comissão tirada, mesma conta da sim).
static func net_of(total: int) -> int:
	return total - int(round(total * Balance.AUCTION_CUT))

## Texto da entrada da caixa: "Vendeu ...  —  120 ouro" / "Comprou X  ·  x3".
static func mail_text(m: Dictionary) -> String:
	if str(m.get("kind", "")) == "gold":
		return "%s  —  %d ouro" % [m.get("text", ""), int(m.get("gold", 0))]
	return str(m.get("text", "")) + (("  ·  x%d" % int(m["count"])) if int(m.get("count", 1)) > 1 else "")      # o texto da sim já tem o nome

## Rótulo da aba (com contagem em Meus anúncios e Caixa).
static func tab_label(t: String, st: Dictionary) -> String:
	match t:
		"mine": return "Meus anúncios (%d/%d)" % [(st.get("listings", []) as Array).size(), int(st.get("max_listings", Balance.AUCTION_PLAYER_LISTINGS))]
		"mail":
			var n := (st.get("mail", []) as Array).size()
			return "Caixa (%d)" % n if n > 0 else "Caixa"
	for x in TABS:
		if x[0] == t:
			return str(x[1])
	return t

## Itens da bolsa que aparecem na aba Vender: [item_id, quantidade, motivo ("" = pode)], os que podem primeiro.
static func bag_rows(p: SimEntity) -> Array:
	var out: Array = []
	if p == null:
		return out
	for iid in p.inventory:
		var it: ItemDef = GameData.items.get(iid)
		if it == null or it.type == ItemDef.Type.QUEST:
			continue
		out.append([str(iid), int(p.inventory[iid]), str(api("auction_sellable", [str(iid)], ""))])
	out.sort_custom(func(a: Array, b: Array) -> bool:
		var ia: ItemDef = GameData.items[a[0]]
		var ib: ItemDef = GameData.items[b[0]]
		return [a[2] != "", ia.type, ia.name] < [b[2] != "", ib.type, ib.name])
	return out

# --- pulso com campo em foco ---------------------------------------------------
static var pending := false            # pulso do mercado que esperou o campo perder o foco (npc_ui._process reconstrói)

## Campo de texto (LineEdit, também o de dentro de um SpinBox) da janela que está com o foco; null = nenhum.
static func typing_in(root: Control) -> LineEdit:
	if root == null or not is_instance_valid(root) or not root.is_inside_tree():
		return null
	var f := root.get_viewport().gui_get_focus_owner()
	return f as LineEdit if f is LineEdit and root.is_ancestor_of(f) else null

## Pulso do mercado (Events.auction_changed) com o jogador digitando preço/busca: reconstruir tiraria o foco e o texto.
## Nesse caso só os rótulos mudam (ouro, abas, taxa/total/erro da Vender) e a reconstrução fica para quando o foco sair.
## Devolve true se adiou.
static func defer_refresh(root: Control) -> bool:
	if typing_in(root) == null:
		return false
	pending = true
	var st := _status()
	var gl := root.find_child("GoldLabel", true, false) as Label
	if gl:
		gl.text = "Ouro: %d" % int(st.get("gold", 0))
	for t in TABS:
		var b := root.find_child("tab_" + str(t[0]), true, false) as Button
		if b:
			b.text = tab_label(str(t[0]), st)
	_sell_update()
	return true

# --- janela ------------------------------------------------------------------
static func _refresh(ui: Object) -> void:
	if ui != null and ui.has_method("_rebuild"):
		ui.call("_rebuild")

static func _tip(ui: Object, c: Control, tip: String) -> void:
	if ui != null and ui.has_method("_tip"):
		ui.call("_tip", c, tip)
	else:
		c.tooltip_text = tip

static func _act(ui: Object, m: String, args: Array) -> void:
	var r: Variant = api(m, args, "Indisponível agora.")
	msg = str(r)
	msg_ok = msg == ""
	if msg_ok:
		match m:
			"auction_buy": msg = "Comprado: o item está na Caixa."
			"auction_list": msg = "Anunciado."; sel_item = ""
			"auction_cancel": msg = "Cancelado: o item voltou para a Caixa."
			"auction_collect": msg = "Retirado da Caixa."
	if ui != null and ui.get("hud") != null:
		ui.call("_hide_tip")
	_refresh(ui)

static func set_tab(ui: Object, t: String) -> void:
	tab = t
	msg = ""
	_refresh(ui)

## Monta a janela inteira em `body` (ui = npc_ui ou null no teste).
static func build(ui: Object, body: VBoxContainer) -> void:
	pending = false
	var p := _player()
	var st := _status()
	var w: Variant = ui.get("win") if ui != null else null
	if w is Control:
		(w as Control).custom_minimum_size = Vector2(WIN_W + 30, 560)
	var sc: Variant = ui.get("_scroll") if ui != null else null
	if sc is Control:
		(sc as Control).custom_minimum_size = Vector2(WIN_W, 520)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	body.add_child(top)
	var gl := UiKit.label("Ouro: %d" % int(st.get("gold", p.gold if p else 0)), 16, UiKit.GOLD)
	gl.name = "GoldLabel"
	gl.custom_minimum_size.x = 130
	top.add_child(gl)
	for t in TABS:
		var b := UiKit.button(tab_label(str(t[0]), st), set_tab.bind(ui, str(t[0])), 0)
		b.name = "tab_" + str(t[0])
		b.toggle_mode = true
		b.button_pressed = tab == t[0]
		top.add_child(b)
	var near := bool(st.get("near", false))
	if not near:
		body.add_child(UiKit.para("Você está longe do Leiloeiro: dá para olhar, mas comprar, anunciar e pegar só no balcão.", 12, ERR_COLOR))
	if msg != "":
		var ml := UiKit.para(msg, 12, OK_COLOR if msg_ok else ERR_COLOR)
		ml.name = "MsgLabel"
		body.add_child(ml)
	body.add_child(UiKit.hsep(2))
	match tab:
		"sell": _sell(ui, body, st, near)
		"mine": _mine(ui, body, st, near)
		"mail": _mail(ui, body, st, near)
		_: _buy(ui, body, st, near)

# --- Comprar -------------------------------------------------------------------
static func _buy(ui: Object, body: VBoxContainer, st: Dictionary, near: bool) -> void:
	var p := _player()
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	body.add_child(row1)
	var le := LineEdit.new()
	le.name = "SearchText"
	le.placeholder_text = "Buscar pelo nome…"
	le.text = f_draft if f_draft != "" else f_text
	le.custom_minimum_size.x = 220
	le.text_submitted.connect(func(t: String): _search(ui, t))
	le.text_changed.connect(func(t: String): f_draft = t)
	row1.add_child(le)
	row1.add_child(UiKit.button("Buscar", func(): _search(ui, le.text), 80))
	var bo := OptionButton.new()
	bo.name = "BandPick"
	bo.add_item(band_label(-1), 0)
	bo.tooltip_text = "Nível exigido do item"
	for i in Balance.XP_BANDS.size():
		bo.add_item(band_label(i), i + 1)
	bo.select(f_band + 1)
	bo.item_selected.connect(func(i: int): f_band = i - 1; page = 0; _refresh(ui))
	row1.add_child(bo)
	row1.add_child(UiKit.label("Preço máx.", 12, UiKit.MUTED))
	var pm := SpinBox.new()
	pm.name = "PriceMax"
	pm.min_value = 0
	pm.max_value = 9999999
	pm.value = f_price_max
	pm.tooltip_text = "Por unidade; 0 = sem teto"
	pm.value_changed.connect(func(x: float): f_price_max = int(x); page = 0; _refresh(ui))
	row1.add_child(pm)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 3)
	body.add_child(row2)
	for t in TYPES:
		var tb := UiKit.button(str(t[1]), func(): f_type = str(t[0]); f_slot = ""; page = 0; _refresh(ui), 0)
		tb.name = "type_" + (str(t[0]) if str(t[0]) != "" else "all")
		tb.toggle_mode = true
		tb.button_pressed = f_type == t[0]
		row2.add_child(tb)
	if f_type == "card":
		var so := OptionButton.new()
		so.name = "SlotPick"
		so.add_item("Todo encaixe", 0)
		for i in Balance.CARD_SLOTS.size():
			so.add_item(str(SLOT_NAMES.get(Balance.CARD_SLOTS[i], Balance.CARD_SLOTS[i])), i + 1)
		so.select(Balance.CARD_SLOTS.find(f_slot) + 1)
		so.item_selected.connect(func(i: int): f_slot = "" if i == 0 else str(Balance.CARD_SLOTS[i - 1]); page = 0; _refresh(ui))
		row2.add_child(so)
	var rows: Array = api("auction_search", [filters(f_text, f_type, f_slot, f_band, f_price_max)], [])
	var pages := maxi(1, ceili(rows.size() / float(PAGE)))
	page = clampi(page, 0, pages - 1)
	if rows.is_empty():
		var e := UiKit.para("Nada à venda com esses filtros. Os bots anunciam coisa nova a cada poucos minutos.", 12, UiKit.MUTED)
		e.name = "EmptyLabel"
		body.add_child(e)
		return
	var g := GridContainer.new()
	g.name = "BuyList"
	g.columns = 8
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 3)
	body.add_child(g)
	for h in ["", "Item", "Nível", "Vendedor", "Prazo", "Preço", "Total", ""]:
		g.add_child(UiKit.label(h, 11, UiKit.MUTED))
	var gold := int(st.get("gold", p.gold if p else 0))
	for i in range(page * PAGE, mini(rows.size(), (page + 1) * PAGE)):
		var r: Dictionary = rows[i]
		_row_cells(ui, g, r)
		if bool(r.get("mine", false)):
			var cb := UiKit.button("Cancelar", func(): _act(ui, "auction_cancel", [_player(), int(r["id"])]), 96)
			cb.name = "cancel_%d" % int(r["id"])
			cb.disabled = not near
			g.add_child(cb)
		else:
			var bb := UiKit.button("Comprar", func(): _act(ui, "auction_buy", [_player(), int(r["id"])]), 96)
			bb.name = "buy_%d" % int(r["id"])
			bb.disabled = not near or gold < int(r.get("total", 0))
			if gold < int(r.get("total", 0)):
				bb.tooltip_text = "Ouro insuficiente"
			g.add_child(bb)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	body.add_child(foot)
	var pv := UiKit.button("◀", func(): page -= 1; _refresh(ui), 40)
	pv.disabled = page <= 0
	foot.add_child(pv)
	foot.add_child(UiKit.label("Página %d de %d  ·  %d anúncios (mais barato primeiro)" % [page + 1, pages, rows.size()], 12, UiKit.MUTED))
	var nx := UiKit.button("▶", func(): page += 1; _refresh(ui), 40)
	nx.disabled = page >= pages - 1
	foot.add_child(nx)

static func _search(ui: Object, t: String) -> void:
	f_text = t
	f_draft = ""
	page = 0
	_refresh(ui)

## Colunas comuns de uma linha de anúncio (Comprar e Meus anúncios): ícone, nome+setinha, nível, vendedor, prazo, unidade, total.
static func _row_cells(ui: Object, g: GridContainer, r: Dictionary) -> void:
	var it: ItemDef = GameData.items.get(str(r.get("item", "")))
	var cell: Control = UiKit.icon_cell(it, ROW_ICON) if it else UiKit.empty_slot(ROW_ICON)
	if int(r.get("count", 1)) > 1:
		UiKit.corner_label(cell, str(int(r["count"])), ROW_ICON, true)
	if it:
		_tip(ui, cell, UiKit.item_tooltip(it) + "\n[color=#ffd966]Referência: %d por unidade · %s[/color]" % [int(r.get("ref", 0)), trend_word(int(r.get("trend", 0)))])
	g.add_child(cell)
	var nm := HBoxContainer.new()
	nm.add_theme_constant_override("separation", 4)
	nm.custom_minimum_size.x = 330
	var nl := UiKit.label(str(r.get("name", "?")) + ((" x%d" % int(r["count"])) if int(r.get("count", 1)) > 1 else ""), 13,
		UiKit.rarity_color(it.rarity) if it else UiKit.TEXT)
	nl.clip_text = true
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.add_child(nl)
	var tl := UiKit.label(trend_mark(int(r.get("trend", 0))), 13, trend_color(int(r.get("trend", 0))))
	tl.add_theme_font_override("font", UiKit.mark_font())
	tl.tooltip_text = "Preço %s" % trend_word(int(r.get("trend", 0)))
	tl.mouse_filter = Control.MOUSE_FILTER_STOP
	nm.add_child(tl)
	g.add_child(nm)
	g.add_child(UiKit.label(str(it.level_req) if it else "-", 12, UiKit.TEXT))
	var mine := bool(r.get("mine", false))
	var sl := UiKit.label(seller_text(r), 12, UiKit.GOLD if mine else UiKit.TEXT)
	sl.custom_minimum_size.x = 110
	sl.clip_text = true
	g.add_child(sl)
	g.add_child(UiKit.label(time_left(float(r.get("left", 0.0))), 12, UiKit.MUTED))
	g.add_child(UiKit.label(unit_text(r), 12, UiKit.GOLD))
	g.add_child(UiKit.label(str(int(r.get("total", 0))), 13, UiKit.GOLD))

# --- Vender --------------------------------------------------------------------
static var _sell_refs := {}            # rótulos/botão que mudam sem reconstruir (quantidade e preço)

static func select(item_id: String) -> void:
	sel_item = item_id
	sel_price = int(api("auction_suggest", [item_id], 0))
	sel_count = 1
	var p := _player()
	if p:
		var it: ItemDef = GameData.items.get(item_id)
		sel_count = mini(int(p.inventory.get(item_id, 0)), it.stack_max if it else 1)   # o lote inteiro por padrão
	sel_count = maxi(1, sel_count)

static func _sell(ui: Object, body: VBoxContainer, st: Dictionary, near: bool) -> void:
	var p := _player()
	var rows := bag_rows(p)
	if sel_item != "" and (p == null or int(p.inventory.get(sel_item, 0)) <= 0 or str(api("auction_sellable", [sel_item], "x")) != ""):
		sel_item = ""
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	body.add_child(cols)
	var left := VBoxContainer.new()
	cols.add_child(left)
	left.add_child(UiKit.label("Sua bolsa  (clique para escolher)", 13, UiKit.GOLD))
	var g := UiKit.grid(COLS, 4)
	g.name = "SellBag"
	left.add_child(g)
	for r in rows:
		var it: ItemDef = GameData.items[r[0]]
		var ok: bool = r[2] == ""
		var cell := UiKit.icon_cell(it, CELL, Color.WHITE if ok else Color(0.45, 0.45, 0.5, 0.7))
		cell.name = "bag_" + str(r[0])
		if int(r[1]) > 1:
			UiKit.corner_label(cell, str(int(r[1])), CELL, true)
		if str(r[0]) == sel_item:
			var hl := Panel.new()
			hl.set_anchors_preset(Control.PRESET_FULL_RECT)
			hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hl.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0, 0, 0, 0), UiKit.GOLD, 4, 2))
			cell.add_child(hl)
		_tip(ui, cell, UiKit.item_tooltip(it) + ("\n[color=#9f9]clique: anunciar[/color]" if ok else "\n[color=#f88]%s[/color]" % r[2]))
		if ok:
			cell.gui_input.connect(_bag_click.bind(ui, str(r[0])))
		g.add_child(cell)
	for i in maxi(0, COLS * 4 - rows.size()):
		g.add_child(UiKit.empty_slot(CELL))
	left.add_child(UiKit.para("Só itens da bolsa: equipado ou encaixado, tire do boneco/encaixe primeiro. Lendários e itens de missão não vão a leilão.", 11, UiKit.MUTED))
	var right := VBoxContainer.new()
	right.name = "SellDetail"
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 5)
	cols.add_child(right)
	if sel_item == "":
		var e := UiKit.para("Escolha um item da bolsa. O balcão sugere o preço pela média dos últimos negócios.", 12, UiKit.MUTED)
		e.name = "SellEmpty"
		right.add_child(e)
		return
	var it: ItemDef = GameData.items[sel_item]
	var have := int(p.inventory.get(sel_item, 0))
	var hd := HBoxContainer.new()
	hd.add_theme_constant_override("separation", 8)
	right.add_child(hd)
	hd.add_child(UiKit.item_icon(it, 44))
	var hv := VBoxContainer.new()
	hd.add_child(hv)
	hv.add_child(UiKit.label(it.name, 15, UiKit.rarity_color(it.rarity)))
	hv.add_child(UiKit.label("Você tem %d  ·  o mercador paga %d cada" % [have, CraftSystem.sell_price(it)], 11, UiKit.MUTED))
	var rng: Vector2i = api("auction_price_range", [sel_item], Vector2i(1, 1))
	var sug := int(api("auction_suggest", [sel_item], rng.x))
	var tr := int(api("auction_trend", [sel_item], 0))
	var refl := HBoxContainer.new()
	refl.add_theme_constant_override("separation", 6)
	right.add_child(refl)
	refl.add_child(UiKit.label("Sugerido: %d  ·  referência %d" % [sug, int(api("auction_ref", [sel_item], 0))], 12, UiKit.GOLD))
	var tl := UiKit.label("%s %s" % [trend_mark(tr), trend_word(tr)], 12, trend_color(tr))
	tl.add_theme_font_override("font", UiKit.mark_font())
	refl.add_child(tl)
	right.add_child(UiKit.label("Faixa permitida: %d a %d por unidade" % [rng.x, rng.y], 11, UiKit.MUTED))
	var form := GridContainer.new()
	form.columns = 2
	form.add_theme_constant_override("h_separation", 8)
	right.add_child(form)
	form.add_child(UiKit.label("Quantidade", 12))
	var cnt := SpinBox.new()
	cnt.name = "SellCount"
	cnt.min_value = 1
	cnt.max_value = maxi(1, mini(have, it.stack_max))
	sel_count = clampi(sel_count, 1, int(cnt.max_value))
	cnt.value = sel_count
	form.add_child(cnt)
	form.add_child(UiKit.label("Preço por unidade", 12))
	var ph := HBoxContainer.new()
	form.add_child(ph)
	var pr := SpinBox.new()
	pr.name = "SellPrice"
	pr.min_value = rng.x
	pr.max_value = maxi(rng.x, rng.y)
	sel_price = clampi(sel_price if sel_price > 0 else sug, rng.x, maxi(rng.x, rng.y))
	pr.value = sel_price
	ph.add_child(pr)
	var usb := UiKit.button("Usar sugestão", func(): pr.value = sug, 0)
	usb.name = "UseSuggest"
	ph.add_child(usb)
	form.add_child(UiKit.label("Prazo", 12))
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 3)
	form.add_child(hrow)
	var durs: Array = st.get("durations", Balance.AUCTION_DURATIONS_H)
	if not sel_hours in durs:
		sel_hours = int(durs[mini(1, durs.size() - 1)])
	for h in durs:
		var hb := UiKit.button("%d h" % int(h), func(): sel_hours = int(h); _refresh(ui), 56)
		hb.name = "hours_%d" % int(h)
		hb.toggle_mode = true
		hb.button_pressed = sel_hours == int(h)
		hrow.add_child(hb)
	var tot := UiKit.label("", 13, UiKit.GOLD)
	tot.name = "SellTotal"
	right.add_child(tot)
	var fee := UiKit.label("", 12, UiKit.TEXT)
	fee.name = "SellFee"
	right.add_child(fee)
	var err := UiKit.para("", 11, ERR_COLOR)
	err.name = "SellError"
	right.add_child(err)
	var lb := UiKit.button("Anunciar", func(): _act(ui, "auction_list", [_player(), sel_item, sel_count, sel_price, sel_hours]), 160)
	lb.name = "ListButton"
	right.add_child(lb)
	_sell_refs = {"total": tot, "fee": fee, "err": err, "btn": lb}
	cnt.value_changed.connect(func(x: float): sel_count = int(x); _sell_update())
	pr.value_changed.connect(func(x: float): sel_price = int(x); _sell_update())
	cnt.get_line_edit().text_changed.connect(_typed.bind(cnt, false))     # o que se digita vale já (pulso/reconstrução não perde)
	pr.get_line_edit().text_changed.connect(_typed.bind(pr, true))
	_sell_update()
	if not near:
		lb.disabled = true

## Texto digitado num SpinBox da Vender (antes do Enter): número válido já vira a quantidade/preço escolhidos, dentro dos limites.
static func _typed(t: String, box: SpinBox, price: bool) -> void:
	if not t.strip_edges().is_valid_int():
		return
	var v := clampi(t.strip_edges().to_int(), int(box.min_value), int(box.max_value))
	if price:
		sel_price = v
	else:
		sel_count = v
	_sell_update()

## Recalcula total, taxa e o motivo do botão cinza sem reconstruir (o foco fica no campo).
static func _sell_update() -> void:
	if _sell_refs.is_empty() or not is_instance_valid(_sell_refs["btn"]):
		return
	var total := sel_count * sel_price
	var fee := int(api("auction_fee", [sel_item, sel_count, sel_price, sel_hours], 0))
	(_sell_refs["total"] as Label).text = "Total: %d ouro  ·  se vender, entram %d na Caixa (comissão %d%%)" % [total, net_of(total), roundi(Balance.AUCTION_CUT * 100.0)]
	(_sell_refs["fee"] as Label).text = "Taxa de anúncio: %d ouro agora (não volta se cancelar ou vencer)" % fee
	var why := str(api("auction_list_error", [_player(), sel_item, sel_count, sel_price, sel_hours], ""))
	(_sell_refs["err"] as Label).text = why
	(_sell_refs["btn"] as Button).disabled = why != ""

static func _bag_click(ev: InputEvent, ui: Object, item_id: String) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		select(item_id)
		msg = ""
		_refresh(ui)

# --- Meus anúncios -------------------------------------------------------------
static func _mine(ui: Object, body: VBoxContainer, st: Dictionary, near: bool) -> void:
	var rows: Array = st.get("listings", [])
	body.add_child(UiKit.label("%d de %d anúncios ativos" % [rows.size(), int(st.get("max_listings", Balance.AUCTION_PLAYER_LISTINGS))], 13, UiKit.GOLD))
	if rows.is_empty():
		var e := UiKit.para("Nenhum anúncio. Anuncie na aba Vender: os bots compram o que estiver no preço.", 12, UiKit.MUTED)
		e.name = "EmptyLabel"
		body.add_child(e)
		return
	var g := GridContainer.new()
	g.name = "MineList"
	g.columns = 8
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 3)
	body.add_child(g)
	for h in ["", "Item", "Nível", "Vendedor", "Prazo", "Preço", "Total", ""]:
		g.add_child(UiKit.label(h, 11, UiKit.MUTED))
	for r: Dictionary in rows:
		_row_cells(ui, g, r)
		var cb := UiKit.button("Cancelar", func(): _act(ui, "auction_cancel", [_player(), int(r["id"])]), 96)
		cb.name = "cancel_%d" % int(r["id"])
		cb.disabled = not near
		cb.tooltip_text = "O item volta para a Caixa; a taxa não volta."
		g.add_child(cb)

# --- Caixa ---------------------------------------------------------------------
static func _mail(ui: Object, body: VBoxContainer, st: Dictionary, near: bool) -> void:
	var mail: Array = st.get("mail", [])
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	body.add_child(top)
	var gold_in := 0
	for m: Dictionary in mail:
		gold_in += int(m.get("gold", 0)) if str(m.get("kind", "")) == "gold" else 0
	var hl := UiKit.label("%d de %d entradas  ·  %d ouro esperando" % [mail.size(), int(st.get("mail_max", Balance.AUCTION_MAIL_MAX)), gold_in], 13, UiKit.GOLD)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(hl)
	var all := UiKit.button("Pegar tudo", func(): _act(ui, "auction_collect", [_player(), -1]), 130)
	all.name = "CollectAll"
	all.disabled = not near or mail.is_empty()
	top.add_child(all)
	if mail.size() >= int(st.get("mail_max", Balance.AUCTION_MAIL_MAX)):
		body.add_child(UiKit.para("Caixa cheia: esvazie para poder comprar (vendas e devoluções continuam chegando).", 11, ERR_COLOR))
	if mail.is_empty():
		var e := UiKit.para("Caixa vazia. Compras, vendas e anúncios que voltam chegam aqui.", 12, UiKit.MUTED)
		e.name = "EmptyLabel"
		body.add_child(e)
		return
	var g := GridContainer.new()
	g.name = "MailList"
	g.columns = 3
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 3)
	body.add_child(g)
	for m: Dictionary in mail:
		var gold := str(m.get("kind", "")) == "gold"
		var it: ItemDef = GameData.items.get(str(m.get("item", "")))
		var ic: Control
		if gold:
			ic = UiKit._icon_or_square("art_gold", UiKit.GOLD, ROW_ICON)     # arte pintada do ouro (item_icons)
		elif it:
			ic = UiKit.icon_cell(it, ROW_ICON)
			if int(m.get("count", 1)) > 1:
				UiKit.corner_label(ic, str(int(m["count"])), ROW_ICON, true)
			_tip(ui, ic, UiKit.item_tooltip(it))
		else:
			ic = UiKit.empty_slot(ROW_ICON)
		g.add_child(ic)
		var tl := UiKit.label(mail_text(m), 12, UiKit.GOLD if gold else UiKit.TEXT)
		tl.custom_minimum_size.x = 640
		tl.clip_text = true
		g.add_child(tl)
		var pb := UiKit.button("Pegar", func(): _act(ui, "auction_collect", [_player(), int(m["id"])]), 80)
		pb.name = "collect_%d" % int(m["id"])
		pb.disabled = not near
		g.add_child(pb)
