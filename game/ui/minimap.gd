class_name Minimap
extends Control
## Minimapa redondo (canto superior direito), desenhado a partir do MapDef — sem segunda câmera 3D.
## Camada estática (chão do vale, água, estradas, vila, casas, árvores, penhascos, portais) é desenhada uma vez
## por mapa; a dinâmica (jogador, bots, monstros, NPCs) a cada frame. Gira com a câmera: "para cima" = para onde
## a câmera olha. Roda do mouse sobre o minimapa = zoom.

const SIZE := 210.0
var side := SIZE                      # lado em pixels (o mapa grande do M usa um lado maior)
var big := false                      # mapa grande (M): norte para cima, mapa inteiro, nomes dos portais
var _origin := Vector2.ZERO           # centro do desenho no mundo (jogador; no mapa grande, o centro do mapa)
const ZOOM_MIN := 0.8
const ZOOM_MAX := 3.2
const C_ROAD := Color(0.78, 0.68, 0.5)
const C_STREET := Color(0.8, 0.78, 0.72)
const C_WATER := Color(0.36, 0.6, 0.85)
const C_CLIFF := Color(0.36, 0.32, 0.28)
const C_TREE := Color(0.22, 0.42, 0.24)
const C_WALL := Color(0.9, 0.86, 0.76)

var camera: CameraRig
var zoom := 1.5                       # pixels por metro
var _def: MapDef = null
var _clip: Panel
var _holder: Node2D                   # centro do minimapa; gira com a câmera
var _static: Node2D                   # mapa inteiro em coordenadas de mundo × zoom
var _dynamic: Node2D
var _north: Label
var _marks: Dictionary = {}           # id do NPC -> marcador de quest
var _marks_timer := 0.0
var hud: Node = null                  # dono da quest rastreada (hud.tracked_quest())
var _guide: Dictionary = {}           # QuestSystem.guide_point da quest rastreada
const C_GUIDE := Color(1.0, 0.85, 0.2)

const PLACE_COLORS := {"cabin": Color(1.0, 0.85, 0.4), "camp": Color(0.95, 0.4, 0.3), "shrine": Color(0.6, 0.85, 1.0), "dungeon": Color(0.8, 0.45, 1.0)}

func _ready() -> void:
	custom_minimum_size = Vector2(side, side)
	size = Vector2(side, side)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# recorte redondo: o painel desenha o círculo e recorta os filhos nele
	_clip = Panel.new()
	_clip.set_anchors_preset(Control.PRESET_FULL_RECT)
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = C_CLIFF
	st.set_corner_radius_all(0 if big else int(side / 2))
	st.anti_aliasing = true
	_clip.add_theme_stylebox_override("panel", st)
	_clip.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	add_child(_clip)
	_holder = Node2D.new()
	_holder.position = Vector2(side, side) * 0.5
	_clip.add_child(_holder)
	_static = Node2D.new()
	_static.draw.connect(_draw_baked)
	_static.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_holder.add_child(_static)
	# camada estática assada numa textura (uma vez por mapa): desenhada direto eram ~1.500 draw calls por quadro
	# (cada árvore/pedra/casa um círculo ou retângulo, o mapa inteiro, todo quadro)
	_bake_vp = SubViewport.new()
	_bake_vp.disable_3d = true
	_bake_vp.transparent_bg = true
	_bake_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_bake_vp)
	_bake = Node2D.new()
	_bake.draw.connect(_draw_static_in.bind(_bake))
	_bake_vp.add_child(_bake)
	_dynamic = Node2D.new()
	_dynamic.draw.connect(_draw_dynamic)
	_holder.add_child(_dynamic)
	# moldura dourada por cima do recorte
	var ring := Panel.new()
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(0, 0, 0, 0)
	rs.border_color = UiKit.BORDER
	rs.set_border_width_all(3)
	rs.set_corner_radius_all(6 if big else int(side / 2))
	rs.anti_aliasing = true
	ring.add_theme_stylebox_override("panel", rs)
	add_child(ring)
	_north = UiKit.label("N", 13, UiKit.GOLD)
	_north.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_north)

func set_map(def: MapDef) -> void:
	_def = def
	_static.scale = Vector2.ONE * zoom
	_bake_static()
	_static.queue_redraw()

## Textura da camada estática: retângulo do mapa (+ margem) a BAKE_PPM pixels por metro (menos em mapa enorme).
const BAKE_PPM := 5.0
const BAKE_MAX := 4096
const BAKE_MARGIN := 12.0
var _bake_vp: SubViewport
var _bake: Node2D
var _bake_rect := Rect2()             # área do mundo (x, z) coberta pela textura

func _bake_static() -> void:
	if _def == null:
		return
	var h := _def.half() + Vector2.ONE * BAKE_MARGIN
	_bake_rect = Rect2(-h, h * 2.0)
	var ppm := minf(BAKE_PPM, float(BAKE_MAX) / maxf(_bake_rect.size.x, _bake_rect.size.y))
	_bake_vp.size = Vector2i(ceili(_bake_rect.size.x * ppm), ceili(_bake_rect.size.y * ppm))
	_bake.scale = Vector2.ONE * ppm
	_bake.position = -_bake_rect.position * ppm
	_bake.queue_redraw()
	_bake_vp.render_target_update_mode = SubViewport.UPDATE_ONCE

func _draw_baked() -> void:
	if _def == null or _bake_vp == null:
		return
	_static.draw_texture_rect(_bake_vp.get_texture(), _bake_rect, false)

func _gui_input(event: InputEvent) -> void:
	if big:
		return
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = minf(ZOOM_MAX, zoom * 1.15)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = maxf(ZOOM_MIN, zoom / 1.15)
		else:
			return
		_static.scale = Vector2.ONE * zoom
		accept_event()

func _process(delta: float) -> void:
	var p: SimEntity = Sim.player
	if p == null or _def == null or not is_visible_in_tree():
		return
	_marks_timer -= delta
	if _marks_timer <= 0.0:
		_marks_timer = 0.25
		_marks.clear()
		for e in Sim.map_entities(p.map_id):
			if e.kind == SimEntity.Kind.NPC:
				_marks[e.id] = QuestSystem.npc_marker(p, e.npc_data.get("id", ""))
		var qid: String = hud.tracked_quest() if hud else ""
		_guide = QuestSystem.guide_point(p, GameData.quests[qid]) if GameData.quests.has(qid) else {}
	if big:                               # mapa inteiro, norte para cima, centrado no mapa
		_holder.rotation = 0.0
		zoom = side / maxf(_def.size.x, _def.size.y) * 1.02
		_static.scale = Vector2.ONE * zoom
		_origin = Vector2.ZERO
	else:
		var f := camera.forward_flat() if camera else Vector3(0, 0, -1)
		_holder.rotation = Vector2(f.x, f.z).angle_to(Vector2(0, -1))
		_origin = Vector2(p.position.x, p.position.z)
	_static.position = -_origin * zoom
	_dynamic.queue_redraw()
	if big:
		_north.position = Vector2(side * 0.5 - 5.0, 4.0)
		return
	# "N" na borda, no lado do norte do mundo (-z)
	var n := Vector2(0, -1).rotated(_holder.rotation) * (side * 0.5 - 12)
	_north.position = Vector2(side, side) * 0.5 + n - Vector2(5, 9)

## Mundo (x, z) -> coordenada local do _static (antes do zoom).
static func _w(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)

func _draw_static_in(n: Node2D) -> void:
	if _def == null:
		return
	var ground := _def.ground_color.lightened(0.05)
	# chão do vale: polígono pela face interna dos penhascos (ou retângulo do mapa)
	var cliffs: Array = []
	for ob in _def.obstacles:
		if ob.get("kind", "") == "cliff":
			cliffs.append(_w(ob["pos"]))
	if cliffs.size() > 8:
		cliffs.sort_custom(func(a, b): return a.angle() < b.angle())
		var poly := PackedVector2Array()
		for c in cliffs:
			poly.append(c - c.normalized() * 3.5)
		n.draw_colored_polygon(poly, ground)
	else:
		var h := _def.half()
		n.draw_rect(Rect2(-h, h * 2.0), ground)
	# água
	for w in _def.water:
		if w.get("kind", "") == "lake":
			n.draw_circle(w["pos"], float(w["r"]), C_WATER)
		elif w.has("pts"):
			n.draw_polyline(w["pts"], C_WATER, float(w.get("w", 6.0)), true)
	# estradas e praças
	for r in _def.roads:
		var pts: PackedVector2Array = r["pts"]
		if pts.size() == 1:
			n.draw_circle(pts[0], float(r.get("r", 4.0)), C_STREET if r.get("kind", "") == "street" else C_ROAD)
		elif pts.size() > 1:
			n.draw_polyline(pts, C_ROAD, float(r.get("w", 4.0)), true)
	_draw_places(n)
	# obstáculos: casas (telhado), muralha, árvores, pedras, morros
	for ob in _def.obstacles:
		var kind: String = ob.get("kind", "")
		var pos := _w(ob["pos"])
		var sz: Vector3 = ob.get("size", Vector3.ONE)
		match kind:
			"tree", "pine":
				n.draw_circle(pos, maxf(1.0, sz.x * 0.75), C_TREE)
			"dead_tree":
				n.draw_circle(pos, maxf(0.8, sz.x * 0.5), Color(0.42, 0.36, 0.3))
			"bush":
				n.draw_circle(pos, maxf(0.6, sz.x * 0.45), C_TREE.lightened(0.15))
			"rock":
				n.draw_circle(pos, maxf(0.6, sz.x * 0.5), Color(0.55, 0.53, 0.5))
			"house", "wall", "pillar", "ruin", "hill", "tent", "stall", "fountain", "well", "statue":
				var col: Color = ob.get("roof", ob.get("color", C_WALL)) if kind == "house" else (C_WALL if kind in ["wall", "pillar"] else Color(0.6, 0.58, 0.52))
				if kind == "hill":
					col = _def.ground_color.darkened(0.25)
				if kind == "fountain":
					col = C_WATER
				var rot := -deg_to_rad(float(ob.get("rot", 0.0)))   # rotação Y do jogo -> ângulo no plano xz
				n.draw_set_transform(pos, rot, Vector2.ONE)
				if kind in ["hill", "pillar", "fountain", "well", "statue"]:
					n.draw_circle(Vector2.ZERO, maxf(sz.x, sz.z) * 0.5, col)
				else:
					n.draw_rect(Rect2(-Vector2(sz.x, sz.z) * 0.5, Vector2(sz.x, sz.z)), col)
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# portais
	for pt in _def.portals:
		var pos := _w(pt["pos"])
		n.draw_circle(pos, 3.2, Color(0.75, 0.45, 1.0))
		n.draw_circle(pos, 1.6, Color(1, 1, 1))

func _draw_dynamic() -> void:
	var p: SimEntity = Sim.player
	if p == null:
		return
	var origin := _origin
	var d := _dynamic
	var quest_marks: Array = []
	# investida: anel pulsante no povoado atacado (o alvo da marcha)
	var rs: Dictionary = Sim.raid_status(p.map_id)
	if not rs.is_empty() and rs["active"]:
		var at := (Vector2(rs["target"].x, rs["target"].z) - origin) * zoom
		if at.length() < side * 0.5 + float(rs["radius"]) * zoom:
			var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.006)
			d.draw_arc(at, float(rs["radius"]) * zoom, 0.0, TAU, 48, Color(1.0, 0.45, 0.2, 0.35 + 0.4 * pulse), 2.5, true)
	for e in Sim.map_entities(p.map_id):
		if e == p or not e.is_alive():
			continue
		var rel := (Vector2(e.position.x, e.position.z) - origin) * zoom
		var mark: String = _marks.get(e.id, "")
		if mark in ["!", "?", QuestSystem.REPEAT]:
			rel = rel.limit_length(side * 0.5 - 12.0)       # pendência longe fica na borda, apontando o rumo
		if rel.length() > side * 0.5:
			continue
		match e.kind:
			SimEntity.Kind.MONSTER:
				if e.raid_id >= 0:              # investida: losango laranja com borda, maior que o monstro comum
					var dm := PackedVector2Array([rel + Vector2(0, -4.5), rel + Vector2(4.5, 0), rel + Vector2(0, 4.5), rel + Vector2(-4.5, 0)])
					d.draw_colored_polygon(dm, Color(1.0, 0.55, 0.15))
					dm.append(dm[0])
					d.draw_polyline(dm, Color(0.2, 0.05, 0.0), 1.2, true)
				else:
					d.draw_circle(rel, 4.0 if e.monster_def and e.monster_def.is_boss else 2.6, Color(0.95, 0.3, 0.3))
			SimEntity.Kind.BOT:
				if Sim.same_party(e, p):
					d.draw_circle(rel, 4.0, Color(0.1, 0.25, 0.1))
					d.draw_circle(rel, 3.2, Color(0.45, 1.0, 0.5))
				else:
					d.draw_circle(rel, 2.6, Color(0.45, 0.8, 1.0))
			SimEntity.Kind.NPC:
				if mark != "":
					quest_marks.append([rel, mark])
				elif e.npc_data.get("role", "") == "crystal":       # cristal de retorno: losango azul (maior se for o seu)
					var r := 5.0 if p.bind_map == p.map_id else 3.6
					var dm := PackedVector2Array([rel + Vector2(0, -r), rel + Vector2(r * 0.7, 0), rel + Vector2(0, r), rel + Vector2(-r * 0.7, 0)])
					d.draw_colored_polygon(dm, Color(0.45, 0.8, 1.0))
					dm.append(dm[0])
					d.draw_polyline(dm, Color(0.05, 0.15, 0.3), 1.2, true)
				else:
					d.draw_circle(rel, 3.0, Color(0.95, 0.95, 0.8))
	for qm in quest_marks:
		_draw_quest_mark(d, qm[0], qm[1])
	_draw_guide(d, origin)
	if big:
		_draw_labels(d, origin)
	# jogador: seta na direção em que encara (girada junto com o mapa); no mapa grande, maior e onde ele está
	var pp := (Vector2(p.position.x, p.position.z) - origin) * zoom
	var k := 1.6 if big else 1.0
	var fwd := Vector2(sin(p.facing), cos(p.facing))
	var sd := Vector2(-fwd.y, fwd.x)
	var tip := pp + fwd * 8.0 * k
	var poly := PackedVector2Array([tip, pp - fwd * 4.0 * k + sd * 5.0 * k, pp - fwd * 1.5 * k, pp - fwd * 4.0 * k - sd * 5.0 * k])
	d.draw_colored_polygon(poly, Color(1, 1, 1))
	poly.append(tip)
	d.draw_polyline(poly, Color(0.1, 0.1, 0.1), 1.2, true)

## Mapa grande: nome de cada portal (para onde leva) e dos lugares com NPC.
func _draw_labels(d: Node2D, origin: Vector2) -> void:
	var font: Font = UiKit.mark_font()
	var used: Array = []                  # nomes não se sobrepõem: tenta acima, abaixo e dos lados; senão pula
	for pt in _def.portals:
		var rel := (Vector2(pt["pos"].x, pt["pos"].z) - origin) * zoom
		d.draw_circle(rel, 5.0, Color(0.75, 0.55, 1.0))
		if str(pt.get("target_map", "")).begins_with("in_"):
			continue                          # porta de casa: só o ponto (nome embolava o centro da vila)
		var txt := "➜ " + str(pt.get("label", ""))
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		for off in [Vector2(-w * 0.5, -10.0), Vector2(-w * 0.5, 22.0), Vector2(-w - 10.0, 5.0), Vector2(10.0, 5.0)]:
			var at: Vector2 = rel + off
			at.x = clampf(at.x, -side * 0.5 + 4.0, side * 0.5 - w - 4.0)
			var r := Rect2(at - Vector2(2, 14), Vector2(w + 4, 18))
			if used.any(func(u): return (u as Rect2).intersects(r)):
				continue
			used.append(r)
			d.draw_string_outline(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0.05, 0.03, 0.08))
			d.draw_string(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.92, 0.85, 1.0))
			break
	for e in Sim.map_entities(Sim.player.map_id):
		if e.kind != SimEntity.Kind.NPC or e.guard or e.npc_data.get("role", "") in ["villager", "guard", ""]:
			continue
		var rel := (Vector2(e.position.x, e.position.z) - origin) * zoom
		var nm: String = e.name
		var w := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		for off in [Vector2(-w * 0.5, 16.0), Vector2(-w * 0.5, -8.0), Vector2(8.0, 4.0), Vector2(-w - 8.0, 4.0)]:
			var r := Rect2(rel + off - Vector2(2, 12), Vector2(w + 4, 15))
			if used.any(func(u): return (u as Rect2).intersects(r)):
				continue
			used.append(r)
			d.draw_string_outline(font, rel + off, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color(0.05, 0.04, 0.03))
			d.draw_string(font, rel + off, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.95, 0.8))
			break

## Seta amarela da quest rastreada: longe = presa na borda apontando o rumo; perto = sobre o ponto
## (ponta para baixo, sempre de pé) com um anel. Objetivo noutro mapa aponta para o portal do caminho.
func _draw_guide(d: Node2D, origin: Vector2) -> void:
	if _guide.is_empty():
		return
	var gp: Vector3 = _guide["pos"]
	var rel := (Vector2(gp.x, gp.z) - origin) * zoom
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
	var edge := side * 0.5 - 14.0
	var dir: Vector2
	var at: Vector2
	if rel.length() > edge:
		dir = rel.normalized()
		at = dir * (edge - 2.0 * pulse)
	else:
		d.draw_arc(rel, 5.0 + 2.0 * pulse, 0.0, TAU, 24, Color(C_GUIDE, 0.85), 2.0, true)
		dir = Vector2(0, 1).rotated(-_holder.rotation)      # ponta para baixo na tela
		at = rel - dir * (9.0 + 2.0 * pulse)
	var side := Vector2(-dir.y, dir.x)
	var tip := at + dir * 7.0
	var pts := PackedVector2Array([tip, at - dir * 5.0 + side * 6.0, at - dir * 2.0, at - dir * 5.0 - side * 6.0])
	d.draw_colored_polygon(pts, C_GUIDE)
	pts.append(tip)
	d.draw_polyline(pts, Color(0.25, 0.15, 0.0), 1.4, true)

## Lugares do mapa: um ponto com a cor do tipo (dungeon em destaque).
## Símbolo sempre de pé: desfaz a rotação do mapa só para este desenho.
func _draw_quest_mark(d: Node2D, rel: Vector2, mark: String) -> void:
	var font: Font = UiKit.mark_font()
	var text := UiKit.quest_mark_text(mark)
	var at := Vector2(-font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x * 0.5, 7.0)
	d.draw_set_transform(rel, -_holder.rotation)
	d.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, 5, Color(0.1, 0.07, 0.04))
	d.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, UiKit.quest_mark_color(mark))
	d.draw_set_transform(Vector2.ZERO)

func _draw_places(n: Node2D) -> void:
	for pl in _def.places:
		var col: Color = PLACE_COLORS.get(pl["type"], Color.WHITE)
		var pos := _w(pl["pos"])
		n.draw_circle(pos, 5.0 if pl["type"] == "dungeon" else 3.5, Color(0, 0, 0, 0.55))
		n.draw_circle(pos, 3.8 if pl["type"] == "dungeon" else 2.5, col)
