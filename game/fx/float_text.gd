class_name FloatText
extends Node3D
## Texto flutuante de combate (dano, "Esquiva!", "+cura"): Label3D reaproveitados (pool), faixas por alvo para não
## empilhar no mesmo ponto, repetição do mesmo texto no mesmo alvo vira um só ("Esquiva! ×5") e no máximo
## MAX_PER_TARGET por alvo (o mais velho some rápido). Só desenho: lê nada da sim.

const MAX_PER_TARGET := 4       # pops vivos por alvo; o 5º apressa o mais velho
const MAX_TOTAL := 48           # teto geral (a briga grande chegava a 383 Label3D num quadro)
const MERGE_WINDOW := 0.6       # s desde o último repique para somar no mesmo pop
const LIFE := 1.3               # tempo de vida (igual ao tween antigo: sobe 0,9 s, apaga de 0,4 a 1,3 s)
const RISE := 1.4               # m que sobe
const RISE_TIME := 0.9
const FADE_DELAY := 0.4
const SHRINK_DELAY := 0.3
const EVICT_LEFT := 0.12        # s que sobram ao pop expulso pelo teto
## Faixas na tela (direita da câmera, para cima): centro, esquerda, direita, centro alto.
const LANES := [Vector2(0.0, 0.0), Vector2(-0.55, 0.3), Vector2(0.55, 0.3), Vector2(0.0, 0.6)]

var _live: Array = []           # [{label, key, text, count, age, fade, life, pos, lane, side, size, punch}]
var _pool: Array[Label3D] = []

## Mostra `text` sobre o alvo `key` (id da entidade; -1 = sem alvo, sem faixa nem fusão).
## `merge`: repetição do mesmo texto no mesmo alvo dentro de MERGE_WINDOW soma no pop existente.
func pop(pos: Vector3, text: String, color: Color, size: float = 1.0, key: int = -1, merge: bool = false) -> void:
	if merge and key >= 0:
		var i := find_merge(_live, key, text)
		if i >= 0:
			var r: Dictionary = _live[i]
			r["count"] = int(r["count"]) + 1
			r["fade"] = 0.0                     # recomeça a apagar; a subida continua de onde está
			r["life"] = LIFE
			r["punch"] = 1.0
			(r["label"] as Label3D).text = merged_text(text, int(r["count"]))
			return
	if key >= 0:
		for j in evict_for(_live, key, MAX_PER_TARGET):
			_live[j]["life"] = minf(float(_live[j]["life"]), float(_live[j]["fade"]) + EVICT_LEFT)
	if _live.size() >= MAX_TOTAL:
		_recycle(0)
	var lane := free_lane(_live, key) if key >= 0 else 0
	var off: Vector2 = LANES[lane]
	var right := _cam_right()
	var jitter := randf_range(-0.12, 0.12)
	var start := pos + right * (off.x + jitter) + Vector3(0, off.y, 0)
	var side := signf(off.x) if off.x != 0.0 else randf_range(-1.0, 1.0)
	var l := _take()
	l.text = text
	l.modulate = color
	l.font_size = int(44 * size)
	l.position = start
	l.scale = Vector3.ONE
	l.visible = true
	_live.append({"label": l, "key": key, "text": text, "count": 1, "age": 0.0, "fade": 0.0, "life": LIFE,
		"pos": start, "drift": right * side * 0.4, "lane": lane, "punch": 0.0})

func _process(delta: float) -> void:
	var i := 0
	while i < _live.size():
		var r: Dictionary = _live[i]
		r["age"] = float(r["age"]) + delta
		r["fade"] = float(r["fade"]) + delta
		if float(r["fade"]) >= float(r["life"]):
			_recycle(i)
			continue
		var l: Label3D = r["label"]
		var k := minf(1.0, float(r["age"]) / RISE_TIME)
		l.position = (r["pos"] as Vector3) + ((r["drift"] as Vector3) + Vector3(0, RISE, 0)) * k
		var f: float = r["fade"]
		var left: float = float(r["life"]) - f
		var a := 1.0 - clampf((f - FADE_DELAY) / RISE_TIME, 0.0, 1.0)
		a = minf(a, clampf(left / EVICT_LEFT, 0.0, 1.0)) if float(r["life"]) < LIFE else a
		l.modulate.a = a
		var s := lerpf(1.0, 0.6, clampf((f - SHRINK_DELAY) / RISE_TIME, 0.0, 1.0))
		var p: float = r["punch"]
		if p > 0.0:
			s *= 1.0 + 0.25 * p                 # repique da fusão: incha e volta
			r["punch"] = maxf(0.0, p - delta * 6.0)
		l.scale = Vector3.ONE * s
		i += 1

## Quantos pops vivos (testes e medição).
func live_count() -> int:
	return _live.size()

func pooled_count() -> int:
	return _pool.size()

## Texto de um pop somado: "Esquiva! ×5".
static func merged_text(text: String, count: int) -> String:
	return text if count <= 1 else "%s ×%d" % [text, count]

## Índice do pop vivo do mesmo alvo com o mesmo texto ainda na janela de fusão, ou -1.
static func find_merge(live: Array, key: int, text: String) -> int:
	for i in range(live.size() - 1, -1, -1):
		var r: Dictionary = live[i]
		if int(r["key"]) == key and r["text"] == text and float(r["fade"]) <= MERGE_WINDOW and float(r["life"]) >= LIFE:
			return i
	return -1

## Pops do alvo que precisam sair para caber um novo (os mais velhos primeiro; já expulsos não contam).
static func evict_for(live: Array, key: int, cap: int) -> Array[int]:
	var mine: Array[int] = []
	for i in live.size():
		var r: Dictionary = live[i]
		if int(r["key"]) == key and float(r["life"]) >= LIFE:
			mine.append(i)
	var out: Array[int] = []
	var n := mine.size() - (cap - 1)
	for j in maxi(0, n):
		out.append(mine[j])
	return out

## Primeira faixa livre do alvo (só os pops ainda inteiros ocupam); todas ocupadas = a do pop mais velho.
static func free_lane(live: Array, key: int) -> int:
	var used := {}
	var oldest := -1
	for r: Dictionary in live:
		if int(r["key"]) == key and float(r["life"]) >= LIFE:
			used[int(r["lane"])] = true
			if oldest < 0:
				oldest = int(r["lane"])
	for lane in LANES.size():
		if not used.has(lane):
			return lane
	return maxi(0, oldest)

func _take() -> Label3D:
	if not _pool.is_empty():
		return _pool.pop_back()
	var l := Label3D.new()
	l.outline_size = 14
	l.pixel_size = 0.012
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(l)
	return l

func _recycle(i: int) -> void:
	var l: Label3D = _live[i]["label"]
	_live.remove_at(i)
	l.visible = false
	if _pool.size() < MAX_TOTAL:
		_pool.append(l)
	else:
		l.queue_free()

## Direita da câmera no chão (a faixa espalha de lado na tela, não no eixo X do mundo).
func _cam_right() -> Vector3:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return Vector3.RIGHT
	var r := cam.global_transform.basis.x
	r.y = 0.0
	return r.normalized() if r.length() > 0.01 else Vector3.RIGHT
