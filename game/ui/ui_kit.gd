class_name UiKit
extends RefCounted
## Helpers de UI: painéis, botões e barras com um visual consistente (escuro, bordas quentes).

const BG := Color(0.09, 0.08, 0.12, 0.92)
const BG_LIGHT := Color(0.16, 0.14, 0.2, 0.95)
const BORDER := Color(0.75, 0.62, 0.38)
const TEXT := Color(0.95, 0.93, 0.88)
const MUTED := Color(0.65, 0.62, 0.6)
const GOLD := Color(1.0, 0.85, 0.4)
const QUEST_GOLD := Color(1.0, 0.82, 0.15)
const QUEST_LOCKED := Color(0.62, 0.62, 0.66)
const QUEST_REPEAT := Color(0.35, 0.75, 1.0)        # repetível: azul
const SLOT_BG := Color(0.05, 0.045, 0.07, 0.9)     # quadrado vazio de bolsa/loja/depósito
const SLOT_EDGE := Color(0.22, 0.2, 0.27)
const DIM := Color(0.55, 0.55, 0.6)                 # item que não dá para pegar/trocar agora

## Símbolo e cor de um marcador de QuestSystem.npc_marker (mesma aparência na cabeça e no minimapa).
static func quest_mark_text(mark: String) -> String:
	return "!" if mark == QuestSystem.LOCKED else mark

static var _mark_font: Font = null

## Fonte dos marcadores: a padrão + símbolos do sistema como reserva (o "↻" não existe na fonte embutida).
static func mark_font() -> Font:
	if _mark_font == null:
		var sym := SystemFont.new()
		sym.font_names = PackedStringArray(["Segoe UI Symbol", "Noto Sans Symbols2", "Noto Sans Symbols", "DejaVu Sans", "Apple Symbols"])
		var fv := FontVariation.new()
		fv.base_font = ThemeDB.fallback_font
		fv.fallbacks = [sym]
		_mark_font = fv
	return _mark_font

## Rótulo azul "↻ Repetível" (fonte com o símbolo); vazio para quest de uma vez só.
static func repeat_label(q: QuestDef, size: int = 12) -> Label:
	var l := label(QuestSystem.repeat_tag(q), size, QUEST_REPEAT)
	l.add_theme_font_override("font", mark_font())
	return l

static func quest_mark_color(mark: String) -> Color:
	if mark == QuestSystem.REPEAT:
		return QUEST_REPEAT
	return QUEST_LOCKED if mark == QuestSystem.LOCKED else QUEST_GOLD

static func panel_style(bg: Color = BG, border: Color = BORDER, radius: int = 6, border_w: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(10)
	return s

static func panel(bg: Color = BG, border: Color = BORDER) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(bg, border))
	return p

static func label(text: String, size: int = 14, color: Color = TEXT, outline: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline:
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		l.add_theme_constant_override("outline_size", 3)
	return l

## Parágrafo com quebra de linha automática (para descrições dentro de janelas)
static func para(text: String, size: int = 12, color: Color = TEXT) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

static func title(text: String) -> Label:
	return label(text, 20, GOLD)

static func button(text: String, on_pressed: Callable = Callable(), min_w: int = 0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	var st := panel_style(BG_LIGHT, BORDER, 4, 1)
	st.set_content_margin_all(6)
	b.add_theme_stylebox_override("normal", st)
	var h := panel_style(Color(0.26, 0.22, 0.3, 1.0), GOLD, 4, 1)
	h.set_content_margin_all(6)
	b.add_theme_stylebox_override("hover", h)
	var pr := panel_style(Color(0.35, 0.28, 0.2, 1.0), GOLD, 4, 1)
	pr.set_content_margin_all(6)
	b.add_theme_stylebox_override("pressed", pr)
	var dis := panel_style(Color(0.12, 0.11, 0.14, 0.8), Color(0.3, 0.3, 0.3), 4, 1)
	dis.set_content_margin_all(6)
	b.add_theme_stylebox_override("disabled", dis)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_disabled_color", MUTED)
	b.add_theme_font_size_override("font_size", 14)
	if min_w > 0:
		b.custom_minimum_size.x = min_w
	if on_pressed.is_valid():
		b.pressed.connect(on_pressed)
	return b

static func bar(color: Color, height: int = 16) -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.custom_minimum_size.y = height
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.05, 0.08, 0.9)
	bg.set_corner_radius_all(3)
	bg.border_color = Color(0, 0, 0, 0.6)
	bg.set_border_width_all(1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	p.add_theme_stylebox_override("background", bg)
	p.add_theme_stylebox_override("fill", fill)
	return p

## Símbolo do tipo de item (sigla da bolsa e amostras do --bag_shot; a arte vem de item_texture).
const WEAPON_GLYPHS := {"sword": "sword", "sword2h": "sword", "mace": "mace", "mace2h": "hammer", "axe": "axe", "axe2h": "axe",
	"dagger": "dagger", "bow": "longbow", "staff": "staff", "wand": "wand", "scythe": "scythe", "shield": "shield", "orb": "orb", "scepter": "scepter", "rifle": "rifle"}
const SLOT_GLYPHS := {ItemDef.Slot.HEAD: "helm", ItemDef.Slot.BODY: "armor", ItemDef.Slot.LEGS: "pants", ItemDef.Slot.GLOVES: "fist",
	ItemDef.Slot.BOOTS: "boot", ItemDef.Slot.CAPE: "cape", ItemDef.Slot.AMULET: "amulet", ItemDef.Slot.RING: "ring",
	ItemDef.Slot.RING2: "ring", ItemDef.Slot.ACCESSORY: "ring"}
## material: palavra no id -> símbolo (o primeiro que bater)
const MATERIAL_GLYPHS := [["gel", "drop"], ["pelt", "hide"], ["tusk", "claw"], ["fang", "claw"], ["herb", "leaf"], ["ore", "ore"],
	["silk", "net"], ["bark", "tree"], ["badge", "star"], ["bone", "bone"], ["dust", "cloud"], ["essence", "ghost"],
	["core", "crystal"], ["scale", "scale"]]

static func item_glyph(it: ItemDef) -> String:
	if it.is_equipment():
		if it.weapon_type != "":
			return WEAPON_GLYPHS.get(it.weapon_type, "sword")
		return SLOT_GLYPHS.get(it.slot, "armor")
	if it.type == ItemDef.Type.CONSUMABLE:
		return "potion"
	if it.type == ItemDef.Type.QUEST:
		return "scroll"
	for kw in MATERIAL_GLYPHS:
		if it.id.contains(kw[0]):
			return kw[1]
	return "ore"

## Arte do item: a própria (assets/icons/<icon>.png) ou a pintada por tools/icons/item_icons.tscn (art_<id>.png).
static func item_texture(it: ItemDef) -> Texture2D:
	if it == null:
		return null
	if it.icon != "":
		var own := icon_texture(it.icon)
		if own != null:
			return own
	return icon_texture("art_" + (it.base_id if it.base_id != "" else it.id))

## Ícone do item: a arte (própria ou pintada, as duas com fundo transparente) sobre a moldura da raridade (slot_r<N>.png);
## sem arte, o quadrado da cor.
static func item_icon(it: ItemDef, size: int = 40) -> Control:
	var art := item_texture(it)
	if art == null:
		return color_square(it.icon_color, size)
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.texture = icon_texture("slot_r%d" % clampi(it.rarity, 0, 4))
	var g := TextureRect.new()
	g.texture = art
	g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	g.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	g.set_anchors_preset(Control.PRESET_FULL_RECT)
	if it.icon != "" and art != icon_texture("art_" + it.id):    # foto do conjunto vai até a borda: recua para a moldura aparecer
		var m := roundf(size * 0.1)
		g.offset_left = m; g.offset_top = m; g.offset_right = -m; g.offset_bottom = -m
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_child(g)
	return t

## Ícone gerado por tools/icons/make_icons.tscn; sem o arquivo, o quadrado de cor de sempre.
static func skill_icon(sk: SkillDef, size: int = 40) -> Control:
	return _icon_or_square("skill_" + sk.id, sk.icon_color, size)

static func class_icon(cls: ClassDef, size: int = 40) -> Control:
	return _icon_or_square("class_" + cls.id, cls.color, size)

static func icon_texture(file: String) -> Texture2D:
	var path := "res://assets/icons/%s.png" % file
	return load(path) if ResourceLoader.exists(path) else null

static func _icon_or_square(file: String, color: Color, size: int) -> Control:
	var tex := icon_texture(file)
	if tex == null:
		return color_square(color, size)
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

## Célula de item (ícone com a moldura da raridade) que recebe o mouse; `tint` apaga quando não dá.
static func icon_cell(it: ItemDef, px: int, tint: Color = Color.WHITE) -> Control:
	var cell := Control.new()
	cell.custom_minimum_size = Vector2(px, px)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	var ic := item_icon(it, px)
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.modulate = tint
	cell.add_child(ic)
	return cell

## Texto pequeno alinhado à direita num canto da célula (quantidade em cima/embaixo, preço embaixo).
static func corner_label(cell: Control, text: String, px: int, top: bool, color: Color = TEXT) -> Label:
	var c := label(text, 11, color)
	c.position = Vector2(2, 1 if top else px - 16)
	c.size = Vector2(px - 4, 14)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(c)
	return c

## Quadrado vazio (completa a grade).
static func empty_slot(px: int) -> Panel:
	var empty := Panel.new()
	empty.custom_minimum_size = Vector2(px, px)
	empty.add_theme_stylebox_override("panel", panel_style(SLOT_BG, SLOT_EDGE, 4, 1))
	return empty

## Grade de células com o mesmo espaço nas duas direções.
static func grid(cols: int, sep: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", sep)
	g.add_theme_constant_override("v_separation", sep)
	return g

## Palco 3D de prévia de personagem (ficha e criação): SubViewport com mundo próprio, luz principal + contraluz,
## fundo transparente. O SubViewport é o filho 0 do container; o boneco entra nele.
static func preview_stage(size: Vector2, cam_from: Vector3, cam_to: Vector3, glow: bool) -> SubViewportContainer:
	var cont := SubViewportContainer.new()
	cont.stretch = true
	cont.custom_minimum_size = size
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	cont.add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.85, 1.0)
	e.ambient_light_energy = 0.35
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	if glow:
		e.glow_enabled = true
		e.glow_intensity = 0.15
	e.tonemap_exposure = 0.9
	env.environment = e
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 35, 0)
	sun.light_energy = 0.75
	vp.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 200, 0)
	rim.light_energy = 0.3
	rim.light_color = Color(0.7, 0.8, 1.0)
	vp.add_child(rim)
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	cam.look_at_from_position(cam_from, cam_to, Vector3.UP)
	return cont

static func color_square(color: Color, size: int = 40) -> ColorRect:
	var c := ColorRect.new()
	c.color = color
	c.custom_minimum_size = Vector2(size, size)
	return c

static func hsep(h: int = 6) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c

static func attr_name(a: String) -> String:
	match a:
		"FOR": return "FOR (força)"
		"AGI": return "AGI (agilidade)"
		"VIT": return "VIT (vitalidade)"
		"WILL": return "WILL (vontade)"
		"INT": return "INT (inteligência)"
	return a

static func slot_name(slot: int) -> String:
	match slot:
		ItemDef.Slot.WEAPON: return "Arma"
		ItemDef.Slot.OFFHAND: return "Mão secundária"
		ItemDef.Slot.HEAD: return "Cabeça"
		ItemDef.Slot.BODY: return "Peito"
		ItemDef.Slot.LEGS: return "Calça"
		ItemDef.Slot.GLOVES: return "Luvas"
		ItemDef.Slot.BOOTS: return "Botas"
		ItemDef.Slot.CAPE: return "Capa"
		ItemDef.Slot.AMULET: return "Amuleto"
		ItemDef.Slot.RING, ItemDef.Slot.RING2: return "Anel"
	return "-"

const EQUIP_SLOTS := [ItemDef.Slot.WEAPON, ItemDef.Slot.OFFHAND, ItemDef.Slot.HEAD, ItemDef.Slot.BODY, ItemDef.Slot.LEGS,
	ItemDef.Slot.GLOVES, ItemDef.Slot.BOOTS, ItemDef.Slot.CAPE, ItemDef.Slot.AMULET, ItemDef.Slot.RING, ItemDef.Slot.RING2]
const RARITY_NAMES := ["Comum", "Incomum", "Raro", "Épico", "Lendário"]
const RARITY_COLORS := [Color(0.9, 0.9, 0.9), Color(0.5, 0.9, 0.5), Color(0.45, 0.65, 1.0), Color(0.75, 0.45, 1.0), Color(1.0, 0.6, 0.15)]

static func rarity_color(r: int) -> Color:
	return RARITY_COLORS[clampi(r, 0, RARITY_COLORS.size() - 1)]

## Texto de um bônus de conjunto (ver SetDef).
static func set_bonus_text(b: Dictionary) -> String:
	var parts: Array = []
	var attrs: Dictionary = b.get("attrs", {})
	for a in attrs:
		parts.append("%s +%d" % [a, int(attrs[a])])
	for k in [["atk_pct", "ATK"], ["matk_pct", "MATK"], ["def_pct", "DEF"], ["hp_pct", "HP"], ["heal_pct", "Cura"], ["speed_pct", "Velocidade"],
			["aspd_pct", "Velocidade de ataque"], ["lifesteal", "Roubo de vida"], ["buff_pct", "Duração das bênçãos"], ["radiance", "Radiância"], ["pet_pct", "Companheiro"], ["evasion", "Esquiva"], ["backstab", "Pelas costas"], ["fire_pct", "Dano de fogo"], ["frost_pct", "Dano de gelo"], ["storm_pct", "Dano de raio"]]:
		if b.has(k[0]):
			parts.append("%s +%d%%" % [k[1], int(b[k[0]])])
	if b.has("crit"):
		parts.append("Crítico +%d" % int(b["crit"]))
	var dmg: Dictionary = b.get("skill_dmg", {})
	for sid in dmg:
		var s: SkillDef = GameData.skills.get(sid)
		parts.append("%s +%d%% de %s" % [s.name if s else sid, int(dmg[sid]), "cura" if s and s.kind == SkillDef.Kind.HEAL else "dano"])
	var cdr: Dictionary = b.get("skill_cdr", {})
	for sid in cdr:
		var s: SkillDef = GameData.skills.get(sid)
		parts.append("%s -%d%% de recarga" % [s.name if s else sid, int(cdr[sid])])
	return ", ".join(parts)

## Bloco de conjunto para tooltips: peças (✔ equipadas) e bônus (ativos em destaque).
static func set_block(set_id: String) -> String:
	var sd: SetDef = GameData.sets.get(set_id)
	if sd == null:
		return ""
	var p: SimEntity = Sim.player
	var n: int = int(p.stats.active_sets.get(set_id, 0)) if p else 0
	var t := "\n\n[color=#ffa040][b]%s[/b] (%d/%d) · Lv %d[/color]" % [sd.name, n, sd.armor.size(), sd.level]
	for pid in sd.armor:
		var it: ItemDef = GameData.items.get(pid)
		var worn := false
		if p:
			for slot in p.equipment:
				var eq_it: ItemDef = p.equipment[slot]
				if eq_it and (eq_it.id == pid or (eq_it.id in sd.alt_pieces and it and eq_it.slot == it.slot and not pid.ends_with("_offhand"))):
					worn = true
		t += "\n[color=%s]%s %s[/color]" % ["#9f9" if worn else "#777", "✔" if worn else "·", it.name if it else pid]
	var ks := sd.bonuses.keys()
	ks.sort()
	for k in ks:
		t += "\n[color=%s](%d) %s[/color]" % ["#ffd966" if n >= int(k) else "#888", int(k), set_bonus_text(sd.bonuses[k])]
	var arms: Array = sd.pieces.filter(func(x): return not sd.armor.has(x)) + sd.alt_pieces
	if not arms.is_empty():
		t += "\n[color=#aaa]Armas do conjunto (efeito próprio, não contam nas peças):[/color]"
		for pid in arms:
			var w: ItemDef = GameData.items.get(pid)
			if w:
				t += "\n[color=#999]· %s[/color]" % w.name
	return t

static func target_name(t: int) -> String:
	match t:
		SkillDef.Target.SELF: return "em si / área ao redor"
		SkillDef.Target.DIRECTION: return "direção do cursor"
		SkillDef.Target.GROUND: return "área no cursor"
		SkillDef.Target.CONE: return "cone à frente"
		SkillDef.Target.TARGET: return "alvo sob o cursor"
	return ""

## O que um atributo faz (o mesmo texto da ficha do personagem).
const ATTR_EFFECT := {"FOR": "ataque físico e bloqueio", "AGI": "arco/adaga e crítico físico", "VIT": "HP e DEF física",
	"WILL": "cura, MP e DEF mágica", "INT": "dano e crítico mágico"}
const STYLE_WORDS := {"plate": "placa", "leather": "couro", "cloth": "pano"}

## Descrição do equipamento montada dos dados: que peça é, quem usa e o que os atributos favorecem.
static func item_summary(it: ItemDef) -> String:
	if not it.is_equipment():
		return ""
	var parts: Array = []
	var users: Array = []
	if it.weapon_type != "":
		var kind: String = GearCatalog.WEAPON_NAMES.get(it.weapon_type, it.weapon_type)
		parts.append("%s de %s" % [kind, "duas mãos" if it.is_two_handed() else ("mão secundária" if it.slot == ItemDef.Slot.OFFHAND else "uma mão")])
		for cid in GameData.classes:
			var cls: ClassDef = GameData.classes[cid]
			if it.weapon_type in cls.weapon_types or it.weapon_type in cls.offhand_types:
				users.append(cls.name)
	else:
		var st: String = STYLE_WORDS.get(it.armor_style, "")
		parts.append("%s%s" % [slot_name(it.slot), (" de " + st) if st != "" else ""])
		if st != "":
			for cid in GameData.classes:
				var cls: ClassDef = GameData.classes[cid]
				if cls.builds.any(func(b): return b.get("armor", "") == it.armor_style):
					users.append(cls.name)
	if not it.class_restriction.is_empty():
		users = []
		for c in it.class_restriction:
			users.append(GameData.classes[c].name if GameData.classes.has(c) else c)
	if not users.is_empty() and users.size() < GameData.classes.size():
		parts.append("para " + ", ".join(users))
	var attrs: Array = it.attributes.keys().filter(func(k): return int(it.attributes[k]) > 0)
	attrs.sort_custom(func(a, b): return int(it.attributes[a]) > int(it.attributes[b]))
	var fav: Array = []
	for k in attrs.slice(0, 2):
		fav.append("%s (%s)" % [k, ATTR_EFFECT.get(k, k)])
	var line: String = ", ".join(parts) + "."
	if not fav.is_empty():
		line += " Favorece " + " e ".join(fav) + "."
	return line

## Aprimoramento do item no jogador (0 se não tem).
static func plus_of(it: ItemDef) -> int:
	return it.plus if it != null else 0

## Nome do item (a versão +N já vem com o "+N" no nome).
static func plus_name(it: ItemDef, _pl: int = 0) -> String:
	return it.name

static func _plus_txt(v: float) -> String:
	return " [color=#8fd0ff](+%d)[/color]" % int(round(v)) if v >= 0.5 else ""

static func item_tooltip(it: ItemDef) -> String:
	var desc := it.description.strip_edges()
	if desc.begins_with("Conjunto inicial"):
		desc = ""
	var summary := item_summary(it)
	if summary != "":
		desc = (desc + "\n" if desc != "" else "") + "[i][color=#c8c2d6]%s[/color][/i]" % summary
	var pl := plus_of(it)
	var t := "[b][color=#%s]%s[/color][/b]\n%s" % [rarity_color(it.rarity).to_html(false), plus_name(it, pl), desc]
	if it.is_equipment():
		t += "\n[color=#%s]%s[/color] [color=#aaa]· %s" % [rarity_color(it.rarity).to_html(false), RARITY_NAMES[clampi(it.rarity, 0, 4)], slot_name(it.slot)]
		if it.weapon_type != "":
			t += " · " + GearCatalog.WEAPON_NAMES.get(it.weapon_type, it.weapon_type)
			if it.is_two_handed():
				t += " (duas mãos)"
			elif it.weapon_type in ItemDef.ONE_HANDED_MELEE:
				t += " (1 mão · Shift+clique: mão secundária)"
		t += " · Lv %d[/color]" % it.level_req
		var b: ItemDef = GameData.items.get(it.base_id, it) if it.base_id != "" else it      # números da base + (bônus do aprimoramento)
		if it.atk > 0: t += "\nATK +%d" % b.atk + _plus_txt(it.atk - b.atk)
		if it.matk > 0: t += "\nMATK +%d" % b.matk + _plus_txt(it.matk - b.matk)
		if it.def > 0: t += "\nDEF +%d" % b.def + _plus_txt(it.def - b.def)
		if it.mdef > 0: t += "\nMDEF +%d" % b.mdef + _plus_txt(it.mdef - b.mdef)
		for a in it.attributes:
			if int(it.attributes[a]) != 0:
				t += "\n[color=#ffd966]%s +%d[/color]" % [a, int(b.attributes.get(a, 0))] + _plus_txt(int(it.attributes[a]) - int(b.attributes.get(a, 0)))
	elif it.type == ItemDef.Type.CONSUMABLE:
		t += "\n[color=#aaa]Consumível · cooldown %.0fs[/color]" % it.consume_cooldown
	t += "\n[color=#888]Preço: %d ouro[/color]" % it.price
	if not it.legend_effect.is_empty():
		t += "\n[color=#ffa040]✦ Efeito lendário: %s[/color]" % legend_effect_text(it.legend_effect)
	if it.set_id != "":
		t += set_block(it.set_id)
	return t

static func legend_effect_text(le: Dictionary) -> String:
	var nm: String = str(le.get("name", ""))
	var sk: SkillDef = GameData.skills.get(str(le.get("skill", "")))
	var skn: String = sk.name if sk else ""
	var body := ""
	match str(le.get("kind", "")):
		"echo": body = "%.0f%% de chance do golpe bater de novo com %.0f%% do dano" % [float(le["chance"]), float(le["pct"])]
		"thorns": body = "devolve %.0f%% do dano corpo a corpo recebido" % float(le["pct"])
		"ward": body = "%.0f%% de cada cura vira barreira no alvo" % float(le["pct"])
		"cast_on_basic": body = "ataques e habilidades têm %.0f%% de chance de lançar %s ao acertar (no máximo 1 por segundo)" % [float(le["chance"]), skn]
		"cast_when_hit": body = "ao levar um golpe lança %s (no máximo a cada %.0f s)" % [skn, float(le["icd"])]
		"chain": body = "ataques e habilidades de alvo único saltam para +%d alvo%s com %.0f%% do dano" % [int(le["targets"]), "s" if int(le["targets"]) > 1 else "", float(le["pct"])]
		"splash": body = "tiros e habilidades de alvo único explodem: %.0f%% do dano em quem estiver a %.1f m do alvo" % [float(le["pct"]), float(le["radius"])]
		"stun": body = "%.0f%% de chance de atordoar por %.1f s (a cada %.0f s no máximo)" % [float(le["chance"]), float(le["dur"]), float(le["icd"])]
		"frenzy": body = "cada golpe dá +%.1f%% de velocidade de ataque por 4 s (até %d vezes)" % [float(le["pct"]), int(le["max"])]
		"execute": body = "+%.0f%% de dano em alvo abaixo de %.0f%% da vida" % [float(le["pct"]), float(le["below"]) * 100.0]
		"bleed": body = "%.0f%% de chance de sangrar o alvo (%.0f%% do ATK por segundo, 3 s)" % [float(le["chance"]), float(le["pct"])]
		"poison": body = "%.0f%% de chance de envenenar o alvo (%.0f%% do ATK por segundo, 3 s)" % [float(le["chance"]), float(le["pct"])]
		"mark": body = "o alvo atingido recebe +%.0f%% de dano de todos por 4 s" % float(le["pct"])
		"riposte": body = "ao esquivar, contra-ataca com %.0f%% do ATK" % float(le["pct"])
		"raise_on_kill": body = "abater levanta um esqueleto por %.0f s (a cada %.0f s no máximo)" % [float(le["time"]), float(le["icd"])]
		"heal_on_kill": body = "abater cura %.1f%% da vida" % float(le["pct"])
		"penance": body = "cada golpe marca o alvo; na %dª marca ele explode em fogo sagrado (%.0f%% do ATK a %.1f m)" % [int(le["stacks"]), float(le["pct"]), float(le["radius"])]
		"mend": body = "%.0f%% do dano de ataques e habilidades cura o aliado mais ferido por perto (você incluso)" % float(le["pct"])
	return ("%s — %s" % [nm, body]) if nm != "" else body

## Tooltip de skill: números com a maestria atual (+ próximo nível) e exigência de arma.
static func skill_tooltip(p: SimEntity, sk: SkillDef) -> String:
	var lv := p.mastery_of(sk.id)
	var t := "[b]%s[/b]  [color=#aaa]Lv %d[/color]\n%s" % [sk.name, sk.unlock_level, sk.description]
	var pw := ("Poder %.0f%% · " % (sk.power_at(lv) * 100.0)) if sk.power > 0.0 else ""      # forma/bônus: sem poder
	t += "\n[color=#aaa]Mira: %s · %sMP %.0f · CD %.1fs · Alcance %.1f[/color]" % [target_name(sk.target), pw, sk.mp_cost_at(lv), sk.cooldown_at(lv), sk.range if sk.target != SkillDef.Target.CONE else sk.radius]
	if p.knows(sk.id) and lv < Balance.MASTERY_MAX:
		var nxt := ("Poder %.0f%% · " % (sk.power_at(lv + 1) * 100.0)) if sk.power > 0.0 else ""
		t += "\n[color=#888]Maestria %d: %sMP %.0f · CD %.1fs[/color]" % [lv + 1, nxt, sk.mp_cost_at(lv + 1), sk.cooldown_at(lv + 1)]
	if sk.requires.size() > 0:
		t += "\n[color=%s]Exige: %s[/color]" % ["#9f9" if p.stats.meets(sk.requires) else "#f88", Sim.requires_text(sk.requires)]
	var bonus := float(p.stats.skill_dmg_pct.get(sk.id, 0.0))
	if bonus > 0.0:
		t += "\n[color=#ffa040]Conjunto: +%d%% de poder[/color]" % int(bonus)
	return t
