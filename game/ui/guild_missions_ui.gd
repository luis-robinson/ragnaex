class_name GuildMissionsUi
extends RefCounted
## Aba Missões da janela da Guilda (design/gdd/banco-da-guilda.md §3.7; pedido do usuário 2026-11-27: o aviso único ao
## lado do minimapa abre esta aba). Tudo das encomendas num lugar: as que voltaram (mensagem do bot + "Pôr na bolsa"),
## os bots fora com o tempo que falta, o formulário de mandar e os pedidos dos bots. Só lê `Sim.guild_bank()` e age pelos
## `Sim.guild_*` (pela fonte do GuildUi: testes trocam por GuildUi.src).

static var msg := ""                   # resposta da última ação (bolsa cheia, erro ao mandar)
static var m_kind := "material"        # encomenda: o que buscar
static var m_target := ""
static var m_rids: Array = []
static var m_time := 1

const TIME_LABELS := ["Curta", "Média", "Longa"]
const BACK_BORDER := Color(1.0, 0.82, 0.4)

static func _api(m: String, args: Array = [], fb: Variant = null) -> Variant:
	return GuildUi.api(m, args, fb)

static func _refresh(w: Control) -> void:
	if w and w.has_method("refresh_window"):
		w.refresh_window("guild")

static func _act(w: Control, m: String, args: Array) -> void:
	msg = str(_api(m, args, "Indisponível."))
	_refresh(w)

static func build(w: Control, body: VBoxContainer) -> void:
	var v: Dictionary = _api("guild_bank", [], {})
	if v.is_empty():
		body.add_child(UiKit.para("Entre numa guilda para mandar encomendas.", 12, UiKit.MUTED))
		return
	if msg != "":
		var ml := UiKit.para(msg, 11, Color(1.0, 0.6, 0.5))
		ml.name = "MissionsMsg"
		body.add_child(ml)
	_returned(w, body, v)
	_away(body, v)
	body.add_child(UiKit.hsep(4))
	body.add_child(UiKit.label("Mandar bots buscar", 14, UiKit.GOLD))
	if not bool(v.get("can_missions", false)):
		body.add_child(UiKit.para("Encomendas a partir de Veterano.", 11, UiKit.MUTED))
	else:
		_order_form(w, body, v)
	body.add_child(UiKit.hsep(4))
	_requests(w, body, v)

# --- voltaram ----------------------------------------------------------------
static func _returned(w: Control, body: VBoxContainer, v: Dictionary) -> void:
	var ns: Array = v.get("notices", [])
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	body.add_child(head)
	var hl := UiKit.label("Voltaram  %d" % ns.size(), 14, UiKit.GOLD)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hl)
	if ns.size() > 1:
		var all := UiKit.button("Pôr tudo na bolsa", _collect_all.bind(w), 170)
		all.name = "CollectAll"
		head.add_child(all)
	if ns.is_empty():
		body.add_child(UiKit.para("Nenhuma encomenda esperando.", 11, UiKit.MUTED))
	for n: Dictionary in ns:
		body.add_child(_back_card(w, n))

static func _back_card(w: Control, n: Dictionary) -> Control:
	var id := int(n.get("id", -1))
	var card := UiKit.panel(UiKit.BG_LIGHT, BACK_BORDER.darkened(0.25))
	card.name = "back_%d" % id
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	var cls: ClassDef = GameData.classes.get(str(n.get("class", "")))
	row.add_child(UiKit.class_icon(cls, 40) if cls else UiKit.color_square(Color(0.3, 0.3, 0.35), 40))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	col.add_child(UiKit.label(str(n.get("name", "?")), 13, UiKit.GOLD))
	var say := UiKit.para("“%s”" % str(n.get("text", "")), 12, UiKit.TEXT)
	say.name = "BotMessage"
	col.add_child(say)
	var got := HFlowContainer.new()
	got.add_theme_constant_override("h_separation", 10)
	col.add_child(got)
	for pair in n.get("items", []):
		var it: ItemDef = GameData.items.get(str(pair[0]))
		if it == null:
			continue
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 4)
		r.add_child(UiKit.item_icon(it, 28))
		r.add_child(UiKit.label("%s x%d" % [it.name, int(pair[1])], 12, UiKit.rarity_color(it.rarity)))
		got.add_child(r)
	if int(n.get("gold", 0)) > 0:
		got.add_child(UiKit.label("+%d de ouro (metade da taxa)" % int(n.get("gold", 0)), 12, UiKit.GOLD))
	var b := UiKit.button("Pôr na bolsa", _collect.bind(w, id), 130)
	b.name = "collect_%d" % id
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(b)
	return card

static func _collect(w: Control, id: int) -> void:
	_act(w, "guild_mission_collect", [id])        # bolsa cheia: a sim diz e o item continua reservado

## "Pôr tudo na bolsa": recolhe na ordem; para no primeiro erro (bolsa cheia) e mostra a resposta.
static func collect_all() -> String:
	var v: Dictionary = _api("guild_bank", [], {})
	for n: Dictionary in v.get("notices", []):
		var err := str(_api("guild_mission_collect", [int(n.get("id", -1))], "Indisponível."))
		if err != "":
			return err
	return ""

static func _collect_all(w: Control) -> void:
	msg = collect_all()
	_refresh(w)

# --- fora agora --------------------------------------------------------------
static func _away(body: VBoxContainer, v: Dictionary) -> void:
	var ms: Array = v.get("missions", [])
	body.add_child(UiKit.label("Fora agora  (%d de %d)" % [ms.size(), int(v.get("missions_max", 0))], 14, UiKit.GOLD))
	if ms.is_empty():
		body.add_child(UiKit.para("Nenhum bot fora numa encomenda.", 11, UiKit.MUTED))
	for m: Dictionary in ms:
		var it: ItemDef = GameData.items.get(str(m.get("target", "")))
		var l := UiKit.label("• %s buscando %s em %s · volta em %s" % [" e ".join(PackedStringArray(m.get("names", []))), it.name if it else "?",
			GuildUi.map_name(str(m.get("map", ""))), GuildBankUi.dur(float(m.get("left", 0.0)))], 12, UiKit.TEXT)
		l.name = "away_%d" % int(m.get("id", 0))
		body.add_child(l)

# --- mandar ------------------------------------------------------------------
static func _order_form(w: Control, body: VBoxContainer, v: Dictionary) -> void:
	var tg: Dictionary = v.get("targets", {})
	var opts: Array = tg.get(m_kind, [])
	if not (m_target in opts):
		m_target = str(opts[0]) if not opts.is_empty() else ""
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	body.add_child(h)
	var kb := OptionButton.new()
	kb.name = "OrderKind"
	kb.add_item("Material", 0)
	kb.add_item("Carta", 1)
	kb.select(0 if m_kind == "material" else 1)
	kb.item_selected.connect(func(i: int): m_kind = "material" if i == 0 else "card"; m_target = ""; _refresh(w))
	h.add_child(kb)
	var ob := OptionButton.new()
	ob.name = "OrderTarget"
	for i in opts.size():
		var it: ItemDef = GameData.items.get(str(opts[i]))
		ob.add_item(it.name if it else str(opts[i]), i)
		if opts[i] == m_target:
			ob.select(i)
	ob.item_selected.connect(func(i: int): m_target = str(opts[i]))
	ob.custom_minimum_size = Vector2(200, 0)
	h.add_child(ob)
	var tb := OptionButton.new()
	tb.name = "OrderTime"
	for i in Balance.GBANK_MISSION_TIMES.size():
		tb.add_item("%s (%s)" % [TIME_LABELS[mini(i, 2)], GuildBankUi.dur(float(Balance.GBANK_MISSION_TIMES[i]) * 60.0)], i)
	tb.select(m_time)
	tb.item_selected.connect(func(i: int): m_time = i; _refresh(w))
	h.add_child(tb)
	if opts.is_empty():
		body.add_child(UiKit.para("Nada para buscar ainda (cartas: monstros que você já viu).", 11, UiKit.MUTED))
	# bots
	var g: Dictionary = GuildUi.player_guild()
	var bots := HFlowContainer.new()
	bots.add_theme_constant_override("h_separation", 4)
	bots.add_theme_constant_override("v_separation", 4)
	body.add_child(bots)
	m_rids = m_rids.filter(func(x): return (g.get("members", []) as Array).any(func(mm): return int(mm.get("rid", -1)) == int(x)))
	for mm: Dictionary in g.get("members", []):
		var rid := int(mm.get("rid", -1))
		if rid < 0:
			continue
		var away := float(_api("guild_mission_away", [rid], 0.0))
		var b := UiKit.button("%s %d" % [mm.get("name", "?"), int(mm.get("level", 1))], _toggle_bot.bind(w, rid))
		b.name = "order_bot_%d" % rid
		b.toggle_mode = true
		b.button_pressed = rid in m_rids
		b.disabled = away > 0.0
		if away > 0.0:
			b.tooltip_text = "Fora numa encomenda: volta em %s" % GuildBankUi.dur(away)
		bots.add_child(b)
	var hours := float(Balance.GBANK_MISSION_TIMES[m_time]) / 60.0
	var cost := int(_api("guild_mission_fee", [hours, maxi(1, m_rids.size())], 0))
	var h2 := HBoxContainer.new()
	h2.add_theme_constant_override("separation", 8)
	body.add_child(h2)
	var why := str(_api("guild_mission_error", [m_kind, m_target, m_rids, m_time], ""))
	var send := UiKit.button("Mandar (taxa %d)" % cost, _send.bind(w), 170)
	send.name = "OrderSend"
	send.disabled = why != ""
	h2.add_child(send)
	if why != "":
		h2.add_child(UiKit.label(why, 11, UiKit.MUTED))

static func _send(w: Control) -> void:
	msg = str(_api("guild_mission_start", [m_kind, m_target, m_rids.duplicate(), m_time], "Indisponível."))
	if msg == "":
		m_rids.clear()
	_refresh(w)

static func _toggle_bot(w: Control, rid: int) -> void:
	if rid in m_rids:
		m_rids.erase(rid)
	elif m_rids.size() < Balance.GBANK_MISSION_BOTS:
		m_rids.append(rid)
	_refresh(w)

# --- pedidos dos bots ----------------------------------------------------------
static func _requests(w: Control, body: VBoxContainer, v: Dictionary) -> void:
	body.add_child(UiKit.label("Pedidos dos bots", 14, UiKit.GOLD))
	if not bool(v.get("can_requests", false)):
		body.add_child(UiKit.para("Pedidos a partir de Membro.", 11, UiKit.MUTED))
		return
	body.add_child(UiKit.label("Quadro novo em %s" % GuildBankUi.dur(float(v.get("next_requests_in", 0.0))), 11, UiKit.MUTED))
	for q: Dictionary in v.get("requests", []):
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		r.name = "request_%d" % int(q.get("id", 0))
		body.add_child(r)
		var it: ItemDef = GameData.items.get(str(q.get("target", "")))
		if it:
			r.add_child(UiKit.item_icon(it, 28))
		var l := UiKit.label("%s  ·  +%d ouro, +%d Contribuição" % [q.get("text", ""), int(q.get("gold", 0)), int(q.get("contrib", 0))], 12,
			Color(0.6, 0.95, 0.65) if q.get("state", "") == "accepted" else UiKit.TEXT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r.add_child(l)
		var id := int(q.get("id", 0))
		if q.get("state", "") == "open":
			r.add_child(UiKit.button("Aceitar", func(): _act(w, "guild_request_accept", [id]), 80))
		elif q.get("kind", "") != "kill":
			var b := UiKit.button("Entregar", func(): _act(w, "guild_request_deliver", [id]), 80)
			b.disabled = not bool(q.get("ready", false))
			r.add_child(b)
		else:
			r.add_child(UiKit.label("aceito", 11, UiKit.MUTED))
