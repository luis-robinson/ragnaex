class_name WebFog
extends Node2D
## Névoa por faixa de nível na teia (janela K): escurece o FUNDO em volta dos nós que pedem nível acima do do jogador,
## mais escura a cada faixa de 10 níveis, com um rótulo "Nv N+" na borda de cada região. Os nós continuam os mesmos.
## A névoa é uma textura pequena (PX_PER_UNIT por unidade da teia) montada uma vez por (classe, teia, nível) e desenhada
## esticada no espaço da teia: arrastar/zoom movem junto, e o quadro custa um draw call.

const STEP := 10                  # largura da faixa (níveis): 23-29, 30-39, 40-49 para quem é nível 22
const PX_PER_UNIT := 5.0          # resolução da névoa (pixels da textura por unidade da teia)
const FOG_R := 1.55               # raio da névoa em volta de um nó trancado (unidades; o aro dos círculos fica em 1,5)
const FOG_SOFT := 0.6             # largura da borda suave
const CLEAR_R := 0.5              # em volta de um nó já liberado a névoa abre (estrada de nível 1 entre círculos trancados)
const CLEAR_SOFT := 0.35
const ALPHA := [0.0, 0.52, 0.66, 0.76, 0.82]     # escuridão por faixa (0 = liberado)
const FOG_RGB := Color(0.0, 0.0, 0.015)
const LABEL_GAP := 3.2            # rótulos a menos disso (unidades) um do outro: fica só o primeiro
const LABEL_COLOR := Color(1.0, 0.6, 0.5)

static var _cache_key := ""
static var _cache: Dictionary = {}

## Faixa do nó para o jogador: 0 = liberado; 1 = até a próxima dezena; 2, 3... = dezenas seguintes.
static func band(level: int, player_level: int) -> int:
	if level <= player_level:
		return 0
	return 1 + maxi(0, level / STEP - (player_level + 1) / STEP)

## Primeiro nível da faixa `b` (b >= 1) para o jogador.
static func band_floor(b: int, player_level: int) -> int:
	if b <= 1:
		return player_level + 1
	return ((player_level + 1) / STEP + b - 1) * STEP

## Rótulos da névoa: [{pos (unidades), text, band}]. Por faixa b, regiões ligadas de nós com faixa >= b (discos que se
## tocam); o rótulo vai no nó da região mais perto do início, do lado do início. Faixa 1 mostra o menor nível da região.
static func labels(nodes: Dictionary, player_level: int, origin: Vector2) -> Array:
	var locked: Array = []
	var top := 0
	for nid in nodes:
		var b := band(int(nodes[nid]["level"]), player_level)
		if b > 0:
			locked.append(nid)
			top = maxi(top, b)
	locked.sort_custom(func(a, c): return ((nodes[a]["pos"] as Vector2) - origin).length() < ((nodes[c]["pos"] as Vector2) - origin).length())
	var out: Array = []
	for b in range(1, top + 1):
		var ids: Array = locked.filter(func(nid): return band(int(nodes[nid]["level"]), player_level) >= b)
		var reach := FOG_R * 2.0 - FOG_SOFT
		var grid := {}                             # baldes de lado `reach`: vizinho só nos 9 baldes em volta
		for nid in ids:
			var k := Vector2i(((nodes[nid]["pos"] as Vector2) / reach).floor())
			if not grid.has(k):
				grid[k] = []
			grid[k].append(nid)
		var seen := {}
		for seed_id in ids:                        # já em ordem de distância: a 1ª de cada região é a âncora
			if seen.has(seed_id):
				continue
			var lo := 999
			var queue: Array = [seed_id]
			seen[seed_id] = true
			while not queue.is_empty():
				var cur: String = queue.pop_back()
				lo = mini(lo, int(nodes[cur]["level"]))
				var cp: Vector2 = nodes[cur]["pos"]
				var ck := Vector2i((cp / reach).floor())
				for dx in [-1, 0, 1]:
					for dy in [-1, 0, 1]:
						for o in grid.get(ck + Vector2i(dx, dy), []):
							if not seen.has(o) and cp.distance_to(nodes[o]["pos"]) < reach:
								seen[o] = true
								queue.append(o)
			var at: Vector2 = nodes[seed_id]["pos"]
			var back := (origin - at).normalized() if at.distance_to(origin) > 0.01 else Vector2.UP
			var pos := at + back * (FOG_R - 0.35) + Vector2(0.0, -0.3)     # um pouco acima: o nome do nó fica embaixo dele
			if out.any(func(l): return (l["pos"] as Vector2).distance_to(pos) < LABEL_GAP):
				continue
			out.append({"pos": pos, "text": "Nv %d+" % (lo if b == 1 else band_floor(b, player_level)), "band": b})
	return out

## Textura da névoa: {tex, rect (unidades), labels}. Guarda a última (a janela é refeita a cada compra, o nível não muda).
static func build_fog(key: String, nodes: Dictionary, player_level: int, origin: Vector2) -> Dictionary:
	if key == _cache_key:
		return _cache
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var any := false
	for nid in nodes:
		var p: Vector2 = nodes[nid]["pos"]
		lo = lo.min(p)
		hi = hi.max(p)
		any = any or band(int(nodes[nid]["level"]), player_level) > 0
	var res := {"tex": null, "rect": Rect2(), "labels": []}
	if any:
		lo -= Vector2.ONE * (FOG_R + 0.5)
		hi += Vector2.ONE * (FOG_R + 0.5)
		var w := ceili((hi.x - lo.x) * PX_PER_UNIT)
		var h := ceili((hi.y - lo.y) * PX_PER_UNIT)
		var fog := PackedFloat32Array()
		fog.resize(w * h)
		var clear := PackedFloat32Array()
		clear.resize(w * h)
		for nid in nodes:
			var b := band(int(nodes[nid]["level"]), player_level)
			var r := FOG_R if b > 0 else CLEAR_R
			var soft := FOG_SOFT if b > 0 else CLEAR_SOFT
			var top: float = ALPHA[mini(b, ALPHA.size() - 1)] if b > 0 else 1.0
			var buf := fog if b > 0 else clear
			var c: Vector2 = ((nodes[nid]["pos"] as Vector2) - lo) * PX_PER_UNIT
			var rp := r * PX_PER_UNIT
			for y in range(maxi(0, floori(c.y - rp)), mini(h, ceili(c.y + rp) + 1)):
				for x in range(maxi(0, floori(c.x - rp)), mini(w, ceili(c.x + rp) + 1)):
					var d := Vector2(x + 0.5, y + 0.5).distance_to(c) / PX_PER_UNIT
					if d >= r:
						continue
					var v := top * smoothstep(0.0, 1.0, (r - d) / soft)
					var i := y * w + x
					if v > buf[i]:
						buf[i] = v
		var data := PackedByteArray()
		data.resize(w * h * 4)
		var rgb := [FOG_RGB.r8, FOG_RGB.g8, FOG_RGB.b8]
		for i in range(w * h):
			data[i * 4] = rgb[0]
			data[i * 4 + 1] = rgb[1]
			data[i * 4 + 2] = rgb[2]
			data[i * 4 + 3] = int(clampf(fog[i] * (1.0 - clear[i]), 0.0, 1.0) * 255.0)
		var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)
		res["tex"] = ImageTexture.create_from_image(img)
		res["rect"] = Rect2(lo, Vector2(w, h) / PX_PER_UNIT)
		res["labels"] = labels(nodes, player_level, origin)
	_cache_key = key
	_cache = res
	return res

var _tex: Texture2D = null
var _rect := Rect2()

## Névoa da teia `nodes` (sem os talentos de escolha) para o nível `player_level`; `unit` = px por unidade da teia.
## Os rótulos entram como filhos (Label) por cima da névoa.
func setup(key: String, nodes: Dictionary, player_level: int, origin: Vector2, unit: float) -> void:
	var f := build_fog(key, nodes, player_level, origin)
	_tex = f["tex"]
	_rect = Rect2((f["rect"] as Rect2).position * unit, (f["rect"] as Rect2).size * unit)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for l in f["labels"]:
		var lb := Label.new()
		lb.text = str(l["text"])
		lb.add_theme_font_size_override("font_size", 20 if int(l["band"]) == 1 else 24)
		lb.add_theme_color_override("font_color", LABEL_COLOR.darkened(0.08 * (int(l["band"]) - 1)))
		lb.add_theme_constant_override("outline_size", 4)
		lb.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.size = Vector2(120, 36)
		lb.position = (l["pos"] as Vector2) * unit - lb.size * 0.5
		add_child(lb)
	queue_redraw()

func _draw() -> void:
	if _tex:
		draw_texture_rect(_tex, _rect, false)
