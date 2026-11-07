class_name ActionBar
extends PanelContainer
## Barra de ações (estilo MMO clássico): moldura de bronze no centro de baixo com as skills 1-6, as poções F1-F3,
## montaria (H) e volta à cidade (G), o menu de atalhos (I C K L P M Esc) e a barra de XP de 20 gomos por baixo de tudo. Arte toda desenhada aqui.

const BRONZE := Color(0.62, 0.47, 0.25)
const BRONZE_DARK := Color(0.28, 0.2, 0.1)
const FRAME_BG := Color(0.075, 0.065, 0.09, 0.94)
const XP_FILL := Color(0.52, 0.36, 0.92)
const XP_SEGMENTS := 20
const SKILL_PX := 50
const POTION_PX := 42

var hud
var skill_slots: Array = []
var potion_slots: Array = []
var util_slots: Array = []          # [montaria (H), volta à cidade (G)]
## [tecla, ícone (assets/icons/action_<id>.png), dica]
const UTIL := [["H", "mount", "Montar / desmontar (H)
Cavalo: anda %d%% mais rápido. Não dá para montar em combate."],
	["G", "recall", "Voltar à cidade (G)
Conjura %.1f s, também em combate. Andar ou agir cancela; levar dano interrompe."]]
var xp: XpBar
var level_cap: Crest
## [tecla, nome, janela que abre (@map/@menu = mapa grande / menu do Esc)]
const MICRO := [["I", "Bolsa", "inventory"], ["C", "Personagem", "character"], ["K", "Skills", "skills"],
	["L", "Quests", "quests"], ["P", "Grupo", "party"], ["M", "Mapa", "@map"], ["Esc", "Menu", "@menu"]]

func build() -> void:
	var st := StyleBoxFlat.new()
	st.bg_color = FRAME_BG
	st.border_color = BRONZE
	st.set_border_width_all(2)
	st.border_width_top = 3
	st.set_corner_radius_all(8)
	st.shadow_color = Color(0, 0, 0, 0.55)
	st.shadow_size = 6
	st.content_margin_left = 6; st.content_margin_right = 6
	st.content_margin_top = 6; st.content_margin_bottom = 5
	add_theme_stylebox_override("panel", st)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_END
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	level_cap = Crest.new()
	level_cap.kind = "level"
	row.add_child(level_cap)
	for i in range(6):
		var s := make_button("%d" % (i + 1), SKILL_PX)
		row.add_child(s["root"])
		skill_slots.append(s)
	row.add_child(_divider())
	for i in range(3):
		var s := make_button("F%d" % (i + 1), POTION_PX)
		s["root"].size_flags_vertical = Control.SIZE_SHRINK_END
		row.add_child(s["root"])
		potion_slots.append(s)
	row.add_child(_divider())
	for u in UTIL:
		var s := make_button(u[0], POTION_PX)
		s["root"].size_flags_vertical = Control.SIZE_SHRINK_END
		s["tex"].texture = UiKit.icon_texture("action_" + u[1])
		s["bevel"].set_empty(false)
		s["id"] = u[1]
		s["root"].tooltip_text = u[2] % (roundi((Balance.MOUNT_SPEED_MULT - 1.0) * 100.0) if u[1] == "mount" else Balance.RECALL_TIME)
		row.add_child(s["root"])
		util_slots.append(s)
	row.add_child(_divider())
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(grid)
	for m in MICRO:
		grid.add_child(_micro(m[0], m[1], m[2]))
	var cap := Crest.new()
	cap.kind = "sun"
	row.add_child(cap)
	xp = XpBar.new()
	xp.custom_minimum_size = Vector2(0, 14)
	col.add_child(xp)

## Moldura: filete dourado por dentro e rebites de bronze no alto e embaixo.
func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(3, 3, w - 6, h - 6), Color(0.85, 0.66, 0.32, 0.25), false, 1.0)
	var n := int(w / 70.0)
	for i in range(n + 1):
		var x := 12.0 + (w - 24.0) * i / float(maxi(n, 1))
		for y in [1.5, h - 1.5]:
			draw_circle(Vector2(x, y), 2.6, Color(0.25, 0.17, 0.08))
			draw_circle(Vector2(x, y), 1.8, Color(0.9, 0.72, 0.38))
			draw_circle(Vector2(x - 0.5, y - 0.6), 0.7, Color(1, 0.95, 0.8))

func _divider() -> Control:
	var d := Divider.new()
	d.custom_minimum_size = Vector2(10, SKILL_PX)
	return d

func _micro(key: String, tip: String, what: String) -> Control:
	var b := Button.new()
	b.text = key
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(30, 24)
	b.tooltip_text = "%s (%s)" % [tip, key]
	b.add_theme_font_size_override("font_size", 11)
	b.add_theme_color_override("font_color", Color(0.95, 0.86, 0.6))
	b.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.75))
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.16, 0.12, 0.09) if state == "normal" else (Color(0.26, 0.19, 0.11) if state == "hover" else Color(0.1, 0.07, 0.05))
		sb.border_color = BRONZE if state != "normal" else BRONZE.darkened(0.35)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		b.add_theme_stylebox_override(state, sb)
	b.pressed.connect(_micro_pressed.bind(what))
	return b

func _micro_pressed(what: String) -> void:
	if hud == null:
		return
	if what == "@map":
		hud.toggle_world_map()
	elif what == "@menu":
		hud.open_game_menu()
	else:
		hud.windows_script.toggle(what)

## Botão de ação: fundo fundo (afundado), ícone, sombra de recarga em leque, tecla e número.
## Devolve o mesmo dicionário que o HUD já usa ({root, icon, tex, cd, cdt, lv}) + "sweep".
static func make_button(key: String, px: int) -> Dictionary:
	var p := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.03, 0.03, 0.04)
	st.border_color = Color(0.42, 0.33, 0.2)
	st.set_border_width_all(2)
	st.set_corner_radius_all(3)
	st.set_content_margin_all(2)
	p.add_theme_stylebox_override("panel", st)
	var box := Control.new()
	box.custom_minimum_size = Vector2(px, px)
	box.clip_contents = true
	p.add_child(box)
	var icon := ColorRect.new()
	icon.color = Color(0.1, 0.1, 0.12)
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_child(icon)
	var tex := TextureRect.new()
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(tex)
	var bevel := Bevel.new()                      # luz em cima/esquerda, sombra embaixo/direita (botão de vidro)
	bevel.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_child(bevel)
	var sweep := CdSweep.new()                    # recarga: leque escuro que gira no sentido do relógio
	sweep.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_child(sweep)
	var cd := ColorRect.new()                     # sem MP / arma errada: véu inteiro
	cd.color = Color(0, 0, 0, 0.55)
	cd.set_anchors_preset(Control.PRESET_FULL_RECT)
	cd.visible = false
	box.add_child(cd)
	var cdt := UiKit.label("", 17 if px >= 48 else 14)
	cdt.set_anchors_preset(Control.PRESET_FULL_RECT)
	cdt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cdt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cdt.add_theme_constant_override("outline_size", 4)
	cdt.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	box.add_child(cdt)
	var k := UiKit.label(key, 11, Color(0.92, 0.9, 0.85))
	k.add_theme_constant_override("outline_size", 3)
	k.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	k.position = Vector2(3, 0)
	box.add_child(k)
	var lv := UiKit.label("", 10, Color(0.8, 1, 0.8))
	lv.add_theme_constant_override("outline_size", 3)
	lv.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lv.anchor_left = 1.0; lv.anchor_right = 1.0; lv.anchor_top = 1.0; lv.anchor_bottom = 1.0
	lv.offset_left = -30; lv.offset_right = -3; lv.offset_top = -16; lv.offset_bottom = 0
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(lv)
	for c in p.find_children("*", "Control", true, false):      # só o painel recebe o mouse (arrastar/soltar, botão direito)
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.mouse_entered.connect(func(): st.border_color = Color(1.0, 0.82, 0.4))
	p.mouse_exited.connect(func(): st.border_color = Color(0.42, 0.33, 0.2))
	return {"root": p, "icon": icon, "tex": tex, "cd": cd, "cdt": cdt, "lv": lv, "sweep": sweep, "style": st, "bevel": bevel}

## XP do nível: texto no meio, preenchimento violeta e 20 gomos.
func set_xp(level: int, cur: int, need: int) -> void:
	xp.frac = clampf(float(cur) / float(need), 0.0, 1.0) if need > 0 else 1.0
	xp.text = ("Nível %d  ·  %d / %d XP  (%d%%)" % [level, cur, need, int(xp.frac * 100.0)]) if need > 0 else "Nível %d  ·  nível máximo" % level
	xp.tooltip_text = xp.text
	xp.queue_redraw()
	if level_cap.value != str(level):
		level_cap.value = str(level)
		level_cap.queue_redraw()

class CdSweep extends Control:
	var frac := 0.0                   # quanto da recarga ainda falta (1 = começou agora)
	var color := Color(0, 0, 0, 0.62)     # leque de recarga; conjuração (G) usa um leque claro
	func set_color(c: Color) -> void:
		if c != color:
			color = c
			queue_redraw()
	func set_frac(f: float) -> void:
		if absf(f - frac) > 0.004 or (f == 0.0) != (frac == 0.0):
			frac = f
			queue_redraw()
	func _draw() -> void:
		if frac <= 0.0:
			return
		var c := size * 0.5
		var r := size.length() * 0.5 + 1.0
		var pts := PackedVector2Array([c])
		var steps := maxi(3, int(40.0 * frac))
		var a0 := -PI * 0.5 + TAU * (1.0 - frac)      # o leque some no sentido do relógio a partir do topo
		for i in range(steps + 1):
			var a := a0 + TAU * frac * float(i) / float(steps)
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, color)
		var edge := c + Vector2(cos(a0), sin(a0)) * r
		draw_line(c, edge, Color(1.0, 0.9, 0.55, 0.7), 1.5, true)

class Bevel extends Control:
	var empty := true                 # slot vazio: trama fina de losangos (não fica um buraco preto)
	var active := false               # ligado (montado, conjurando): aro dourado por dentro
	func set_empty(e: bool) -> void:
		if e != empty:
			empty = e
			queue_redraw()
	func set_active(a: bool) -> void:
		if a != active:
			active = a
			queue_redraw()
	func _draw() -> void:
		var w := size.x
		var h := size.y
		if empty:
			var step := 10.0
			var x := -h
			while x < w:
				draw_line(Vector2(x, h), Vector2(x + h, 0), Color(0.6, 0.5, 0.35, 0.07), 1.0)
				draw_line(Vector2(x, 0), Vector2(x + h, h), Color(0.6, 0.5, 0.35, 0.07), 1.0)
				x += step
		draw_rect(Rect2(0, 0, w, h * 0.42), Color(1, 1, 1, 0.07))               # brilho de vidro em cima
		draw_line(Vector2(0, 0.5), Vector2(w, 0.5), Color(1, 1, 1, 0.22), 1.0)
		draw_line(Vector2(0.5, 0), Vector2(0.5, h), Color(1, 1, 1, 0.14), 1.0)
		draw_line(Vector2(0, h - 0.5), Vector2(w, h - 0.5), Color(0, 0, 0, 0.55), 1.0)
		draw_line(Vector2(w - 0.5, 0), Vector2(w - 0.5, h), Color(0, 0, 0, 0.45), 1.0)
		if active:
			draw_rect(Rect2(1.5, 1.5, w - 3.0, h - 3.0), Color(1.0, 0.85, 0.4, 0.95), false, 3.0)
			draw_rect(Rect2(4.5, 4.5, w - 9.0, h - 9.0), Color(1.0, 0.95, 0.7, 0.35), false, 2.0)

class Divider extends Control:
	func _draw() -> void:
		var x := size.x * 0.5
		draw_line(Vector2(x, 4), Vector2(x, size.y - 4), Color(0.0, 0.0, 0.0, 0.6), 2.0)
		draw_line(Vector2(x + 1.5, 4), Vector2(x + 1.5, size.y - 4), Color(0.62, 0.47, 0.25, 0.55), 1.0)
		var m := Vector2(x + 0.5, size.y * 0.5)
		draw_colored_polygon(PackedVector2Array([m + Vector2(0, -5), m + Vector2(4, 0), m + Vector2(0, 5), m + Vector2(-4, 0)]), Color(0.85, 0.66, 0.32))

## Brasão nas pontas da moldura: escudo de bronze com o nível (esquerda) ou um sol (direita).
class Crest extends Control:
	var kind := "level"
	var value := ""
	func _init() -> void:
		custom_minimum_size = Vector2(44, 54)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var cx := w * 0.5
		var top := h * 0.5 - 25.0
		var shield := PackedVector2Array([Vector2(cx - 19, top), Vector2(cx + 19, top), Vector2(cx + 19, top + 26),
			Vector2(cx, top + 50), Vector2(cx - 19, top + 26)])
		draw_colored_polygon(shield, Color(0.62, 0.47, 0.25))
		var inner := PackedVector2Array()
		for q in shield:
			inner.append(Vector2(cx, top + 22) + (q - Vector2(cx, top + 22)) * 0.8)
		draw_colored_polygon(inner, Color(0.13, 0.1, 0.16))
		var line := shield.duplicate()
		line.append(shield[0])
		draw_polyline(line, Color(0.25, 0.17, 0.08), 1.5, true)
		draw_line(Vector2(cx - 17, top + 3), Vector2(cx + 17, top + 3), Color(1, 0.9, 0.6, 0.5), 1.0)
		var font := get_theme_default_font()
		if kind == "level":
			var fs := 18 if value.length() < 3 else 14
			var tw := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string_outline(font, Vector2(cx - tw * 0.5, top + 29), value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0))
			draw_string(font, Vector2(cx - tw * 0.5, top + 29), value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.86, 0.45))
			var lt := "Nv"
			var lw := font.get_string_size(lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
			draw_string(font, Vector2(cx - lw * 0.5, top + 11), lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.85, 0.75, 0.55))
		else:
			var c := Vector2(cx, top + 21)
			for i in range(8):
				var a := TAU * i / 8.0
				draw_line(c + Vector2(cos(a), sin(a)) * 6.0, c + Vector2(cos(a), sin(a)) * 11.0, Color(1.0, 0.82, 0.4), 2.0, true)
			draw_circle(c, 5.0, Color(1.0, 0.88, 0.5))

class XpBar extends Control:
	var frac := 0.0
	var text := ""
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.02, 0.02, 0.03, 0.95))
		var f := Rect2(Vector2(1, 1), Vector2((size.x - 2) * frac, size.y - 2))
		draw_rect(f, ActionBar.XP_FILL)
		draw_rect(Rect2(f.position, Vector2(f.size.x, f.size.y * 0.4)), Color(1, 1, 1, 0.18))
		for i in range(1, ActionBar.XP_SEGMENTS):
			var x := floorf(size.x * i / float(ActionBar.XP_SEGMENTS)) + 0.5
			draw_line(Vector2(x, 1), Vector2(x, size.y - 1), Color(0, 0, 0, 0.7), 1.0)
			draw_line(Vector2(x + 1, 1), Vector2(x + 1, size.y - 1), Color(1, 1, 1, 0.08), 1.0)
		draw_rect(r, ActionBar.BRONZE.darkened(0.2), false, 1.0)
		var font := get_theme_default_font()
		var fs := 11
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at := Vector2((size.x - tw) * 0.5, size.y * 0.5 + fs * 0.36)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.97, 0.95, 1.0))
