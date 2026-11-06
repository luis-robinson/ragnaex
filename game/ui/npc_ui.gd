extends Control
## Diálogo de NPC: falas, aceitar/entregar quests, loja (mercador) e crafting (ferreiro/alquimista).

var hud
var win: PanelContainer = null
var npc_id := ""
var npc: Dictionary = {}
var mode := "dialog"   # dialog | shop | craft

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Events.item_gained.connect(func(id, _i, _c): _refresh_if_mine(id))      # só o que é do jogador (bots pegam itens o tempo todo)
	Events.item_removed.connect(func(id, _i, _c): _refresh_if_mine(id))
	Events.quest_completed.connect(func(id, _q): _refresh_if_mine(id))

func _process(_delta: float) -> void:
	if win != null and npc_id != "":
		Sim.hold_npc(npc_id)          # conversando: o morador não sai andando

func is_open() -> bool:
	return win != null

func _refresh_if_mine(entity_id: int) -> void:
	if Sim.player and entity_id == Sim.player.id:
		_refresh_if_open()

func _refresh_if_open() -> void:
	if win and mode != "dialog":
		_rebuild()

func open(id: String) -> void:
	npc_id = id
	npc = {}
	for mid in GameData.maps:
		for n in GameData.maps[mid].npcs:
			if n["id"] == id:
				npc = n
	if npc.is_empty():
		return
	mode = "dialog"
	QuestSystem.on_talk(Sim.player, id)
	hud.windows_script.close_all()
	_rebuild()

func close() -> void:
	if win:
		win.queue_free()
		win = null
	hud._update_blocking()

var _scroll: ScrollContainer = null
var _scroll_mode := ""

func _rebuild() -> void:
	var keep := 0                      # mesma tela (ex.: craftou algo): volta para onde estava a rolagem
	if _scroll and is_instance_valid(_scroll) and _scroll_mode == mode:
		keep = _scroll.scroll_vertical
	if win:
		win.queue_free()
	win = UiKit.panel()
	win.custom_minimum_size = Vector2(680, 320)
	add_child(win)
	var v := VBoxContainer.new()
	win.add_child(v)
	var header := HBoxContainer.new()
	v.add_child(header)
	var t := UiKit.title(npc.get("name", "NPC"))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(t)
	header.add_child(UiKit.button("✕ (Esc)", close))
	var scroll := ScrollContainer.new()
	_scroll = scroll
	_scroll_mode = mode
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(650, 340)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	match mode:
		"dialog": _dialog(body)
		"shop": _shop(body)
		"craft": _craft(body)
		"enhance": _enhance(body)
		"storage": _storage(body)
		"relic": _relic(body)
	win.reset_size()
	win.position = (get_viewport_rect().size - win.size) * 0.5
	if keep > 0:
		_restore_scroll.call_deferred(scroll, keep)

func _restore_scroll(scroll: ScrollContainer, v: int) -> void:
	await get_tree().process_frame          # a lista nova só tem altura depois de um quadro
	if is_instance_valid(scroll):
		scroll.scroll_vertical = v

## Relicária: uma linha por nível (preço em moedas), as peças lendárias da classe; clique troca.
func _relic(body: VBoxContainer) -> void:
	var p: SimEntity = Sim.player
	var coins := int(p.inventory.get("legend_coin", 0))
	body.add_child(UiKit.label("✦ Moedas lendárias: %d" % coins, 16, Color(1.0, 0.65, 0.2)))
	var by_lv := {}
	for iid in Sim.relic_offer(p):
		var it: ItemDef = GameData.items[iid]
		if not by_lv.has(it.level_req):
			by_lv[it.level_req] = []
		by_lv[it.level_req].append(it)
	for lv in Balance.LEGENDARY_LEVELS:
		if not by_lv.has(lv):
			continue
		var cost: int = Sim.relic_cost(by_lv[lv][0])
		var head := UiKit.label("Nível %d — %d moeda%s" % [lv, cost, "s" if cost > 1 else ""], 13, UiKit.GOLD if p.level >= lv else Color(1.0, 0.62, 0.5))
		body.add_child(head)
		var grid := UiKit.grid(12, 4)
		body.add_child(grid)
		var items: Array = by_lv[lv]
		items.sort_custom(func(a, b): return a.name < b.name)
		for it in items:
			var why := Sim.relic_block_reason(p, it.id)
			var cell := UiKit.icon_cell(it, 46, Color.WHITE if why == "" else UiKit.DIM)
			var hint: String = ("[color=#9f9]Clique: trocar por %d moeda%s[/color]" % [cost, "s" if cost > 1 else ""]) if why == "" else ("[color=#f99]%s[/color]" % why.capitalize())
			_tip(cell, func(): return UiKit.item_tooltip(it) + "\n" + hint)
			cell.gui_input.connect(_on_relic_click.bind(it.id))
			grid.add_child(cell)

## Dica ao passar o mouse: texto pronto ou Callable que monta o texto na hora.
func _tip(c: Control, tip: Variant) -> void:
	c.mouse_entered.connect(func(): hud.windows_script.show_tip(tip.call() if tip is Callable else str(tip)))
	c.mouse_exited.connect(hud.windows_script.hide_tip)

func _on_relic_click(ev: InputEvent, item_id: String) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if Sim.relic_exchange(Sim.player, item_id):
			_rebuild()

## Depósito: bolsa à esquerda, depósito à direita. Clique leva a pilha inteira para o outro lado; Shift+clique leva 1.
func _storage(body: VBoxContainer) -> void:
	var p: SimEntity = Sim.player
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	body.add_child(row)
	row.add_child(_store_side("Bolsa", p.inventory, true))
	row.add_child(_store_side("Depósito (%d/%d)" % [p.storage.size(), Balance.STORAGE_SLOTS], p.storage, false))
	body.add_child(UiKit.para("Clique: leva a pilha toda  ·  Shift+clique: leva 1  ·  equipado não entra (tire no boneco primeiro)", 11, UiKit.MUTED))

func _store_side(title: String, items: Dictionary, from_bag: bool) -> Control:
	var v := VBoxContainer.new()
	v.add_child(UiKit.label(title, 14, UiKit.GOLD))
	var grid := UiKit.grid(7, 4)
	v.add_child(grid)
	var ids := items.keys()
	ids.sort_custom(func(a, b): return GameData.items[a].name < GameData.items[b].name)
	for iid in ids:
		var it: ItemDef = GameData.items.get(iid)
		if it == null:
			continue
		var cell := UiKit.icon_cell(it, 40)
		var n := int(items[iid])
		if n > 1:
			UiKit.corner_label(cell, str(n), 40, false)
		_tip(cell, func(): return UiKit.item_tooltip(it) + "\n[color=#9f9]x%d · clique: leva tudo · Shift: leva 1[/color]" % n)
		cell.gui_input.connect(_on_store_click.bind(str(iid), from_bag))
		grid.add_child(cell)
	for i in range(maxi(0, 21 - ids.size())):
		grid.add_child(UiKit.empty_slot(40))
	return v

func _on_store_click(ev: InputEvent, item_id: String, from_bag: bool) -> void:
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	var p: SimEntity = Sim.player
	var have: int = int((p.inventory if from_bag else p.storage).get(item_id, 0))
	var n: int = 1 if Input.is_key_pressed(KEY_SHIFT) else have
	var ok: bool = Sim.storage_deposit(p, item_id, n) if from_bag else Sim.storage_withdraw(p, item_id, n)
	if ok:
		_rebuild()

func _dialog(body: VBoxContainer) -> void:
	var p: SimEntity = Sim.player
	var role: String = npc.get("role", "")
	# quests para entregar
	var turnins := QuestSystem.turnins_at(p, npc_id)
	for q in turnins:
		var card := UiKit.panel(Color(0.12, 0.2, 0.12, 0.95), Color(0.5, 0.9, 0.5))
		body.add_child(card)
		var cv := VBoxContainer.new()
		card.add_child(cv)
		cv.add_child(UiKit.label("✔ %s" % q.title, 14, Color(0.6, 1, 0.6)))
		if q.repeatable:
			cv.add_child(UiKit.repeat_label(q, 11))
		cv.add_child(UiKit.para('"%s"' % q.dialog_complete, 12))
		var rew := "Recompensa: %d XP, %d ouro" % [q.reward_xp, q.reward_gold]
		for iid in q.reward_items:
			var it: ItemDef = GameData.items.get(iid)
			rew += ", %s x%d" % [it.name if it else iid, int(q.reward_items[iid])]
		if q.reward_gear_tier >= 0:
			rew += ", 1 peça de equipamento"
		cv.add_child(UiKit.label(rew, 11, UiKit.MUTED))
		cv.add_child(UiKit.button("Entregar", func(): QuestSystem.complete(p, q, Sim); _rebuild(), 120))
	# quests em andamento com este NPC
	for qid in p.quests_active:
		var q: QuestDef = GameData.quests[qid]
		if (q.giver_npc == npc_id or q.turnin() == npc_id) and not QuestSystem.is_complete(p, q):
			var card := UiKit.panel(UiKit.BG_LIGHT, Color(0.3, 0.28, 0.35))
			body.add_child(card)
			var cv := VBoxContainer.new()
			card.add_child(cv)
			cv.add_child(UiKit.label("… %s (%d/%d)" % [q.title, QuestSystem.progress(p, q), q.count], 13, UiKit.GOLD))
			if q.repeatable:
				cv.add_child(UiKit.repeat_label(q, 11))
			cv.add_child(UiKit.para('"%s"' % q.dialog_progress, 12))
	# quests disponíveis
	for q in QuestSystem.available_from_npc(p, npc_id):
		var card := UiKit.panel(Color(0.2, 0.18, 0.1, 0.95), UiKit.GOLD)
		body.add_child(card)
		var cv := VBoxContainer.new()
		card.add_child(cv)
		if q.repeatable:                      # repetível: azul, com o símbolo e o lembrete
			var t := UiKit.label("↻ %s  (Lv %d)  ·  Repetível" % [q.title, q.level_req], 14, UiKit.QUEST_REPEAT)
			t.add_theme_font_override("font", UiKit.mark_font())
			cv.add_child(t)
			cv.add_child(UiKit.para("Pode fazer de novo quantas vezes quiser; a recompensa vem toda vez.", 11, UiKit.QUEST_REPEAT))
		else:
			cv.add_child(UiKit.label("! %s  (Lv %d)" % [q.title, q.level_req], 14, UiKit.GOLD))
		cv.add_child(UiKit.para('"%s"' % q.dialog_offer, 12))
		cv.add_child(UiKit.para(q.description + "  —  " + q.map_hint, 11, UiKit.MUTED))
		cv.add_child(UiKit.button("Aceitar", func(): QuestSystem.accept(p, q); _rebuild(), 120))
	# falas
	var lines: Array = npc.get("dialog", [])
	if lines.size() > 0:
		body.add_child(UiKit.hsep())
		body.add_child(UiKit.para('"%s"' % lines[randi() % lines.size()], 13, Color(0.9, 0.9, 0.95)))
	# ações por papel
	body.add_child(UiKit.hsep())
	var actions := HBoxContainer.new()
	body.add_child(actions)
	match role:
		"merchant":
			actions.add_child(UiKit.button("Abrir loja", func(): mode = "shop"; _rebuild(), 140))
		"smith":
			actions.add_child(UiKit.button("Usar a forja", func(): mode = "craft"; _rebuild(), 140))
			actions.add_child(UiKit.button("Aprimorar (+1 a +9)", func(): mode = "enhance"; _rebuild(), 170))
		"alchemy":
			actions.add_child(UiKit.button("Usar o caldeirão", func(): mode = "craft"; _rebuild(), 140))
		"storage":
			actions.add_child(UiKit.button("Abrir o depósito", func(): mode = "storage"; _rebuild(), 160))
		"relic":
			actions.add_child(UiKit.button("Trocar moedas lendárias", func(): mode = "relic"; _rebuild(), 200))
		"crystal":
			var bound: bool = p.bind_map == p.map_id
			if bound:
				body.add_child(UiKit.para("Este é o seu ponto de retorno: o G e o renascer trazem você aqui. Dentro do povoado dá para trocar skills.", 12, Color(0.6, 0.85, 1.0)))
			else:
				var here: String = GameData.maps[Sim.home_of(p)["map"]].name
				body.add_child(UiKit.para("Ponto de retorno atual: %s. Vincular aqui muda o destino do G e onde você renasce." % here, 12, UiKit.MUTED))
				actions.add_child(UiKit.button("Vincular aqui", func(): Sim.bind_crystal(p, npc_id); _rebuild(), 150))
		"board":
			body.add_child(UiKit.para("Campina (Lv 1-10): fora dos portões · Floresta (Lv 10-20): desfiladeiro leste · Ruínas (Lv 20-30): passagem oeste", 11, UiKit.MUTED))
	actions.add_child(UiKit.button("Fechar", close, 100))

var shop_tab := "all"          # all | potions | gear (filtro da loja)
const SHOP_COLS := 8
const SHOP_CELL := 52

## Loja estilo MMO: mercadoria à esquerda (preço embaixo), bolsa à direita (quanto paga). Clique compra/vende 1,
## Shift+clique compra 5 / vende a pilha. "Vender materiais" limpa o que nenhuma quest ativa pede.
func _shop(body: VBoxContainer) -> void:
	var p: SimEntity = Sim.player
	win.custom_minimum_size = Vector2(SHOP_COLS * (SHOP_CELL + 4) * 2 + 80, 420)
	_scroll.custom_minimum_size = Vector2(SHOP_COLS * (SHOP_CELL + 4) * 2 + 50, 430)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	body.add_child(top)
	top.add_child(UiKit.label("Ouro: %d" % p.gold, 16, UiKit.GOLD))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	for tab in [["all", "Tudo"], ["potions", "Poções e elixires"], ["gear", "Equipamento"]]:
		top.add_child(UiKit.button(("● " if shop_tab == tab[0] else "") + tab[1], _set_shop_tab.bind(tab[0]), 120))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	body.add_child(cols)
	# --- mercadoria ---
	var left := VBoxContainer.new()
	cols.add_child(left)
	left.add_child(UiKit.label("Mercadoria", 14, UiKit.GOLD))
	var g1 := _shop_grid(left)
	var stock: Array = []
	for iid in npc.get("shop", []):
		var it: ItemDef = GameData.items.get(iid)
		if it and _shop_tab_has(it):
			stock.append(it)
	for it in stock:
		var err := Sim.equip_error(p, it) if it.slot != ItemDef.Slot.NONE else ""
		var cell := _shop_cell(it, "", "%d" % it.price, p.gold < it.price or err != "")
		var tip := UiKit.item_tooltip(it) + "\n[color=#ffd966]Preço: %d ouro[/color]\n[color=#9f9]clique: compra 1 · Shift: compra 5[/color]" % it.price
		if err != "":
			tip += "\n[color=#f88]%s[/color]" % err
		_tip(cell, tip)
		cell.gui_input.connect(_on_shop_buy.bind(it.id))
		g1.add_child(cell)
	_pad_grid(g1, stock.size(), 24)
	# --- bolsa ---
	var right := VBoxContainer.new()
	cols.add_child(right)
	right.add_child(UiKit.label("Sua bolsa (vende por 50%)", 14, UiKit.GOLD))
	var g2 := _shop_grid(right)
	var ids: Array = p.inventory.keys().filter(func(i): return GameData.items.has(i) and _sellable(GameData.items[i]))
	ids.sort_custom(func(x, y): return [GameData.items[x].type, GameData.items[x].name] < [GameData.items[y].type, GameData.items[y].name])
	for iid in ids:
		var it: ItemDef = GameData.items[iid]
		var n := int(p.inventory[iid])
		var each := int(it.price * 0.5)
		var cell := _shop_cell(it, str(n) if n > 1 else "", "+%d" % each, false)
		var tip := UiKit.item_tooltip(it) + "\n[color=#ffd966]Paga %d ouro (x%d = %d)[/color]\n[color=#9f9]clique: vende 1 · Shift: vende a pilha[/color]" % [each, n, each * n]
		_tip(cell, tip)
		cell.gui_input.connect(_on_shop_sell.bind(str(iid)))
		g2.add_child(cell)
	_pad_grid(g2, ids.size(), 24)
	# --- rodapé ---
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	body.add_child(foot)
	foot.add_child(UiKit.button("← Voltar", _back_to_dialog, 100))
	var junk := _junk(p)
	var total := 0
	for iid in junk:
		total += int(GameData.items[iid].price * 0.5) * int(p.inventory[iid])
	var jb := UiKit.button("Vender materiais (+%d ouro)" % total, _sell_junk, 220)
	jb.disabled = junk.is_empty()
	jb.tooltip_text = "Vende todos os materiais da bolsa que nenhuma quest ativa pede."
	foot.add_child(jb)
	foot.add_child(UiKit.para("Clique compra/vende 1 · Shift+clique compra 5 / vende a pilha", 11, UiKit.MUTED))

func _back_to_dialog() -> void:
	mode = "dialog"
	_rebuild()

func _set_shop_tab(tab: String) -> void:
	shop_tab = tab
	_rebuild()

func _shop_tab_has(it: ItemDef) -> bool:
	match shop_tab:
		"potions": return it.slot == ItemDef.Slot.NONE
		"gear": return it.slot != ItemDef.Slot.NONE
	return true

static func _sellable(it: ItemDef) -> bool:
	return it.price > 0 and it.type != ItemDef.Type.QUEST

## Materiais que dá para vender sem atrapalhar quest ativa (COLLECT/CRAFT pedem pelo id).
static func junk_of(p: SimEntity) -> Array:
	var keep := {}
	for qid in p.quests_active:
		var q: QuestDef = GameData.quests.get(qid)
		if q:
			keep[q.target_id] = true
	var out: Array = []
	for iid in p.inventory:
		var it: ItemDef = GameData.items.get(iid)
		if it and it.type == ItemDef.Type.MATERIAL and _sellable(it) and not keep.has(iid):
			out.append(iid)
	return out

func _junk(p: SimEntity) -> Array:
	return junk_of(p)

func _sell_junk() -> void:
	var p: SimEntity = Sim.player
	var got := 0
	for iid in _junk(p):
		var n := int(p.inventory[iid])
		got += int(GameData.items[iid].price * 0.5) * n
		CraftSystem.sell(p, iid, n)
	Events.notification.emit("Materiais vendidos: +%d ouro" % got)
	_rebuild()

func _on_shop_buy(ev: InputEvent, item_id: String) -> void:
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	var it: ItemDef = GameData.items[item_id]
	var n := mini(5 if Input.is_key_pressed(KEY_SHIFT) else 1, Sim.player.gold / maxi(1, it.price))
	if n <= 0:
		Events.notification.emit("Ouro insuficiente")
	elif CraftSystem.buy(Sim.player, item_id, n):
		_rebuild()

func _on_shop_sell(ev: InputEvent, item_id: String) -> void:
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	var have := int(Sim.player.inventory.get(item_id, 0))
	if CraftSystem.sell(Sim.player, item_id, have if Input.is_key_pressed(KEY_SHIFT) else 1):
		hud.windows_script.hide_tip()
		_rebuild()

func _shop_grid(parent: Control) -> GridContainer:
	var g := UiKit.grid(SHOP_COLS, 4)
	parent.add_child(g)
	return g

func _pad_grid(g: GridContainer, used: int, minimum: int) -> void:
	var want := maxi(minimum, ceili(used / float(SHOP_COLS)) * SHOP_COLS)
	for i in range(want - used):
		g.add_child(UiKit.empty_slot(SHOP_CELL))

## Célula: ícone com a moldura da raridade, quantidade em cima, preço embaixo (dourado; vermelho se não dá).
func _shop_cell(it: ItemDef, count_text: String, price_text: String, dim: bool) -> Control:
	var cell := UiKit.icon_cell(it, SHOP_CELL, Color(0.55, 0.5, 0.5, 0.85) if dim else Color.WHITE)
	if count_text != "":
		UiKit.corner_label(cell, count_text, SHOP_CELL, true)
	UiKit.corner_label(cell, price_text, SHOP_CELL, false, Color(1.0, 0.45, 0.4) if dim else UiKit.GOLD)
	return cell

## Ferreiro: aprimora o que está vestido e o equipamento da bolsa. Nunca quebra; +5 brilha leve, +9 brilha forte.
func _enhance(body: VBoxContainer) -> void:
	var p: SimEntity = Sim.player
	win.custom_minimum_size = Vector2(760, 420)
	body.add_child(UiKit.label("Ouro: %d   ·   Minério de Ferro: %d   ·   Minério Estelar: %d" % [p.gold, int(p.inventory.get("iron_ore", 0)), int(p.inventory.get("star_ore", 0))], 13, UiKit.GOLD))
	body.add_child(UiKit.para("Sem chance de quebrar. Armadura: +%d%% de DEF e MDEF por nível; arma: +%d%% de ATK e MATK; e +%d%% dos atributos da peça. +%d brilha leve, +%d brilha forte. De +%d em diante pede Minério Estelar." % [
		int(Balance.PLUS_ARMOR_PCT * 100), int(Balance.PLUS_WEAPON_PCT * 100), int(Balance.PLUS_ATTR_PCT * 100), Balance.PLUS_GLOW_LOW, Balance.PLUS_GLOW_HIGH, Balance.PLUS_STAR_FROM], 11, UiKit.MUTED))
	var list: Array = []          # [item, onde, slot (-1 = bolsa)]
	for sl in p.equipment:
		var it: ItemDef = p.equipment[sl]
		if it:
			list.append([it, "vestido", sl])
	for iid in p.inventory:
		var bit: ItemDef = GameData.items.get(iid)
		if bit and bit.is_equipment():
			var n := int(p.inventory[iid])
			list.append([bit, "bolsa" + (" x%d" % n if n > 1 else ""), -1])
	for row in list:
		var it: ItemDef = row[0]
		var cur := it.plus
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		body.add_child(h)
		var ic := UiKit.icon_cell(it, 36)
		_tip(ic, UiKit.item_tooltip(it))
		h.add_child(ic)
		var nm := UiKit.label("%s  [%s]" % [UiKit.plus_name(it, cur), row[1]], 13, UiKit.rarity_color(it.rarity) if cur < Balance.PLUS_GLOW_LOW else Color(0.6, 0.85, 1.0))
		nm.custom_minimum_size.x = 300
		h.add_child(nm)
		if cur >= Balance.PLUS_MAX:
			h.add_child(UiKit.label("máximo", 12, UiKit.GOLD))
			continue
		var c := Sim.enhance_cost(it, cur)
		h.add_child(UiKit.label("%d ouro · %d %s" % [int(c["gold"]), int(c["count"]), GameData.items[c["item"]].name], 12, UiKit.TEXT))
		var err := Sim.enhance_error(p, it.id, int(row[2]))
		var b := UiKit.button("→ +%d" % (cur + 1), _do_enhance.bind(it.id, int(row[2])), 80)
		b.disabled = err != ""
		b.tooltip_text = err
		h.add_child(b)
	body.add_child(UiKit.hsep())
	body.add_child(UiKit.button("← Voltar", func(): mode = "dialog"; _rebuild(), 100))

func _do_enhance(item_id: String, slot: int) -> void:
	if Sim.enhance(Sim.player, item_id, slot) != null:
		hud.windows_script.hide_tip()
		_rebuild()

func _craft(body: VBoxContainer) -> void:
	var p: SimEntity = Sim.player
	var station: String = npc.get("role", "smith")
	body.add_child(UiKit.label("Ouro: %d   ·   Nível: %d" % [p.gold, p.level], 13, UiKit.GOLD))
	for r in CraftSystem.recipes_for_station(station, p.class_def):     # só o que a sua classe usa
		var it: ItemDef = GameData.items.get(r.result_item)
		var can := CraftSystem.can_craft(p, r)
		var card := UiKit.panel(UiKit.BG_LIGHT, Color(0.5, 0.9, 0.5) if can else Color(0.3, 0.28, 0.35))
		body.add_child(card)
		var h := HBoxContainer.new()
		card.add_child(h)
		h.add_child(UiKit.item_icon(it, 32))
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		v.add_child(UiKit.label("%s x%d   (Lv %d%s)" % [it.name, r.result_count, r.level_req, (", %d ouro" % r.gold_cost) if r.gold_cost > 0 else ""], 13, UiKit.GOLD if can else UiKit.TEXT))
		var ing := ""
		for iid in r.ingredients:
			var ii: ItemDef = GameData.items.get(iid)
			var have := int(p.inventory.get(iid, 0))
			var need := int(r.ingredients[iid])
			ing += "[color=%s]%s %d/%d[/color]   " % ["#9f9" if have >= need else "#f88", ii.name if ii else iid, have, need]
		var rt := RichTextLabel.new()
		rt.bbcode_enabled = true
		rt.fit_content = true
		rt.text = ing
		rt.add_theme_font_size_override("normal_font_size", 11)
		rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(rt)
		var lbl := UiKit.para(it.description, 10, UiKit.MUTED)
		v.add_child(lbl)
		var b := UiKit.button("Criar", func(): CraftSystem.craft(p, r), 90)
		b.disabled = not can
		_tip(b, func(): return UiKit.item_tooltip(it))
		h.add_child(b)
	body.add_child(UiKit.hsep())
	body.add_child(UiKit.button("← Voltar", func(): mode = "dialog"; _rebuild(), 100))
