class_name RefinePanel
extends RefCounted
## Refino no ferreiro (GDD design/gdd/forja-e-refino-ui.md §3.2): abas Vestido/Bolsa, prévia antes → depois
## (GameData.plus_item, o mesmo da sim), "Até +N" pagando todos os passos (N chamadas de Sim.enhance, para no 1º erro),
## material especial em toda linha, retorno no sucesso (pisca, som enhance_ok, "A peça brilha!").
## Pergaminho de Refino (mvp-premios.md §3.3): botão "Usar Pergaminho (+5)" / Superior (+7) quando você tem o pergaminho;
## desligado com o motivo fora da faixa; segundo clique confirma (Sim.use_refine_scroll, sem ouro nem material).

const LIST_W := 420
const DETAIL_W := 520
const LIST_H := 440
const COMPACT_LIST_H := 190      # janela estreita: lista curta em cima, detalhe embaixo
const ROW_ICON := 34

var ui                                   # npc_ui
var tab := "worn"                        # worn | bag
var sel_id := ""                         # item selecionado
var sel_slot := -2                       # slot do vestido (-1 = bolsa; -2 = nada escolhido)
var target := 0                          # alvo do "Até +N" (0 = próximo passo)
var flash_id := ""                       # peça que acabou de subir (pisca no próximo desenho)
var flash_note := ""                     # "A peça brilha!" ao cruzar +5/+9
var row_buttons := {}                    # "id|slot" -> linha (testes/revisão)
var go_button: Button = null             # "Refinar" do detalhe aberto
var scroll_buttons := {}                 # id do pergaminho -> botão do detalhe aberto (testes/revisão)

func _init(owner = null) -> void:
	ui = owner

# --- funções puras (testes) ---------------------------------------------------

## Linhas da aba: [{it, slot, where}]. Vestido = ordem do boneco; Bolsa = raridade, depois nível (maiores primeiro).
static func rows(p: SimEntity, which: String) -> Array:
	var out: Array = []
	if which == "worn":
		for sl in UiKit.EQUIP_SLOTS:
			var it: ItemDef = p.equipment.get(sl)
			if it:
				out.append({"it": it, "slot": int(sl), "where": "vestido"})
		return out
	for iid in p.inventory:
		var bit: ItemDef = GameData.items.get(iid)
		if bit and bit.is_equipment():
			var n := int(p.inventory[iid])
			out.append({"it": bit, "slot": -1, "where": "bolsa x%d" % n if n > 1 else "bolsa"})
	out.sort_custom(func(a, b): return [-a["it"].rarity, -a["it"].level_req, a["it"].name] < [-b["it"].rarity, -b["it"].level_req, b["it"].name])
	return out

static func base_of(it: ItemDef) -> ItemDef:
	return GameData.items.get(it.base_id, it) if it.base_id != "" else it

## Versão +n da peça (a mesma conta da sim).
static func at_plus(it: ItemDef, n: int) -> ItemDef:
	return GameData.plus_item(base_of(it), n)

## Prévia: [[rótulo, antes, depois]] do que muda de +cur para +n (ATK/MATK/DEF/MDEF arredondados e cada atributo).
static func preview(it: ItemDef, n: int) -> Array:
	var a := at_plus(it, it.plus)
	var b := at_plus(it, n)
	var out: Array = []
	for pr in [["ATK", a.atk, b.atk], ["MATK", a.matk, b.matk], ["DEF", a.def, b.def], ["MDEF", a.mdef, b.mdef]]:
		if float(pr[1]) > 0.0 or float(pr[2]) > 0.0:
			out.append([pr[0], roundi(float(pr[1])), roundi(float(pr[2]))])
	for k in b.attributes:
		if int(b.attributes[k]) != 0 or int(a.attributes.get(k, 0)) != 0:
			out.append([str(k), int(a.attributes.get(k, 0)), int(b.attributes[k])])
	return out

static func glow_name(n: int) -> String:
	if n >= Balance.PLUS_GLOW_HIGH:
		return "forte"
	if n >= Balance.PLUS_GLOW_LOW:
		return "leve"
	return "nenhum"

## Custo de +cur até +n: {"gold", "items": {id: qtd}, "steps": [{n, gold, item, count}]} (Σ Sim.enhance_cost).
static func plan(sim: WorldSim, it: ItemDef, n: int) -> Dictionary:
	var gold := 0
	var items := {}
	var steps: Array = []
	for k in range(it.plus, mini(n, Balance.PLUS_MAX)):
		var c: Dictionary = sim.enhance_cost(at_plus(it, k), k)
		gold += int(c["gold"])
		items[c["item"]] = int(items.get(c["item"], 0)) + int(c["count"])
		steps.append({"n": k + 1, "gold": int(c["gold"]), "item": str(c["item"]), "count": int(c["count"])})
	return {"gold": gold, "items": items, "steps": steps}

## Maior alvo que o ouro e o material pagam (todos os passos), com este ferreiro; = it.plus se nem o +1 dá.
static func max_target(sim: WorldSim, p: SimEntity, it: ItemDef, slot: int, smith: String) -> int:
	if sim.enhance_error(p, it.id, slot, smith) != "":
		return it.plus
	var best := it.plus
	for n in range(it.plus + 1, Balance.PLUS_MAX + 1):
		var pl := plan(sim, it, n)
		if p.gold < int(pl["gold"]):
			break
		var ok := true
		for iid in pl["items"]:
			ok = ok and p.has_item(iid, int(pl["items"][iid]))
		if not ok:
			break
		best = n
	return best

## Sobe a peça até +n, um passo por vez (Sim.enhance); para no 1º erro. Devolve a última versão (ou null).
static func refine_to(sim: WorldSim, p: SimEntity, item_id: String, slot: int, n: int, smith: String) -> ItemDef:
	var last: ItemDef = null
	var cur_id := item_id
	var guard := 0
	while guard < Balance.PLUS_MAX:
		guard += 1
		var cur: ItemDef = GameData.items.get(cur_id)
		if cur == null or cur.plus >= n:
			break
		var nxt: ItemDef = sim.enhance(p, cur_id, slot, smith)
		if nxt == null:
			break
		last = nxt
		cur_id = nxt.id
	return last

# --- montagem ----------------------------------------------------------------

func _set_tab(t: String) -> void:
	tab = t
	sel_id = ""
	sel_slot = -2
	ui._scroll = null                     # aba nova: lista do topo
	ui._rebuild()

func select(item_id: String, slot: int) -> void:
	sel_id = item_id
	sel_slot = slot
	target = 0
	ui._rebuild()

func build(body: VBoxContainer, compact: bool) -> void:
	row_buttons.clear()
	go_button = null
	var p: SimEntity = Sim.player
	var smith: String = ui.npc_id
	var list := rows(p, tab)
	if not list.any(func(x): return x["it"].id == sel_id and x["slot"] == sel_slot):
		var first: Dictionary = {}
		for x in list:                      # a 1ª que ainda sobe
			if x["it"].plus < Balance.PLUS_MAX:
				first = x
				break
		if first.is_empty() and not list.is_empty():
			first = list[0]
		sel_id = first["it"].id if not first.is_empty() else ""
		sel_slot = int(first["slot"]) if not first.is_empty() else -2
		target = 0
	# --- topo: ouro + materiais que as linhas pedem (inclusive os especiais)
	var mats := {}
	for x in list:
		if x["it"].plus < Balance.PLUS_MAX:
			mats[str(Sim.enhance_cost(x["it"], x["it"].plus)["item"])] = true
	for iid in ["iron_ore", "star_ore"]:
		mats[iid] = true
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	body.add_child(top)
	top.add_child(UiKit.label("Ouro: %d" % p.gold, 14, UiKit.GOLD))
	var ids: Array = mats.keys()
	ids.sort()
	for iid in ids:
		var ii: ItemDef = GameData.items.get(iid)
		if ii == null:
			continue
		var m := HBoxContainer.new()
		m.add_theme_constant_override("separation", 4)
		m.mouse_filter = Control.MOUSE_FILTER_STOP
		ui._tip(m, ItemSources.tip.bind(str(iid), p.level))
		m.add_child(UiKit.item_icon(ii, 22))
		var l := UiKit.label("%s %d" % [ii.name, int(p.inventory.get(iid, 0))], 13, UiKit.TEXT)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.add_child(l)
		top.add_child(m)
	var tabs_row := HBoxContainer.new()
	tabs_row.add_theme_constant_override("separation", 6)
	body.add_child(tabs_row)
	for t in [["worn", "Vestido"], ["bag", "Bolsa"]]:
		var n := rows(p, t[0]).size()
		var b := UiKit.button(("● " if tab == t[0] else "") + "%s (%d)" % [t[1], n], _set_tab.bind(t[0]), 110)
		if tab == t[0]:
			b.add_theme_color_override("font_color", UiKit.GOLD)
		tabs_row.add_child(b)
	tabs_row.add_child(UiKit.label("   Sem chance de quebrar · +%d brilha leve · +%d brilha forte" % [Balance.PLUS_GLOW_LOW, Balance.PLUS_GLOW_HIGH], 12, UiKit.MUTED))
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
		list_box.add_child(UiKit.para("Nenhum equipamento na bolsa." if tab == "bag" else "Nada vestido.", 13, UiKit.MUTED))
	for x in list:
		list_box.add_child(_row(p, x, smith))
	var det := UiKit.panel(UiKit.BG_LIGHT, UiKit.SLOT_EDGE)
	det.custom_minimum_size = Vector2(0 if compact else DETAIL_W, 0 if compact else LIST_H)
	cols.add_child(det)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 6)
	det.add_child(dv)
	var sel: ItemDef = GameData.items.get(sel_id)
	if sel:
		_detail(dv, p, sel, sel_slot, smith)
	else:
		dv.add_child(UiKit.para("Escolha uma peça na lista.", 13, UiKit.MUTED))
	body.add_child(UiKit.hsep(4))
	var back := UiKit.button("← Voltar", ui._back_to_dialog, 100)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	body.add_child(back)

func _row(p: SimEntity, x: Dictionary, smith: String) -> Control:
	var it: ItemDef = x["it"]
	var slot: int = x["slot"]
	var is_sel: bool = it.id == sel_id and slot == sel_slot
	var card := UiKit.panel(Color(0.24, 0.2, 0.3, 1.0) if is_sel else Color(0.12, 0.11, 0.15, 0.95), UiKit.GOLD if is_sel else Color(0.22, 0.2, 0.27))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.gui_input.connect(_on_row_input.bind(it.id, slot))
	row_buttons["%s|%d" % [it.id, slot]] = card
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(h)
	h.add_child(UiKit.item_icon(it, ROW_ICON))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var nm := UiKit.label(it.name, 13, UiKit.rarity_color(it.rarity) if it.plus < Balance.PLUS_GLOW_LOW else Color(0.6, 0.85, 1.0))
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
	if it.plus >= Balance.PLUS_MAX:
		sub.text = "[color=#8a8794]%s · [/color][color=#ffd966]máximo[/color]" % x["where"]
	else:
		var c: Dictionary = Sim.enhance_cost(it, it.plus)
		var ii: ItemDef = GameData.items.get(c["item"])
		var ok_g := p.gold >= int(c["gold"])
		var ok_m := p.has_item(c["item"], int(c["count"]))
		var err := Sim.enhance_error(p, it.id, slot, smith)
		var tail := ""
		if ItemSystem.kharzun_tier(it) and not smith in Balance.PLUS_KHARZUN_SMITHS:
			tail = "  [color=#ffa060]outro ferreiro[/color]"
		elif err == "":
			tail = "  [color=#9f9]→ +%d[/color]" % (it.plus + 1)
		sub.text = "[color=#8a8794]%s · [/color][color=%s]%d ouro[/color][color=#8a8794] · [/color][color=%s]%d %s[/color]%s" % [
			x["where"], "#ffd966" if ok_g else "#f88", int(c["gold"]), "#c8c2d6" if ok_m else "#f88", int(c["count"]),
			ii.name if ii else str(c["item"]), tail]
	v.add_child(sub)
	return card

func _on_row_input(ev: InputEvent, item_id: String, slot: int) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if item_id != sel_id or slot != sel_slot:
			select(item_id, slot)

func _detail(dv: VBoxContainer, p: SimEntity, it: ItemDef, slot: int, smith: String) -> void:
	var cur := it.plus
	var mx := max_target(Sim, p, it, slot, smith)
	if target <= cur:
		target = cur + 1
	target = clampi(target, cur + 1, maxi(cur + 1, mx))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	dv.add_child(head)
	var ic := UiKit.item_icon(it, 64)
	head.add_child(ic)
	if flash_id == it.id:
		_flash(ic, cur)
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hv)
	var tl := UiKit.label(it.name + (("   →   +%d" % target) if cur < Balance.PLUS_MAX else ""), 16,
		UiKit.rarity_color(it.rarity) if cur < Balance.PLUS_GLOW_LOW else Color(0.6, 0.85, 1.0))
	tl.mouse_filter = Control.MOUSE_FILTER_STOP
	ui._tip(tl, UiKit.item_tooltip(it))
	hv.add_child(tl)
	hv.add_child(UiKit.label("%s · %s · Lv %d" % [UiKit.RARITY_NAMES[clampi(it.rarity, 0, 4)], UiKit.slot_name(it.slot), it.level_req], 12, UiKit.MUTED))
	if flash_id == it.id and flash_note != "":
		hv.add_child(UiKit.label(flash_note, 15, Color(KitModel.plus_glow_color(cur).lightened(0.35), 1.0)))
	flash_id = ""
	flash_note = ""
	if cur >= Balance.PLUS_MAX:
		dv.add_child(UiKit.label("Já está no máximo (+%d). Brilho forte." % Balance.PLUS_MAX, 14, UiKit.GOLD))
		return
	# prévia antes -> depois
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 18)
	dv.add_child(g)
	for row in preview(it, target):
		var d: int = int(row[2]) - int(row[1])
		g.add_child(UiKit.label(str(row[0]), 13, UiKit.MUTED))
		g.add_child(UiKit.label("%d" % int(row[1]), 13, UiKit.TEXT))
		g.add_child(UiKit.label("→ %d" % int(row[2]), 13, UiKit.TEXT))
		g.add_child(UiKit.label(("▲%d" % d) if d > 0 else "=", 13, Color(0.55, 1.0, 0.55) if d > 0 else UiKit.MUTED))
	g.add_child(UiKit.label("Brilho", 13, UiKit.MUTED))
	g.add_child(UiKit.label(glow_name(cur), 13, UiKit.TEXT))
	g.add_child(UiKit.label("→ " + glow_name(target), 13, UiKit.TEXT))
	g.add_child(UiKit.label("▲" if glow_name(target) != glow_name(cur) else "=", 13, Color(0.55, 1.0, 0.55) if glow_name(target) != glow_name(cur) else UiKit.MUTED))
	# custo por passo
	var pl := plan(Sim, it, target)
	dv.add_child(UiKit.hsep(2))
	for s in pl["steps"]:
		var ii: ItemDef = GameData.items.get(s["item"])
		dv.add_child(UiKit.label("Custo +%d: %d ouro · %d %s" % [int(s["n"]), int(s["gold"]), int(s["count"]), ii.name if ii else str(s["item"])], 12, UiKit.TEXT))
	# total com tem/precisa (e de onde vem)
	var tot := HBoxContainer.new()
	tot.add_theme_constant_override("separation", 12)
	dv.add_child(tot)
	var gold_ok: bool = p.gold >= int(pl["gold"])
	tot.add_child(UiKit.label("Total: %d ouro" % int(pl["gold"]), 14, UiKit.GOLD if gold_ok else Color(1.0, 0.45, 0.4)))
	for iid in pl["items"]:
		var need := int(pl["items"][iid])
		var have := int(p.inventory.get(iid, 0))
		var ii: ItemDef = GameData.items.get(iid)
		var m := HBoxContainer.new()
		m.add_theme_constant_override("separation", 4)
		m.mouse_filter = Control.MOUSE_FILTER_STOP
		ui._tip(m, ItemSources.tip.bind(str(iid), p.level))
		if ii:
			m.add_child(UiKit.item_icon(ii, 24))
		var l := UiKit.label("%s %d/%d%s" % [ii.name if ii else iid, have, need, "" if have >= need else " ⓘ"], 13,
			Color(0.6, 1.0, 0.6) if have >= need else Color(1.0, 0.45, 0.4))
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.add_child(l)
		tot.add_child(m)
	# alvo + refinar
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	dv.add_child(foot)
	foot.add_child(UiKit.label("Até:", 14, UiKit.TEXT))
	var minus := UiKit.button("−", _step_target.bind(-1), 30)
	minus.disabled = target <= cur + 1
	foot.add_child(minus)
	var tlab := UiKit.label("+%d" % target, 15, UiKit.GOLD)
	tlab.custom_minimum_size.x = 34
	tlab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_child(tlab)
	var plus := UiKit.button("+", _step_target.bind(1), 30)
	plus.disabled = target >= mx
	foot.add_child(plus)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sp)
	_scroll_row(dv, p, it, slot)
	var err := Sim.enhance_error(p, it.id, slot, smith)
	var go := UiKit.button("Refinar até +%d" % target if target > cur + 1 else "Refinar", Callable(), 150)
	go.pressed.connect(_on_go.bind(go, it.id, slot, target, int(pl["gold"])))
	go.disabled = mx < target
	go.tooltip_text = err
	go_button = go
	foot.add_child(go)
	if err != "":
		dv.add_child(UiKit.para(err, 12, Color(1.0, 0.6, 0.45)))
	elif mx < target:
		dv.add_child(UiKit.para("Ouro ou material não pagam até +%d." % target, 12, Color(1.0, 0.6, 0.45)))
	elif mx > cur + 1:
		dv.add_child(UiKit.label("O que você tem paga até +%d." % mx, 11, UiKit.MUTED))

## Pergaminhos que o jogador tem: um botão cada (desligado com o motivo quando não vale nesta peça).
func _scroll_row(dv: VBoxContainer, p: SimEntity, it: ItemDef, slot: int) -> void:
	scroll_buttons.clear()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for sc in [Balance.MVP_SCROLL, Balance.MVP_SUPER_SCROLL]:
		var have := int(p.inventory.get(sc, 0))
		if have <= 0:
			continue
		var err := Sim.refine_scroll_error(p, it.id, slot, sc)
		var b := UiKit.button("Usar %s (+%d) (tem %d)" % ["Pergaminho" if sc == Balance.MVP_SCROLL else "Superior", MvpSystem.scroll_target(sc), have], Callable(), 230)
		b.pressed.connect(_on_scroll.bind(b, it.id, slot, sc))
		b.disabled = err != ""
		b.tooltip_text = err if err != "" else "Leva a peça direto a +%d, sem ouro nem material. Clique duas vezes para confirmar." % MvpSystem.scroll_target(sc)
		scroll_buttons[sc] = b
		row.add_child(b)
		if err != "":
			row.add_child(UiKit.label(err, 11, Color(1.0, 0.6, 0.45)))
	if row.get_child_count() > 0:
		dv.add_child(row)

## Pergaminho: o 1º clique vira a confirmação, o 2º gasta.
func _on_scroll(b: Button, item_id: String, slot: int, sc: String) -> void:
	if not b.text.begins_with("Confirmar"):
		b.text = "Confirmar: gastar 1 %s?" % GameData.items[sc].name
		return
	do_scroll(item_id, slot, sc)

## Usa o pergaminho (Sim.use_refine_scroll); retorno igual ao do refino.
func do_scroll(item_id: String, slot: int, sc: String) -> ItemDef:
	var before: ItemDef = GameData.items.get(item_id)
	var b0 := before.plus if before else 0
	ui.hold_refresh = true
	var last := Sim.use_refine_scroll(Sim.player, item_id, slot, sc)
	ui.hold_refresh = false
	if last:
		sel_id = last.id
		sel_slot = slot
		target = 0
		flash_id = last.id
		if (b0 < Balance.PLUS_GLOW_LOW and last.plus >= Balance.PLUS_GLOW_LOW):
			flash_note = "A peça brilha!"
		Sfx.ui("enhance_ok")
	if ui.hud:
		ui.hud.windows_script.hide_tip()
	ui._rebuild()
	return last

func _step_target(d: int) -> void:
	target += d
	ui._rebuild()

## "Refinar": total >= REFINE_CONFIRM_GOLD pede um 2º clique (o texto vira a confirmação).
func _on_go(b: Button, item_id: String, slot: int, n: int, gold: int) -> void:
	if gold >= Balance.REFINE_CONFIRM_GOLD and not b.text.begins_with("Confirmar"):
		b.text = "Confirmar: %d ouro?" % gold
		return
	do_refine(item_id, slot, n)

## Sobe até +n pagando cada passo; retorno no sucesso (pisca, som, aviso).
func do_refine(item_id: String, slot: int, n: int) -> ItemDef:
	var before: ItemDef = GameData.items.get(item_id)
	var b0 := before.plus if before else 0
	ui.hold_refresh = true
	var last := refine_to(Sim, Sim.player, item_id, slot, n, ui.npc_id)
	ui.hold_refresh = false
	if last:
		sel_id = last.id
		sel_slot = slot
		target = 0
		flash_id = last.id
		if (b0 < Balance.PLUS_GLOW_LOW and last.plus >= Balance.PLUS_GLOW_LOW) or (b0 < Balance.PLUS_GLOW_HIGH and last.plus >= Balance.PLUS_GLOW_HIGH):
			flash_note = "A peça brilha!"
		Sfx.ui("enhance_ok")
		if last.plus < n:
			Events.notification.emit("Parou em +%d" % last.plus)
	if ui.hud:
		ui.hud.windows_script.hide_tip()
	ui._rebuild()
	return last

## Pisca o ícone no tom do brilho (força pelo AccessSettings.flash; 0 = sem clarão).
func _flash(ic: Control, n: int) -> void:
	var k := clampf(AccessSettings.flash, 0.0, 1.0)
	if k <= 0.0 or not ic.is_inside_tree():
		return
	var col := KitModel.plus_glow_color(n)
	if col.a <= 0.0:
		col = Color(1.0, 0.9, 0.6)
	var hi := Color(1.0 + 1.5 * k * col.r, 1.0 + 1.5 * k * col.g, 1.0 + 1.5 * k * col.b, 1.0)
	ic.modulate = hi
	var tw := ic.create_tween()
	tw.tween_property(ic, "modulate", hi, 0.35)
	tw.tween_property(ic, "modulate", Color.WHITE, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
