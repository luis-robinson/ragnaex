class_name GuildBankUi
extends RefCounted
## Aba Banco da janela da Guilda (design/gdd/banco-da-guilda.md): patente e barra de Contribuição, abas do baú
## (Equipamento, Cartas, Materiais, Consumíveis, Ouro), tirar (clique no banco) e depositar (clique na bolsa), registro,
## e o registro (encomendas e pedidos dos bots: aba Missões, GuildMissionsUi). Só lê `Sim.guild_bank()` e age pelos `Sim.guild_*`
## (pela fonte do GuildUi: testes trocam por GuildUi.src).

static var sub := "gear"               # aba do baú aberta
static var msg := ""                   # resposta da última ação
static var gold_amount := 100

const SUBS := [["gear", "Equipamento"], ["card", "Cartas"], ["material", "Materiais"], ["consumable", "Consumíveis"], ["gold", "Ouro"]]
const CELL := 48
const COLS := 9

static func _api(m: String, args: Array = [], fb: Variant = null) -> Variant:
	return GuildUi.api(m, args, fb)

static func _refresh(w: Control) -> void:
	if w and w.has_method("refresh_window"):
		w.refresh_window("guild")

static func _act(w: Control, m: String, args: Array) -> void:
	msg = str(_api(m, args, "Indisponível."))
	_refresh(w)

## "12 min" / "1 h 05 min".
static func dur(s: float) -> String:
	var m := int(ceil(maxf(0.0, s) / 60.0))
	return "%d min" % m if m < 60 else "%d h %02d min" % [m / 60, m % 60]

## Texto da barra de patente: "Veterano · 1.420 / 3.000 para Oficial".
static func rank_text(v: Dictionary) -> String:
	if str(v.get("next_rank", "")) == "":
		return "%s · Contribuição %d (patente máxima)" % [v.get("rank_name", "?"), int(v.get("contrib", 0))]
	return "%s · Contribuição %d / %d para %s" % [v.get("rank_name", "?"), int(v.get("contrib", 0)), int(v.get("next_contrib", 0)), v.get("next_rank", "")]

static func build(w: Control, body: VBoxContainer) -> void:
	var v: Dictionary = _api("guild_bank", [], {})
	if v.is_empty():
		body.add_child(UiKit.para("Entre numa guilda para usar o banco.", 12, UiKit.MUTED))
		return
	if not SUBS.any(func(x): return x[0] == sub):
		sub = "gear"                     # a antiga sub-aba "orders" virou a aba Missões
	# patente
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	body.add_child(top)
	var rl := UiKit.label(rank_text(v), 13, UiKit.GOLD)
	rl.name = "RankLabel"
	rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(rl)
	var tk := "Retiradas: %d (%d/h)" % [int(v.get("takes", 0)), int(v.get("takes_per_h", 0))]
	if int(v.get("takes", 0)) < 1:
		tk += " · próxima em " + dur(float(v.get("next_take_in", 0.0)))
	top.add_child(UiKit.label(tk, 12, UiKit.TEXT))
	var bar := UiKit.bar(UiKit.GOLD, 8)
	bar.name = "RankBar"
	bar.min_value = float(v.get("rank_contrib", 0))
	bar.max_value = float(v.get("next_contrib", 0)) if str(v.get("next_rank", "")) != "" else float(v.get("contrib", 1)) + 1.0
	bar.value = float(v.get("contrib", 0))
	body.add_child(bar)
	var where := str(v.get("where_error", ""))
	if where != "":
		body.add_child(UiKit.para(where, 11, Color(1.0, 0.6, 0.5)))
	# abas do baú
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	body.add_child(row)
	for s in SUBS:
		var b := UiKit.button(str(s[1]), func(): sub = str(s[0]); msg = ""; _refresh(w))
		b.name = "bank_" + str(s[0])
		b.toggle_mode = true
		b.button_pressed = sub == s[0]
		row.add_child(b)
	if msg != "":
		body.add_child(UiKit.para(msg, 11, Color(1.0, 0.6, 0.5)))
	match sub:
		"gold": _gold(w, body, v)
		_: _items(w, body, v)
	body.add_child(UiKit.hsep(4))
	body.add_child(UiKit.label("Registro", 12, UiKit.MUTED))
	var lg: Array = v.get("log", [])
	for i in mini(lg.size(), 6):
		body.add_child(UiKit.label("• %s  (%s)" % [lg[i].get("text", ""), GuildUi.ago(float(lg[i].get("at", 0.0)))], 11, UiKit.TEXT))

static func _items(w: Control, body: VBoxContainer, v: Dictionary) -> void:
	var items: Array = (v.get("items", []) as Array).filter(func(x: Dictionary): return x.get("tab", "") == sub)
	body.add_child(UiKit.label("No banco  %d   (clique para tirar)" % items.size(), 12, UiKit.MUTED))
	var g := UiKit.grid(COLS, 4)
	g.name = "BankGrid"
	body.add_child(g)
	for bi: Dictionary in items:
		var it: ItemDef = GameData.items.get(str(bi.get("id", "")))
		if it == null:
			continue
		var cell := UiKit.icon_cell(it, CELL, Color(1, 1, 1, 0.55) if int(bi.get("res", 0)) != 0 else Color.WHITE)
		cell.name = "bank_item_%d" % int(bi.get("uid", 0))
		if int(bi.get("count", 1)) > 1:
			UiKit.corner_label(cell, str(int(bi["count"])), CELL, true)
		if int(bi.get("res", 0)) != 0:
			UiKit.corner_label(cell, "seu", CELL, false, UiKit.GOLD)
		cell.tooltip_text = "%s%s\npor %s%s" % [it.name, (" x%d" % int(bi["count"])) if int(bi.get("count", 1)) > 1 else "", bi.get("by", "?"),
			"\nReservado: pegue na aba Missões" if int(bi.get("res", 0)) != 0 else ("\nTirar leva %d (1 retirada)" % int(bi.get("take_n", 1)))]
		cell.gui_input.connect(_cell_click.bind(w, "guild_bank_take", [int(bi.get("uid", 0))]))
		g.add_child(cell)
	for i in maxi(0, COLS - items.size()):
		g.add_child(UiKit.empty_slot(CELL))
	# bolsa: o que dá para depositar nesta aba
	body.add_child(UiKit.label("Da sua bolsa  (clique para depositar; número = Contribuição)", 12, UiKit.MUTED))
	var g2 := UiKit.grid(COLS, 4)
	g2.name = "BagGrid"
	body.add_child(g2)
	var p: SimEntity = Sim.player
	var n := 0
	if p:
		var ids: Array = p.inventory.keys()
		ids.sort()
		for iid in ids:
			var it: ItemDef = GameData.items.get(iid)
			if it == null or it.type == ItemDef.Type.QUEST or GuildBankSystem.tab_of(it) != sub:
				continue
			var cnt := int(p.inventory[iid])
			var cell := UiKit.icon_cell(it, CELL)
			cell.name = "bag_item_" + str(iid)
			if cnt > 1:
				UiKit.corner_label(cell, str(cnt), CELL, true)
			var c := int(_api("guild_bank_contrib_of", [iid], 0))
			UiKit.corner_label(cell, "+%d" % (c * cnt), CELL, false, UiKit.GOLD)
			cell.tooltip_text = "%s\nDepositar %d: +%d de Contribuição" % [it.name, cnt, c * cnt]
			cell.gui_input.connect(_cell_click.bind(w, "guild_bank_deposit", [str(iid), cnt]))
			g2.add_child(cell)
			n += 1
	for i in maxi(0, COLS - n):
		g2.add_child(UiKit.empty_slot(CELL))

static func _cell_click(ev: InputEvent, w: Control, m: String, args: Array) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_act(w, m, args)

static func _gold(w: Control, body: VBoxContainer, v: Dictionary) -> void:
	body.add_child(UiKit.label("Cofre: %d de ouro" % int(v.get("gold", 0)), 15, UiKit.GOLD))
	body.add_child(UiKit.label("Você pode tirar %d agora (%d por hora na sua patente)." % [int(v.get("gold_can_take", 0)), int(v.get("gold_per_h", 0))], 12, UiKit.TEXT))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	body.add_child(h)
	var sp := SpinBox.new()
	sp.name = "GoldAmount"
	sp.min_value = 1
	sp.max_value = 1000000
	sp.value = gold_amount
	sp.value_changed.connect(func(x: float): gold_amount = int(x))
	h.add_child(sp)
	h.add_child(UiKit.button("Tirar", func(): _act(w, "guild_bank_take_gold", [gold_amount]), 90))
	h.add_child(UiKit.button("Depositar", func(): _act(w, "guild_bank_deposit_gold", [gold_amount]), 100))
	body.add_child(UiKit.para("Ouro depositado também conta Contribuição (pouca).", 11, UiKit.MUTED))
	body.add_child(UiKit.hsep(4))
	body.add_child(UiKit.label("Patentes", 13, UiKit.GOLD))
	for k in Balance.GBANK_RANKS.size():
		var r: Dictionary = Balance.GBANK_RANKS[k]
		var mine := k == int(v.get("rank_i", 0))
		var lib: String = ["banco", "pedidos dos bots", "encomendas (1)", "2 encomendas, lendário no banco", "3 encomendas"][mini(k, 4)]
		body.add_child(UiKit.label("%s %s  ·  %d  ·  %d retiradas/h  ·  %d ouro/h  ·  %s" % ["▶" if mine else "  ", r["name"], int(r["contrib"]),
			int(r["takes"]), int(r["gold"]), lib], 11, UiKit.GOLD if mine else UiKit.TEXT))
