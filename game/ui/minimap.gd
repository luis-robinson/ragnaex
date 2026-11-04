class_name Minimap
extends Control
## Minimapa redondo (canto superior direito), desenhado a partir do MapDef — sem segunda câmera 3D.
## Camada estática (chão do vale, água, estradas, vila, casas, árvores, penhascos, portais) é desenhada uma vez
## por mapa; a dinâmica (jogador, bots, monstros, NPCs) a cada frame. Gira com a câmera: "para cima" = para onde
## a câmera olha. Roda do mouse sobre o minimapa = zoom.

const SIZE := 210.0
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

const PLACE_COLORS := {"cabin": Color(1.0, 0.85, 0.4), "camp": Color(0.95, 0.4, 0.3), "shrine": Color(0.6, 0.85, 1.0), "dungeon": Color(0.8, 0.45, 1.0)}

func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# recorte redondo: o painel desenha o círculo e recorta os filhos nele
	_clip = Panel.new()
	_clip.set_anchors_preset(Control.PRESET_FULL_RECT)
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = C_CLIFF
	st.set_corner_radius_all(int(SIZE / 2))
	st.anti_aliasing = true
	_clip.add_theme_stylebox_override("panel", st)
	_clip.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	add_child(_clip)
	_holder = Node2D.new()
	_holder.position = Vector2(SIZE, SIZE) * 0.5
	_clip.add_child(_holder)
	_static = Node2D.new()
	_static.draw.connect(_draw_static)
	_holder.add_child(_static)
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
	rs.set_corner_radius_all(int(SIZE / 2))
	rs.anti_aliasing = true
	ring.add_theme_stylebox_override("panel", rs)
	add_child(ring)
	_north = UiKit.label("N", 13, UiKit.GOLD)
	_north.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_north)

func set_map(def: MapDef) -> void:
	_def = def
	_static.scale = Vector2.ONE * zoom
	_static.queue_redraw()

func _gui_input(event: InputEvent) -> void:
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
	var f := camera.forward_flat() if camera else Vector3(0, 0, -1)
	_holder.rotation = Vector2(f.x, f.z).angle_to(Vector2(0, -1))
	_static.position = -Vector2(p.position.x, p.position.z) * zoom
	_dynamic.queue_redraw()
	# "N" na borda, no lado do norte do mundo (-z)
	var n := Vector2(0, -1).rotated(_holder.rotation) * (SIZE * 0.5 - 12)
	_north.position = Vector2(SIZE, SIZE) * 0.5 + n - Vector2(5, 9)

## Mundo (x, z) -> coordenada local do _static (antes do zoom).
static func _w(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)

func _draw_static() -> void:
	if _def == null:
		return
	var n := _static
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
	var origin := Vector2(p.position.x, p.position.z)
	var d := _dynamic
	var quest_marks: Array = []
	for e in Sim.map_entities(p.map_id):
		if e == p or not e.is_alive():
			continue
		var rel := (Vector2(e.position.x, e.position.z) - origin) * zoom
		var mark: String = _marks.get(e.id, "")
		if mark in ["!", "?", QuestSystem.REPEAT]:
			rel = rel.limit_length(SIZE * 0.5 - 12.0)       # pendência longe fica na borda, apontando o rumo
		if rel.length() > SIZE * 0.5:
			continue
		match e.kind:
			SimEntity.Kind.MONSTER:
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
				else:
					d.draw_circle(rel, 3.0, Color(0.95, 0.95, 0.8))
	for qm in quest_marks:
		_draw_quest_mark(d, qm[0], qm[1])
	# jogador: seta na direção em que encara (girada junto com o mapa)
	var fwd := Vector2(sin(p.facing), cos(p.facing))
	var side := Vector2(-fwd.y, fwd.x)
	var tip := fwd * 8.0
	d.draw_colored_polygon(PackedVector2Array([tip, -fwd * 4.0 + side * 5.0, -fwd * 1.5, -fwd * 4.0 - side * 5.0]), Color(1, 1, 1))
	d.draw_polyline(PackedVector2Array([tip, -fwd * 4.0 + side * 5.0, -fwd * 1.5, -fwd * 4.0 - side * 5.0, tip]), Color(0.1, 0.1, 0.1), 1.2, true)

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
