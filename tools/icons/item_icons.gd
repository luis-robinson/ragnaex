class_name ItemIcons
extends Node2D
## Arte dos itens: um ícone colorido por item (assets/icons/art_<id>.png, 128 px) e as molduras por raridade (slot_r<0..4>.png).
##   godot --path . tools/icons/item_icons.tscn [-- --only=<pedaço do id> --sheet=<png>]
## Tudo em laços: cada item sem `icon` próprio vira um job; a forma vem de art_key (tipo de arma, slot + estilo da armadura,
## palavra no id do material) e a cor principal é a do item (icon_color). Materiais fixos (aço, couro, madeira, ouro) nas outras partes.
## Sombreado toon de 3 tons automático: luz de cima/esquerda, faixa clara e faixa escura saem do recorte do polígono deslocado.
## Raridade: aço → aço com ouro → gema; brilho da cor da raridade em volta (lido pela silhueta) e faíscas no épico/lendário.

const SIZE := 512
const OUT := 128
const INK := Color(0.07, 0.05, 0.09)
const LIGHT := Vector2(-0.55, -0.83)        # direção da luz (para onde ela está)
const ART_SCALE := 196.0

## [claro, médio, escuro]
const PAL := {
	"iron": [Color(0.8, 0.82, 0.86), Color(0.56, 0.58, 0.64), Color(0.32, 0.33, 0.4)],
	"steel": [Color(0.97, 0.98, 1.0), Color(0.75, 0.79, 0.87), Color(0.42, 0.46, 0.58)],
	"gold": [Color(1.0, 0.95, 0.62), Color(0.96, 0.74, 0.26), Color(0.62, 0.38, 0.12)],
	"wood": [Color(0.78, 0.56, 0.34), Color(0.56, 0.36, 0.2), Color(0.34, 0.2, 0.11)],
	"darkwood": [Color(0.5, 0.36, 0.3), Color(0.34, 0.23, 0.2), Color(0.2, 0.12, 0.11)],
	"leather": [Color(0.68, 0.48, 0.32), Color(0.47, 0.31, 0.2), Color(0.27, 0.16, 0.1)],
	"dark": [Color(0.44, 0.42, 0.5), Color(0.27, 0.25, 0.32), Color(0.14, 0.12, 0.18)],
	"bone": [Color(1.0, 0.98, 0.9), Color(0.9, 0.86, 0.74), Color(0.6, 0.55, 0.45)],
	"paper": [Color(1.0, 0.98, 0.88), Color(0.93, 0.86, 0.68), Color(0.7, 0.6, 0.42)],
	"stone": [Color(0.66, 0.64, 0.68), Color(0.46, 0.44, 0.5), Color(0.27, 0.26, 0.31)],
	"cork": [Color(0.86, 0.68, 0.46), Color(0.68, 0.5, 0.32), Color(0.44, 0.3, 0.18)],
	"glass": [Color(0.95, 0.98, 1.0, 0.75), Color(0.78, 0.88, 0.95, 0.45), Color(0.5, 0.62, 0.75, 0.6)],
	"wax": [Color(1.0, 0.5, 0.45), Color(0.82, 0.16, 0.16), Color(0.5, 0.06, 0.08)],
	"green": [Color(0.66, 0.9, 0.44), Color(0.36, 0.66, 0.26), Color(0.16, 0.38, 0.14)],
}
const RARITY_GLOW := [Color(0, 0, 0, 0), Color(0.45, 0.95, 0.45), Color(0.4, 0.66, 1.0), Color(0.78, 0.45, 1.0), Color(1.0, 0.62, 0.18)]
const SLOT_ART := {ItemDef.Slot.HEAD: "head", ItemDef.Slot.BODY: "body", ItemDef.Slot.LEGS: "legs", ItemDef.Slot.GLOVES: "gloves",
	ItemDef.Slot.BOOTS: "boots", ItemDef.Slot.CAPE: "cape", ItemDef.Slot.AMULET: "amulet", ItemDef.Slot.RING: "ring",
	ItemDef.Slot.RING2: "ring", ItemDef.Slot.ACCESSORY: "ring"}
## material: palavra no id -> arte (o primeiro que bater)
const MATERIAL_ART := [["legend_coin", "legend_coin"], ["shell", "shell"], ["mushroom", "mushroom"], ["relic", "relic"], ["basket", "basket"],
	["letter", "letter"], ["report", "letter"], ["star_ore", "star"], ["goods", "basket"], ["gel", "gel"], ["pelt", "pelt"], ["hide", "pelt"], ["tusk", "tusk"], ["fang", "tusk"], ["herb", "herb"],
	["ore", "ore"], ["silk", "silk"], ["bark", "bark"], ["badge", "badge"], ["bone", "bone"], ["dust", "dust"],
	["essence", "essence"], ["core", "core"], ["scale", "scale"], ["feather", "feather"], ["steel", "ingot"], ["sap", "sap"], ["heartwood", "bark"]]
## inclinação da arte (rad): armas na diagonal, como na mão
const ANGLE := {"sword": 0.74, "sword2h": 0.74, "dagger": 0.74, "mace": 0.6, "mace2h": 0.5, "axe": 0.42, "axe2h": 0.4, "staff": 0.6,
	"wand": 0.66, "scythe": 0.2, "scepter": 0.6, "rifle": 0.76, "pistol": -0.2, "bow": -0.74, "tusk": 0.3, "bone": 0.7, "herb": 0.18}
## escala extra: armas longas na diagonal ocupam menos área que um elmo
const GROW := {"sword": 1.2, "sword2h": 1.12, "dagger": 1.25, "mace": 1.12, "mace2h": 1.06, "axe": 1.12, "axe2h": 1.06, "staff": 1.14,
	"wand": 1.22, "scythe": 1.08, "scepter": 1.18, "rifle": 1.16, "pistol": 1.3, "bow": 1.1, "bone": 1.2, "tusk": 1.05}

## Arte de um item: arma pelo tipo, armadura pelo slot e estilo, consumível/missão/material pela palavra no id.
static func art_key(it: ItemDef) -> String:
	if it.is_equipment():
		if it.weapon_type != "":
			return it.weapon_type
		var part: String = SLOT_ART.get(it.slot, "body")
		if part in ["head", "body", "legs", "gloves", "boots"]:
			var st := it.armor_style if it.armor_style in ["plate", "leather", "cloth"] else "plate"
			return part + "_" + st
		return part
	if it.type == ItemDef.Type.CONSUMABLE:
		if it.id.begins_with("bag_"):
			return "bag"
		if it.id.begins_with("elixir"):
			return "elixir"
		return "potion_m" if it.id.ends_with("_m") or it.id.ends_with("_l") else "potion_s"
	if it.type == ItemDef.Type.QUEST:
		return "letter"
	for kw in MATERIAL_ART:
		if it.id.contains(kw[0]):
			return kw[1]
	return "ore"

var _queue: Array = []
var _job: Dictionary = {}
var _vp: SubViewport
var _sil_vp: SubViewport
var _art_cv: Node2D
var _sil_cv: Node2D
var _cv: Node2D
var _sil := false
var _rot := 0.0
var _ox := 1.0
var _tint := Color.WHITE
var _r := 0
var _sheet: Array = []

func _ready() -> void:
	var only := ""
	var sheet_path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="): only = a.get_slice("=", 1)
		if a.begins_with("--sheet="): sheet_path = a.get_slice("=", 1)
	if only == "":
		for r in range(5):
			_queue.append({"file": "slot_r%d" % r, "frame": r})
	var ids: Array = GameData.items.keys()
	ids.sort()
	ids.push_front("gold")
	for iid in ids:
		if only != "" and not str(iid).contains(only):
			continue
		if iid == "gold":
			_queue.append({"file": "art_gold", "key": "gold", "tint": Color(1.0, 0.8, 0.25), "rarity": 0, "id": "gold", "glow": false})
			continue
		var it: ItemDef = GameData.items[iid]
		if it.icon != "":
			continue
		var coin := it.id == "legend_coin"
		_queue.append({"file": "art_" + it.id, "key": art_key(it), "tint": it.icon_color, "rarity": 4 if coin else it.rarity, "id": it.id, "glow": it.is_equipment() or coin})
	_vp = _make_vp()
	_sil_vp = _make_vp()
	_sil_cv = Node2D.new()
	_sil_cv.draw.connect(_paint_sil)
	_sil_vp.add_child(_sil_cv)
	_art_cv = Node2D.new()
	_art_cv.draw.connect(_paint)
	_vp.add_child(_art_cv)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/icons"))
	for job in _queue:
		_job = job
		_sil_cv.queue_redraw()
		_art_cv.queue_redraw()
		for k in range(3):
			await RenderingServer.frame_post_draw
		var img := _vp.get_texture().get_image()
		img.resize(OUT, OUT, Image.INTERPOLATE_LANCZOS)
		img.save_png("res://assets/icons/%s.png" % job["file"])
		_sheet.append(img)
	if sheet_path != "":
		_save_sheet(sheet_path)
	print("ITEM_ICONS_OK ", _queue.size())
	get_tree().quit()

func _make_vp() -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = true
	vp.msaa_2d = Viewport.MSAA_8X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	return vp

func _save_sheet(path: String) -> void:
	var cols := 12
	var cell := OUT + 8
	var rows := ceili(_sheet.size() / float(cols))
	var out := Image.create(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.1, 0.09, 0.13))
	var frame: Image = null
	for i in range(_sheet.size()):
		var im: Image = _sheet[i]
		im.convert(Image.FORMAT_RGBA8)
		var at := Vector2i(i % cols * cell + 4, i / cols * cell + 4)
		if i < 5:
			frame = im
		elif frame != null:            # na folha, a arte aparece sobre a moldura comum, como na bolsa
			out.blend_rect(_sheet[0], Rect2i(0, 0, OUT, OUT), at)
		out.blend_rect(im, Rect2i(0, 0, OUT, OUT), at)
	out.save_png(path)

# --- pintura ------------------------------------------------------------------
func _paint_sil() -> void:
	if _job.is_empty() or _job.has("frame"):
		return
	_cv = _sil_cv
	_sil = true
	_draw_art()
	_sil = false

func _paint() -> void:
	if _job.is_empty():
		return
	_cv = _art_cv
	if _job.has("frame"):
		_frame(int(_job["frame"]))
		return
	var tex := _sil_vp.get_texture()
	var r: int = _job["rarity"]
	var glow: Color = RARITY_GLOW[clampi(r, 0, 4)]
	if _job["glow"] and r > 0:                  # halo da raridade: a silhueta repetida em volta
		for ring in [[8.0, 0.16], [18.0, 0.1], [28.0, 0.06]]:
			for k in range(12):
				var o := Vector2.from_angle(TAU * k / 12.0) * float(ring[0])
				_cv.draw_texture(tex, o, Color(glow, float(ring[1]) * (0.7 + 0.15 * r)))
	_cv.draw_texture(tex, Vector2(9, 13), Color(0, 0, 0, 0.38))     # sombra no chão do quadro
	_draw_art()
	if r >= 3 and _job["glow"]:
		for p in [Vector2(96, 104), Vector2(420, 150), Vector2(392, 430), Vector2(130, 400)].slice(0, r - 1):
			_spark_px(p, 22.0 + 6.0 * (r - 3), Color(1, 1, 0.92))

func _draw_art() -> void:
	_tint = _job["tint"]
	if _tint.v < 0.3:                           # cor muito escura some no fundo: clareia
		_tint = _tint.lightened(0.3 - _tint.v)
	_r = _job["rarity"]
	var key: String = _job["key"]
	_rot = float(ANGLE.get(key, 0.0))
	_ox = 1.0
	_cv.draw_set_transform(Vector2(256, 252), _rot, Vector2.ONE * ART_SCALE * float(GROW.get(key, 1.0)))
	call("_a_" + key)
	_cv.draw_set_transform(Vector2.ZERO)

## Moldura do slot: placa escura com fundo que acende na cor da raridade, borda e cantos (épico/lendário).
func _frame(r: int) -> void:
	var rim: Color = Color(0.42, 0.38, 0.46) if r == 0 else (RARITY_GLOW[r] as Color)
	var outer := _rounded(Rect2(4, 4, 504, 504), 60.0)
	_cv.draw_colored_polygon(outer, INK)
	var inner := _rounded(Rect2(20, 20, 472, 472), 46.0)
	var cols := PackedColorArray()
	var top := Color(0.2, 0.18, 0.25).lerp(rim, 0.12 if r > 0 else 0.0)
	var bot := Color(0.08, 0.07, 0.11)
	for p in inner:
		cols.append(top.lerp(bot, clampf((p.y - 20.0) / 472.0, 0.0, 1.0)))
	_cv.draw_polygon(inner, cols)
	for i in range(8):                          # brilho de dentro, mais forte quanto mais rara
		_cv.draw_circle(Vector2(256, 270), 230.0 - i * 26.0, Color(rim, 0.018 + 0.012 * r))
	var loop := inner.duplicate()
	loop.append(inner[0])
	_cv.draw_polyline(loop, Color(rim, 0.95 if r > 0 else 0.7), 12.0 if r > 0 else 9.0, true)
	_cv.draw_arc(Vector2(256, 256), 236.0, PI * 1.12, PI * 1.88, 32, Color(1, 1, 1, 0.07), 10.0, true)    # reflexo de cima
	if r >= 3:
		for c in [Vector2(36, 36), Vector2(476, 36), Vector2(36, 476), Vector2(476, 476)]:
			var d := 30.0 if r == 3 else 38.0
			var pts := PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0)])
			var ol := pts.duplicate()
			ol.append(pts[0])
			_cv.draw_polyline(ol, INK, 14.0, true)
			_cv.draw_colored_polygon(pts, PAL["gold"][1])
			_cv.draw_colored_polygon(PackedVector2Array([pts[0], pts[1], c, pts[3]]), PAL["gold"][0])
			_cv.draw_circle(c, 8.0, rim.lightened(0.3))

func _rounded(rc: Rect2, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var corners := [rc.position + Vector2(rc.size.x - r, r), rc.end - Vector2(r, r), rc.position + Vector2(r, rc.size.y - r), rc.position + Vector2(r, r)]
	for i in range(4):
		for k in range(9):
			out.append(corners[i] + Vector2.from_angle(-PI * 0.5 + i * PI * 0.5 + k * PI / 16.0) * r)
	return out

# --- primitivas (unidade -1..1, y para baixo) -----------------------------------------
## Paleta de 3 tons: nome em PAL, "tint" (cor do item), "blade" (metal puxado para a cor do item), "trim" e "metal"
## (sobem com a raridade) ou uma Color qualquer.
func _pal(m: Variant) -> Array:
	if m is Color:
		var c: Color = m
		return [c.lightened(0.38), c, c.darkened(0.45)]
	match m:
		"tint":
			return _pal(_tint)
		"tint_dark":
			return _pal(_tint.darkened(0.32))
		"tint_light":
			return _pal(_tint.lightened(0.3))
		"blade":
			var s: Array = PAL["steel" if _r > 0 else "iron"]
			return [(s[0] as Color).lerp(_tint.lightened(0.4), 0.3), (s[1] as Color).lerp(_tint, 0.45), (s[2] as Color).lerp(_tint.darkened(0.5), 0.45)]
		"trim":
			return PAL["gold" if _r >= 2 else ("steel" if _r == 1 else "iron")]
		"metal":
			return PAL["steel" if _r >= 1 else "iron"]
		"gem":
			var g: Color = RARITY_GLOW[_r] if _r >= 2 else _tint
			return [Color(1, 1, 1), g.lightened(0.15), g.darkened(0.45)]
		"glow":
			return [Color(1, 1, 1), _tint.lightened(0.45), _tint]
	return PAL[m]

func _light_local() -> Vector2:
	return LIGHT.normalized().rotated(-_rot)

func _P(a: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var i := 0
	while i < a.size():
		out.append(Vector2(float(a[i]) * _ox, float(a[i + 1])))
		i += 2
	return out

func _shift(pts: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + d)
	return out

func _fill(pts: PackedVector2Array, col: Color) -> void:
	if pts.size() >= 3 and not Geometry2D.triangulate_polygon(pts).is_empty():
		_cv.draw_colored_polygon(pts, col)

## Polígono toon: contorno, tom médio, faixa escura do lado oposto à luz e faixa clara do lado da luz.
func _shape(pts: PackedVector2Array, m: Variant, ow: float = 0.055, depth: float = 0.15) -> void:
	var loop := pts.duplicate()
	loop.append(pts[0])
	loop.append(pts[1])
	if _sil:
		_cv.draw_polyline(loop, Color.WHITE, ow * 2.0, true)
		_fill(pts, Color.WHITE)
		return
	var pal := _pal(m)
	if ow > 0.0:
		_cv.draw_polyline(loop, INK, ow * 2.0, true)
	_fill(pts, pal[1])
	if depth <= 0.0:
		return
	var l := _light_local()
	for q in Geometry2D.clip_polygons(pts, _shift(pts, l * depth)):
		_fill(q, pal[2])
	for q in Geometry2D.clip_polygons(pts, _shift(pts, -l * depth * 0.45)):
		_fill(q, pal[0])

func _poly(a: Array, m: Variant, ow: float = 0.055, depth: float = 0.15) -> void:
	_shape(_P(a), m, ow, depth)

func _circle_pts(x: float, y: float, rx: float, ry: float, n: int = 28) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(n):
		var a := TAU * i / n
		out.append(Vector2((x + cos(a) * rx) * _ox, y + sin(a) * ry))
	return out

func _circ(x: float, y: float, r: float, m: Variant, ow: float = 0.05, depth: float = -1.0) -> void:
	_shape(_circle_pts(x, y, r, r), m, ow, r * 0.38 if depth < 0.0 else depth)

func _ell(x: float, y: float, rx: float, ry: float, m: Variant, ow: float = 0.05) -> void:
	_shape(_circle_pts(x, y, rx, ry), m, ow, minf(rx, ry) * 0.38)

## Traço com contorno e filete claro (cordas, correntes, nervuras).
func _line(a: Array, m: Variant, w: float = 0.07, ink: bool = true) -> void:
	var pts := _P(a)
	if _sil:
		_cv.draw_polyline(pts, Color.WHITE, w + 0.1, true)
		return
	var pal := _pal(m)
	if ink:
		_cv.draw_polyline(pts, INK, w + 0.1, true)
	_cv.draw_polyline(pts, pal[1], w, true)
	if w >= 0.06:
		_cv.draw_polyline(_shift(pts, _light_local() * w * 0.22), pal[0], w * 0.35, true)

## Detalhe sem contorno (riscos, costuras, veios) — não entra na silhueta.
func _mark(a: Array, col: Color, w: float = 0.035) -> void:
	if _sil:
		return
	_cv.draw_polyline(_P(a), col, w, true)

func _dot(x: float, y: float, r: float, col: Color) -> void:
	if _sil:
		return
	_cv.draw_circle(Vector2(x * _ox, y), r, col)

## Brilho especular: elipse branca translúcida (vidro, gema, metal polido).
func _shine(x: float, y: float, rx: float, ry: float, a: float = 0.75) -> void:
	if _sil:
		return
	_fill(_circle_pts(x, y, rx, ry, 16), Color(1, 1, 1, a))

func _gem(x: float, y: float, r: float) -> void:
	var pts := _P([x, y - r, x + r * 0.86, y - r * 0.2, x + r * 0.55, y + r, x - r * 0.55, y + r, x - r * 0.86, y - r * 0.2])
	_shape(pts, "gem", 0.04, r * 0.4)
	_shine(x - r * 0.25, y - r * 0.3, r * 0.22, r * 0.14, 0.9)

## Faísca de 4 pontas em pixels (fora da transformação da arte).
func _spark_px(c: Vector2, s: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(8):
		pts.append(c + Vector2.from_angle(i * PI / 4.0 - PI * 0.5) * (s if i % 2 == 0 else s * 0.22))
	_cv.draw_colored_polygon(pts, col)

func _arc(cx: float, cy: float, r: float, a0: float, a1: float, n: int = 16) -> Array:
	var out: Array = []
	for i in range(n + 1):
		var a: float = lerpf(a0, a1, float(i) / n)
		out.append(cx + cos(a) * r)
		out.append(cy + sin(a) * r)
	return out

## Faixa de couro enrolada (cabos): listras na diagonal.
func _grip(x: float, y0: float, y1: float, w: float, m: Variant = "leather") -> void:
	_poly([x - w, y0, x + w, y0, x + w, y1, x - w, y1], m, 0.045, w * 0.7)
	var pal := _pal(m)
	var y := y0 + 0.07
	while y < y1 - 0.02:
		_mark([x - w, y + 0.035, x + w, y - 0.035], pal[2], 0.03)
		y += 0.1

# --- armas ----------------------------------------------------------------------
func _guard(y: float, half: float, h: float, curl: bool) -> void:
	if curl:
		_poly([-half, y - 0.05, -half * 0.5, y, half * 0.5, y, half, y - 0.05, half + 0.06, y + h * 0.6, half * 0.5, y + h, -half * 0.5, y + h, -half - 0.06, y + h * 0.6], "trim", 0.05, 0.07)
	else:
		_poly([-half, y, half, y, half, y + h, -half, y + h], "trim", 0.05, 0.07)
	if _r >= 2:
		_gem(0, y + h * 0.5, h * 0.62)

func _a_sword() -> void:
	_poly([0, -1.05, 0.14, -0.86, 0.14, 0.38, -0.14, 0.38, -0.14, -0.86], "blade", 0.05, 0.12)
	_mark([0, -0.8, 0, 0.32], _pal("blade")[2], 0.05)
	_guard(0.36, 0.42, 0.14, _r >= 1)
	_grip(0, 0.5, 0.86, 0.075)
	_circ(0, 0.94, 0.1, "trim")

func _a_sword2h() -> void:
	_poly([0, -1.12, 0.19, -0.9, 0.17, 0.24, -0.17, 0.24, -0.19, -0.9], "blade", 0.05, 0.14)
	_mark([0, -0.86, 0, 0.18], _pal("blade")[2], 0.06)
	_poly([-0.17, 0.12, 0.17, 0.12, 0.17, 0.24, -0.17, 0.24], "tint_dark", 0.0, 0.04)       # ricasso
	_poly([-0.56, 0.18, -0.2, 0.24, 0.2, 0.24, 0.56, 0.18, 0.6, 0.36, 0.2, 0.36, -0.2, 0.36, -0.6, 0.36], "trim", 0.05, 0.07)
	if _r >= 2:
		_gem(0, 0.3, 0.1)
	_grip(0, 0.36, 0.86, 0.08)
	_poly([0, 0.86, 0.13, 0.95, 0, 1.08, -0.13, 0.95], "trim", 0.05, 0.06)

func _a_dagger() -> void:
	_poly([0, -0.92, 0.2, -0.5, 0.15, 0.22, -0.15, 0.22, -0.2, -0.5], "blade", 0.05, 0.12)
	_mark([0, -0.7, 0, 0.16], _pal("blade")[2], 0.045)
	_poly([-0.36, 0.14, 0, 0.22, 0.36, 0.14, 0.4, 0.3, 0, 0.36, -0.4, 0.3], "trim", 0.05, 0.06)
	_grip(0, 0.36, 0.72, 0.075, "tint_dark")
	_circ(0, 0.8, 0.1, "trim")
	if _r >= 2:
		_gem(0, 0.26, 0.08)

func _a_axe() -> void:
	_grip(0, -0.82, 1.02, 0.07, "wood")
	_poly([0.04, -0.78, 0.46, -0.96, 0.78, -0.52, 0.74, 0.0, 0.46, -0.14, 0.04, -0.26], "blade", 0.055, 0.14)
	_mark([0.7, -0.6, 0.66, -0.06], _pal("blade")[0], 0.05)
	_poly([-0.06, -0.72, -0.24, -0.62, -0.22, -0.4, -0.06, -0.32], "metal", 0.05, 0.06)
	_poly([-0.1, -0.86, 0.1, -0.86, 0.1, -0.2, -0.1, -0.2], "trim", 0.05, 0.06)
	_grip(0, 0.5, 0.92, 0.085, "tint_dark")
	if _r >= 2:
		_gem(0.0, -0.53, 0.08)

func _a_axe2h() -> void:
	_grip(0, -0.92, 1.05, 0.075, "wood")
	for s in [1.0, -1.0]:
		_ox = s
		_poly([0.08, -0.78, 0.5, -0.98, 0.84, -0.48, 0.8, 0.06, 0.48, -0.08, 0.08, -0.22], "blade", 0.055, 0.14)
		_mark([0.76, -0.56, 0.72, -0.02], _pal("blade")[0], 0.05)
	_ox = 1.0
	_poly([-0.12, -0.9, 0.12, -0.9, 0.12, -0.14, -0.12, -0.14], "trim", 0.05, 0.07)
	if _r >= 1:
		_poly([0, -1.18, 0.08, -0.9, -0.08, -0.9], "metal", 0.04, 0.04)
	if _r >= 2:
		_gem(0, -0.52, 0.09)
	_grip(0, 0.46, 0.96, 0.09, "leather")

func _a_mace() -> void:
	_grip(0, -0.3, 0.95, 0.07, "wood")
	_grip(0, 0.45, 0.92, 0.08, "leather")
	var a: Array = []
	for i in range(16):
		var rr := 0.56 if i % 2 == 0 else 0.34
		a.append(cos(i * TAU / 16.0 - PI * 0.5) * rr)
		a.append(-0.5 + sin(i * TAU / 16.0 - PI * 0.5) * rr)
	_poly(a, "blade", 0.05, 0.14)
	_circ(0, -0.5, 0.25, "trim")
	if _r >= 2:
		_gem(0, -0.5, 0.12)
	_poly([0, -1.12, 0.07, -0.98, -0.07, -0.98], "metal", 0.04, 0.03)

func _a_mace2h() -> void:
	_grip(0, -0.45, 1.05, 0.075, "wood")
	_grip(0, 0.5, 1.0, 0.085, "leather")
	_poly([-0.68, -0.92, 0.68, -0.92, 0.76, -0.82, 0.76, -0.3, 0.68, -0.2, -0.68, -0.2, -0.76, -0.3, -0.76, -0.82], "blade", 0.055, 0.16)
	_poly([-0.18, -0.96, 0.18, -0.96, 0.18, -0.16, -0.18, -0.16], "trim", 0.05, 0.07)
	for x in [-0.5, 0.5]:
		_mark([x, -0.82, x, -0.3], _pal("blade")[2], 0.04)
	if _r >= 1:
		_poly([0, -1.24, 0.1, -0.96, -0.1, -0.96], "metal", 0.04, 0.04)
	if _r >= 2:
		_gem(0, -0.56, 0.11)

func _a_staff() -> void:
	var shaft: Array = [0.0, 1.08]
	for i in range(1, 9):
		var t := i / 8.0
		shaft.append(sin(t * 7.0) * 0.035); shaft.append(lerpf(1.08, -0.45, t))
	_line(shaft, "tint", 0.12)
	_line(_arc(0, -0.72, 0.3, PI * 0.5, PI * 2.25, 18), "tint_dark", 0.09)
	var orb := _pal("glow")
	if not _sil:
		for i in range(4):
			_cv.draw_circle(Vector2(0, -0.72), 0.42 - i * 0.07, Color(orb[1], 0.12))
	_circ(0, -0.72, 0.2, "gem" if _r >= 2 else "glow", 0.04)
	_shine(-0.07, -0.8, 0.07, 0.045)
	if _r >= 1:
		_grip(0, 0.15, 0.45, 0.075, "trim")

func _a_wand() -> void:
	_poly([-0.05, -0.32, 0.05, -0.32, 0.07, 0.98, -0.07, 0.98], "darkwood", 0.045, 0.05)
	_grip(0, 0.5, 0.9, 0.08, "tint_dark")
	_poly([-0.1, -0.36, 0.1, -0.36, 0.08, -0.24, -0.08, -0.24], "trim", 0.04, 0.03)
	var a: Array = []
	for i in range(10):
		var rr := 0.4 if i % 2 == 0 else 0.17
		a.append(cos(i * TAU / 10.0 - PI * 0.5) * rr)
		a.append(-0.64 + sin(i * TAU / 10.0 - PI * 0.5) * rr)
	if not _sil:
		for i in range(4):
			_cv.draw_circle(Vector2(0, -0.64), 0.5 - i * 0.09, Color(_tint.lightened(0.4), 0.1))
	_poly(a, "glow", 0.045, 0.08)
	if _r >= 2:
		_gem(0, -0.64, 0.09)

func _a_scythe() -> void:
	_line([-0.18, 1.06, -0.1, 0.2, -0.24, -0.92], "darkwood", 0.12)
	_grip(-0.14, 0.42, 0.78, 0.08, "tint_dark")
	var outer: Array = []
	var inner: Array = []
	for k in range(15):
		var t := k / 14.0
		outer.append(lerpf(-0.26, 0.92, t)); outer.append(-0.92 - sin(t * PI) * 0.22 + t * 0.66)
	for k in range(15):
		var t := 1.0 - k / 14.0
		inner.append(lerpf(-0.2, 0.92, t)); inner.append(-0.56 - sin(t * PI) * 0.12 + t * 0.3)
	_poly(outer + inner, "blade", 0.05, 0.12)
	_poly([-0.36, -1.0, -0.1, -1.0, -0.1, -0.74, -0.36, -0.74], "trim", 0.05, 0.05)
	if _r >= 2:
		_gem(-0.23, -0.87, 0.08)

func _a_shield() -> void:
	var rim := [0, -0.98, 0.8, -0.74, 0.8, 0.06, 0.44, 0.66, 0, 1.0, -0.44, 0.66, -0.8, 0.06, -0.8, -0.74]
	_poly(rim, "trim", 0.06, 0.1)
	_poly([0, -0.84, 0.66, -0.64, 0.66, 0.02, 0.36, 0.56, 0, 0.84, -0.36, 0.56, -0.66, 0.02, -0.66, -0.64], "tint", 0.035, 0.16)
	if _r == 0:                                  # tábuas
		for x in [-0.3, 0.0, 0.3]:
			_mark([x, -0.74, x, 0.66 - absf(x) * 0.5], _pal("tint")[2], 0.035)
	else:
		_poly([-0.09, -0.62, 0.09, -0.62, 0.09, -0.2, 0.42, -0.2, 0.42, -0.04, 0.09, -0.04, 0.09, 0.58, -0.09, 0.58, -0.09, -0.04, -0.42, -0.04, -0.42, -0.2, -0.09, -0.2], "trim", 0.04, 0.05)
	_circ(0, -0.12, 0.15 if _r < 2 else 0.12, "metal")
	if _r >= 2:
		_gem(0, -0.12, 0.09)
	for p in [[-0.6, -0.6], [0.6, -0.6], [-0.56, 0.02], [0.56, 0.02]]:
		_dot(p[0], p[1], 0.04, _pal("trim")[0])

func _a_orb() -> void:
	_poly([-0.44, 0.62, 0.44, 0.62, 0.3, 1.0, -0.3, 1.0], "trim", 0.05, 0.08)
	for s in [-1.0, 1.0]:
		_line([s * 0.3, 0.66, s * 0.62, 0.2, s * 0.5, -0.3], "trim", 0.09)
	if not _sil:
		for i in range(5):
			_cv.draw_circle(Vector2(0, -0.08), 0.86 - i * 0.08, Color(_tint.lightened(0.3), 0.07))
	_circ(0, -0.08, 0.6, "glow", 0.05, 0.22)
	_mark(_arc(0, -0.08, 0.36, 0.4, 2.6, 14), Color(1, 1, 1, 0.55), 0.06)
	_shine(-0.22, -0.32, 0.17, 0.11, 0.85)
	if _r >= 2:
		_gem(0, 0.62, 0.1)

func _a_scepter() -> void:
	_poly([-0.06, -0.38, 0.06, -0.38, 0.06, 1.05, -0.06, 1.05], "trim", 0.045, 0.05)
	for y in [0.2, 0.6]:
		_poly([-0.11, y - 0.05, 0.11, y - 0.05, 0.11, y + 0.05, -0.11, y + 0.05], "tint_dark", 0.035, 0.03)
	_circ(0, 1.06, 0.08, "trim")
	for s in [-1.0, 1.0]:
		_line([s * 0.05, -0.38, s * 0.36, -0.6, s * 0.3, -0.92], "trim", 0.075)
	_circ(0, -0.68, 0.22, "tint", 0.045)
	_shine(-0.07, -0.76, 0.07, 0.05)
	_poly([-0.04, -1.12, 0.04, -1.12, 0.04, -0.86, -0.04, -0.86], "trim", 0.03, 0.02)
	_poly([-0.13, -1.04, 0.13, -1.04, 0.13, -0.96, -0.13, -0.96], "trim", 0.03, 0.02)
	if _r >= 2:
		_gem(0, -0.38, 0.08)

func _a_rifle() -> void:
	_poly([-0.17, 0.52, 0.13, 0.4, 0.19, 1.04, -0.13, 1.08], "wood", 0.05, 0.1)
	_poly([-0.13, -0.24, 0.11, -0.24, 0.11, 0.52, -0.13, 0.52], "wood", 0.05, 0.08)
	_poly([-0.07, -1.08, 0.06, -1.08, 0.06, 0.46, -0.07, 0.46], "blade", 0.045, 0.05)
	for y in [-0.7, -0.16, 0.3]:
		_poly([-0.14, y - 0.04, 0.12, y - 0.04, 0.12, y + 0.04, -0.14, y + 0.04], "trim", 0.035, 0.03)
	_line([0.11, 0.3, 0.24, 0.38, 0.15, 0.5], "metal", 0.05)
	_poly([-0.13, 0.62, 0.15, 0.56, 0.16, 0.7, -0.13, 0.76], "tint", 0.03, 0.03)

## Pistola de pederneira de perfil (Corsário): cano para a direita, coronha curva, cão, gatilho e boca dourada.
func _a_pistol() -> void:
	_poly([-0.86, 0.86, -0.5, 0.98, -0.16, 0.3, 0.02, 0.12, 0.0, -0.16, -0.36, -0.2, -0.62, 0.14], "wood", 0.055, 0.12)
	_circ(-0.72, 0.88, 0.14, "trim")
	_poly([-0.4, -0.36, 0.94, -0.36, 0.94, -0.1, -0.4, -0.1], "blade", 0.05, 0.08)
	_poly([0.84, -0.44, 1.0, -0.44, 1.0, -0.02, 0.84, -0.02], "trim", 0.045, 0.04)
	_poly([-0.3, -0.08, 0.6, -0.08, 0.54, 0.1, -0.22, 0.12], "tint", 0.045, 0.05)
	for x in [0.1, 0.42]:
		_poly([x, -0.4, x + 0.06, -0.4, x + 0.06, -0.06, x, -0.06], "trim", 0.03, 0.02)
	_poly([-0.4, -0.36, -0.46, -0.66, -0.3, -0.7, -0.24, -0.38], "metal", 0.045, 0.04)
	_line([-0.18, 0.12, -0.12, 0.34, 0.06, 0.34, 0.12, 0.14], "metal", 0.05)
	if _r >= 2:
		_gem(-0.22, -0.24, 0.07)

func _a_bow() -> void:
	var limb := _arc(-0.66, 0.0, 1.05, -0.96, 0.96, 22)
	_line([limb[0], limb[1], limb[limb.size() - 2], limb[limb.size() - 1]], Color(0.95, 0.92, 0.85), 0.03)
	_line(limb, "tint", 0.16)
	if not _sil:
		_cv.draw_polyline(_P(limb), _pal("tint")[0], 0.04, true)
	_grip(0.39, -0.2, 0.2, 0.085, "leather")
	for e in [[limb[0], limb[1]], [limb[limb.size() - 2], limb[limb.size() - 1]]]:
		_circ(e[0], e[1], 0.07, "trim")
	if _r >= 2:
		_gem(0.39, 0.0, 0.08)

# --- armaduras (placa usa o metal puxado para a cor; couro e pano usam a cor direto) ---
func _a_head_plate() -> void:
	if _r >= 1:                                   # pluma da cor do item
		var plume: Array = []
		for k in range(9):
			var t := k / 8.0
			plume.append(lerpf(-0.05, 0.62, t)); plume.append(-0.82 - sin(t * PI) * 0.28 + t * 0.34)
		for k in range(9):
			var t := 1.0 - k / 8.0
			plume.append(lerpf(0.05, 0.56, t)); plume.append(-0.7 - sin(t * PI) * 0.1 + t * 0.5)
		_poly(plume, "tint_light" if _r < 2 else "wax", 0.045, 0.08)
	_poly([-0.72, 0.72, -0.76, -0.1, -0.56, -0.62, 0, -0.86, 0.56, -0.62, 0.76, -0.1, 0.72, 0.72, 0.3, 0.86, -0.3, 0.86], "blade", 0.06, 0.2)
	_poly([-0.62, -0.06, 0.62, -0.06, 0.6, 0.08, -0.6, 0.08], INK, 0.0, 0.0)       # fenda
	_poly([-0.07, -0.84, 0.07, -0.84, 0.07, 0.84, -0.07, 0.84], "trim", 0.035, 0.03)
	for y in [0.3, 0.46, 0.62]:
		for x in [-0.32, 0.32]:
			_dot(x, y, 0.035, INK)
	if _r >= 2:
		_gem(0, -0.46, 0.1)

func _a_head_leather() -> void:
	_poly([-0.82, 0.86, -0.78, 0.0, -0.56, -0.6, 0, -0.9, 0.56, -0.6, 0.78, 0.0, 0.82, 0.86, 0.4, 0.66, 0.36, 0.06, -0.36, 0.06, -0.4, 0.66], "tint", 0.06, 0.2)
	_poly([-0.36, 0.06, 0.36, 0.06, 0.4, 0.66, -0.4, 0.66], "dark", 0.0, 0.0)     # rosto na sombra
	_dot(-0.16, 0.3, 0.05, Color(1, 0.9, 0.6)); _dot(0.16, 0.3, 0.05, Color(1, 0.9, 0.6))
	_mark([0, -0.88, 0, -0.1], _pal("tint")[2], 0.04)
	_mark(_arc(0, 0.36, 0.5, PI + 0.25, TAU - 0.25, 12), _pal("tint")[0], 0.04)
	if _r >= 1:
		_poly([-0.84, 0.62, -0.42, 0.56, -0.42, 0.78, -0.84, 0.88], "trim", 0.035, 0.03)
		_poly([0.84, 0.62, 0.42, 0.56, 0.42, 0.78, 0.84, 0.88], "trim", 0.035, 0.03)
	if _r >= 2:
		_gem(0, 0.66, 0.09)

func _a_head_cloth() -> void:
	_poly([-0.9, 0.62, -0.5, 0.42, 0.5, 0.42, 0.9, 0.62, 0.5, 0.82, -0.5, 0.82], "tint_dark", 0.05, 0.1)       # aba
	var cone: Array = [-0.5, 0.5, -0.36, 0.0, -0.12, -0.5, 0.22, -0.92, 0.62, -0.98, 0.4, -0.76, 0.24, -0.4, 0.36, 0.0, 0.5, 0.5]
	_poly(cone, "tint", 0.055, 0.16)
	_poly([-0.46, 0.3, 0.46, 0.3, 0.5, 0.5, -0.5, 0.5], "trim", 0.04, 0.04)
	if _r >= 1:
		var a: Array = []
		for i in range(10):
			var rr := 0.17 if i % 2 == 0 else 0.07
			a.append(-0.05 + cos(i * TAU / 10.0 - PI * 0.5) * rr); a.append(-0.1 + sin(i * TAU / 10.0 - PI * 0.5) * rr)
		_poly(a, "gold", 0.03, 0.03)
	if _r >= 2:
		_gem(0, 0.4, 0.08)

func _a_body_plate() -> void:
	_poly([-0.56, -0.66, -0.2, -0.72, 0, -0.52, 0.2, -0.72, 0.56, -0.66, 0.52, 0.56, 0.3, 0.86, -0.3, 0.86, -0.52, 0.56], "blade", 0.06, 0.2)
	_mark([0, -0.5, 0, 0.84], _pal("blade")[2], 0.04)
	_mark(_arc(0, -0.1, 0.42, 0.3, PI - 0.3, 12), _pal("blade")[0], 0.04)
	for s in [-1.0, 1.0]:                       # ombreiras
		_ox = s
		_poly([0.42, -0.84, 0.84, -0.7, 0.96, -0.28, 0.66, -0.16, 0.46, -0.46], "blade", 0.05, 0.12)
		_poly([0.5, -0.62, 0.9, -0.48, 0.94, -0.3, 0.66, -0.2], "trim", 0.0, 0.04)
	_ox = 1.0
	_poly([-0.5, 0.42, 0.5, 0.42, 0.5, 0.56, -0.5, 0.56], "leather", 0.04, 0.04)
	_poly([-0.09, 0.4, 0.09, 0.4, 0.09, 0.58, -0.09, 0.58], "trim", 0.03, 0.03)
	if _r >= 2:
		_gem(0, -0.12, 0.12)

func _a_body_leather() -> void:
	_poly([-0.5, -0.72, -0.18, -0.8, 0, -0.52, 0.18, -0.8, 0.5, -0.72, 0.9, -0.42, 0.68, -0.08, 0.52, -0.2, 0.54, 0.88, -0.54, 0.88, -0.52, -0.2, -0.68, -0.08, -0.9, -0.42], "tint", 0.06, 0.2)
	for y in [-0.36, -0.14, 0.08]:              # cadarços
		_mark([-0.1, y, 0.1, y + 0.1], Color(0.95, 0.88, 0.7), 0.04)
		_mark([0.1, y, -0.1, y + 0.1], Color(0.95, 0.88, 0.7), 0.04)
	_mark([-0.42, -0.6, -0.44, 0.8], _pal("tint")[2], 0.03)
	_mark([0.42, -0.6, 0.44, 0.8], _pal("tint")[2], 0.03)
	_poly([-0.54, 0.38, 0.54, 0.38, 0.54, 0.54, -0.54, 0.54], "leather", 0.04, 0.04)
	_poly([-0.11, 0.35, 0.11, 0.35, 0.11, 0.57, -0.11, 0.57], "trim", 0.035, 0.03)
	if _r >= 1:
		for s in [-1.0, 1.0]:
			_ox = s
			_poly([0.5, -0.74, 0.88, -0.44, 0.76, -0.3, 0.44, -0.56], "trim", 0.035, 0.04)
		_ox = 1.0
	if _r >= 2:
		_gem(0, 0.46, 0.08)

func _a_body_cloth() -> void:
	_poly([-0.36, -0.84, 0.36, -0.84, 0.62, -0.56, 0.96, 0.2, 0.7, 0.3, 0.52, -0.06, 0.66, 0.96, -0.66, 0.96, -0.52, -0.06, -0.7, 0.3, -0.96, 0.2, -0.62, -0.56], "tint", 0.06, 0.2)
	_poly([-0.36, -0.84, 0, -0.42, 0.36, -0.84, 0.2, -0.88, 0, -0.62, -0.2, -0.88], "tint_dark", 0.035, 0.04)    # gola
	_poly([-0.07, -0.42, 0.07, -0.42, 0.07, 0.96, -0.07, 0.96], "trim", 0.03, 0.03)
	_poly([-0.56, 0.12, 0.56, 0.12, 0.56, 0.26, -0.56, 0.26], "tint_light", 0.035, 0.04)    # faixa
	if _r >= 1:
		_mark([-0.64, 0.84, 0.64, 0.84], _pal("trim")[1], 0.06)
	if _r >= 2:
		_gem(0, 0.19, 0.09)

func _a_legs_plate() -> void:
	_poly([-0.6, -0.86, 0.6, -0.86, 0.66, -0.6, -0.66, -0.6], "leather", 0.05, 0.05)
	for s in [-1.0, 1.0]:
		_ox = s
		_poly([0.06, -0.62, 0.62, -0.62, 0.6, 0.94, 0.12, 0.94], "blade", 0.055, 0.14)
		_poly([0.12, 0.0, 0.58, 0.0, 0.62, 0.22, 0.34, 0.32, 0.08, 0.22], "trim", 0.04, 0.06)    # joelheira
		_mark([0.14, -0.3, 0.56, -0.3], _pal("blade")[2], 0.035)
		_mark([0.16, 0.56, 0.58, 0.56], _pal("blade")[2], 0.035)
	_ox = 1.0
	if _r >= 2:
		_gem(0, -0.73, 0.08)

func _a_legs_leather() -> void:
	_poly([-0.62, -0.86, 0.62, -0.86, 0.72, 0.96, 0.16, 0.96, 0, -0.14, -0.16, 0.96, -0.72, 0.96], "tint", 0.06, 0.18)
	_poly([-0.64, -0.92, 0.64, -0.92, 0.64, -0.66, -0.64, -0.66], "leather", 0.045, 0.05)
	_poly([-0.1, -0.92, 0.1, -0.92, 0.1, -0.66, -0.1, -0.66], "trim", 0.03, 0.03)
	for s in [-1.0, 1.0]:
		_ox = s
		_poly([0.2, 0.12, 0.6, 0.12, 0.62, 0.38, 0.24, 0.38], "tint_dark", 0.035, 0.05)
		_mark([0.4, -0.6, 0.44, 0.9], _pal("tint")[2], 0.03)
	_ox = 1.0
	if _r >= 2:
		_gem(0, -0.79, 0.08)

func _a_legs_cloth() -> void:
	_poly([-0.56, -0.84, 0.56, -0.84, 0.86, 0.9, 0.3, 0.8, 0, 0.96, -0.3, 0.8, -0.86, 0.9], "tint", 0.06, 0.18)
	_poly([-0.6, -0.92, 0.6, -0.92, 0.6, -0.66, -0.6, -0.66], "tint_dark", 0.045, 0.05)
	for x in [-0.36, 0.0, 0.36]:
		_mark([x * 0.7, -0.6, x * 1.5, 0.84], _pal("tint")[2], 0.035)
	if _r >= 1:
		_mark([-0.84, 0.82, -0.3, 0.72, 0, 0.88, 0.3, 0.72, 0.84, 0.82], _pal("trim")[1], 0.06)
	if _r >= 2:
		_gem(0, -0.79, 0.08)

func _a_gloves_plate() -> void:
	_poly([-0.5, 0.36, 0.5, 0.36, 0.56, 0.98, -0.56, 0.98], "trim", 0.05, 0.08)          # punho
	_poly([-0.62, 0.42, -0.66, -0.3, -0.42, -0.64, 0.42, -0.64, 0.64, -0.3, 0.6, 0.42], "blade", 0.06, 0.16)
	for i in range(4):                          # dedos em placas
		var x := -0.42 + i * 0.28
		_poly([x - 0.12, -0.6, x + 0.12, -0.6, x + 0.1, -0.98, x - 0.1, -0.98], "blade", 0.04, 0.07)
		_mark([x - 0.1, -0.8, x + 0.1, -0.8], _pal("blade")[2], 0.03)
	_poly([0.6, -0.1, 0.92, -0.32, 0.98, -0.14, 0.66, 0.16], "blade", 0.045, 0.06)
	_mark([-0.56, 0.0, 0.56, 0.0], _pal("blade")[2], 0.04)
	if _r >= 2:
		_gem(0, 0.66, 0.09)

func _a_gloves_leather() -> void:
	_poly([-0.46, 0.4, 0.46, 0.4, 0.6, 0.98, -0.6, 0.98], "tint_dark", 0.05, 0.08)
	_poly([-0.56, 0.46, -0.6, -0.3, -0.42, -0.6, 0.42, -0.6, 0.6, -0.3, 0.56, 0.46], "tint", 0.06, 0.16)
	for i in range(4):
		var x := -0.42 + i * 0.28
		_poly([x - 0.12, -0.56, x + 0.12, -0.56, x + 0.1, -0.94 + absf(i - 1.5) * 0.08, x - 0.1, -0.94 + absf(i - 1.5) * 0.08], "tint", 0.04, 0.07)
	_poly([0.56, -0.08, 0.9, -0.36, 0.98, -0.18, 0.62, 0.2], "tint", 0.045, 0.06)
	_poly([-0.5, 0.36, 0.5, 0.36, 0.5, 0.5, -0.5, 0.5], "leather", 0.035, 0.03)
	_poly([-0.08, 0.34, 0.08, 0.34, 0.08, 0.52, -0.08, 0.52], "trim", 0.03, 0.02)
	if _r >= 2:
		_gem(0, 0.72, 0.08)

func _a_gloves_cloth() -> void:
	_poly([-0.48, 0.2, 0.48, 0.2, 0.62, 0.98, -0.62, 0.98], "tint", 0.055, 0.14)           # manga larga
	for y in [0.4, 0.6, 0.8]:
		_mark([-0.54, y, 0.54, y - 0.08], _pal("tint")[2], 0.035)
	_poly([-0.5, 0.24, -0.54, -0.3, -0.36, -0.62, 0.36, -0.62, 0.54, -0.3, 0.5, 0.24], "tint_light", 0.055, 0.14)
	for i in range(4):
		var x := -0.36 + i * 0.24
		_poly([x - 0.1, -0.58, x + 0.1, -0.58, x + 0.09, -0.9 + absf(i - 1.5) * 0.07, x - 0.09, -0.9 + absf(i - 1.5) * 0.07], "tint_light", 0.035, 0.06)
	_poly([-0.62, 0.86, 0.62, 0.86, 0.62, 1.0, -0.62, 1.0], "trim", 0.035, 0.03)
	if _r >= 2:
		_gem(0, 0.0, 0.09)

func _boot(m: String, cuff: String, toe: String) -> void:
	_poly([-0.46, -0.92, 0.3, -0.92, 0.32, 0.12, 0.88, 0.38, 0.98, 0.92, -0.52, 0.92], m, 0.06, 0.18)
	_poly([-0.54, 0.7, 0.98, 0.7, 0.98, 0.94, -0.54, 0.94], "dark", 0.045, 0.04)      # sola
	_poly([-0.52, -0.98, 0.36, -0.98, 0.36, -0.7, -0.52, -0.7], cuff, 0.045, 0.06)
	if toe != "":
		_poly([0.36, 0.2, 0.88, 0.4, 0.96, 0.7, 0.4, 0.7], toe, 0.04, 0.06)

func _a_boots_plate() -> void:
	_boot("blade", "trim", "trim")
	for y in [-0.46, -0.16]:
		_mark([-0.44, y, 0.3, y], _pal("blade")[2], 0.035)
	if _r >= 2:
		_gem(-0.08, -0.84, 0.08)

func _a_boots_leather() -> void:
	_boot("tint", "tint_dark", "")
	for y in [-0.5, -0.26, -0.02]:
		_mark([-0.06, y, 0.16, y + 0.08], Color(0.95, 0.88, 0.7), 0.035)
	if _r >= 1:
		_poly([-0.5, -0.1, 0.32, -0.1, 0.32, 0.04, -0.5, 0.04], "trim", 0.03, 0.02)
	if _r >= 2:
		_gem(-0.08, -0.84, 0.08)

func _a_boots_cloth() -> void:
	_poly([-0.36, -0.7, 0.3, -0.7, 0.32, 0.2, 0.9, 0.42, 0.98, 0.88, -0.46, 0.88], "tint", 0.06, 0.18)
	_poly([-0.5, -0.94, 0.42, -0.94, 0.36, -0.62, -0.44, -0.62], "tint_light", 0.045, 0.06)     # dobra
	_poly([-0.5, 0.72, 0.98, 0.72, 0.98, 0.9, -0.5, 0.9], "leather", 0.04, 0.03)
	_poly([0.84, 0.36, 1.06, 0.12, 0.98, 0.5], "tint", 0.035, 0.04)                           # bico virado
	if _r >= 1:
		_circ(1.0, 0.16, 0.07, "trim")
	if _r >= 2:
		_gem(-0.04, -0.78, 0.08)

func _a_cape() -> void:
	_poly([-0.36, -0.84, 0.36, -0.84, 0.82, 0.86, 0.5, 0.74, 0.22, 0.96, -0.1, 0.78, -0.42, 0.96, -0.82, 0.86], "tint", 0.06, 0.2)
	_poly([-0.36, -0.84, 0.36, -0.84, 0.46, -0.6, -0.46, -0.6], "tint_dark", 0.045, 0.04)
	for x in [-0.32, 0.04, 0.36]:
		_mark([x * 0.5, -0.56, x, 0.8], _pal("tint")[2], 0.04)
	_circ(-0.3, -0.72, 0.11, "trim")
	_circ(0.3, -0.72, 0.11, "trim")
	_line([-0.2, -0.72, 0.2, -0.72], "trim", 0.04)
	if _r >= 2:
		_gem(-0.3, -0.72, 0.07)

func _a_amulet() -> void:
	_line([-0.66, -0.12, -0.2, 0.22], "trim", 0.05)
	_line([0.66, -0.12, 0.2, 0.22], "trim", 0.05)
	_line(_arc(0, -0.2, 0.68, PI * 0.98, TAU * 1.01, 18), "trim", 0.05)
	_poly([0, 0.08, 0.36, 0.4, 0.3, 0.8, 0, 1.0, -0.3, 0.8, -0.36, 0.4], "trim", 0.05, 0.08)
	_circ(0, 0.55, 0.22, "tint", 0.035)
	_shine(-0.07, 0.48, 0.08, 0.05, 0.85)
	if _r >= 2:
		for a in [-0.9, 0.9]:
			_gem(sin(a) * 0.32, 0.55 - cos(a) * 0.32, 0.05)

func _a_ring() -> void:
	_ell(0, 0.22, 0.66, 0.6, "trim")
	_ell(0, 0.26, 0.42, 0.38, INK, 0.0)
	if not _sil:
		_cv.draw_arc(Vector2(0, 0.22), 0.53, PI * 1.1, PI * 1.6, 12, Color(1, 1, 1, 0.5), 0.05, true)
	_poly([-0.3, -0.38, 0.3, -0.38, 0.22, -0.18, -0.22, -0.18], "trim", 0.04, 0.04)
	var g := "gem" if _r >= 2 else "tint"
	_shape(_P([0, -0.98, 0.34, -0.66, 0.24, -0.34, -0.24, -0.34, -0.34, -0.66]), g, 0.045, 0.1)
	_shine(-0.1, -0.7, 0.08, 0.05, 0.9)

# --- consumíveis e missão --------------------------------------------------------------
func _liquid(cx: float, cy: float, r: float, level: float) -> void:
	if _sil:
		return
	var pts := _circle_pts(cx, cy, r * 0.9, r * 0.9, 32)
	var cut := PackedVector2Array([Vector2(-2, cy - r + level * 2.0 * r), Vector2(2, cy - r + level * 2.0 * r), Vector2(2, 2), Vector2(-2, 2)])
	for q in Geometry2D.intersect_polygons(pts, cut):
		_fill(q, _tint)
		var l := _light_local()
		for d in Geometry2D.clip_polygons(q, _shift(q, l * 0.16)):
			_fill(d, _tint.darkened(0.4))
	_cv.draw_line(Vector2(cx - r * 0.82, cy - r + level * 2.0 * r), Vector2(cx + r * 0.82, cy - r + level * 2.0 * r), _tint.lightened(0.45), 0.05, true)

func _a_potion_s() -> void:
	_ell(0, 0.32, 0.64, 0.64, "glass")
	_liquid(0, 0.32, 0.64, 0.36)
	_dot(-0.2, 0.5, 0.06, Color(1, 1, 1, 0.5)); _dot(0.16, 0.66, 0.04, Color(1, 1, 1, 0.5))
	_poly([-0.18, -0.6, 0.18, -0.6, 0.18, -0.28, -0.18, -0.28], "glass", 0.045, 0.04)
	_poly([-0.24, -0.72, 0.24, -0.72, 0.24, -0.58, -0.24, -0.58], "glass", 0.04, 0.03)
	_poly([-0.15, -0.98, 0.15, -0.98, 0.18, -0.7, -0.18, -0.7], "cork", 0.045, 0.05)
	_shine(-0.32, 0.06, 0.11, 0.2, 0.7)

func _a_potion_m() -> void:
	_poly([-0.5, -0.24, 0.5, -0.24, 0.6, 0.0, 0.6, 0.86, 0.46, 1.0, -0.46, 1.0, -0.6, 0.86, -0.6, 0.0], "glass", 0.055, 0.1)
	if not _sil:
		var body := _P([-0.52, -0.02, 0.52, -0.02, 0.52, 0.86, 0.42, 0.94, -0.42, 0.94, -0.52, 0.86])
		_fill(body, _tint)
		for d in Geometry2D.clip_polygons(body, _shift(body, _light_local() * 0.18)):
			_fill(d, _tint.darkened(0.4))
		_cv.draw_line(Vector2(-0.5, -0.02), Vector2(0.5, -0.02), _tint.lightened(0.45), 0.05, true)
	_poly([-0.44, 0.3, 0.44, 0.3, 0.44, 0.62, -0.44, 0.62], "paper", 0.035, 0.05)       # rótulo
	_ell(0, 0.46, 0.1, 0.1, _tint.darkened(0.2), 0.0)
	_poly([-0.2, -0.62, 0.2, -0.62, 0.2, -0.22, -0.2, -0.22], "glass", 0.045, 0.04)
	_poly([-0.17, -1.0, 0.17, -1.0, 0.2, -0.6, -0.2, -0.6], "cork", 0.045, 0.05)
	_line([-0.2, -0.56, 0.2, -0.56], "trim", 0.05)
	_shine(-0.4, 0.1, 0.07, 0.24, 0.65)

func _a_elixir() -> void:
	_poly([0, -0.46, 0.66, 0.5, 0.42, 0.98, -0.42, 0.98, -0.66, 0.5], "glass", 0.055, 0.1)
	if not _sil:
		var body := _P([0, -0.2, 0.56, 0.52, 0.36, 0.9, -0.36, 0.9, -0.56, 0.52])
		_fill(body, _tint)
		for d in Geometry2D.clip_polygons(body, _shift(body, _light_local() * 0.16)):
			_fill(d, _tint.darkened(0.4))
		_mark(_arc(0, 0.5, 0.22, 0.0, 4.6, 12), Color(1, 1, 1, 0.55), 0.04)
	_poly([-0.14, -0.74, 0.14, -0.74, 0.14, -0.42, -0.14, -0.42], "glass", 0.04, 0.03)
	_poly([-0.24, -0.86, 0.24, -0.86, 0.2, -0.7, -0.2, -0.7], "gold", 0.04, 0.04)
	_circ(0, -0.98, 0.12, "gold")
	_shine(-0.3, 0.42, 0.06, 0.18, 0.6)

func _a_letter() -> void:
	_poly([-0.9, -0.56, 0.9, -0.56, 0.9, 0.62, -0.9, 0.62], "paper", 0.055, 0.12)
	_mark([-0.88, -0.54, 0, 0.12, 0.88, -0.54], PAL["paper"][2], 0.045)
	_mark([-0.88, 0.6, -0.26, -0.04], PAL["paper"][2], 0.035)
	_mark([0.88, 0.6, 0.26, -0.04], PAL["paper"][2], 0.035)
	var seal: Array = []
	for i in range(14):
		var rr := 0.27 if i % 2 == 0 else 0.23
		seal.append(cos(i * TAU / 14.0) * rr); seal.append(0.12 + sin(i * TAU / 14.0) * rr)
	_poly(seal, "wax", 0.045, 0.08)
	_poly([-0.06, 0.36, 0.06, 0.36, 0.1, 0.62, -0.1, 0.62], "wax", 0.03, 0.03)
	_circ(0, 0.12, 0.12, "wax", 0.0)

func _a_gold() -> void:
	for p in [[-0.42, 0.56], [0.36, 0.6], [0.0, 0.68], [-0.2, 0.32], [0.24, 0.3], [0.02, 0.02], [-0.5, 0.14]]:
		_ell(p[0], p[1], 0.4, 0.17, "gold")
		_ell(p[0], p[1] - 0.03, 0.3, 0.11, PAL["gold"][0] as Color, 0.0)
	_ell(0.48, -0.36, 0.3, 0.3, "gold")                  # moeda em pé
	_ell(0.48, -0.36, 0.2, 0.2, PAL["gold"][2] as Color, 0.0)
	_mark([0.48, -0.5, 0.48, -0.22], PAL["gold"][0], 0.06)
	_shine(0.4, -0.46, 0.06, 0.04, 0.9)

# --- materiais (drops) ------------------------------------------------------------------
func _a_bag() -> void:
	# mochila de couro com aba, fivela e alça
	_line([-0.42, -0.45, -0.3, -0.85, 0.3, -0.85, 0.42, -0.45], "leather", 0.08)
	_poly([-0.74, -0.45, 0.74, -0.45, 0.82, 0.86, -0.82, 0.86], "tint", 0.06, 0.22)
	_poly([-0.74, -0.45, 0.74, -0.45, 0.6, 0.18, -0.6, 0.18], "leather", 0.05, 0.12)
	_poly([-0.12, 0.05, 0.12, 0.05, 0.12, 0.32, -0.12, 0.32], "gold", 0.03, 0.04)
	_mark([-0.62, 0.55, 0.62, 0.55], _pal("tint")[2], 0.04)
	_shine(-0.45, 0.4, 0.14, 0.07, 0.5)

func _a_mushroom() -> void:
	# chapéu vermelho com pintas sobre o pé claro
	_poly([-0.22, 0.2, 0.22, 0.2, 0.28, 0.9, -0.28, 0.9], "paper", 0.05, 0.08)
	var a: Array = []
	for i in range(13):
		var t := PI + PI * i / 12.0
		a.append(cos(t) * 0.86); a.append(0.24 + sin(t) * 0.7)
	_poly(a, "tint", 0.06, 0.2)
	for q in [[-0.42, -0.06, 0.11], [0.1, -0.3, 0.13], [0.48, 0.02, 0.09], [-0.1, 0.06, 0.07]]:
		_dot(q[0], q[1], q[2], Color(1, 0.97, 0.9))
	_shine(-0.4, -0.2, 0.16, 0.08, 0.6)

func _a_relic() -> void:
	# caco de vaso com runas
	_poly([-0.8, -0.3, -0.3, -0.82, 0.5, -0.7, 0.86, -0.1, 0.62, 0.7, -0.1, 0.86, -0.7, 0.5], "tint", 0.06, 0.2)
	_mark([-0.4, -0.3, 0.4, -0.3], _pal("tint")[2], 0.05)
	for q in [[-0.3, 0.05, -0.05, 0.35], [0.05, 0.05, 0.3, 0.35], [0.3, 0.05, 0.05, 0.35]]:
		_mark(q, Color(0.35, 0.25, 0.15), 0.05)
	_shine(-0.45, -0.4, 0.14, 0.07, 0.55)

func _a_basket() -> void:
	# cesto de vime com alça e pano por cima
	_line([-0.6, 0.0, -0.4, -0.7, 0.4, -0.7, 0.6, 0.0], "wood", 0.09)
	_poly([-0.82, 0.0, 0.82, 0.0, 0.62, 0.86, -0.62, 0.86], "wood", 0.06, 0.2)
	for k in range(3):
		var y := 0.2 + k * 0.22
		_mark([-0.74 + k * 0.05, y, 0.74 - k * 0.05, y], _pal("wood")[2], 0.04)
	_poly([-0.7, 0.02, 0.7, 0.02, 0.5, -0.22, -0.5, -0.22], "tint", 0.04, 0.06)
	_shine(-0.4, 0.3, 0.14, 0.07, 0.5)

func _a_star() -> void:
	# pedra com cristais azuis que brilham
	_poly([-0.86, 0.56, -0.74, -0.2, -0.34, -0.72, 0.28, -0.8, 0.82, -0.3, 0.94, 0.46, 0.44, 0.86, -0.4, 0.88], "stone", 0.06, 0.22)
	for q in [[-0.3, 0.1, 0.3], [0.25, -0.2, 0.36], [0.4, 0.4, 0.22]]:
		var x: float = q[0]
		var y: float = q[1]
		var r: float = q[2]
		_poly([x, y - r, x + r * 0.5, y, x, y + r * 0.6, x - r * 0.5, y], "tint", 0.04, 0.05)
	_dot(0.25, -0.3, 0.06, Color(1, 1, 1, 0.9))
	_shine(-0.5, -0.1, 0.12, 0.06, 0.5)

func _a_shell() -> void:
	# casco de caranguejo: leque com gomos e borda serrilhada, pintinhas
	var a: Array = []
	for i in range(15):
		var t := PI + PI * i / 14.0
		var rr := 0.92 if i % 2 == 0 else 0.84
		a.append(cos(t) * rr); a.append(0.42 + sin(t) * rr * 0.95)
	a.append(0.4); a.append(0.62); a.append(-0.4); a.append(0.62)
	_poly(a, "tint", 0.06, 0.22)
	for k in range(5):
		var t := PI + PI * (k + 0.5) / 5.0
		_mark([0, 0.5, cos(t) * 0.78, 0.42 + sin(t) * 0.74], _pal("tint")[2], 0.04)
	_poly([-0.4, 0.58, 0.4, 0.58, 0.28, 0.86, -0.28, 0.86], "tint_dark", 0.05, 0.06)
	for q in [[-0.42, 0.02], [0.3, -0.18], [0.02, -0.34]]:
		_dot(q[0], q[1], 0.06, _pal("tint")[0])
	_shine(-0.36, -0.12, 0.14, 0.08, 0.6)

func _a_legend_coin() -> void:
	_circ(0.08, 0.1, 0.8, PAL["gold"][2] as Color, 0.06, 0.0)          # espessura da moeda
	_circ(0, 0, 0.8, "gold", 0.06, 0.22)
	_circ(0, 0, 0.62, Color(1.0, 0.62, 0.2), 0.035, 0.14)
	var a: Array = []
	for i in range(10):
		var rr := 0.46 if i % 2 == 0 else 0.2
		a.append(cos(i * TAU / 10.0 - PI * 0.5) * rr); a.append(sin(i * TAU / 10.0 - PI * 0.5) * rr)
	_poly(a, "gold", 0.04, 0.08)
	for k in range(16):
		var ang := TAU * k / 16.0
		_dot(cos(ang) * 0.72, sin(ang) * 0.72, 0.03, PAL["gold"][0] as Color)
	_shine(-0.3, -0.4, 0.16, 0.09, 0.8)

func _a_gel() -> void:
	var a: Array = []
	for i in range(26):
		var t := TAU * i / 26.0
		var rr := 0.78 + 0.06 * sin(t * 3.0)
		a.append(cos(t) * rr * 1.05); a.append(0.22 + sin(t) * rr * (0.62 if sin(t) > 0 else 0.92))
	_shape(_P(a), Color(_tint, 0.9), 0.06, 0.2)
	_dot(-0.3, 0.3, 0.09, Color(1, 1, 1, 0.45)); _dot(0.22, 0.46, 0.06, Color(1, 1, 1, 0.4)); _dot(0.36, 0.08, 0.05, Color(1, 1, 1, 0.4))
	_shine(-0.32, -0.18, 0.22, 0.12, 0.85)
	_mark([0.0, 0.88, 0.04, 1.0], _tint.darkened(0.35), 0.06)

func _a_pelt() -> void:
	_poly([-0.5, -0.9, 0, -0.72, 0.5, -0.9, 0.72, -0.46, 0.98, -0.34, 0.72, 0.1, 0.82, 0.62, 0.46, 0.98, 0, 0.78, -0.46, 0.98, -0.82, 0.62, -0.72, 0.1, -0.98, -0.34, -0.72, -0.46], "tint", 0.06, 0.2)
	_poly([-0.36, -0.52, 0.36, -0.52, 0.5, 0.0, 0.36, 0.58, -0.36, 0.58, -0.5, 0.0], "tint_light", 0.0, 0.0)
	for i in range(9):                           # pelos
		var x := -0.36 + (i % 3) * 0.36
		var y := -0.34 + (i / 3) * 0.36
		_mark([x - 0.08, y, x, y + 0.14, x + 0.08, y], _pal("tint")[2], 0.035)
	for p in [[-0.62, -0.56], [0.62, -0.56], [-0.6, 0.62], [0.6, 0.62]]:
		_dot(p[0], p[1], 0.05, Color(0.95, 0.88, 0.7))

func _a_tusk() -> void:
	# presa curva: linha central em arco, grossa na base e fina na ponta
	var outer: Array = []
	var inner: Array = []
	for k in range(15):
		var t := k / 14.0
		var c := Vector2(lerpf(-0.42, 0.42, t) + sin(t * PI) * 0.42, lerpf(0.86, -1.0, t))
		var w := 0.3 * (1.0 - t) + 0.02
		outer.append(c.x + w); outer.append(c.y + w * 0.3)
		inner.push_front(c.y - w * 0.3); inner.push_front(c.x - w)
	_poly(outer + inner, "tint", 0.055, 0.14)
	_poly([-0.82, 0.74, -0.04, 0.74, -0.02, 1.02, -0.84, 1.02], "leather", 0.045, 0.05)
	_mark([-0.68, 0.74, -0.68, 1.0], PAL["leather"][2], 0.03)
	for t: float in [0.25, 0.45]:
		var c := Vector2(lerpf(-0.42, 0.42, t) + sin(t * PI) * 0.42, lerpf(0.86, -1.0, t))
		var w := 0.3 * (1.0 - t)
		_mark([c.x - w * 0.8, c.y + 0.03, c.x + w * 0.8, c.y - 0.03], _pal("tint")[2], 0.03)

func _a_herb() -> void:
	_line([0.0, 1.02, 0.04, 0.3, -0.06, -0.5], Color(0.32, 0.5, 0.2), 0.07)
	for q in [[-0.06, -0.5, 0.0], [0.02, 0.0, -1.0], [0.04, 0.0, 1.0], [0.0, 0.46, -1.0], [0.04, 0.46, 1.0]]:
		var bx: float = q[0]
		var by: float = q[1]
		var dir: float = q[2]
		var ang := -PI * 0.5 + dir * 0.9
		var tip := Vector2(bx, by) + Vector2.from_angle(ang) * 0.62
		var mid := (Vector2(bx, by) + tip) * 0.5
		var n := Vector2.from_angle(ang + PI * 0.5) * 0.2
		_poly([bx, by, mid.x + n.x, mid.y + n.y, tip.x, tip.y, mid.x - n.x, mid.y - n.y], "tint", 0.045, 0.08)
		_mark([bx, by, tip.x, tip.y], _pal("tint")[2], 0.03)
	_poly([-0.2, 0.72, 0.24, 0.72, 0.2, 0.86, -0.18, 0.86], "leather", 0.035, 0.03)      # amarrado

func _a_ore() -> void:
	_poly([-0.86, 0.56, -0.74, -0.2, -0.34, -0.72, 0.28, -0.8, 0.82, -0.3, 0.94, 0.46, 0.44, 0.86, -0.4, 0.88], "stone", 0.06, 0.22)
	_poly([-0.74, -0.2, -0.34, -0.72, 0.28, -0.8, 0.08, -0.12, -0.52, 0.06], PAL["stone"][0] as Color, 0.0, 0.0)
	for q in [[0.38, 0.18, 0.2], [-0.34, 0.42, 0.16], [0.12, -0.42, 0.13], [0.58, -0.22, 0.1]]:
		var x: float = q[0]
		var y: float = q[1]
		var s: float = q[2]
		_poly([x, y - s, x + s * 0.9, y - s * 0.1, x + s * 0.4, y + s, x - s * 0.6, y + s * 0.7, x - s * 0.9, y - s * 0.3], "blade", 0.035, s * 0.4)
		_dot(x - s * 0.3, y - s * 0.3, s * 0.18, Color(1, 1, 1, 0.8))

func _a_silk() -> void:
	_poly([-0.62, -0.84, 0.62, -0.84, 0.62, -0.62, -0.62, -0.62], "wood", 0.05, 0.05)
	_poly([-0.62, 0.62, 0.62, 0.62, 0.62, 0.84, -0.62, 0.84], "wood", 0.05, 0.05)
	_poly([-0.46, -0.62, 0.46, -0.62, 0.52, 0.0, 0.46, 0.62, -0.46, 0.62, -0.52, 0.0], "tint", 0.05, 0.16)
	var y := -0.54
	while y < 0.58:
		_mark([-0.48, y, 0.48, y + 0.04], _pal("tint")[2], 0.025)
		y += 0.11
	_line([0.5, 0.2, 0.8, 0.5, 0.7, 0.96], "tint", 0.04)

func _a_feather() -> void:
	# pena: haste curva na diagonal, palheta em gomos dos dois lados, ponta mais escura
	var spine: Array = []
	for k in range(13):
		var t := k / 12.0
		spine.append(Vector2(lerpf(-0.72, 0.7, t) + sin(t * PI) * 0.12, lerpf(0.86, -0.9, t) + sin(t * PI) * 0.1))
	for side in [-1.0, 1.0]:
		var pts: Array = []
		for k in range(2, 13):
			var c: Vector2 = spine[k]
			var t := k / 12.0
			var w := 0.36 * sin(minf(1.0, t * 1.15) * PI) + 0.04
			var n: Vector2 = ((spine[mini(k + 1, 12)] as Vector2) - (spine[k - 1] as Vector2)).normalized().orthogonal() * side
			pts.append(c.x + n.x * w); pts.append(c.y + n.y * w)
		for k in range(12, 1, -1):
			pts.append((spine[k] as Vector2).x); pts.append((spine[k] as Vector2).y)
		_poly(pts, "tint", 0.045, 0.12)
	for k in [4, 6, 8, 10]:                        # gomos da palheta
		var c: Vector2 = spine[k]
		var n: Vector2 = ((spine[k + 1] as Vector2) - (spine[k - 1] as Vector2)).normalized().orthogonal()
		_mark([c.x, c.y, c.x + n.x * 0.3 + 0.08, c.y + n.y * 0.3 - 0.06], _pal("tint")[2], 0.025)
		_mark([c.x, c.y, c.x - n.x * 0.3 + 0.08, c.y - n.y * 0.3 - 0.06], _pal("tint")[2], 0.025)
	var flat: Array = []
	for q in spine:
		flat.append((q as Vector2).x); flat.append((q as Vector2).y)
	_line(flat, PAL["bone"][1] as Color, 0.05)

func _a_ingot() -> void:
	# lingote élfico: barra trapezoidal com face de cima clara e runa
	_poly([-0.9, 0.42, 0.9, 0.42, 0.62, 0.86, -0.62, 0.86], "tint", 0.055, 0.1)
	_poly([-0.9, 0.42, -0.56, -0.38, 0.56, -0.38, 0.9, 0.42], "tint", 0.055, 0.24)
	_poly([-0.56, -0.38, -0.4, -0.66, 0.4, -0.66, 0.56, -0.38], PAL["steel"][0] as Color, 0.04, 0.0)
	_mark([-0.2, 0.02, 0.0, -0.22, 0.2, 0.02, 0.0, 0.24, -0.2, 0.02], _pal("tint")[2], 0.035)
	_dot(-0.34, -0.5, 0.06, Color(1, 1, 1, 0.85))

func _a_sap() -> void:
	# gota de seiva dourada (ponta para cima) com brilho e folhinha
	var pts: Array = []
	for k in range(32):
		var t := TAU * k / 32.0
		pts.append(0.78 * sin(t) * pow(absf(sin(t * 0.5)), 1.2)); pts.append(-cos(t) * 0.92 + 0.1)
	_poly(pts, "tint", 0.06, 0.2)
	_ell(-0.24, 0.32, 0.12, 0.22, Color(1, 1, 1, 0.55), 0.0)
	_poly([0.1, -0.7, 0.52, -0.86, 0.64, -0.62, 0.24, -0.52], "green", 0.035, 0.04)

func _a_bark() -> void:
	_poly([-0.62, -0.92, 0.5, -0.82, 0.74, -0.2, 0.62, 0.62, 0.36, 0.96, -0.5, 0.86, -0.78, 0.2, -0.7, -0.4], "tint", 0.06, 0.22)
	for x in [-0.4, -0.12, 0.16, 0.42]:
		_mark([x, -0.76, x + 0.08, -0.2, x - 0.04, 0.3, x + 0.04, 0.8], _pal("tint")[2], 0.05)
	_poly([-0.62, -0.92, 0.5, -0.82, 0.4, -0.66, -0.56, -0.74], "wood", 0.0, 0.0)
	for q in [[0.42, 0.42], [-0.46, -0.1], [0.12, 0.62]]:
		_ell(q[0], q[1], 0.14, 0.1, "green", 0.035)

func _a_badge() -> void:
	_poly([0, -0.96, 0.78, -0.7, 0.72, 0.1, 0, 0.98, -0.72, 0.1, -0.78, -0.7], "trim", 0.06, 0.1)
	_poly([0, -0.8, 0.62, -0.58, 0.58, 0.06, 0, 0.8, -0.58, 0.06, -0.62, -0.58], "tint", 0.035, 0.16)
	for s in [-1.0, 1.0]:                        # adagas cruzadas
		_ox = s
		_poly([-0.36, -0.42, -0.28, -0.5, 0.36, 0.3, 0.3, 0.36], "metal", 0.035, 0.04)
		_poly([0.18, 0.18, 0.26, 0.1, 0.44, 0.28, 0.36, 0.36], "leather", 0.03, 0.02)
	_ox = 1.0
	_circ(0, -0.06, 0.13, "bone")
	_dot(-0.04, -0.08, 0.03, INK); _dot(0.05, -0.08, 0.03, INK)

func _a_bone() -> void:
	_poly([-0.1, -0.6, 0.12, -0.6, 0.14, 0.46, 0.04, 0.58, 0.1, 0.72, -0.04, 0.66, -0.12, 0.74, -0.14, 0.46], "tint", 0.05, 0.08)
	for p in [[-0.18, -0.74], [0.2, -0.74]]:
		_circ(p[0], p[1], 0.2, "tint")
	_poly([-0.1, -0.66, 0.12, -0.66, 0.12, -0.5, -0.1, -0.5], "tint", 0.0, 0.0)
	_mark([-0.04, -0.4, -0.06, 0.3], _pal("tint")[0], 0.035)
	_mark([0.06, 0.1, 0.0, 0.2, 0.08, 0.32], _pal("tint")[2], 0.025)

func _a_dust() -> void:
	if not _sil:
		for p in [[-0.62, -0.62, 0.22], [-0.3, -0.84, 0.16], [0.1, -0.74, 0.2], [0.5, -0.86, 0.14], [0.66, -0.54, 0.12]]:
			_cv.draw_circle(Vector2(p[0], p[1]), p[2], Color(_tint.lightened(0.2), 0.55))
	_poly([-0.24, -0.46, 0.24, -0.46, 0.66, 0.1, 0.62, 0.72, 0.3, 0.96, -0.3, 0.96, -0.62, 0.72, -0.66, 0.1], "leather", 0.06, 0.2)
	_poly([-0.3, -0.62, 0.3, -0.62, 0.24, -0.4, -0.24, -0.4], "leather", 0.045, 0.04)
	_line([-0.26, -0.4, 0.26, -0.4], Color(0.9, 0.82, 0.6), 0.05)
	_ell(0, 0.34, 0.26, 0.24, "tint", 0.035)                 # o pó na boca do saco
	_mark(_arc(0, 0.34, 0.14, 0.4, 3.6, 8), _pal("tint")[2], 0.03)

func _a_essence() -> void:
	if not _sil:
		for i in range(5):
			_cv.draw_circle(Vector2(0, 0.0), 0.92 - i * 0.12, Color(_tint, 0.06))
	var a: Array = [0.0, -1.0]
	for k in range(1, 12):
		var t := k / 12.0
		a.append(sin(t * PI) * 0.62 + sin(t * 9.0) * 0.06); a.append(lerpf(-1.0, 0.86, t))
	a.append(0.24); a.append(0.98); a.append(0.0); a.append(0.8); a.append(-0.24); a.append(0.98)
	for k in range(11, 0, -1):
		var t := k / 12.0
		a.append(-sin(t * PI) * 0.62 + sin(t * 7.0) * 0.06); a.append(lerpf(-1.0, 0.86, t))
	_poly(a, "glow", 0.05, 0.18)
	_ell(-0.18, 0.04, 0.09, 0.13, INK, 0.0)
	_ell(0.18, 0.04, 0.09, 0.13, INK, 0.0)
	_dot(-0.16, 0.0, 0.03, Color(1, 1, 1)); _dot(0.2, 0.0, 0.03, Color(1, 1, 1))
	_shine(-0.2, -0.4, 0.1, 0.16, 0.6)

func _a_core() -> void:
	if not _sil:
		for i in range(5):
			_cv.draw_circle(Vector2(0, 0.0), 0.9 - i * 0.1, Color(_tint, 0.07))
	_poly([-0.9, 0.3, -0.62, -0.34, -0.22, -0.66, 0.36, -0.62, 0.84, -0.24, 0.9, 0.36, 0.46, 0.84, -0.42, 0.84], "stone", 0.06, 0.2)
	_poly([0, -0.56, 0.42, -0.12, 0.3, 0.46, 0, 0.66, -0.3, 0.46, -0.42, -0.12], "glow", 0.045, 0.12)
	_poly([0, -0.56, 0.42, -0.12, 0, 0.02, -0.42, -0.12], _tint.lightened(0.5), 0.0, 0.0)
	_mark([0, 0.02, 0, 0.66], _tint.darkened(0.3), 0.03)
	for q in [[-0.66, 0.4], [0.66, 0.42], [0.06, -0.72]]:
		_mark([q[0], q[1], q[0] * 0.6, q[1] * 0.6], _tint.lightened(0.3), 0.04)

func _a_scale() -> void:
	_poly([0, -1.0, 0.68, -0.52, 0.76, 0.2, 0.4, 0.78, 0, 1.0, -0.4, 0.78, -0.76, 0.2, -0.68, -0.52], "tint", 0.06, 0.22)
	for k in range(3):
		var y := -0.46 + k * 0.44
		_mark(_arc(0, y - 0.34, 0.54 - k * 0.06, 0.4, PI - 0.4, 10), _pal("tint")[2], 0.05)
	_mark([0, -0.9, 0, 0.9], _pal("tint")[0], 0.04)
	_shine(-0.3, -0.42, 0.1, 0.2, 0.55)
