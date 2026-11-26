extends Node
## Main: liga simulação (Sim) e apresentação. Cria o mundo visual do mapa atual,
## views de entidades, câmera, controle do jogador, FX e UI.
## Entra pela tela inicial (game/menu/start.tscn), que deixa um `StartRequest`; Esc → volta para ela (design/ux/start-flow.md).
## Caminho do jogador: montagem em etapas, um pedaço por quadro, com progresso no Carregamento (§7);
## dev/autostart: montagem síncrona, sem nenhum `await` (o DevRunner arma corrotinas que contam com o mundo pronto).

const START_SCENE := "res://game/menu/start.tscn"
const DEV_RUNNER_SCRIPT := "res://game/dev/dev_runner.gd"   # carregado só com argumentos de dev (o grafo dele não compila no jogo normal)
const PORTRAIT_SCRIPT := "res://game/menu/portrait.gd"     # retrato do card (etapa C); pode não existir ainda
const PORTRAIT_FRAMES := 3            # Portrait.capture leva 2 quadros; +1 de folga antes de trocar de cena
const LOAD_VIEW_BUDGET_MS := 14.0     # ms/quadro de views durante o Carregamento (o overlay cobre o tranco)
const LOAD_VIEW_FRAMES := 120         # teto de quadros esperando as views de perto
const LOAD_MAP_BUDGET_MS := 24.0      # ms/quadro de Sim.load_map e de bots no Carregamento (vários por quadro)

var world_root: Node3D
var map_node: Node3D = null
var views_root: Node3D
var views: Dictionary = {}       # entity_id -> EntityView (pode faltar: a view nasce pela fila; sempre `views.has`/`get`)
var view_queue := ViewQueue.new()  # entidades do mapa ainda sem view (criadas aos poucos em _drain_views)
var camera: CameraRig
var controller: PlayerController
var fx: FxManager
var lock_marker: LockMarker
var hud                          # Hud (CanvasLayer)
var current_map_id: String = ""
var started := false
var start_req: StartRequest = null     # quem entra e como (vindo da tela inicial)
var _autosave := 0.0
var dev = null                    # DevRunner: modos de revisão/medição (só com argumentos depois de `--`); sem tipo de propósito (boot)
var perf_watch := PerfWatch.new()
var _vignette: ColorRect = null
var _failed := false
var _leaving := false             # return_to_menu em andamento (espera o retrato)
var boot_ms: Dictionary = {}      # etapa -> ms de trabalho da última montagem (BOOT; medição)

func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	_boot("main_enter", t0)          # desde o início do processo: autoloads + tela inicial + main.tscn
	WindowKeys.install(get_tree())   # F11 (vale também no menu e no Carregamento)
	Events.quest_completed.connect(_on_quest_done_visual)
	Engine.max_physics_steps_per_frame = 2     # quadro lento não vira bola de neve de ticks (a sim desacelera um pouco na batalha grande)
	SimSync.install(get_tree(), not DevArgs.has("--sim_sync"))     # sim numa thread enquanto o quadro desenha
	KeyBindings.load_settings()                         # teclas trocadas (Configurações → Controles), antes de ler input
	AccessSettings.load_settings()                      # tremor, clarões, avisos com padrão, efeitos dos aliados
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
	var sfx := Sfx.new()                     # efeitos sonoros (banco em assets/audio/sfx, volume no Esc)
	sfx.name = "Sfx"
	sfx.main = self
	add_child(sfx)
	var hit_react := HitReact.new()          # golpe forte: tronco do personagem inclina; chefe com postura (C3 2026-11-23)
	hit_react.name = "HitReact"
	hit_react.main = self
	add_child(hit_react)
	var music := Music.new()                # música por lugar, chefe e investida (assets/audio/music, volume no Esc)
	music.name = "Music"
	music.main = self
	add_child(music)
	var festival := FestivalFx.new()          # fogos nas praças depois do Lich (fim do Ato I)
	festival.name = "FestivalFx"
	festival.main = self
	world_root.add_child(festival)
	var recall_fx := RecallFx.new()          # coluna de luz da volta à cidade (G)
	recall_fx.name = "RecallFx"
	world_root.add_child(recall_fx)
	controller = PlayerController.new()
	controller.name = "PlayerController"
	controller.camera = camera
	controller.set_physics_process(false)
	add_child(controller)
	hud = load("res://game/ui/hud.gd").new()
	hud.main = self
	add_child(hud)
	lock_marker = LockMarker.new()           # Tab: marca dourada no chefe travado (BossLock)
	lock_marker.name = "LockMarker"
	lock_marker.main = self
	world_root.add_child(lock_marker)
	var dash_gauge := DashGauge.new()          # Shift: gomos da recarga do dash nos pés do jogador (+ pista de pronto)
	dash_gauge.name = "DashGauge"
	dash_gauge.main = self
	world_root.add_child(dash_gauge)
	controller.lock_changed.connect(_on_lock_changed)

	start_req = StartRequest.take()
	if start_req == null:                    # main.tscn aberto direto: decide como a tela inicial decidiria
		var cls: String = load(DEV_RUNNER_SCRIPT).autostart_class(DevArgs.all(), false) if DevArgs.any() else ""
		if cls == "":
			get_tree().change_scene_to_file.call_deferred(START_SCENE)
			return
		start_req = StartRequest.dev_start(cls, int(DevArgs.value("--preset", "1")))
	Events.entity_spawned.connect(_on_spawned)
	Events.entity_despawned.connect(_on_despawned)
	Events.entity_changed_map.connect(_on_changed_map)
	Events.equipment_changed.connect(_on_equipment_changed)
	_boot("main_nodes", Time.get_ticks_msec() - t0)
	if DevArgs.any():
		dev = load(DEV_RUNNER_SCRIPT).new()
		dev.name = "Dev"
		dev.main = self
		add_child(dev)
	if start_req.dev:
		_enter_sync()
	else:
		_enter_staged()                      # corrotina: o _ready volta já, o resto sai quadro a quadro

## Partida automática de dev/smoke: tudo neste quadro, como antes (nenhum `await` aqui dentro).
func _enter_sync() -> void:
	var t0 := Time.get_ticks_msec()
	build_world(false)
	if dev:
		dev.before_start(false)     # chaves de medição; tour/bancada só na partida automática
	SaveSystem.slot = start_req.slot         # -1 = partida de teste/revisão: nunca grava por cima de um personagem
	var cls_def: ClassDef = GameData.classes.get(start_req.class_id, GameData.classes["paladin"])
	start_game(cls_def, start_req.char_name, start_req.load_save, start_req.look, start_req.preset)     # preset 10...: começo rápido
	_boot("world_total", Time.get_ticks_msec() - t0)
	_ready_done()
	if dev:
		dev.after_start()

## Caminho do jogador: etapas com progresso (LoadingScreen.STEPS); falha volta a Personagens.
func _enter_staged() -> void:
	var t0 := Time.get_ticks_msec()
	if dev:
		dev.before_start(true)               # não é partida automática: só as chaves de medição
	_progress(&"prepare", 0.0)
	await get_tree().process_frame
	await build_world(true)
	if _failed:
		return
	SaveSystem.slot = start_req.slot
	var data := {}
	if start_req.load_save:
		data = SaveSystem.load_data()
		if data.is_empty():
			_fail("save do espaço %d vazio ou danificado" % start_req.slot)
			return
	if DevArgs.has("--loading_fail"):        # revisão: força a falha (volta a Personagens com a faixa vermelha)
		_fail("falha forçada (--loading_fail)")
		return
	var t := Time.get_ticks_msec()
	_progress(&"player", 0.0)
	var cls_def: ClassDef = GameData.classes.get(start_req.class_id, GameData.classes["paladin"])
	var p := _spawn_player(cls_def, start_req.char_name, start_req.load_save, start_req.look, start_req.preset, data)
	_boot("player", Time.get_ticks_msec() - t)
	_progress(&"assets", 0.0)
	await _await_loads()                     # GLB do mapa/kit e main.tscn (em thread desde o começo do Carregamento)
	if _failed:
		return
	if not GameData.maps.has(p.map_id):
		_fail("mapa '%s' não existe" % p.map_id)
		return
	_progress(&"map_build", 0.0)
	await get_tree().process_frame           # o texto da etapa aparece antes do quadro pesado
	t = Time.get_ticks_msec()
	_show_map(p.map_id)
	_boot("map_build", Time.get_ticks_msec() - t)
	if map_node == null:
		_fail("mapa '%s' não montou" % p.map_id)
		return
	await _settle_views()
	_go_live(p, start_req.char_name, start_req.load_save, start_req.preset)
	_boot("world_total", Time.get_ticks_msec() - t0, "wall")
	_ready_done()

## Mundo pronto: o Carregamento segura 100% e some; as cargas em thread já foram usadas.
func _ready_done() -> void:
	if start_req.loading and is_instance_valid(start_req.loading):
		start_req.loading.call("finish")
	start_req.held.clear()

## Monta o mundo: todos os mapas na sim (o "servidor" simula tudo) e os bots.
## `staged` = caminho do jogador: vários quadros (mapas da sim em fatias de LOAD_MAP_BUDGET_MS), progresso no Carregamento.
## Use com `await` quando staged; sem staged roda inteira na hora, sem `await`.
func build_world(staged: bool) -> void:
	var t0 := Time.get_ticks_msec()
	var work := 0
	var ids: Array = GameData.maps.keys()
	var slice := Time.get_ticks_msec()
	for i in ids.size():
		var tm := Time.get_ticks_msec()
		Sim.load_map(GameData.maps[ids[i]])
		work += Time.get_ticks_msec() - tm
		if staged and Time.get_ticks_msec() - slice >= LOAD_MAP_BUDGET_MS:
			_progress(&"sim_maps", float(i + 1) / ids.size())
			await get_tree().process_frame
			slice = Time.get_ticks_msec()
	_boot("sim_maps", work, "wall=%d mapas=%d" % [Time.get_ticks_msec() - t0, ids.size()])
	if staged:
		_progress(&"bots", 0.0)
		await get_tree().process_frame
	var t := Time.get_ticks_msec()
	var bot_work: int = await _populate_bots(staged)
	_boot("bots", bot_work, "wall=%d entidades=%d" % [Time.get_ticks_msec() - t, Sim.entities.size()])

## Bots de todos os mapas (o passo mais caro da montagem: ~17 s headless com 380 bots). `staged` = fatias de
## LOAD_MAP_BUDGET_MS por quadro com progresso. Devolve os ms de trabalho (sem as esperas de quadro).
func _populate_bots(staged: bool = false) -> int:
	var names: Array = GameData.bot_names.duplicate()
	names.shuffle()
	var classes: Array = GameData.class_list()
	var total := 0
	for mid in GameData.maps:
		total += (GameData.maps[mid] as MapDef).bot_population
	var k := 0
	var work := 0
	var slice := Time.get_ticks_msec()
	for mid in GameData.maps:
		var md: MapDef = GameData.maps[mid]
		for i in range(md.bot_population):
			var tm := Time.get_ticks_msec()
			var cls: ClassDef = classes[randi() % classes.size()]
			var band := BotBandSystem.spawn_levels(md)        # cidade também nasce na faixa dela (antes: 1-30 em Aldara)
			var lv := randi_range(band.x, band.y)
			var pos := Sim.random_walkable(md, md.spawn_point, 10.0)
			if md.is_town:                                     # espalhados pelos pontos de encontro, não todos na praça
				pos = Sim.random_walkable(md, BotBandSystem.spawn_spot(md, i), 2.0)
			Sim.mvp_bot_showcase(Sim.spawn_bot(cls, names[k % names.size()], mid, pos, lv))     # parte já monta o bicho de um MVP (vitrine)
			k += 1
			work += Time.get_ticks_msec() - tm
			if staged and Time.get_ticks_msec() - slice >= LOAD_MAP_BUDGET_MS:
				_progress(&"bots", float(k) / maxi(1, total))
				await get_tree().process_frame
				slice = Time.get_ticks_msec()
	return work

## Espera as cargas em thread do pedido (LoadingScreen.begin) e guarda os Resources em `held` até o "pronto":
## MapBuilder.build/KitModel.create chamam `load()` e só acertam o cache enquanto há referência viva.
func _await_loads() -> void:
	var t0 := Time.get_ticks_msec()
	var paths: PackedStringArray = start_req.load_paths
	for i in paths.size():
		var path := paths[i]
		var progress := []
		var st := ResourceLoader.load_threaded_get_status(path, progress)
		while st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			var sub := (float(i) + (float(progress[0]) if progress.size() > 0 else 0.0)) / paths.size()
			_progress(&"assets", sub)
			await get_tree().process_frame
			st = ResourceLoader.load_threaded_get_status(path, progress)
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			start_req.held.append(ResourceLoader.load_threaded_get(path))
		elif st == ResourceLoader.THREAD_LOAD_FAILED:
			_fail("carga em thread falhou: %s" % path)
			return
		# INVALID_RESOURCE: nunca foi pedido (ou já foi entregue): o `load()` normal cuida
	_progress(&"assets", 1.0)
	_boot("assets_wait", Time.get_ticks_msec() - t0, "arquivos=%d" % paths.size())

## Cria as views de perto com orçamento maior (o overlay cobre); para quando não há mais ninguém perto na fila.
func _settle_views() -> void:
	var t0 := Time.get_ticks_msec()
	var keep := view_budget_ms
	if view_budget_ms > 0.0:
		view_budget_ms = maxf(view_budget_ms, LOAD_VIEW_BUDGET_MS)
	var total := maxi(1, views_pending_near())
	for f in LOAD_VIEW_FRAMES:
		var left := views_pending_near()
		_progress(&"views", 1.0 - float(left) / total)
		if left == 0:
			break
		_queue_dirty = true
		await get_tree().process_frame      # _process -> _drain_views
	view_budget_ms = keep
	_boot("views", Time.get_ticks_msec() - t0, "views=%d fila=%d" % [views.size(), view_queue.size()])

## Progresso da etapa `id` (LoadingScreen.STEPS) com `sub` 0..1 dentro dela.
func _progress(id: StringName, sub: float) -> void:
	if start_req and start_req.loading and is_instance_valid(start_req.loading):
		start_req.loading.call("set_step", id, sub)

## Montagem falhou: nada é gravado, a sim volta a vazia e o Carregamento leva de volta a Personagens.
func _fail(msg: String) -> void:
	_failed = true
	started = false
	push_error("Carregamento: %s" % msg)
	Sim.reset_world()
	start_req.held.clear()
	start_req.drop_loads()                   # falha antes de _await_loads: as cargas em thread não ficam presas no ResourceLoader
	if start_req.loading and is_instance_valid(start_req.loading):
		start_req.loading.call("fail", msg)
	else:
		LoadingScreen.back_to_menu(get_tree(), msg, start_req)

## Marca de tempo da montagem: `BOOT <etapa> <ms> [extra]` (os pesos da barra saem daqui; design/ux/start-flow.md §7).
func _boot(step: String, ms: int, extra: String = "") -> void:
	boot_ms[step] = ms
	print("BOOT %s %d%s" % [step, ms, (" " + extra) if extra != "" else ""])


## Chamado pela UI de seleção de classe (e pela partida automática): tudo de uma vez.
func start_game(cls: ClassDef, char_name: String, load_save: bool, look: Dictionary = {}, preset: int = 1) -> void:
	var data := SaveSystem.load_data() if load_save else {}
	var t := Time.get_ticks_msec()
	var p := _spawn_player(cls, char_name, load_save, look, preset, data)
	_boot("player", Time.get_ticks_msec() - t)
	t = Time.get_ticks_msec()
	_show_map(p.map_id)
	_boot("map_build", Time.get_ticks_msec() - t, "views=%d fila=%d" % [views.size(), view_queue.size()])
	_go_live(p, char_name, load_save, preset)

## Nasce o jogador na sim (save aplicado ou começo rápido), ainda sem visual.
func _spawn_player(cls: ClassDef, char_name: String, load_save: bool, look: Dictionary, preset: int, data: Dictionary) -> SimEntity:
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
	if not (load_save and data.size() > 0):
		UnlockSystem.setup(p, start_req.knows_game if start_req else true)     # introdução dos sistemas (Criação)
	Sim.roster_start()          # Bots com Memória: elenco do save (ou sorteado dos bots de agora), antes das vistas do mapa
	return p

## O jogo começa: controle, sim rodando, HUD e boas-vindas.
func _go_live(p: SimEntity, char_name: String, load_save: bool, preset: int) -> void:
	if current_map_id != p.map_id:
		_show_map(p.map_id)
	controller.set_physics_process(true)
	Sim.running = true
	started = true
	hud.on_game_started()
	if load_save:
		char_name = p.name
	# boas-vindas: a de Aldara só no personagem novo (nasce na praça, nível 1); save carregado pode estar em qualquer
	# mapa e nível. Partida de revisão (--autostart) não mostra (a foto vai a outro mapa/nível), salvo com --welcome
	var review := SaveSystem.slot == -1 and DevArgs.any() and not DevArgs.has("--welcome")
	if load_save:
		Events.notification.emit("Bem-vindo de volta, %s!" % char_name)
	elif review:
		pass
	elif preset > 1:
		Events.notification.emit(str(StartCatalog.PRESETS.get(preset, {}).get("welcome", "Começo rápido (nível %d)." % p.level)))
	else:
		Events.notification.emit("Bem-vindo a Aldara, %s! Fale com o Ancião Ravi (F) para começar." % char_name)
	Events.chat_message.emit("Sistema", "%s entrou no jogo." % char_name, "system")

## Salva o personagem em jogo e tira o retrato do card (pontos de salvar: autosave, Esc → Salvar/Sair, fechar).
## O hud chama isto no lugar de `SaveSystem.save_player(Sim.player)`. O retrato leva 2 quadros e não é esperado aqui:
## antes de trocar de cena use `return_to_menu` (que espera).
func save_game() -> void:
	if Sim.player == null:
		return
	_portrait()
	SaveSystem.save_player(Sim.player)

## Gancho do retrato (game/menu/portrait.gd, etapa C): `Portrait.capture(view, slot)`, corrotina de 2 quadros. Sem o
## arquivo, sem a função, em partida de teste (espaço -1) ou sem tela (headless), não faz nada. true = pediu a foto.
func _portrait() -> bool:
	if SaveSystem.slot < 0 or Sim.player == null or not views.has(Sim.player.id) or DisplayServer.get_name() == "headless":
		return false
	if not ResourceLoader.exists(PORTRAIT_SCRIPT):
		return false
	var s: Script = load(PORTRAIT_SCRIPT)
	if s == null:
		return false
	for m in s.get_script_method_list():
		if str(m.get("name", "")) == "capture":
			s.call("capture", views[Sim.player.id], SaveSystem.slot)
			return true
	return false

func _process(delta: float) -> void:
	_drain_views()
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
		NameplateCrowd.update(views, Sim.player, controller.aim_point if controller else Vector3.INF)     # matilha densa: nomes dos comuns somem
		_hide_labels_under_hud()
	_sync_name_size()
	_follow_torch()
	_autosave += delta
	if _autosave > 60.0:
		_autosave = 0.0
		save_game()

# ---------------------------------------------------------------------------
## Bonecos longe do jogador (fora da tela) somem e param de processar (animação, placa de nome, barra);
## a sim continua rodando para eles. Voltam a aparecer ao chegar perto.
var VIEW_CULL_DIST := 58.0
var _cull_t := 0.0
var _cull_test := ""         # --cull_test=hide|noproc (medir: só esconde / só para de processar)
## Criar bonecos custa ms na thread principal (kit + fusão): a 1ª leva de um spawner ou a chegada num mapa cheio
## travava o quadro (100+ views de uma vez). Cada quadro cria views da fila até gastar este orçamento, as do grupo/alvo
## primeiro e depois a mais perto; quem está além de VIEW_CULL_DIST + VIEW_QUEUE_MARGIN espera chegar perto.
## 0 = tudo de uma vez e sem esperar a distância (como antes; revisões com foto, `--view_budget=<ms>`).
var view_budget_ms := 3.5
const VIEW_QUEUE_MARGIN := 8.0
var _queue_dirty := false
var map_build_ms := 0.0      # último _show_map (medição: --perf)

func _cull_views() -> void:
	if Sim.player == null or not views.has(Sim.player.id):
		return
	var at: Vector3 = Sim.player.position
	var lim2 := VIEW_CULL_DIST * VIEW_CULL_DIST
	if view_queue.size() > 0:
		_queue_dirty = true          # quem esperava longe pode ter chegado perto
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

## Zoom mudou: pixel_size dos nomes acompanha (EntityView.name_pixel_size); só escreve na troca.
var _name_dist := -1.0
func _sync_name_size() -> void:
	if camera == null or is_equal_approx(camera.distance, _name_dist):
		return
	_name_dist = camera.distance
	EntityView.name_px = EntityView.name_pixel_size(_name_dist)
	for id in views:
		(views[id] as EntityView).apply_name_size()

## Nomes do mundo (bonecos e portas de casa) cujo ponto na tela cai sob a HUD somem (R2 #16). Passada a cada 0,2 s.
func _hide_labels_under_hud() -> void:
	if hud == null or camera == null or camera.cam == null:
		return
	var rects: Array[Rect2] = hud.label_blockers()
	var cam: Camera3D = camera.cam
	for id in views:
		var v: EntityView = views[id]
		if not v.visible or v.nameplate == null:
			continue
		var gp := v.nameplate.global_position
		v.set_hud_hidden(not cam.is_position_behind(gp) and Hud.covered(cam.unproject_position(gp), rects))
	if map_node and map_node.has_meta("door_labels"):
		for l in map_node.get_meta("door_labels"):
			var dl := l as Label3D
			if is_instance_valid(dl):
				dl.visible = cam.is_position_behind(dl.global_position) or not Hud.covered(cam.unproject_position(dl.global_position), rects)

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
		var parts: Array = [node] if node is GeometryInstance3D else node.get_children()      # peça do GLB da zona: ela mesma
		for c in parts:
			if c is GeometryInstance3D:
				var tr: float = c.transparency
				if absf(tr - want) > 0.004:          # parado: não mexe (cada escrita atualiza a instância no render)
					c.transparency = lerpf(tr, want, minf(1.0, delta * 10.0)) if absf(tr - want) > 0.02 else want

## Quest concluída: o mapa atual se atualiza (front limpo, acampamento que some).
func _on_quest_done_visual(_eid: int, _qid: String) -> void:
	if map_node:
		MapBuilder.apply_conquest(map_node)

func _show_map(map_id: String) -> void:
	var t0 := Time.get_ticks_usec()
	if map_node:
		map_node.queue_free()
		map_node = null
	for id in views.keys():
		views[id].queue_free()
	views.clear()
	view_queue.clear()
	current_map_id = map_id
	var def: MapDef = GameData.maps[map_id]
	map_node = MapBuilder.build(def)
	world_root.add_child(map_node)
	map_node.add_child(GatherView.create(map_id))        # pontos de colheita (F)
	map_node.add_child(AmbientLife.create(map_id))       # bichos de ambiente e falas soltas dos NPCs (só visual)
	map_node.add_child(SiegeFx.create(map_id))           # fumaça e fogo do Cerco Vivo (marcadores do JSON da zona)
	for e in Sim.map_entities(map_id):                   # o jogador na hora; o resto pela fila, os de perto já neste quadro
		if e == Sim.player:
			_create_view(e)
		else:
			view_queue.push(e)
	_queue_dirty = true
	_drain_views()
	map_build_ms = (Time.get_ticks_usec() - t0) / 1000.0
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
	view_queue.erase(e.id)
	if views.has(e.id):
		return
	var v := EntityView.new()
	v.setup(e, e == Sim.player)
	views_root.add_child(v)
	views[e.id] = v
	v.snap_visual_state()        # nasceu depois dos eventos: forma/aura do jeito que a entidade está agora
	fx.sync_entity_visuals(e)
	if e != Sim.player and Sim.player and views.has(Sim.player.id):     # já nasce no estado do corte (longe = some e para)
		var d: Vector3 = e.position - Sim.player.position
		if d.x * d.x + d.z * d.z >= VIEW_CULL_DIST * VIEW_CULL_DIST and _cull_test == "":
			v.visible = false
			v.process_mode = Node.PROCESS_MODE_DISABLED
	if e == Sim.player:
		camera.target = v
		camera.global_position = v.global_position
		if MapBuilder.is_dungeon(GameData.maps[e.map_id]):
			v.add_child(_torch())

func _on_spawned(e: SimEntity) -> void:
	if e.map_id == current_map_id:
		_queue_view(e)

## Jogador ganha a view na hora; os outros entram na fila (_drain_views).
func _queue_view(e: SimEntity) -> void:
	if e == Sim.player:
		_create_view(e)
	elif not views.has(e.id):
		view_queue.push(e)
		_queue_dirty = true

## Cria views da fila até gastar `view_budget_ms` neste quadro (pelo menos 1). Ordem: grupo do jogador, suas invocações
## e o último alvo; depois a mais perto do jogador (na tela de título, da câmera).
func _drain_views() -> void:
	if not _queue_dirty or view_queue.size() == 0:
		return
	var p := Sim.player
	var mine := p != null and p.map_id == current_map_id
	var at: Vector3 = p.position if mine else camera.global_position
	var prio := {}
	if mine:
		for m in Sim.party_members(p):
			prio[(m as SimEntity).id] = true
		prio[p.id] = true
		if p.last_target_id >= 0:
			prio[p.last_target_id] = true
	var unlimited := view_budget_ms <= 0.0
	var list := view_queue.ready_list(current_map_id, at, INF if unlimited else VIEW_CULL_DIST + VIEW_QUEUE_MARGIN, prio)
	var t0 := Time.get_ticks_usec()
	var budget := int(view_budget_ms * 1000.0)
	var made := 0
	for i in list.size():
		if made > 0 and not unlimited and Time.get_ticks_usec() - t0 > budget:
			return                   # continua no próximo quadro
		var e: SimEntity = list[i]
		if Sim.get_entity(e.id) != e or e.map_id != current_map_id:
			view_queue.erase(e.id)   # sumiu ou saiu do mapa sem evento visto
			continue
		_create_view(e)
		made += 1
	_queue_dirty = false

## Medição (--perf): quantos da fila já poderiam ganhar view (perto do jogador).
func views_pending_near() -> int:
	if view_queue.size() == 0:
		return 0
	var at: Vector3 = Sim.player.position if Sim.player else camera.global_position
	return view_queue.ready_list(current_map_id, at, INF if view_budget_ms <= 0.0 else VIEW_CULL_DIST + VIEW_QUEUE_MARGIN, {}).size()

func _on_despawned(id: int) -> void:
	view_queue.erase(id)
	if views.has(id):
		views[id].queue_free()
		views.erase(id)

func _on_changed_map(id: int, map_id: String) -> void:
	var e: SimEntity = Sim.get_entity(id)
	if e == Sim.player:
		_show_map(map_id)
		Events.notification.emit("— %s —" % GameData.maps[map_id].name)
		return
	if e and map_id == current_map_id:
		_queue_view(e)
	else:
		_on_despawned(id)

func _on_equipment_changed(id: int) -> void:
	if views.has(id):
		views[id].refresh_equipment()

## Esc → "Salvar e voltar ao menu": retrato (espera os quadros dele com o boneco vivo), salva, zera a sim e troca para
## a tela inicial (abre em Personagens).
func return_to_menu() -> void:
	if _leaving:
		return
	_leaving = true
	if started:
		controller.set_physics_process(false)
		if _portrait():
			for i in PORTRAIT_FRAMES:
				await get_tree().process_frame
		SaveSystem.save_player(Sim.player)
	started = false
	StartRequest.returning = true
	StartRequest.last_slot = SaveSystem.slot
	Sim.reset_world()
	get_tree().change_scene_to_file(START_SCENE)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and started:
		save_game()

## Trava no chefe mudou (Tab ou solta sozinha): marcador no mundo + etiqueta no HUD.
func _on_lock_changed(target_id: int) -> void:
	lock_marker.set_target(target_id)
	hud.set_lock(target_id)
