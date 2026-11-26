class_name CraftPanel
extends RefCounted
## Forja e caldeirão (GDD design/gdd/forja-e-refino-ui.md §3.1): lista à esquerda (abas por tipo, "Minha faixa",
## "Só o que posso fazer"), detalhe à direita (tooltip, comparação com o vestido, materiais com ⓘ, "Criar xN").
## Só apresentação: quem cria é CraftSystem.craft; a janela é a do npc_ui (`ui`).

const TAB_ORDER := ["amulet", "ring", "cape", "bag", "potion", "elixir", "other"]
const TAB_NAMES := {"amulet": "Amuletos", "ring": "Anéis", "cape": "Capas", "bag": "Bolsas", "potion": "Poções",
	"elixir": "Elixires", "other": "Outros"}
const LIST_W := 400
const DETAIL_W := 540
const LIST_H := 440
const COMPACT_LIST_H := 190      # janela estreita: lista curta em cima, detalhe embaixo
const ROW_ICON := 34
const MAT_ICON := 28

var ui                                  # npc_ui (janela, _rebuild, _tip, _scroll)
var tab := {}                           # estação -> aba aberta
var selected := {}                      # estação -> id da receita selecionada
var qty := 1
var prefs := {}                         # personagem -> {"band", "can_only"} (lembrados na sessão)

func _init(owner = null) -> void:
	ui = owner

# --- funções puras (testes) ---------------------------------------------------

## Aba do resultado da receita (agrupa pelo tipo/slot do item).
static func tab_of(it: ItemDef) -> String:
	if it == null:
		return "other"
	if it.consume.has("bag"):
		return "bag"
	match it.slot:
		ItemDef.Slot.AMULET: return "amulet"
		ItemDef.Slot.RING, ItemDef.Slot.RING2: return "ring"
		ItemDef.Slot.CAPE: return "cape"
	if it.type == ItemDef.Type.CONSUMABLE:
		return "elixir" if it.id.begins_with("elixir") else "potion"
	return "other"

## Abas que têm receita, na ordem fixa.
static func tabs_of(recipes: Array) -> Array:
	var have := {}
	for r in recipes:
		have[tab_of(GameData.items.get((r as RecipeDef).result_item))] = true
	return TAB_ORDER.filter(func(t): return have.has(t))

## Linhas da aba: [{r, can, above, max}] na ordem do GDD (nível maior primeiro; no nível, as que dá primeiro;
## acima do seu nível no fim). band = "Minha faixa" (nível - CRAFT_BAND_BELOW até o nível); can_only esconde as que não dá.
static func rows(p: SimEntity, recipes: Array, which: String, band: bool, can_only: bool) -> Array:
	var out: Array = []
	for r in recipes:
		var rd: RecipeDef = r
		if tab_of(GameData.items.get(rd.result_item)) != which:
			continue
		var above := rd.level_req > p.level
		if band and not above and rd.level_req < p.level - Balance.CRAFT_BAND_BELOW:
			continue
		var mx := CraftSystem.max_craftable(p, rd)
		if can_only and mx <= 0:
			continue
		out.append({"r": rd, "can": mx > 0, "above": above, "max": mx})
	out.sort_custom(_row_before)
	return out

static func _row_before(a: Dictionary, b: Dictionary) -> bool:
	if a["above"] != b["above"]:
		return not a["above"]
	if a["above"]:
		return a["r"].level_req < b["r"].level_req          # acima do nível: a mais perto primeiro
	if a["r"].level_req != b["r"].level_req:
		return a["r"].level_req > b["r"].level_req
	if a["can"] != b["can"]:
		return a["can"]
	return a["r"].id < b["r"].id

## Peça vestida para comparar (anel: o pior dos dois; null = nada no slot ou não é equipamento).
static func worn_for(p: SimEntity, it: ItemDef) -> ItemDef:
	if it == null or not it.is_equipment():
		return null
	if it.slot == ItemDef.Slot.RING or it.slot == ItemDef.Slot.RING2:
		var a: ItemDef = p.equipment.get(ItemDef.Slot.RING)
		var b: ItemDef = p.equipment.get(ItemDef.Slot.RING2)
		if a == null or b == null:
			return null                                       # vaga livre: o anel novo não substitui nada
		return a if score(a) <= score(b) else b
	return p.equipment.get(it.slot)

## Nota grosseira de uma peça (só para escolher o pior anel): números + atributos.
static func score(it: ItemDef) -> float:
	var s := it.atk + it.matk + it.def + it.mdef
	for a in it.attributes:
		s += float(it.attributes[a])
	for k in it.bonus:
		s += float(it.bonus[k])
	return s

## Diferenças novo - vestido: [[rótulo, delta]] (só o que muda).
static func compare(new_it: ItemDef, worn: ItemDef) -> Array:
	var out: Array = []
	var pairs := [["ATK", new_it.atk, worn.atk], ["MATK", new_it.matk, worn.matk], ["DEF", new_it.def, worn.def], ["MDEF", new_it.mdef, worn.mdef]]
	for pr in pairs:
		var d := roundi(float(pr[1]) - float(pr[2]))
		if d != 0:
			out.append([pr[0], d])
	var keys: Array = new_it.attributes.keys()
	for k in worn.attributes:
		if not k in keys:
			keys.append(k)
	for a in keys:
		var d := int(new_it.attributes.get(a, 0)) - int(worn.attributes.get(a, 0))
		if d != 0:
			out.append([str(a), d])
	var bks: Array = new_it.bonus.keys()
	for k in worn.bonus:
		if not k in bks:
			bks.append(k)
	for k in bks:
		var d := float(new_it.bonus.get(k, 0)) - float(worn.bonus.get(k, 0))
		if absf(d) > 0.001:
			out.append([_bonus_label(str(k)), d])
	return out

static func _bonus_label(k: String) -> String:
	if k == "hp_pct":
		return "Vida %"
	if k in UiKit.BONUS_LABELS:
		return (UiKit.BONUS_LABELS[k] as String).split(" ")[0] + " %"
	return k

## Cria até n (CraftSystem.craft, um por vez); para quando não dá mais. Devolve quantos fez.
static func craft_batch(p: SimEntity, r: RecipeDef, n: int) -> int:
	var done := 0
	while done < n and CraftSystem.max_craftable(p, r) > 0:
		if not CraftSystem.craft(p, r, false):
			break
		done += 1
	return done

## Por que não dá para criar agora ("" = dá).
static func block_reason(p: SimEntity, r: RecipeDef) -> String:
	if p.level < r.level_req:
		return "Pede nível %d" % r.level_req
	if p.gold < r.gold_cost:
		return "Ouro insuficiente (%d)" % r.gold_cost
	for iid in r.ingredients:
		if not p.has_item(iid, int(r.ingredients[iid])):
			var ii: ItemDef = GameData.items.get(iid)
			return "Faltam %d %s" % [int(r.ingredients[iid]) - int(p.inventory.get(iid, 0)), ii.name if ii else iid]
	if CraftSystem.max_craftable(p, r) <= 0:
		return "Bolsa cheia"
	return ""

# --- montagem ----------------------------------------------------------------

func _pref(key: String) -> bool:
	var who: String = Sim.player.name if Sim.player else ""
	var d: Dictionary = prefs.get(who, {"band": true, "can_only": false})
	return bool(d.get(key, false))

func _set_pref(key: String, on: bool) -> void:
	var who: String = Sim.player.name if Sim.player else ""
	var d: Dictionary = prefs.get(who, {"band": true, "can_only": false})
	d[key] = on
	prefs[who] = d
	ui._scroll = null                     # filtro novo: lista do topo
	ui._rebuild()

func station() -> String:
	return ui.npc.get("role", "smith")

func build(body: VBoxContainer, compact: bool) -> void:
	ui.craft_cards.clear()
	var p: SimEntity = Sim.player
	var st := station()
	var recipes: Array = CraftSystem.recipes_for_station(st, p.class_def)
	var tabs := tabs_of(recipes)
	var cur_tab: String = tab.get(st, "")
	if not cur_tab in tabs:
		cur_tab = tabs[0] if not tabs.is_empty() else "other"
		tab[st] = cur_tab
	var band := _pref("band")
	var can_only := _pref("can_only")
	var list := rows(p, recipes, cur_tab, band, can_only)
	var sel: String = selected.get(st, "")
	if not list.any(func(x): return x["r"].id == sel):
		sel = list[0]["r"].id if not list.is_empty() else ""
		selected[st] = sel
		qty = 1
	# --- topo: ouro, nível, filtros, abas
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	body.add_child(top)
	top.add_child(UiKit.label("Ouro: %d   ·   Nível: %d" % [p.gold, p.level], 14, UiKit.GOLD))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	top.add_child(_check_box("Só o que posso fazer", can_only, "can_only"))
	top.add_child(_check_box("Minha faixa", band, "band"))
	var tabs_row := HBoxContainer.new()
	tabs_row.add_theme_constant_override("separation", 6)
	body.add_child(tabs_row)
	for t in tabs:
		var b := UiKit.button(("● " if t == cur_tab else "") + TAB_NAMES[t], _set_tab.bind(t), 96)
		if t == cur_tab:
			b.add_theme_color_override("font_color", UiKit.GOLD)
		tabs_row.add_child(b)
	# --- colunas
	var cols: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	cols.add_theme_constant_override("separation", 10)
	body.add_child(cols)
	var list_box := VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 3)
	var frame := UiKit.panel(Color(0.06, 0.055, 0.08, 0.9), UiKit.SLOT_EDGE)
	cols.add_child(frame)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, COMPACT_LIST_H) if compact else Vector2(LIST_W, LIST_H)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(sc)
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list_box)
	if not compact:
		ui._scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED     # a rolagem é a da lista
	ui._scroll = sc
	if list.is_empty():
		var msg := "Nada na sua faixa — desligue o filtro" if band else ("Nada que dê para fazer agora" if can_only else "Nenhuma receita")
		list_box.add_child(UiKit.para(msg, 13, UiKit.MUTED))
	for x in list:
		list_box.add_child(_row(p, x, x["r"].id == sel))
	var det := UiKit.panel(UiKit.BG_LIGHT, UiKit.SLOT_EDGE)
	det.custom_minimum_size = Vector2(0 if compact else DETAIL_W, 0 if compact else LIST_H)
	cols.add_child(det)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 6)
	det.add_child(dv)
	if sel != "":
		_detail(dv, p, GameData.recipes[sel])
	else:
		dv.add_child(UiKit.para("Escolha uma receita na lista.", 13, UiKit.MUTED))
	body.add_child(UiKit.hsep(4))
	var back := UiKit.button("← Voltar", ui._back_to_dialog, 100)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	body.add_child(back)

func _check_box(text: String, on: bool, key: String) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = on
	c.focus_mode = Control.FOCUS_NONE
	c.add_theme_color_override("font_color", UiKit.TEXT)
	c.add_theme_color_override("font_pressed_color", UiKit.GOLD)
	c.add_theme_color_override("font_hover_color", UiKit.GOLD)
	c.add_theme_color_override("font_hover_pressed_color", UiKit.GOLD)
	c.add_theme_font_size_override("font_size", 13)
	c.toggled.connect(func(v: bool): _set_pref(key, v))
	return c

func _set_tab(t: String) -> void:
	tab[station()] = t
	ui._scroll = null                     # aba nova: lista do topo
	ui._rebuild()

func _row(p: SimEntity, x: Dictionary, is_sel: bool) -> Control:
	var r: RecipeDef = x["r"]
	var it: ItemDef = GameData.items.get(r.result_item)
	var above: bool = x["above"]
	var card := UiKit.panel(Color(0.24, 0.2, 0.3, 1.0) if is_sel else Color(0.12, 0.11, 0.15, 0.95), UiKit.GOLD if is_sel else Color(0.22, 0.2, 0.27))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.gui_input.connect(_on_row_input.bind(r.id))
	ui.craft_cards[r.id] = card
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(h)
	var ic := UiKit.item_icon(it, ROW_ICON)
	if above:
		ic.modulate = UiKit.DIM
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var nm := UiKit.label(it.name + (" x%d" % r.result_count if r.result_count > 1 else ""), 13,
		UiKit.DIM if above else (UiKit.rarity_color(it.rarity) if x["can"] else UiKit.TEXT))
	nm.clip_text = true
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(nm)
	var sub := RichTextLabel.new()
	sub.bbcode_enabled = true
	sub.fit_content = true
	sub.scroll_active = false
	sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.add_theme_font_size_override("normal_font_size", 11)
	var dots := ""
	var missing := 0
	for iid in r.ingredients:
		var ok := p.has_item(iid, int(r.ingredients[iid]))
		dots += "[color=%s]%s[/color]" % ["#9f9" if ok else "#776f80", "●" if ok else "○"]
		missing += 0 if ok else 1
	var state := ""
	if above:
		state = "[color=#8a8794]pede Lv %d[/color]" % r.level_req
	elif x["can"]:
		state = "[color=#9f9]pode fazer[/color]"
	elif missing > 0:
		state = "[color=#f88]falta %d[/color]" % missing
	else:
		state = "[color=#f88]%s[/color]" % block_reason(p, r)
	sub.text = "[color=#%s]Lv %d[/color]  %s  %s" % ["8a8794" if above else "c8c2d6", r.level_req, dots, state]
	v.add_child(sub)
	return card

func _on_row_input(ev: InputEvent, rid: String) -> void:
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	if (ev as InputEventMouseButton).double_click:
		select(rid)
		do_craft(1)
		return
	if selected.get(station(), "") != rid:
		select(rid)

## Seleciona a receita (mantém a rolagem da lista).
func select(rid: String) -> void:
	selected[station()] = rid
	qty = 1
	ui._rebuild()

func _detail(dv: VBoxContainer, p: SimEntity, r: RecipeDef) -> void:
	var it: ItemDef = GameData.items.get(r.result_item)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	dv.add_child(head)
	var ic := UiKit.item_icon(it, 64)
	head.add_child(ic)
	var tip := RichTextLabel.new()
	tip.bbcode_enabled = true
	tip.fit_content = true
	tip.scroll_active = false
	tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip.custom_minimum_size.x = DETAIL_W - 100          # texto que quebra precisa de largura antes da 1ª medida
	tip.add_theme_font_size_override("normal_font_size", 12)
	tip.add_theme_font_size_override("bold_font_size", 15)
	tip.add_theme_font_size_override("italics_font_size", 12)
	tip.text = UiKit.item_tooltip(it) + ("\n[color=#c8c2d6]Faz x%d[/color]" % r.result_count if r.result_count > 1 else "")
	head.add_child(tip)
	# comparação com o vestido
	if it.is_equipment():
		var worn := worn_for(p, it)
		var cmp := RichTextLabel.new()
		cmp.bbcode_enabled = true
		cmp.fit_content = true
		cmp.scroll_active = false
		cmp.add_theme_font_size_override("normal_font_size", 12)
		cmp.custom_minimum_size.x = DETAIL_W - 30
		if worn == null:
			cmp.text = "[color=#9f9]Vaga livre: nada vestido para comparar[/color]"
		else:
			var parts: Array = []
			for d in compare(it, worn):
				var v: float = float(d[1])
				var num := ("%+d" % int(v)) if is_equal_approx(v, roundf(v)) else ("%+.1f" % v)
				parts.append("[color=%s]%s %s %s[/color]" % ["#8f8" if v > 0 else "#f88", d[0], num.replace("-", "−"), "▲" if v > 0 else "▼"])
			cmp.text = "[color=#c8c2d6]vs. vestido (%s):[/color]  %s" % [worn.name, "   ".join(parts) if not parts.is_empty() else "igual"]
		dv.add_child(cmp)
	dv.add_child(UiKit.hsep(2))
	dv.add_child(UiKit.label("Materiais", 13, UiKit.GOLD))
	for iid in r.ingredients:
		dv.add_child(_mat_row(p, str(iid), int(r.ingredients[iid]) * maxi(1, qty)))
	# custo, lote, criar
	var mx := mini(CraftSystem.max_craftable(p, r), Balance.CRAFT_BATCH_MAX)
	qty = clampi(qty, 1, maxi(1, mx))
	var gold_need := r.gold_cost * qty
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	dv.add_child(foot)
	foot.add_child(UiKit.label("%d ouro" % gold_need if gold_need > 0 else "Sem custo em ouro", 14,
		UiKit.GOLD if p.gold >= gold_need else Color(1.0, 0.45, 0.4)))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sp)
	var minus := UiKit.button("−", _step_qty.bind(-1), 30)
	minus.disabled = qty <= 1
	foot.add_child(minus)
	var ql := UiKit.label("%d" % qty, 15, UiKit.TEXT)
	ql.custom_minimum_size.x = 28
	ql.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_child(ql)
	var plus := UiKit.button("+", _step_qty.bind(1), 30)
	plus.disabled = qty >= mx
	foot.add_child(plus)
	var mxb := UiKit.button("Máx", _max_qty.bind(mx), 50)
	mxb.disabled = mx <= 1 or qty >= mx
	foot.add_child(mxb)
	var go := UiKit.button("Criar x%d" % qty, do_craft.bind(-1), 110)
	var why := block_reason(p, r)
	go.disabled = why != ""
	go.tooltip_text = why
	foot.add_child(go)
	if why != "":
		dv.add_child(UiKit.label(why, 12, Color(1.0, 0.55, 0.5)))
	elif mx > 1:
		dv.add_child(UiKit.label("Dá para fazer até %d agora (duplo clique na lista = criar 1)" % mx, 11, UiKit.MUTED))

## Linha de material: ícone, nome, tem/precisa; passar o mouse = de onde vem (ⓘ no que falta).
func _mat_row(p: SimEntity, iid: String, need: int) -> Control:
	var ii: ItemDef = GameData.items.get(iid)
	var have := int(p.inventory.get(iid, 0))
	var ok := have >= need
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_STOP
	ui._tip(h, ItemSources.tip.bind(iid, p.level))
	if ii:
		h.add_child(UiKit.item_icon(ii, MAT_ICON))
	var nm := UiKit.label(ii.name if ii else iid, 13, UiKit.TEXT if ok else Color(1.0, 0.55, 0.5))
	nm.custom_minimum_size.x = 250
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(nm)
	var n := UiKit.label("%d/%d" % [have, need], 13, Color(0.6, 1.0, 0.6) if ok else Color(1.0, 0.45, 0.4))
	n.custom_minimum_size.x = 60
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(n)
	if not ok:
		var info := UiKit.label("ⓘ de onde vem", 12, Color(0.55, 0.8, 1.0))
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(info)
	mat_rows[iid] = h
	return h

var mat_rows := {}          # material -> linha no detalhe aberto (revisão: --craft_src)

func _step_qty(d: int) -> void:
	qty += d
	ui._rebuild()

func _max_qty(mx: int) -> void:
	qty = mx
	ui._rebuild()

## Cria a receita selecionada n vezes (-1 = a quantidade escolhida); um aviso só no fim.
func do_craft(n: int = -1) -> void:
	var rid: String = selected.get(station(), "")
	if rid == "" or not GameData.recipes.has(rid):
		return
	var r: RecipeDef = GameData.recipes[rid]
	var want := qty if n < 0 else n
	ui.hold_refresh = true                  # cada item ganho reconstruiria a janela: uma vez só no fim
	var done := craft_batch(Sim.player, r, want)
	ui.hold_refresh = false
	var it: ItemDef = GameData.items.get(r.result_item)
	if done > 0:
		Events.notification.emit("Criou %s x%d" % [it.name, done * r.result_count])
	if done < want:
		Events.notification.emit("Parou em %d de %d: %s" % [done, want, block_reason(Sim.player, r)])
	qty = 1
	ui._rebuild()
