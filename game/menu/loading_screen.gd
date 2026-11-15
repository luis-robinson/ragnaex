class_name LoadingScreen
extends CanvasLayer
## Overlay de Carregamento (design/ux/start-flow.md §3, §5, §7): arte da zona de destino em tela cheia (ou um degradê
## de entardecer), nome da zona, barra que nunca volta, texto da etapa e uma dica.
## Fica na raiz (`get_tree().root`, layer 100) e sobrevive à troca start -> main; `begin` pede em thread main.tscn, o GLB
## do mapa e o kit do personagem (o `main` guarda os Resources em `req.held`). O `main` chama `set_step` a cada etapa,
## `finish()` quando o mundo está pronto (segura 100% e some num fade) ou `fail(msg)` (volta a Personagens).

## Tudo pronto: o overlay terminou o fade e se libera.
signal finished
## A montagem falhou: já pediu a volta a Personagens com a faixa vermelha.
signal failed(message: String)

const LAYER := 100
const MAIN_SCENE := "res://game/main.tscn"
const START_SCENE := "res://game/menu/start.tscn"
const ART_PATH := "res://assets/ui/loading/%s.jpg"
const ERROR_TEXT := "Não foi possível carregar. Tente de novo."
const ERROR_SHOW_S := 6.0
const HOLD_S := 0.3              # segura 100% antes de sumir
const FADE_S := 0.4
const BAR_SPEED := 10.0          # a barra desenhada corre atrás do progresso (lerp por quadro)
## Etapas da montagem do `main` em ordem; `w` = fração da barra, medida pelos prints BOOT (soma 1). Medido 2026-11-14,
## headless, cidade: sim_maps 221 ms (33 mapas), bots 16752 ms (383 entidades), player 1, map_build 493, views ~0,3-1 s.
const STEPS := [
	{"id": &"prepare", "text": "Preparando a viagem…", "w": 0.35},
	{"id": &"sim_maps", "text": "Despertando o mundo…", "w": 0.05},
	{"id": &"bots", "text": "Chamando os aventureiros…", "w": 0.25},
	{"id": &"player", "text": "Arrumando a bagagem…", "w": 0.01},
	{"id": &"assets", "text": "Carregando a zona…", "w": 0.04},
	{"id": &"map_build", "text": "Erguendo o lugar…", "w": 0.22},
	{"id": &"views", "text": "Acordando os vizinhos…", "w": 0.08},
]
## Entardecer (tons do menu_set): topo, meio, horizonte.
const DUSK := [Color(0.10, 0.07, 0.16), Color(0.32, 0.17, 0.26), Color(0.78, 0.45, 0.30)]

var map_id := ""
var _req: StartRequest = null
var _root: Control
var _art: TextureRect
var _zone_label: Label
var _sub_label: Label
var _tip_label: Label
var _step_label: Label
var _bar: ProgressBar
var _progress := 0.0
var _shown := 0.0
var _closing := false

func _ready() -> void:
	name = "LoadingScreen"
	layer = LAYER
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP      # nada passa para o jogo/menu embaixo
	add_child(_root)
	_art = TextureRect.new()
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.texture = dusk_texture()
	_root.add_child(_art)
	var shade := TextureRect.new()                       # rodapé escuro: o texto lê sobre qualquer arte
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.25), Color(0, 0, 0, 0.85)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 128
	shade.texture = gt
	_root.add_child(shade)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	box.offset_left = 80
	box.offset_right = -80
	box.offset_top = -250
	box.offset_bottom = -56
	box.add_theme_constant_override("separation", 8)
	box.alignment = BoxContainer.ALIGNMENT_END
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)
	_zone_label = UiKit.label("", 44, UiKit.GOLD)
	box.add_child(_zone_label)
	_sub_label = UiKit.label("", 16, UiKit.TEXT)
	box.add_child(_sub_label)
	box.add_child(UiKit.hsep(10))
	_tip_label = UiKit.label("Dica: " + pick_tip(), 15, UiKit.TEXT)
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_tip_label)
	_step_label = UiKit.label(str(STEPS[0]["text"]), 14, Color(0.85, 0.82, 0.76))
	box.add_child(_step_label)
	_bar = UiKit.bar(UiKit.GOLD, 12)
	_bar.max_value = 1.0
	_bar.show_percentage = false
	box.add_child(_bar)

func _process(delta: float) -> void:
	if _bar == null:
		return
	_shown = minf(_progress, lerpf(_shown, _progress, minf(1.0, delta * BAR_SPEED)) + 0.0005)
	_bar.value = _shown

## Começa a carga do pedido: zona de destino na tela e as cargas em thread (main.tscn, GLB do mapa, kit).
func begin(req: StartRequest) -> void:
	_req = req
	req.loading = self
	show_zone(req.destination_map())
	req.load_paths = PackedStringArray()
	for p in req.preload_list(MAIN_SCENE):
		if ResourceLoader.load_threaded_request(p) == OK:
			req.load_paths.append(p)

## Só a tela (revisão `--loading_shot`): zona `mid` com a barra em `fraction`, sem carregar nada.
func preview(mid: String, fraction: float, step: StringName = &"map_build") -> void:
	show_zone(mid)
	set_step(step, 0.5)
	_progress = fraction
	_shown = fraction
	_bar.value = fraction

## Arte, nome e faixa de nível da zona `mid`.
func show_zone(mid: String) -> void:
	map_id = mid
	var def: MapDef = GameData.maps.get(mid)
	_art.texture = art_for(mid)
	_zone_label.text = def.name if def else "RagnaEx"
	if def == null:
		_sub_label.text = ""
	elif def.is_town:
		_sub_label.text = "Cidade · porto seguro"
	else:
		_sub_label.text = "Nível %d–%d" % [def.level_range.x, def.level_range.y]

## Progresso da etapa `id` (STEPS) com `sub` 0..1 dentro dela; o texto vira o da etapa.
func set_step(id: StringName, sub: float) -> void:
	var r := step_range(id)
	var txt := ""
	for s in STEPS:
		if s["id"] == id:
			txt = str(s["text"])
	set_progress(r.x + (r.y - r.x) * clampf(sub, 0.0, 1.0), txt)

## Progresso 0..1 (nunca anda para trás) e o texto da etapa.
func set_progress(fraction: float, step: String = "") -> void:
	_progress = maxf(_progress, clampf(fraction, 0.0, 1.0))
	if _step_label and step != "":
		_step_label.text = step

## Progresso atual (0..1, o pedido, não o desenhado).
func progress() -> float:
	return _progress

## Mundo pronto: 100%, segura HOLD_S e some em FADE_S.
func finish() -> void:
	if _closing:
		return
	_closing = true
	set_progress(1.0, "Pronto!")
	_shown = 1.0
	_bar.value = 1.0
	await get_tree().create_timer(HOLD_S).timeout
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, FADE_S)
	await tw.finished
	finished.emit()
	queue_free()

## Falha na carga: o erro vai ao log, a tela volta a Personagens com a faixa vermelha; nada é gravado.
func fail(message: String) -> void:
	if _closing:
		return
	_closing = true
	failed.emit(message)
	back_to_menu(get_tree(), message, _req)
	queue_free()

# ---------------------------------------------------------------------------
## Início e fim (0..1) da etapa `id` na barra.
static func step_range(id: StringName) -> Vector2:
	var a := 0.0
	for s in STEPS:
		var w: float = s["w"]
		if s["id"] == id:
			return Vector2(a, a + w)
		a += w
	return Vector2(a, a)

## Uma dica qualquer de `Tips.TIPS`.
static func pick_tip() -> String:
	var all: Array = Tips.TIPS.values()
	return str(all[randi() % all.size()])

## Arte da zona (`assets/ui/loading/<mapa>.jpg`); sem ela, o degradê de entardecer.
static func art_for(mid: String) -> Texture2D:
	var p := ART_PATH % mid
	if mid != "" and ResourceLoader.exists(p):
		var t: Texture2D = load(p)
		if t:
			return t
	return dusk_texture()

static func dusk_texture() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	g.colors = PackedColorArray(DUSK)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 256
	return gt

## Volta a Personagens depois de uma falha: a tela inicial abre na lista (card do espaço selecionado) e mostra a faixa
## vermelha (`show_pending_error`); o texto do erro fica em `StartRequest.error` e no log.
static func back_to_menu(tree: SceneTree, message: String, req: StartRequest) -> void:
	StartRequest.returning = true
	StartRequest.last_slot = req.slot if req and req.load_save else -1
	StartRequest.error = message
	tree.change_scene_to_file.call_deferred(START_SCENE)

## Chamado pela tela inicial depois de abrir a tela: falha pendente do Carregamento vira a faixa vermelha
## (`CharList.show_error`; sem ela, p.ex. caiu na Criação com 0 personagens, uma faixa própria na raiz). Limpa o erro.
static func show_pending_error(screen: Node) -> void:
	if StartRequest.error == "" or screen == null:
		return
	StartRequest.error = ""
	if screen.has_method("show_error"):
		screen.call("show_error", ERROR_TEXT)
	elif screen.is_inside_tree():
		_error_banner(screen.get_tree())

static func _error_banner(tree: SceneTree) -> void:
	var old := tree.root.get_node_or_null("LoadError")
	if old:
		old.queue_free()
	var layer := CanvasLayer.new()
	layer.name = "LoadError"
	layer.layer = LAYER + 1
	var panel := UiKit.panel(Color(0.45, 0.08, 0.08, 0.95), Color(0.9, 0.3, 0.25))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.offset_top = 40
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lb := UiKit.label(ERROR_TEXT, 18, UiKit.TEXT)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(lb)
	layer.add_child(panel)
	tree.root.add_child.call_deferred(layer)
	tree.create_timer(ERROR_SHOW_S).timeout.connect(layer.queue_free)
