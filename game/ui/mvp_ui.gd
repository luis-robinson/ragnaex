class_name MvpUi
extends Control
## Prêmios de MVP na tela (design/gdd/mvp-premios.md): cartão do resumo do prêmio (Events.mvp_award do jogador),
## escolha do Baú do MVP (1 de 3 pacotes) e o painel do Intendente das Caçadas (loja de insígnias + correio).
## Só lê a sim e chama Sim.mvp_open_chest / mvp_buy / mvp_take_mail.

const COL := Color(0.95, 0.72, 0.4)

var hud
var award_card: PanelContainer = null      # resumo do último prêmio (revisão: --mvp_shot)
var chest_card: PanelContainer = null      # escolha do baú aberta
var chest_buttons: Array = []              # botões dos 3 pacotes (testes/revisão)

func _init(owner = null) -> void:
	hud = owner
	name = "MvpUi"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	Events.mvp_award.connect(_on_award)

func _on_award(entity_id: int, s: Dictionary) -> void:
	if Sim.player and entity_id == Sim.player.id:
		show_award(s)

# --- textos (puros; testados) ---

## Linhas do resumo: insígnias, baú, pergaminhos, cosmético/repetido, carta, correio.
static func award_lines(s: Dictionary) -> Array:
	var out: Array = ["+%d Insígnias de Caçada" % int(s.get("coins", 0))]
	var chest: ItemDef = GameData.items.get(str(s.get("chest", "")))
	if chest:
		out.append(chest.name)
	if s.get("scroll", false):
		out.append(GameData.items[Balance.MVP_SCROLL].name + "!")
	if s.get("super", false):
		out.append(GameData.items[Balance.MVP_SUPER_SCROLL].name + "!")
	if str(s.get("cosmetic", "")) != "":
		out.append("Novo na coleção: %s!" % MvpSystem.cosmetic_name(str(s["cosmetic"])))
	if int(s.get("dup", 0)) > 0:
		out.append("Cosmético repetido: +%d insígnias" % int(s["dup"]))
	if str(s.get("card", "")) != "":
		out.append("%s!" % GameData.items[str(s["card"])].name)
	if not (s.get("mail", []) as Array).is_empty():
		out.append("Bolsa cheia: %d no correio do Intendente das Caçadas" % (s["mail"] as Array).size())
	return out

# --- cartão do prêmio ---

func show_award(s: Dictionary) -> void:
	if award_card and is_instance_valid(award_card):
		award_card.queue_free()
	var md: MonsterDef = GameData.monsters.get(str(s.get("boss", "")))
	award_card = _card("MVP: %s" % (md.name if md else "Chefe de Mundo"), 380)
	var v: VBoxContainer = award_card.get_child(0)
	for l in award_lines(s):
		var rare: bool = str(l).ends_with("!")
		v.add_child(UiKit.label(str(l), 14, COL if rare else UiKit.TEXT))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var cid := str(s.get("chest", ""))
	if Sim.player and Sim.player.has_item(cid):
		row.add_child(UiKit.button("Abrir o baú", func(): _close_award(); open_chest(cid), 130))
	row.add_child(UiKit.button("Fechar", _close_award, 100))

func _close_award() -> void:
	if award_card and is_instance_valid(award_card):
		award_card.queue_free()
	award_card = null

# --- Baú do MVP ---

## Abre a escolha: 3 pacotes; clicar fica com um (os outros somem).
func open_chest(item_id: String) -> void:
	var packs := MvpSystem.chest_packs(item_id)
	if packs.is_empty() or Sim.player == null:
		return
	if chest_card and is_instance_valid(chest_card):
		chest_card.queue_free()
	chest_buttons.clear()
	chest_card = _card(GameData.items[item_id].name, 560)
	var v: VBoxContainer = chest_card.get_child(0)
	v.add_child(UiKit.para("Escolha 1 pacote de material de refino. Os outros dois somem.", 12, UiKit.MUTED))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	for i in range(packs.size()):
		var pack: Dictionary = packs[i]
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(170, 0)
		col.add_theme_constant_override("separation", 4)
		row.add_child(col)
		var icons := HBoxContainer.new()
		icons.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_child(icons)
		for iid in pack["items"]:
			var ii: ItemDef = GameData.items.get(iid)
			if ii:
				var ic := UiKit.item_icon(ii, 44)
				UiKit.corner_label(ic, str(int(pack["items"][iid])), 44, false)
				icons.add_child(ic)
		if int(pack.get("gold", 0)) > 0:
			icons.add_child(UiKit.label("+%d ouro" % int(pack["gold"]), 13, UiKit.GOLD))
		var t := UiKit.para(MvpSystem.pack_text(pack), 12, UiKit.TEXT)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(t)
		var err := MvpSystem.open_chest_error(Sim.player, item_id, i)
		var b := UiKit.button("Ficar com este", _pick.bind(item_id, i), 150)
		b.disabled = err != ""
		b.tooltip_text = err
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(b)
		chest_buttons.append(b)
	var close := UiKit.button("Guardar fechado", _close_chest, 150)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(close)

func _pick(item_id: String, i: int) -> void:
	if Sim.mvp_open_chest(Sim.player, item_id, i):
		Sfx.ui("enhance_ok")
	_close_chest()

func _close_chest() -> void:
	if chest_card and is_instance_valid(chest_card):
		chest_card.queue_free()
	chest_card = null
	chest_buttons.clear()

func _card(title: String, w: float) -> PanelContainer:
	var c := UiKit.panel(Color(0.08, 0.06, 0.04, 0.96), COL)
	c.anchor_left = 0.5; c.anchor_right = 0.5; c.anchor_top = 0.38; c.anchor_bottom = 0.38
	c.offset_left = -w * 0.5; c.offset_right = w * 0.5
	c.grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	c.add_child(v)
	var t := UiKit.label(title, 18, COL)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	add_child(c)
	return c

# --- Intendente das Caçadas (npc_ui modo "hunt") ---

## Painel da loja de insígnias e do correio. `ui` = npc_ui (reconstrói depois de comprar).
static func hunt_panel(ui, body: VBoxContainer) -> void:
	var p: SimEntity = Sim.player
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	body.add_child(top)
	top.add_child(UiKit.label("Insígnias de Caçada: %d" % p.mvp_coins, 16, COL))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	var nmail := p.mvp_mail.size()
	var mb := UiKit.button("Correio: pegar %d" % nmail if nmail > 0 else "Correio vazio", func(): Sim.mvp_take_mail(p); ui._rebuild(), 170)
	mb.disabled = nmail == 0
	top.add_child(mb)
	if nmail > 0:
		var names: Array = []
		for iid in p.mvp_mail:
			names.append("%d %s" % [int(p.mvp_mail[iid]), GameData.items[iid].name])
		body.add_child(UiKit.para("No correio: " + ", ".join(names), 12, UiKit.MUTED))
	body.add_child(UiKit.hsep(2))
	for r in MvpSystem.shop_rows(p):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		body.add_child(row)
		var it: ItemDef = GameData.items.get(str(r["id"]))
		if it:
			row.add_child(UiKit.item_icon(it, 32))
		else:
			row.add_child(_cosmetic_swatch(str(r["id"])))
		var nv := VBoxContainer.new()
		nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nv)
		nv.add_child(UiKit.label(str(r["name"]), 14, UiKit.TEXT))
		var sub := ("Chefe: %s" % r["source"]) if str(r["source"]) != "" else (it.description if it else "")
		if not r["ok"]:
			sub = str(r["why"]) + ("  ·  " + sub if sub != "" else "")
		nv.add_child(UiKit.label(sub, 11, UiKit.MUTED if r["ok"] else Color(1.0, 0.6, 0.45)))
		row.add_child(UiKit.label("%d" % int(r["price"]), 15, COL))
		var b := UiKit.button("Comprar", _buy.bind(ui, str(r["id"])), 100)
		b.disabled = not r["ok"]
		b.tooltip_text = str(r["why"])
		row.add_child(b)
	var fought: Array = []
	for boss in MonstersCatalog.WORLD_BOSSES:
		if int(p.mvp_fights.get(boss, 0)) > 0:
			fought.append("%s %d" % [GameData.monsters[boss].name, int(p.mvp_fights[boss])])
	body.add_child(UiKit.hsep(2))
	body.add_child(UiKit.para(("Lutas: " + " · ".join(fought)) if not fought.is_empty() else
		"Enfrente um Chefe de Mundo para liberar as cores e armaduras dele. O tipo de montaria pede %d lutas." % Balance.MVP_MOUNT_FIGHTS, 11, UiKit.MUTED))

static func _buy(ui, id: String) -> void:
	var err := Sim.mvp_buy(Sim.player, id)
	if err != "":
		Events.notification.emit(err)
	ui._rebuild()

## Quadradinho do cosmético: cor = a própria cor; armadura/tipo = o ícone do H do tipo.
static func _cosmetic_swatch(key: String) -> Control:
	var p := key.split(":")
	if p[0] == "dye":
		return UiKit.color_square(MountLook.coat(p[1], int(p[2]), 0), 32)
	var kind: String = p[1] if p[0] == "kind" else MvpSystem.kind_of_boss(MvpSystem.boss_of_cosmetic(key))
	var tr := TextureRect.new()
	tr.texture = UiKit.icon_texture(ActionBar.mount_icon(kind))
	tr.custom_minimum_size = Vector2(32, 32)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return tr
