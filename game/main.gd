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
var _smoke_test := false
var _smoke_t := 0.0
var _shot_path := ""
var _shot_done := false
var _vignette: ColorRect = null
var _tour_dir := ""          # --tour=<pasta>: screenshots pelos POIs da zona e sai
var _tour_i := 0
var _tour_t := 0.0
var _tour_map := "city_aldara"
var showcase: Showcase = null     # --showcase=<classe|all> [--skill=<id>] --out=<pasta> [--check]: bancada de skills
const TOURS := {
	"dg_gruta": [["entrada", Vector3(0, 0, 40)], ["salao", Vector3(-20, 0, 22)], ["chefe", Vector3(8, 0, -30)]],
	"dg_catacumbas": [["entrada", Vector3(0, 0, 40)], ["vestibulo", Vector3(0, 0, 22)], ["oeste", Vector3(-30, 0, 18)], ["capitao", Vector3(-24, 0, -32)], ["alcova", Vector3(30, 0, 40)], ["viuva", Vector3(24, 0, -32)], ["selo", Vector3(0, 0, -6)]],
	"dg_catacumbas_trono": [["galeria", Vector3(0, 0, 18)], ["trono", Vector3(0, 0, -14)]],
	"dg_ninho": [["entrada", Vector3(0, 0, 40)], ["salao", Vector3(20, 0, 22)], ["chefe", Vector3(-8, 0, -30)]],
	"dg_cripta": [["entrada", Vector3(0, 0, 40)], ["salao", Vector3(-20, 0, 22)], ["chefe", Vector3(8, 0, -30)]],
	"field_forest": [["herborista", Vector3(-41, 0, 38)], ["cacador", Vector3(62, 0, -14)], ["emboscada", Vector3(38, 0, 88)], ["circulo", Vector3(-27, 0, -92)], ["ninho", Vector3(-60, 0, 86)],
		["hub", Vector3(0, 0, 5)], ["chegada", Vector3(-100, 0, 9)], ["ponte", Vector3(26, 0, -6)],
		["bandidos_portao", Vector3(52, 0, -40)], ["bandidos_centro", Vector3(66, 0, -56)], ["aranhas", Vector3(-50, 0, -50)],
		["ents", Vector3(56, 0, 54)], ["arvore_mae", Vector3(8, 0, -76)], ["pantano", Vector3(-30, 0, 66)],
		["borda_norte", Vector3(-18, 0, -104)], ["borda_leste", Vector3(94, 0, 25)]],
	"field_ruins": [["coveiro", Vector3(60, 0, -6)], ["escavacao", Vector3(60, 0, 94)], ["patrulha", Vector3(-76, 0, -32)], ["obelisco", Vector3(38, 0, 49)], ["cripta", Vector3(20, 0, -80)],
		["hub", Vector3(0, 0, 5)], ["chegada", Vector3(94, 0, -5)], ["altar", Vector3(-72, 0, -12)],
		["cemiterio", Vector3(52, 0, -42)], ["bairro", Vector3(4, 0, 60)], ["pantano", Vector3(-6, 0, -62)],
		["pedreira", Vector3(-56, 0, 48)], ["zigurate", Vector3(40, 0, -76)], ["ponte", Vector3(-38, 0, -6)],
		["borda_sul", Vector3(-10, 0, 112)], ["borda_oeste", Vector3(-107, 0, -39)]],
}
const TOUR := [["anciao", Vector3(2, 0, -8)], ["lenhador", Vector3(-92, 0, -46)], ["eremita", Vector3(47, 0, 96)], ["covil", Vector3(-20, 0, -48)], ["marco", Vector3(-54, 0, 78)], ["gruta", Vector3(84, 0, -29)],
	["hub", Vector3(0, 0, 4)], ["portao_sul", Vector3(0, 0, 38)], ["lago", Vector3(6, 0, 58)],
	["bosque", Vector3(66, 0, 8)], ["colinas", Vector3(-4, 0, -68)], ["clareira", Vector3(-70, 0, 26)],
	["castelo", Vector3(28, 0, -38)], ["ponte", Vector3(-47, 0, 9)], ["fazenda", Vector3(-48, 0, 58)],
	["portal_floresta", Vector3(94, 0, -28)], ["portal_ruinas", Vector3(-94, 0, -26)],
	["borda_norte", Vector3(0, 0, -111)], ["borda_leste", Vector3(107, 0, 39)], ["borda_sudoeste", Vector3(-58, 0, 100)]]

const WINDOWED_SIZE := Vector2i(1920, 1080)

## F11: tela cheia <-> janela 1920x1080 centralizada (começa em tela cheia, ver project.godot).
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
	# tela grande (ultrawide, 1440p+): já tem pixel de sobra; render acima de 100% só custa GPU
	var scr := DisplayServer.screen_get_size()
	if scr.x * scr.y >= 2560 * 1300:
		get_viewport().scaling_3d_scale = 1.0
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
	# smoke test headless:  godot --headless --path . -- --autostart=berserker [--screenshot=/tmp/x.png]
	var autostart := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			_shot_path = arg.get_slice("=", 1)
		if arg.begins_with("--tour_map="):
			_tour_map = arg.get_slice("=", 1)
		if arg.begins_with("--tour="):
			_tour_dir = arg.get_slice("=", 1)
			autostart = "paladin"
		if arg.begins_with("--autostart"):
			autostart = arg.get_slice("=", 1) if "=" in arg else "paladin"
		if arg.begins_with("--showcase="):
			var sc_cls := arg.get_slice("=", 1)
			autostart = sc_cls if GameData.classes.has(sc_cls) else "paladin"
			var sc_skill := ""
			var sc_out := ""
			var sc_check := false
			for a2 in OS.get_cmdline_user_args():
				if a2.begins_with("--skill="): sc_skill = a2.get_slice("=", 1)
				if a2.begins_with("--out="): sc_out = a2.get_slice("=", 1)
				if a2 == "--check": sc_check = true
			showcase = Showcase.new()
			showcase.setup(self, sc_cls, sc_skill, sc_out, sc_check)
	if "--no_prune" in OS.get_cmdline_user_args():
		KitModel.prune = false
	if "--no_away" in OS.get_cmdline_user_args():
		Sim.away_every = 1
	for arg in OS.get_cmdline_user_args():
		if arg == "--no_merge":
			KitModel.merge = false
			RigidMerge.enabled = false
		if arg.begins_with("--cull_test="):
			_cull_test = arg.get_slice("=", 1)
		if arg == "--anim_test":
			EntityView.anim_test = true
		if arg == "--no_anim_lod":
			EntityView.anim_lod = false
		if arg.begins_with("--cull="):        # medir: distância de corte dos bonecos
			VIEW_CULL_DIST = float(arg.get_slice("=", 1))
		if arg.begins_with("--soak_map="):
			_soak_map = arg.get_slice("=", 1)
		if arg.begins_with("--soak="):        # joga sozinho (cérebro de bot) por N s e imprime FPS/nós/memória a cada 5 s
			_soak_left = float(arg.get_slice("=", 1))
			autostart = "berserker" if autostart == "" else autostart
		if arg.begins_with("--gather_shot="):   # colhendo minério e erva (fotos <png>_ore.png / <png>_herb.png)
			_gather_shot.call_deferred(arg.get_slice("=", 1))
		if arg.begins_with("--title_shot="):    # foto da tela de criação com uma classe escolhida (revisar o layout)
			_title_shot.call_deferred(arg.get_slice("=", 1))
		if arg == "--perf":                 # mede a cidade cheia por ~8 s e sai (FPS, draw calls, nós, tempo da sim)
			autostart = "paladin"
			_perf_run()
	if returning:
		autostart = ""
		_tour_dir = ""
		showcase = null
	if autostart != "":
		SaveSystem.slot = -1                 # partida de teste/revisão nunca grava por cima de um personagem
		start_game(GameData.classes.get(autostart, GameData.classes["paladin"]), "Smoke", false)
		if "--return_check" in OS.get_cmdline_user_args():      # revisão: menu do Esc (foto) e "voltar ao menu"
			_smoke_test = false
			_menu_check()
			return
		_smoke_test = showcase == null and not ("--perf" in OS.get_cmdline_user_args())
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--block_shot="):      # fotos do bloqueio e do aparar (escudo: --shield=<id>)
				_smoke_test = false
				_block_shot(arg.get_slice("=", 1))
		if showcase:
			camera.distance = 9.0
			add_child(showcase)
		if "--mount" in OS.get_cmdline_user_args():      # começa a cavalo (revisar a montaria)
			Sim.player.mounted = true
		if "--loot_demo" in OS.get_cmdline_user_args():  # amostra de drops ao lado do jogador (revisar o baú)
			_smoke_test = false
			var lm: Dictionary = Sim.maps[Sim.player.map_id]
			var samples := ["gold", "legend_coin", "slime_gel", "sword_iron", "leg_paladin_guardiao_30_head"]
			for i in range(samples.size()):
				if samples[i] == "gold" or GameData.items.has(samples[i]):
					var lp: Vector3 = Sim.player.position + Vector3(-2.4 + i * 1.2, 0, 2.0)
					lm["loot"].append({"pos": lp, "item": samples[i], "count": 1, "timer": 999.0, "owner": -1, "free_at": 0.0})
					Events.loot_dropped.emit(Sim.player.map_id, lp, samples[i], 1)
			var king := Sim.spawn_monster(Sim.elite_def(GameData.monsters["slime"]), Sim.player.map_id, Sim.player.position + Vector3(3.5, 0, -2.5))
			king.brain = null                     # Rei Slime parado ao lado (revisar tamanho e cor)
			king.hp = king.stats.max_hp * 0.3     # barras de vida: Rei a 30%, jogador a 50%
			king.aggro_target = Sim.player.id
			Sim.player.hp = Sim.player.stats.max_hp * 0.5
			# itens entrando na bolsa: aparece o aviso de "pegou" com a arte
			get_tree().create_timer(1.6).timeout.connect(func(): Sim.player.add_item("wolf_pelt", 3); Sim.player.add_item("sword_iron", 1); Sim.player.add_item("potion_mp_m", 2))
			_demo_shot()
		# --gear=<set_id>: começa vestindo um conjunto (revisar visual/ícones do lendário no smoke)
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--gear="):
				var sd: SetDef = GameData.sets.get(arg.get_slice("=", 1))
				if sd:
					Sim.player.level = maxi(Sim.player.level, sd.level)
					for iid in sd.pieces:
						Sim.player.add_item(iid)
						Sim.equip(Sim.player, iid, iid.ends_with("_offhand") and GameData.items[iid].weapon_type != "shield")
					for fa in OS.get_cmdline_user_args():      # --form=wolf|bear: já começa transformado (revisar a forma do Druida)
						if fa.begins_with("--form="):
							Sim._apply_effects(Sim.player, Sim.player, {"form": fa.get_slice("=", 1)}, 1.0)
					if "--mace" in OS.get_cmdline_user_args() and not sd.alt_pieces.is_empty():     # --mace: a maça do conjunto no lugar da espada
						Sim.player.add_item(sd.alt_pieces[0])
						Sim.equip(Sim.player, sd.alt_pieces[0], false)
			if arg.begins_with("--bag_shot="):      # foto da bolsa e da ficha com uma amostra de cada tipo de item
				_smoke_test = false
				_bag_shot(arg.get_slice("=", 1))
		return
	hud.show_class_select(SaveSystem.has_save())
	if returning and "--return_check" in OS.get_cmdline_user_args():     # revisão: foto da tela inicial depois de voltar
		await get_tree().create_timer(1.5).timeout
		var shot := ""
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--return_shot="):
				shot = arg.get_slice("=", 1)
		if shot != "":
			get_viewport().get_texture().get_image().save_png(shot)
		print("RETURN_CHECK ok entities=%d maps=%d player=%s" % [Sim.entities.size(), Sim.maps.size(), str(Sim.player != null)])
		get_tree().quit()
	for arg in OS.get_cmdline_user_args():      # --select_shot=<png>: foto da tela de classes e sai
		if arg.begins_with("--select_shot="):
			await get_tree().create_timer(2.0).timeout
			get_viewport().get_texture().get_image().save_png(arg.get_slice("=", 1))
			get_tree().quit()

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
func start_game(cls: ClassDef, char_name: String, load_save: bool, look: Dictionary = {}) -> void:
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
		if map_id != p.map_id:
			var pos: Array = data.get("pos", [0, 0])
			Sim._change_map(p, map_id, Vector3(float(pos[0]), 0, float(pos[1])))
		else:
			var pos: Array = data.get("pos", [0, 8])
			p.position = Vector3(float(pos[0]), 0, float(pos[1]))
	_show_map(p.map_id)
	controller.set_physics_process(true)
	Sim.running = true
	started = true
	hud.on_game_started()
	Events.notification.emit("Bem-vindo a Aldara, %s! Fale com o Ancião Ravi (F) para começar." % char_name)
	Events.chat_message.emit("Sistema", "%s entrou no jogo." % char_name, "system")

func _process(delta: float) -> void:
	if not started:
		return
	_perf_watch(delta)
	if _soak_left > 0.0:
		_soak(delta)
	if _tour_dir != "":
		_tour(delta)
	elif _smoke_test:
		_smoke(delta)
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

static func _grow_aldara(v: Vector3) -> Vector3:
	var r := Vector2(v.x, v.z).length()
	if r <= 36.0:
		return v
	var k := (36.0 + (r - 36.0) * 1.2) / r
	return Vector3(v.x * k, v.y, v.z * k)

func _gather_shot(path: String) -> void:
	await get_tree().create_timer(3.0).timeout
	_smoke_test = false                          # o smoke mandaria andar/atacar (cancela a colheita)
	var p := Sim.player
	p.mounted = false
	for want in ["ore", "herb"]:
		for g in Sim.maps[p.map_id]["gather"]:
			if g["kind"] == want:
				g["ready_at"] = 0.0
				p.position = g["pos"] + Vector3(0.9, 0, 0.6)
				views[p.id].position = p.position
				views[p.id]._smooth_pos = p.position
				break
		await get_tree().create_timer(0.6).timeout
		var cmd := InputCommand.new()
		cmd.interact = true
		cmd.aim = p.position
		Sim.set_player_command(cmd)
		await get_tree().process_frame
		Sim.set_player_command(InputCommand.new())
		await get_tree().create_timer(0.55).timeout
		print("GATHER_SHOT %s gathering=%.2f" % [want, p.gather_left])
		get_viewport().get_texture().get_image().save_png(path.trim_suffix(".png") + "_" + want + ".png")
		await get_tree().create_timer(1.0).timeout
	get_tree().quit()

func _title_shot(path: String) -> void:
	await get_tree().create_timer(2.5).timeout
	var cs = hud.class_select
	if cs:
		var cid := "druid"
		var step := ""
		var tab := ""
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--title_class="):
				cid = a.get_slice("=", 1)
			if a.begins_with("--title_step="):      # slots | class | look
				step = a.get_slice("=", 1)
			if a.begins_with("--title_tab="):       # body | hair | face
				tab = a.get_slice("=", 1)
		if step != "slots" and step != "":
			if cs._page != "create":
				cs._go_create()
			cs._select(GameData.classes[cid])
			if tab != "":
				cs._look_tab = tab
			cs._set_step(step)
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()

func _menu_check() -> void:
	await get_tree().create_timer(1.5).timeout
	hud.open_game_menu()
	await get_tree().create_timer(0.5).timeout
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--menu_shot="):
			get_viewport().get_texture().get_image().save_png(arg.get_slice("=", 1))
	hud._menu_to_title()

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

## Smoke test: anda, ataca, usa skills, abre janelas e troca de mapa sozinho, depois sai.
## Encena um bloqueio e um aparo na frente da câmera e salva as duas fotos (revisão do efeito dos escudos).
## Revisão dos ícones de item: um item de cada símbolo na bolsa, bolsa e ficha abertas, foto e sai.
## Foto depois de 2 s e sai (demos de revisão que não usam o smoke test).
func _demo_shot() -> void:
	await get_tree().create_timer(2.0).timeout
	if _shot_path != "":
		get_viewport().get_texture().get_image().save_png(_shot_path)
	get_tree().quit()

func _perf_run() -> void:
	await get_tree().create_timer(1.0).timeout
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--perf_map=") and Sim.player:     # medir dentro de outro mapa (ex.: --perf_map=dg_catacumbas)
			var pm := a.get_slice("=", 1)
			Sim._change_map(Sim.player, pm, GameData.maps[pm].spawn_point)
			Sim._process_map_changes()
		if a.begins_with("--perf_at=") and Sim.player:      # medir num ponto do mapa (ex.: --perf_at=80,14)
			var xz := a.get_slice("=", 1).split(",")
			Sim.player.position = Vector3(float(xz[0]), 0, float(xz[1]))
	await get_tree().create_timer(2.5).timeout
	Sim.profile = true
	Sim.prof.clear()
	if "--test_no_anim" in OS.get_cmdline_user_args():
		for v in views.values():
			for a in v.find_children("*", "AnimationMixer", true, false):
				a.process_mode = Node.PROCESS_MODE_DISABLED
	if "--test_no_labels" in OS.get_cmdline_user_args() or "--test_no_shadow" in OS.get_cmdline_user_args():
		for v in views.values():
			for g in v.find_children("*", "GeometryInstance3D", true, false):
				if g is Label3D and "--test_no_labels" in OS.get_cmdline_user_args():
					g.visible = false
				elif "--test_no_shadow" in OS.get_cmdline_user_args():
					g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	var ticks0 := Sim.tick_count
	EntityView.prof_us = 0.0
	var frames := 0
	var t0 := Time.get_ticks_usec()
	var sim_us := 0.0
	var draws := 0.0
	var tick_sum := 0.0
	var proc_us := 0.0
	var gpu_sum := 0.0
	var rcpu_sum := 0.0
	while Time.get_ticks_usec() - t0 < 5_000_000:
		await get_tree().process_frame
		frames += 1
		tick_sum += Sim.tick_usec
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		sim_us += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1_000_000.0
		proc_us += Performance.get_monitor(Performance.TIME_PROCESS) * 1_000_000.0
		gpu_sum += RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
		rcpu_sum += RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid())
	var secs := (Time.get_ticks_usec() - t0) / 1_000_000.0
	print("PERF sim_tick_ms=%.2f away=%d ticks_per_frame=%.2f" % [tick_sum / frames / 1000.0, Sim.away_every, float(Sim.tick_count - ticks0) / frames])
	print("PERF views_script_ms=%.2f per_frame (%d bonecos visíveis)" % [EntityView.prof_us / frames / 1000.0, views.values().filter(func(v): return v.visible).size()])
	var nt := maxi(1, Sim.tick_count - ticks0)
	var keys: Array = Sim.prof.keys()
	keys.sort_custom(func(a, b): return Sim.prof[a] > Sim.prof[b])
	for k in keys:
		print("PERF   %-24s %.3f ms/tick" % [k, Sim.prof[k] / nt / 1000.0])
	var counts := {}
	for mid in Sim.maps:
		for e in Sim.maps[mid]["entities"]:
			var key: String = "%s:%s" % [mid, SimEntity.Kind.keys()[e.kind]]
			counts[key] = int(counts.get(key, 0)) + 1
	print("PERF entities ", counts)
	var merged := 0
	var msurf := 0
	var vis_src := 0
	for v in views.values():
		if not v.visible or v.kit == null:
			continue
		for mi in v.kit.find_children("*", "MeshInstance3D", true, false):
			if mi.name == "KitMerged":
				merged += 1
				msurf += mi.mesh.get_surface_count() if mi.mesh else 0
			elif mi.visible and mi.name != "WeaponTrail":
				vis_src += 1
	print("PERF kits merged=%d surfaces=%d visible_unmerged_pieces=%d" % [merged, msurf, vis_src])
	# triângulos por grupo de malha (prefixo do nome) e por dono: mapa x bonecos
	var tri := {}
	var cnt := {}
	for mi in get_tree().root.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var n := 0
		for si in range(mi.mesh.get_surface_count()):
			var arr: Array = mi.mesh.surface_get_arrays(si)
			n += (arr[Mesh.ARRAY_INDEX].size() if arr[Mesh.ARRAY_INDEX] != null else arr[Mesh.ARRAY_VERTEX].size()) / 3
		var key: String = String(mi.name).rstrip("0123456789._").left(28)
		var p_node: Node = mi
		var owner_kind := "?"
		while p_node:
			if p_node is EntityView:
				owner_kind = "entity"
				break
			p_node = p_node.get_parent()
		if owner_kind == "entity":
			key = "ENTITY"
		tri[key] = int(tri.get(key, 0)) + n
		cnt[key] = int(cnt.get(key, 0)) + 1
	var tk: Array = tri.keys()
	tk.sort_custom(func(a, b): return tri[a] > tri[b])
	for k in tk.slice(0, 18):
		print("PERF   tri %-28s %8d  (%d malhas)" % [k, tri[k], cnt[k]])
	print("PERF avg process_ms=%.2f physics_ms=%.2f gpu_ms=%.2f render_cpu_ms=%.2f" % [proc_us / frames / 1000.0, sim_us / frames / 1000.0, gpu_sum / frames, rcpu_sum / frames])
	print("PERF process_ms=%.2f phys_objects=%d pairs=%d islands=%d gpu_ms=%.2f cpu_ms=%.2f prims=%d" % [Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS), Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS),
		Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT), RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()),
		RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	print("PERF fps=%.1f frame_ms=%.2f draws=%.0f nodes=%d objects=%d mem_mb=%.0f physics_ms=%.2f prune=%s" % [frames / secs, secs * 1000.0 / frames,
		draws / frames, Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, sim_us / frames / 1000.0, str(KitModel.prune)])
	get_tree().quit()

## Confere o arrastar e soltar: capacete da bolsa no slot da cabeça, depois de volta para a bolsa; anel no 2º slot.
func _dnd_check() -> void:
	var w = hud.windows_script
	var p := Sim.player
	var ok := true
	var head := ""
	var ring := ""
	for iid in p.inventory:
		var it: ItemDef = GameData.items[iid]
		if head == "" and it.slot == ItemDef.Slot.HEAD and Sim.equip_error(p, it) == "":
			head = iid
		if ring == "" and it.slot == ItemDef.Slot.RING and Sim.equip_error(p, it) == "":
			ring = iid
	ok = ok and head != "" and w._can_drop_on_slot(Vector2.ZERO, {"rx_drag": "bag", "item": head}, ItemDef.Slot.HEAD)
	ok = ok and not w._can_drop_on_slot(Vector2.ZERO, {"rx_drag": "bag", "item": head}, ItemDef.Slot.BOOTS)
	w._drop_on_slot(Vector2.ZERO, {"rx_drag": "bag", "item": head}, ItemDef.Slot.HEAD)
	ok = ok and p.equipment.get(ItemDef.Slot.HEAD) != null and p.equipment[ItemDef.Slot.HEAD].id == head
	ok = ok and w._can_drop_on_bag(Vector2.ZERO, {"rx_drag": "slot", "slot": ItemDef.Slot.HEAD})
	w._drop_on_bag(Vector2.ZERO, {"rx_drag": "slot", "slot": ItemDef.Slot.HEAD})
	ok = ok and p.equipment.get(ItemDef.Slot.HEAD) == null and p.has_item(head)
	if ring != "":
		w._drop_on_slot(Vector2.ZERO, {"rx_drag": "bag", "item": ring}, ItemDef.Slot.RING2)
		ok = ok and p.equipment.get(ItemDef.Slot.RING2) != null and p.equipment.get(ItemDef.Slot.RING) == null
	print("DND_CHECK ", "ok" if ok else "FAIL", " head=", head, " ring=", ring)

func _bag_shot(path: String) -> void:
	var seen := {}
	for iid in GameData.items:
		var it: ItemDef = GameData.items[iid]
		var g := UiKit.item_glyph(it) if it.icon == "" else "own_" + it.icon.get_slice("_", 0)
		if not seen.has(g) and Sim.player.inventory.size() < 40:
			seen[g] = true
			Sim.player.add_item(iid)
	var wins := ["inventory", "character"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--wins="):          # outras janelas: --wins=skills (com --level=N para um boneco do meio do jogo)
			wins = Array(a.get_slice("=", 1).split(","))
		if a.begins_with("--level="):
			var lv := int(a.get_slice("=", 1))
			Sim.player.level = lv
			Sim.player.mastery_points = lv
			for sid in Sim.player.class_def.skill_ids:       # maestria como a de um bot do mesmo nível (anel da árvore)
				if Sim.player.knows(sid):
					Sim.player.mastery[sid] = clampi(lv / 6 - Sim.player.class_def.skill_ids.find(sid) % 3, 0, Balance.MASTERY_MAX)
	if "--status_demo" in OS.get_cmdline_user_args():     # buffs e debuffs de amostra na barra (revisar ícones e tempos)
		Sim.player.buffs.append({"id": "elixir", "remaining": 44.0, "atk_pct": 20})
		Sim.player.buffs.append({"id": "frost_armor", "remaining": 7.2, "def_pct": 30})
		Sim.player.buffs.append({"id": "juramento", "remaining": 5.0, "stacks": 3})
		Sim.player.debuffs.append({"kind": "dot", "remaining": 3.4, "dps": 0.0, "fire": true, "src": -1})
		Sim.player.debuffs.append({"kind": "dot", "remaining": 8.0, "dps": 0.0, "src": -1})
		Sim.player.debuffs.append({"kind": "slow", "remaining": 2.6, "pct": 30.0})
		Sim.player.debuffs.append({"kind": "curse", "remaining": 75.0, "taken_pct": 0.0, "weaken_pct": 0.0})
	if "--picks" in OS.get_cmdline_user_args():           # janela K na aba Talentos (revisar as escolhas)
		hud.windows_script._skills_tab = "picks"
	if "--dnd_check" in OS.get_cmdline_user_args():      # arrastar e soltar pelos mesmos métodos da janela
		_dnd_check()
	await get_tree().create_timer(0.5).timeout
	for w in wins:
		if w != "":
			hud.windows_script.toggle(w)
	if "--craft_check" in OS.get_cmdline_user_args():      # forja aberta e rolada: a rolagem não pode voltar ao topo
		hud.windows_script.close_all()
		hud.npc_ui.open("smith")
		hud.npc_ui.mode = "craft"
		hud.npc_ui._rebuild()
		await get_tree().process_frame
		await get_tree().process_frame
		hud.npc_ui._scroll.scroll_vertical = 300
		var at0: int = hud.npc_ui._scroll.scroll_vertical
		await get_tree().create_timer(4.0).timeout          # bots pegando itens na cidade não mexem na janela
		var at1: int = hud.npc_ui._scroll.scroll_vertical
		Sim.player.add_item("iron_ore", 1)                  # item do jogador: reconstrói e mantém a rolagem
		await get_tree().create_timer(0.3).timeout
		print("CRAFT_CHECK start=%d after_bots=%d after_rebuild=%d" % [at0, at1, hud.npc_ui._scroll.scroll_vertical])
	if "--enhance" in OS.get_cmdline_user_args():          # ferreiro: aprimorar; arma +9 e peito +5 para ver o brilho
		var pp := Sim.player
		pp.gold = 5000
		pp.add_item("iron_ore", 30)
		pp.add_item("star_ore", 6)
		for sl in pp.equipment:
			var eit: ItemDef = pp.equipment[sl]
			if eit:
				pp.equipment[sl] = GameData.plus_item(eit, 9 if sl == ItemDef.Slot.WEAPON else (5 if sl == ItemDef.Slot.BODY else 2))
		pp.recompute_stats()
		Events.equipment_changed.emit(pp.id)
		hud.windows_script.close_all()
		if "--glow_only" in OS.get_cmdline_user_args():     # sem janela, câmera perto: ver o brilho do +9/+5
			camera.distance = camera.min_distance
			hud.root.visible = false
			await get_tree().create_timer(0.8).timeout
		else:
			hud.npc_ui.open("smith")
			hud.npc_ui.mode = "enhance"
			hud.npc_ui._rebuild()
	if "--shop" in OS.get_cmdline_user_args():             # loja do mercador com a bolsa de amostra (revisar compra/venda)
		Sim.player.gold = 350
		hud.windows_script.close_all()
		hud.npc_ui.open("merchant")
		hud.npc_ui.mode = "shop"
		hud.npc_ui._rebuild()
	if "--relic" in OS.get_cmdline_user_args():            # janela da Relicária com moedas (revisar a troca)
		for n in Sim.maps[Sim.player.map_id]["def"].npcs:
			if n["role"] == "relic":
				Sim.player.position = n["pos"] + Vector3(0, 0, 1.5)
		Sim.player.add_item("legend_coin", 3)
		hud.windows_script.close_all()
		hud.npc_ui.open("relic")
		hud.npc_ui.mode = "relic"
		hud.npc_ui._rebuild()
	if "--storage" in OS.get_cmdline_user_args():          # janela do depósito, perto do Guarda-volumes
		for n in Sim.maps[Sim.player.map_id]["def"].npcs:
			if n["role"] == "storage":
				Sim.player.position = n["pos"] + Vector3(0, 0, 1.5)
		Sim.player.storage = {"wolf_pelt": 6, "iron_ore": 12, "potion_hp_m": 3}
		hud.windows_script.close_all()
		hud.npc_ui.open("storage")
		hud.npc_ui.mode = "storage"
		hud.npc_ui._rebuild()
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(path)
	print("bag_shot: " + path)
	get_tree().quit()

func _block_shot(path: String) -> void:
	await get_tree().create_timer(2.0).timeout
	var p: SimEntity = Sim.player
	var shield := "shield_deus_guerra"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shield="):
			shield = arg.get_slice("=", 1)
	p.equipment[ItemDef.Slot.OFFHAND] = GameData.items[shield]
	p.recompute_stats()
	Events.equipment_changed.emit(p.id)
	var foe: SimEntity = Sim.spawn_monster(GameData.monsters["wolf"], p.map_id, p.position + Vector3(1.4, 0, -1.2))
	foe.state_time = 0.0
	await get_tree().create_timer(0.3).timeout
	for shot in ["_bloqueio", "_aparo"]:
		p.face_towards(foe.position)
		p.is_blocking = true                     # o comando do tick limpa: precisa valer no golpe
		p.parry_left = Balance.PARRY_WINDOW if shot == "_aparo" else 0.0
		p.shield_react_cd = 0.0
		Sim._deal_damage(foe, p, 30, false, true, "physical")
		await get_tree().create_timer(0.14, true, false, true).timeout
		get_viewport().get_texture().get_image().save_png(path.replace(".png", shot + ".png"))
		await get_tree().create_timer(1.2).timeout
	Sim.running = false                          # sem tick a guarda fica erguida: foto limpa do arco
	p.is_blocking = true
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(path.replace(".png", "_arco.png"))
	get_tree().quit()

func _tour(delta: float) -> void:
	_tour_t += delta
	var p := Sim.player
	p.hp = p.stats.max_hp
	if _tour_t < 2.0:
		return
	var stops: Array = TOURS.get(_tour_map, TOUR)
	if GameData.maps.has(_tour_map) and GameData.maps[_tour_map].interior:      # casa: uma foto da sala, perto da porta
		stops = [["sala", Vector3(0, 0, GameData.maps[_tour_map].size.y * 0.5 - 3.0)]]
	elif not TOURS.has(_tour_map):             # paradas do Vale: escritas no layout antigo; o vale cresceu 20% (places.grow_aldara)
		stops = stops.map(func(st): return [st[0], _grow_aldara(st[1])])
		stops.append(["praia_caranguejos", Vector3(6.7, 0, 111.0)])
		stops.append(["portas_casas", Vector3(13.0, 0, 12.0)])
	if p.map_id != _tour_map:
		Sim._change_map(p, _tour_map, stops[0][1])
		_tour_t = 0.5
		return
	if _tour_i >= stops.size():
		get_tree().quit()
		return
	if not has_meta("tour_moved"):
		set_meta("tour_moved", true)
		p.position = stops[_tour_i][1]
		_tour_t = 2.0
	elif _tour_t > 3.6:
		get_viewport().get_texture().get_image().save_png("%s/tour_%s_%02d_%s.png" % [_tour_dir, _tour_map, _tour_i, stops[_tour_i][0]])
		_tour_i += 1
		remove_meta("tour_moved")

var _smoke_stage := 0
var _soak_left := 0.0
var _soak_brain: BotBrain = null
var _soak_t := 0.0
var _soak_frames := 0
var _soak_ticks0 := 0
var _soak_worst := 0.0

var _soak_map := ""

# ---------------------------------------------------------------------------
## Vigia de desempenho: a cada 2 s mede o FPS; abaixo de 25 grava em user://perf_log.txt onde estava e o que pesou
## (a sim mede as fases nos 2 s seguintes). Para investigar lentidão que só aparece jogando.
const PERF_LOW_FPS := 25.0
const PERF_LOG := "user://perf_log.txt"
var _pw_t := 0.0
var _pw_frames := 0
var _pw_worst := 0.0
var _pw_profiling := false
var _pw_ticks0 := 0

func _perf_watch(delta: float) -> void:
	if Sim.player == null:
		return
	_pw_t += delta
	_pw_frames += 1
	_pw_worst = maxf(_pw_worst, delta)
	if _pw_t < 2.0:
		return
	var fps := _pw_frames / _pw_t
	if _pw_profiling:                          # 2 s medindo as fases: grava e desliga
		var nt := maxi(1, Sim.tick_count - _pw_ticks0)
		var keys: Array = Sim.prof.keys()
		keys.sort_custom(func(a, b): return Sim.prof[a] > Sim.prof[b])
		var parts: Array = []
		for k in keys.slice(0, 8):
			parts.append("%s=%.2f" % [k, Sim.prof[k] / nt / 1000.0])
		_perf_log("  fases (ms/tick): " + ", ".join(parts))
		Sim.profile = false
		_pw_profiling = false
	elif fps < PERF_LOW_FPS:
		var p := Sim.player
		var awake := 0
		var mobs := 0
		for e in Sim.map_entities(p.map_id):
			if e.kind == SimEntity.Kind.MONSTER:
				mobs += 1
				if not e.dormant:
					awake += 1
		var rid := get_viewport().get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(rid, true)
		_perf_log("%s fps=%.1f pior_quadro=%.0fms mapa=%s pos=(%.0f,%.0f) nv=%d classe=%s monstros=%d acordados=%d bonecos=%d nos=%d objetos=%d draws=%d tick=%.2fms gpu=%.1fms cpu_render=%.1fms mem=%.0fMB" % [
			Time.get_datetime_string_from_system(), fps, _pw_worst * 1000.0, p.map_id, p.position.x, p.position.z, p.level, p.class_def.id, mobs, awake,
			views.values().filter(func(v): return v.visible).size(), Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_COUNT),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Sim.tick_usec / 1000.0,
			RenderingServer.viewport_get_measured_render_time_gpu(rid), RenderingServer.viewport_get_measured_render_time_cpu(rid), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
		Sim.prof.clear()
		Sim.profile = true
		_pw_profiling = true
		_pw_ticks0 = Sim.tick_count
	_pw_t = 0.0
	_pw_frames = 0
	_pw_worst = 0.0

func _perf_log(line: String) -> void:
	var f := FileAccess.open(PERF_LOG, FileAccess.READ_WRITE if FileAccess.file_exists(PERF_LOG) else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(line)
	f.close()

func _soak_fight(p: SimEntity) -> void:
	p.hp = p.stats.max_hp
	p.mp = p.stats.max_mp
	var best: SimEntity = null
	var bd := 1e9
	for e in Sim.map_entities(p.map_id):
		if e.kind == SimEntity.Kind.MONSTER and e.is_alive():
			var d: float = e.position.distance_squared_to(p.position)
			if d < bd:
				bd = d
				best = e
	var cmd := InputCommand.new()
	if best:
		var to := best.position - p.position
		cmd.aim = best.position
		if to.length() > 2.0:
			cmd.move = Vector2(to.x, to.z).normalized()
		else:
			cmd.attack = true
			cmd.skill_slot = (Engine.get_process_frames() / 10) % 6 if Engine.get_process_frames() % 10 == 0 else -1
	Sim.set_player_command(cmd)

## Sessão longa automática: o jogador vira um bot (caça, viaja, entra em dungeon) e a cada 5 s sai uma linha de medição.
func _soak(delta: float) -> void:
	var p := Sim.player
	if p == null:
		return
	if _soak_brain == null:
		_soak_brain = BotBrain.new()
		_soak_brain.setup(p, Sim.rng)
		_smoke_test = false
		Sim.profile = true
		_soak_ticks0 = Sim.tick_count
	_soak_left -= delta
	_soak_t += delta
	_soak_frames += 1
	_soak_worst = maxf(_soak_worst, delta)
	if _soak_map != "" and p.map_id != _soak_map:
		Sim._change_map(p, _soak_map, GameData.maps[_soak_map].spawn_point)
		Sim._process_map_changes()
		p.level = 12
		p.mastery_points = 40
		for sid in p.class_def.skill_ids:          # aprende o que der e enche a barra
			Sim.learn_skill(p, sid)
		p.recompute_stats()
		var k := 0
		for cid in ["paladin", "bishop", "elementalist"]:      # grupo de bots junto, brigando também
			var b := Sim.spawn_bot(GameData.classes[cid], "Grupo%d" % k, _soak_map, p.position + Vector3(2 + k, 0, 2), 12)
			Sim.party_invite(p, b)
			Sim.party_accept(b)
			k += 1
	if _soak_map != "":
		_soak_fight(p)                     # dungeon: briga com o monstro mais perto (bot não caça em dungeon sozinho)
	elif Sim.maps.has(p.map_id):
		Sim.set_player_command(_soak_brain.think(p, Sim, Sim.maps[p.map_id], delta))
	if _soak_t >= 5.0:
		var near := 0
		for e in Sim.map_entities(p.map_id):
			if e.kind == SimEntity.Kind.MONSTER and not e.dormant:
				near += 1
		print("SOAK t=%.0f fps=%.1f map=%s lv=%d awake_mobs=%d nodes=%d objects=%d mem_mb=%.0f tick_ms=%.2f views=%d worst_ms=%.0f" % [Time.get_ticks_msec() / 1000.0,
			_soak_frames / _soak_t, p.map_id, p.level, near, Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, Sim.tick_usec / 1000.0, views.size(), _soak_worst * 1000.0])
		_soak_worst = 0.0
		_soak_t = 0.0
		_soak_frames = 0
	if _soak_left <= 0.0:
		var nt := maxi(1, Sim.tick_count - _soak_ticks0)
		var keys: Array = Sim.prof.keys()
		keys.sort_custom(func(a, b): return Sim.prof[a] > Sim.prof[b])
		for k in keys.slice(0, 14):
			print("SOAK   %-24s %.3f ms/tick" % [k, Sim.prof[k] / nt / 1000.0])
		get_tree().quit()

func _smoke(delta: float) -> void:
	_smoke_t += delta
	var p := Sim.player
	var cmd := InputCommand.new()
	cmd.aim = p.position + p.forward() * 3.0
	match _smoke_stage:
		0:
			cmd.move = Vector2(0, 1)
			cmd.jump = _smoke_t > 0.8 and _smoke_t < 0.85      # pula correndo (pulo + pouso no smoke)
			if _smoke_t > 2.0: _smoke_stage = 1
		1:
			cmd.attack = true
			cmd.skill_slot = int(_smoke_t * 4.0) % 6
			if _smoke_t > 4.0: _smoke_stage = 2
		2:
			cmd.dash = true
			cmd.potion_slot = 0
			hud.windows_script.toggle("inventory")
			hud.windows_script.toggle("character")
			hud.windows_script.toggle("skills")
			hud.windows_script.toggle("quests")
			hud.windows_script.close_all()
			hud.npc_ui.open("elder")
			hud.npc_ui.mode = "shop"; hud.npc_ui._rebuild()
			hud.npc_ui.mode = "craft"; hud.npc_ui._rebuild()
			hud.npc_ui.close()
			_smoke_party(p)
			if _shot_path != "":
				hud.windows_script.toggle("skills")
				_smoke_stage = 20
			else:
				_smoke_stage = 3
		20:
			if _smoke_t > 4.6:
				get_viewport().get_texture().get_image().save_png(_shot_path.replace(".png", "_skills.png"))
				hud.windows_script.close_all()
				hud.windows_script.toggle("character")
				hud.windows_script.toggle("inventory")
				_smoke_stage = 22
		22:
			if _smoke_t > 5.0:
				get_viewport().get_texture().get_image().save_png(_shot_path.replace(".png", "_char.png"))
				hud.windows_script.close_all()
				hud.windows_script.toggle("party")
				_smoke_stage = 23
		23:
			if _smoke_t > 5.3:
				get_viewport().get_texture().get_image().save_png(_shot_path.replace(".png", "_party.png"))
				hud.windows_script.close_all()
				hud.npc_ui.open("smith")
				hud.npc_ui.mode = "craft"; hud.npc_ui._rebuild()
				_smoke_stage = 21
		21:
			if _smoke_t > 5.9:
				get_viewport().get_texture().get_image().save_png(_shot_path.replace(".png", "_craft.png"))
				hud.npc_ui.close()
				_smoke_stage = 3
		3:
			if _shot_path != "":
				var img := get_viewport().get_texture().get_image()
				img.save_png(_shot_path.replace(".png", "_town.png"))
			p.position = Vector3(6, 0, 52)      # Campina: estrada sul, perto do lago dos slimes
			_smoke_stage = 4
			_smoke_t = 0.0
		4:
			if _smoke_t > 0.3 and not has_meta("smoke_mobs"):
				set_meta("smoke_mobs", true)
				for i in range(3):
					Sim.spawn_monster(GameData.monsters["slime"], p.map_id, p.position + Vector3(2.5 + i * 0.8, 0, 1.0 + i * 0.6))
				Sim.spawn_monster(GameData.monsters["wolf"], p.map_id, p.position + Vector3(-3.0, 0, 2.0))
			cmd.aim = p.position + Vector3(3.0, 0, 1.5)
			if _smoke_t > 0.6:
				cmd.attack = true
			if _smoke_t > 1.4 and _smoke_t < 1.5:
				cmd.skill_slot = 0
			if _smoke_t > 2.0:
				Input.action_press("skill_4")
			if _smoke_t > 2.6: _smoke_stage = 5
		5:
			if _shot_path != "":
				var img := get_viewport().get_texture().get_image()
				img.save_png(_shot_path)
				print("screenshot: " + _shot_path)
			print("SMOKE OK: map=%s hp=%d entities=%d views=%d" % [p.map_id, p.hp, Sim.entities.size(), views.size()])
			get_tree().quit(0)
	Sim.set_player_command(cmd)

## Smoke do grupo: bot convida o jogador (popup → aceitar), passa a liderança, jogador convida mais um bot.
func _smoke_party(p: SimEntity) -> void:
	var near: Array = Sim.map_entities(p.map_id).filter(func(e): return e.kind == SimEntity.Kind.BOT and e.party_id < 0 and e.is_alive())
	near.sort_custom(func(a, b): return a.position.distance_squared_to(p.position) < b.position.distance_squared_to(p.position))
	if near.size() < 2:
		print("SMOKE party: poucos bots por perto")
		return
	Sim.party_invite(near[0], p)
	hud.answer_invite(true)
	Sim.party_promote(near[0], p)
	Sim.party_invite(p, near[1])
	Sim.party_accept(near[1])
	hud._chat_command("/p bora pra campina")
	hud.windows_script.toggle("party")
	hud.windows_script.close("party")
	print("SMOKE party: %d membros, líder=%s" % [Sim.party_members(p).size(), Sim.party_leader(p).name])

