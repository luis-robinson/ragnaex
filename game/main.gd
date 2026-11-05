extends Node
## Main: liga simulação (Sim) e apresentação. Cria o mundo visual do mapa atual,
## views de entidades, câmera, controle do jogador, FX e UI.

var world_root: Node3D
var map_node: Node3D = null
var views_root: Node3D
var views: Dictionary = {}       # entity_id -> EntityView
var camera: CameraRig
var controller: PlayerController
var fx: FxManager
var hud                          # Hud (CanvasLayer)
var current_map_id: String = ""
var started := false
static var returning := false     # voltou ao menu pelo Esc: não repete o --autostart da linha de comando
var _autosave := 0.0
var dev: DevRunner = null         # modos de revisão/medição (só com argumentos depois de `--`)
var perf_watch := PerfWatch.new()
var _vignette: ColorRect = null

const WINDOWED_SIZE := Vector2i(1920, 1080)

## F11: janela 1920x1080 centralizada <-> tela cheia (começa em janela, ver project.godot).
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(WINDOWED_SIZE)
			var screen := DisplayServer.screen_get_usable_rect()
			DisplayServer.window_set_position(screen.position + (screen.size - WINDOWED_SIZE) / 2)
		get_viewport().set_input_as_handled()

func _ready() -> void:
	Engine.max_physics_steps_per_frame = 3     # quadro lento não vira bola de neve de ticks (a sim desacelera um pouco)
	GraphicsSettings.load_and_apply(get_viewport())     # Nítido (125%, 100% em tela grande) ou FSR 2 (menu Esc → Gráficos)
	world_root = Node3D.new()
	world_root.name = "World"
	add_child(world_root)
	views_root = Node3D.new()
	views_root.name = "Entities"
	world_root.add_child(views_root)
	camera = CameraRig.new()
	camera.name = "CameraRig"
	world_root.add_child(camera)
	fx = FxManager.new()
	fx.name = "FX"
	fx.camera = camera
	fx.main = self
	world_root.add_child(fx)
	controller = PlayerController.new()
	controller.name = "PlayerController"
	controller.camera = camera
	controller.set_physics_process(false)
	add_child(controller)
	hud = load("res://game/ui/hud.gd").new()
	hud.main = self
	add_child(hud)

	# carrega todos os mapas na simulação (o "servidor" simula tudo)
	for mid in GameData.maps:
		Sim.load_map(GameData.maps[mid])
	_populate_bots()

	Events.entity_spawned.connect(_on_spawned)
	Events.entity_despawned.connect(_on_despawned)
	Events.entity_changed_map.connect(_on_changed_map)
	Events.equipment_changed.connect(_on_equipment_changed)

	# mostra a cidade de fundo enquanto escolhe a classe
	_show_map(GameData.town_map_id())
	camera.global_position = Vector3(0, 0, 4)
	if DevArgs.any():
		dev = DevRunner.new()
		dev.name = "Dev"
		dev.main = self
		add_child(dev)
	# partida automática (smoke/revisão):  godot --headless --path . -- --autostart=berserker [--screenshot=/tmp/x.png]
	var autostart := dev.before_start(returning) if dev else ""
	if autostart != "":
		SaveSystem.slot = -1                 # partida de teste/revisão nunca grava por cima de um personagem
		start_game(GameData.classes.get(autostart, GameData.classes["paladin"]), "Smoke", false)
		dev.after_start()
		return
	hud.show_class_select(SaveSystem.has_save())
	if dev:
		dev.at_title(returning)

func _populate_bots() -> void:
	var names: Array = GameData.bot_names.duplicate()
	names.shuffle()
	var classes: Array = GameData.class_list()
	var k := 0
	for mid in GameData.maps:
		var md: MapDef = GameData.maps[mid]
		for i in range(md.bot_population):
			var cls: ClassDef = classes[randi() % classes.size()]
			var lv := randi_range(md.level_range.x, md.level_range.y)
			if md.is_town:
				lv = randi_range(1, 30)
			var pos := Sim.random_walkable(md, md.spawn_point if not md.is_town else md.town_center, 10.0)
			Sim.spawn_bot(cls, names[k % names.size()], mid, pos, lv)
			k += 1


## Chamado pela UI de seleção de classe
func start_game(cls: ClassDef, char_name: String, load_save: bool, look: Dictionary = {}, preset: int = 1) -> void:
	var data := SaveSystem.load_data() if load_save else {}
	var map_id := GameData.town_map_id()
	if load_save and data.has("class"):
		cls = GameData.classes.get(data["class"], cls)
		char_name = data.get("name", char_name)
		if GameData.maps.has(data.get("map", "")):
			map_id = data["map"]
	var p := Sim.spawn_player(cls, char_name, GameData.town_map_id(), look)
	if load_save and data.size() > 0:
		SaveSystem.apply_to(p, data)
		var pos: Array = data.get("pos", [0, 0] if map_id != p.map_id else [0, 8])
		Sim.place_loaded(p, map_id, Vector3(float(pos[0]), 0, float(pos[1])))
	elif preset > 1:
		Sim.apply_start_preset(p, preset)        # começo rápido (criação de personagem, MVP)
	_show_map(p.map_id)
	controller.set_physics_process(true)
	Sim.running = true
	started = true
	hud.on_game_started()
	if preset > 1 and not load_save:
		Events.notification.emit("Começo rápido (nível %d): a Capitã Mira manda você à Floresta. Portão leste do vale, depois o Ranger Teo." % p.level)
	else:
		Events.notification.emit("Bem-vindo a Aldara, %s! Fale com o Ancião Ravi (F) para começar." % char_name)
	Events.chat_message.emit("Sistema", "%s entrou no jogo." % char_name, "system")

func _process(delta: float) -> void:
	if not started:
		return
	perf_watch.tick(self, delta)
	if dev:
		dev.tick(delta)
	_fade_occluders(delta)
	_cull_t -= delta
	if _cull_t <= 0.0:
		_cull_t = 0.2
		_cull_views()
	_follow_torch()
	_autosave += delta
	if _autosave > 60.0:
		_autosave = 0.0
		SaveSystem.save_player(Sim.player)

# ---------------------------------------------------------------------------
## Bonecos longe do jogador (fora da tela) somem e param de processar (animação, placa de nome, barra);
## a sim continua rodando para eles. Voltam a aparecer ao chegar perto.
var VIEW_CULL_DIST := 58.0
var _cull_t := 0.0
var _cull_test := ""         # --cull_test=hide|noproc (medir: só esconde / só para de processar)

func _cull_views() -> void:
	if Sim.player == null or not views.has(Sim.player.id):
		return
	var at: Vector3 = Sim.player.position
	var lim2 := VIEW_CULL_DIST * VIEW_CULL_DIST
	for id in views:
		var v: EntityView = views[id]
		var e: SimEntity = v.entity
		var dx: float = e.position.x - at.x
		var dz: float = e.position.z - at.z
		var near: bool = id == Sim.player.id or dx * dx + dz * dz < lim2
		if near != v.visible or (_cull_test == "hide" and near != (v.process_mode != Node.PROCESS_MODE_DISABLED)):
			if _cull_test == "noproc":
				v.process_mode = Node.PROCESS_MODE_INHERIT if near else Node.PROCESS_MODE_DISABLED
				continue
			v.visible = near
			if _cull_test != "hide":
				v.process_mode = Node.PROCESS_MODE_INHERIT if near else Node.PROCESS_MODE_DISABLED
			if near:
				v._smooth_pos = e.position       # sem deslizar de onde sumiu
				v.position = e.position

# ---------------------------------------------------------------------------
## Obstáculos altos entre a câmera e o jogador ficam translúcidos (estilo ToS/RO).
func _fade_occluders(delta: float) -> void:
	if map_node == null or not map_node.has_meta("occluders") or not views.has(Sim.player.id):
		return
	var pv: Node3D = views[Sim.player.id]
	var ppos := pv.global_position + Vector3(0, 0.8, 0)
	var cpos := camera.cam.global_position
	var seg := ppos - cpos
	var seg_len := seg.length()
	var seg_dir := seg / maxf(seg_len, 0.01)
	for n in map_node.get_meta("occluders"):
		var node: Node3D = n
		var h: float = node.get_meta("occluder_h")
		var center := node.global_position + Vector3(0, h * 0.5, 0)
		var rel := center - cpos
		var along := rel.dot(seg_dir)
		var want := 0.0
		if along > 0.0 and along < seg_len + 1.0:
			var perp := (rel - seg_dir * along).length()
			if perp < 1.6 + h * 0.25:
				want = 0.72
		for c in node.get_children():
			if c is GeometryInstance3D:
				var tr: float = c.transparency
				if absf(tr - want) > 0.004:          # parado: não mexe (cada escrita atualiza a instância no render)
					c.transparency = lerpf(tr, want, minf(1.0, delta * 10.0)) if absf(tr - want) > 0.02 else want

func _show_map(map_id: String) -> void:
	if map_node:
		map_node.queue_free()
		map_node = null
	for id in views.keys():
		views[id].queue_free()
	views.clear()
	current_map_id = map_id
	var def: MapDef = GameData.maps[map_id]
	map_node = MapBuilder.build(def)
	world_root.add_child(map_node)
	map_node.add_child(GatherView.create(map_id))        # pontos de colheita (F)
	for e in Sim.map_entities(map_id):
		_create_view(e)
	fx.sync_loot_for_map()
	_update_vignette(def)
	if hud:
		hud.on_map_changed(def)

## Luz que o jogador carrega na dungeon: quente, acima da cabeça, alcança uma sala pequena.
func _torch() -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = "Torch"
	l.position = Vector3(0, 4.5, 0)
	l.light_color = MapBuilder.TORCH_COLOR
	l.light_energy = 7.0
	l.light_specular = 0.0          # sem reflexo: o brilho ficava no chão entre o jogador e a câmera
	l.omni_range = 14.0
	l.omni_attenuation = 1.0
	l.shadow_enabled = false
	l.top_level = true              # posição no mundo, seguindo o jogador em _follow_torch
	return l

func _follow_torch() -> void:
	if not views.has(Sim.player.id):
		return
	var pv: Node3D = views[Sim.player.id]
	var t: Node3D = pv.get_node_or_null("Torch")
	if t:
		t.global_position = Sim.player.position + Vector3(0, 3.5, 0)

## Bordas da tela escurecem na dungeon (o mundo aberto fica sem).
func _update_vignette(def: MapDef) -> void:
	if _vignette == null:
		var layer := CanvasLayer.new()
		layer.layer = 1           # acima do mundo, abaixo do HUD (10)
		add_child(layer)
		_vignette = ColorRect.new()
		_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
		_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;
uniform vec4 tint : source_color;
void fragment() {
	vec2 d = (UV - 0.5) * vec2(1.6, 1.0);
	COLOR = vec4(tint.rgb, smoothstep(0.42, 0.95, length(d)) * tint.a);
}"
		var mat := ShaderMaterial.new()
		mat.shader = sh
		_vignette.material = mat
		layer.add_child(_vignette)
	_vignette.visible = MapBuilder.is_dungeon(def)
	(_vignette.material as ShaderMaterial).set_shader_parameter("tint", Color(def.ambient.darkened(0.9), 0.85))

func _create_view(e: SimEntity) -> void:
	if views.has(e.id):
		return
	var v := EntityView.new()
	v.setup(e, e == Sim.player)
	views_root.add_child(v)
	views[e.id] = v
	if e == Sim.player:
		camera.target = v
		camera.global_position = v.global_position
		if MapBuilder.is_dungeon(GameData.maps[e.map_id]):
			v.add_child(_torch())

func _on_spawned(e: SimEntity) -> void:
	if e.map_id == current_map_id:
		_create_view(e)

func _on_despawned(id: int) -> void:
	if views.has(id):
		views[id].queue_free()
		views.erase(id)

func _on_changed_map(id: int, map_id: String) -> void:
	var e: SimEntity = Sim.get_entity(id)
	if e == Sim.player:
		_show_map(map_id)
		Events.notification.emit("— %s —" % GameData.maps[map_id].name)
		return
	if map_id == current_map_id:
		_create_view(e)
	else:
		_on_despawned(id)

func _on_equipment_changed(id: int) -> void:
	if views.has(id):
		views[id].refresh_equipment()

## Esc → "Salvar e voltar ao menu": salva, zera a sim e recarrega a cena (a tela inicial lista os personagens).
func return_to_menu() -> void:
	if started:
		SaveSystem.save_player(Sim.player)
	started = false
	returning = true
	Sim.reset_world()
	get_tree().reload_current_scene()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and started:
		SaveSystem.save_player(Sim.player)
