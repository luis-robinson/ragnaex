class_name StartDev
extends Node
## Revisão da tela inicial pela linha de comando (só com argumentos depois de `--`; design/ux/start-flow.md §8):
## `--return_check` (volta do jogo: o mundo tem de estar vazio), `--select_shot=<png>`, `--title_shot=<png>`
## [`--title_class=<c>` `--title_step=title|slots|class|look|loading` `--title_tab=body|hair|face` `--title_wait=<s>`],
## `--loading_shot=<png>` [`--loading_map=<id>`] (Carregamento a ~60%) e `--path_shot=<pasta>` [`--path_class=<c>`]
## (caminho do jogador: Título -> Jogar -> Criação -> Carregamento -> mundo, num espaço -1 que nunca grava; fotos a_*.png).
## Fala com as telas só pelos sinais/métodos públicos (TitleScreen, CharList, CharCreate, LoadingScreen).

const SHOT_FRACTION := 0.6
static var _booted := false

var start: Node                  # game/menu/start.gd
var returning := false

## Primeira coisa do start._ready: marca BOOT (desde o início do processo: motor + autoloads + start.tscn) e o F11.
static func boot(tree: SceneTree) -> void:
	WindowKeys.install(tree)
	if not _booted:
		_booted = true
		print("BOOT start_enter %d" % Time.get_ticks_msec())

## No fim do start._ready: liga a revisão se houver argumentos.
static func attach(start_node: Node) -> void:
	if not DevArgs.any():
		return
	var d := StartDev.new()
	d.name = "StartDev"
	d.start = start_node
	d.returning = bool(start_node.get("returning"))
	start_node.add_child(d)

func _ready() -> void:
	_run()

func _run() -> void:
	if returning and DevArgs.has("--return_check"):
		await _wait(1.5)
		if DevArgs.flag("--return_shot"):
			_shot(DevArgs.value("--return_shot"))
		print("RETURN_CHECK ok entities=%d maps=%d parties=%d player=%s screen=%s" % [Sim.entities.size(), Sim.maps.size(),
			Sim.parties.size(), str(Sim.player != null), str(start.get("state"))])
		await _quit()
	elif DevArgs.flag("--loading_shot"):
		var mid := DevArgs.value("--loading_map", GameData.town_map_id())
		await _wait(1.0)
		_preview_loading(mid)
		await _wait(1.2)
		_shot(DevArgs.value("--loading_shot"))
		print("LOADING_SHOT map=%s" % mid)
		await _quit()
	elif DevArgs.flag("--select_shot"):
		if DevArgs.has("--title_settings") and start.has_method("_on_settings") and str(start.get("state")) == "title":
			start.call("_on_settings")     # foto das Configurações sobre o Título
			if DevArgs.value("--settings_tab") == "access":     # --settings_tab=access: aba Acessibilidade
				var sp := start.find_child("SettingsPanel", true, false) as SettingsPanel
				if sp:
					sp.show_tab(1)
		await _wait(2.0)
		print("SELECT_SHOT screen=%s maps=%d entities=%d" % [str(start.get("state")), Sim.maps.size(), Sim.entities.size()])
		_shot(DevArgs.value("--select_shot"))
		await _quit()
	elif DevArgs.flag("--title_shot"):
		await _title_shot(DevArgs.value("--title_shot"))
	elif DevArgs.flag("--path_shot") and not returning:
		await _path_shot(DevArgs.value("--path_shot"))
	elif DevArgs.flag("--path_shot") and returning:     # a montagem falhou (--loading_fail): foto da lista com a faixa
		await _wait(1.5)
		_shot(DevArgs.value("--path_shot").path_join("a_fail.png"))
		print("PATH_SHOT voltou screen=%s error=%s maps=%d entities=%d" % [str(start.get("state")), StartRequest.error,
			Sim.maps.size(), Sim.entities.size()])
		await _quit()

## Foto de uma tela do início. Criação: usa as funções de teste `select_class(id)`, `show_step(step)` e `show_tab(tab)`
## da tela (etapa P5); sem elas a foto sai no estado padrão (aviso no log).
func _title_shot(path: String) -> void:
	await _wait(2.5)
	var step := DevArgs.value("--title_step", "title")
	if step == "loading":
		_preview_loading(GameData.town_map_id())
	else:
		var scr: Node = start.get("screen")
		if scr is CharCreate:
			_try(scr, "select_class", DevArgs.value("--title_class", "druid"))
			if step in ["class", "look"]:
				_try(scr, "show_step", step)
			if DevArgs.value("--title_tab") != "":
				_try(scr, "show_tab", DevArgs.value("--title_tab"))
	await _wait(float(DevArgs.value("--title_wait", "1.0")))      # P5: --title_wait=0.3 pega a demonstração da classe no meio
	_shot(path)
	print("TITLE_SHOT step=%s screen=%s" % [step, str(start.get("state"))])
	await _quit()

## Caminho do jogador de ponta a ponta, só pelos sinais das telas. Personagem no espaço -1 (nunca grava).
func _path_shot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	await _wait(2.0)
	_shot(dir.path_join("a_title.png"))
	var scr: Node = start.get("screen")
	if scr is TitleScreen:
		scr.emit_signal("play_requested")
	await _wait(1.0)
	scr = start.get("screen")
	if scr is CharList:
		scr.emit_signal("create_requested", SaveSystem.first_free_slot())
		await _wait(1.0)
		scr = start.get("screen")
	if not scr is CharCreate:
		print("PATH_SHOT FAIL sem Criação (tela=%s)" % str(start.get("state")))
		get_tree().quit(1)
		return
	await _wait(1.0)
	_shot(dir.path_join("a_create.png"))
	reparent(get_tree().root)                # a cena do start sai na troca; a revisão continua
	var t0 := Time.get_ticks_msec()
	scr.emit_signal("create_confirmed", StartRequest.new_character(DevArgs.value("--path_class", "paladin"), "Viajante", {}, 1, -1))
	scr.emit_signal("create_confirmed", StartRequest.new_character("druid", "Repetido", {}, 1, -1))     # Enter repetido: tem de ser ignorado
	await get_tree().process_frame
	var overlays := get_tree().root.get_children().filter(func(n: Node) -> bool: return n is LoadingScreen).size()
	print("PATH_SHOT carregamentos=%d (esperado 1)" % overlays)
	var shot_loading := false
	var seen_loading := false
	while Time.get_ticks_msec() - t0 < 120000:
		await get_tree().process_frame
		var ls := get_tree().root.get_node_or_null("LoadingScreen") as LoadingScreen
		if ls:
			seen_loading = true
			if not shot_loading and ls.progress() >= 0.45:
				shot_loading = true
				_shot(dir.path_join("a_loading.png"))
				print("PATH_SHOT loading %.2f em %d ms" % [ls.progress(), Time.get_ticks_msec() - t0])
		elif seen_loading:
			break
	var main := get_tree().current_scene
	var ok: bool = main != null and main.get("started") == true
	print("PATH_SHOT carregado=%s em %d ms (mapa=%s)" % [str(ok), Time.get_ticks_msec() - t0, str(main.get("current_map_id")) if main else "?"])
	if not ok:
		return                               # falhou: a tela inicial reabre e o StartDev dela tira a foto
	await _wait(3.0)
	_shot(dir.path_join("a_world.png"))
	var views: Variant = main.get("views")
	print("PATH_SHOT fim player=%s views=%d" % [str(Sim.player != null), (views as Dictionary).size() if views is Dictionary else 0])
	await _quit()

## Sai pelo mesmo caminho do botão Sair (solta o tema antes: sem vazamento no fim do processo).
func _quit() -> void:
	if start.has_method("quit_game"):
		await start.call("quit_game")
	else:
		get_tree().quit()

func _preview_loading(mid: String) -> void:
	var ls := LoadingScreen.new()
	get_tree().root.add_child(ls)
	ls.preview(mid, SHOT_FRACTION)

func _try(obj: Object, method: String, arg: Variant) -> void:
	if obj.has_method(method):
		obj.call(method, arg)
	else:
		push_warning("StartDev: tela sem %s() (API de teste da etapa P5)" % method)

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _shot(path: String) -> void:
	if path != "":
		get_viewport().get_texture().get_image().save_png(path)
