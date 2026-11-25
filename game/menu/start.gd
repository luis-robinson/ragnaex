extends Node
## Tela inicial (cena principal, design/ux/start-flow.md): máquina de telas Título -> Personagens -> Criação -> Carregamento.
## O mundo NÃO existe aqui: nenhum Sim.load_map/spawn nem SimSync até o `main` (§7). Flag de autostart de dev vai
## direto ao main.tscn, como antes (§8, `DevRunner.autostart_class`).

const MAIN_SCENE := "res://game/main.tscn"
const DEV_RUNNER_SCRIPT := "res://game/dev/dev_runner.gd"   # só com argumentos de dev: sem tipo estático, o DevRunner não compila no boot
const SCREEN_TITLE := &"title"
const SCREEN_LIST := &"list"
const SCREEN_CREATE := &"create"
const SCREEN_LOADING := &"loading"

var apply_settings := true       # testes: false (não mexe no viewport/barramentos do runner)
var dev_routing := true          # testes: false (não troca de cena nem lê as flags de dev)
var overlay_parent: Node = null  # onde o Carregamento entra (null = raiz; testes: o runner, a raiz está ocupada no _ready)
var menu_set: MenuSet
var ui: CanvasLayer              # camada das telas que são Control
var screen: Node = null          # tela atual
var state: StringName = &""
var returning := false           # voltou do jogo pelo Esc
# B2: som do menu, boneco do card no pedestal, Configurações sobrepostas
var menu_audio: MenuAudio = null    # só com apply_settings (mexe nos barramentos)
var preview: PedestalPreview
var settings: Control = null        # painel de Configurações aberto (null = fechado)

var _quitting: bool = false

func _ready() -> void:
	get_tree().auto_accept_quit = false
	StartDev.boot(get_tree())         # BOOT + F11 na raiz (etapa A)
	returning = StartRequest.take_returning()
	if dev_routing and DevArgs.any():
		var cls: String = load(DEV_RUNNER_SCRIPT).autostart_class(DevArgs.all(), returning)
		if cls != "":            # smoke/revisão: main.tscn direto, montagem síncrona, sem Carregamento
			StartRequest.pending = StartRequest.dev_start(cls, int(DevArgs.value("--preset", "1")))
			get_tree().change_scene_to_file.call_deferred(MAIN_SCENE)
			return
	if apply_settings:           # antes de desenhar: preset de gráficos salvo e barramentos/volumes (§9)
		GraphicsSettings.load_and_apply(get_viewport())
		AudioSettings.load_and_apply()
		AccessSettings.load_settings()
		KeyBindings.load_settings()      # teclas trocadas (aba Controles)
	menu_set = MenuSet.new()
	menu_set.name = "MenuSet"
	add_child(menu_set)
	# B2 ---------------------------------------------------------------
	preview = PedestalPreview.create(menu_set)
	add_child(preview)
	if apply_settings:
		menu_audio = MenuAudio.create(true)
		add_child(menu_audio)
	# ------------------------------------------------------------------
	ui = CanvasLayer.new()
	ui.name = "UI"
	ui.layer = 10
	add_child(ui)
	if returning:
		show_list(StartRequest.last_slot)
	elif dev_routing and (DevArgs.flag("--look") or DevArgs.value("--title_step") in ["class", "look"]):
		show_create(SaveSystem.first_free_slot())
	elif dev_routing and DevArgs.value("--title_step") == "slots" and CharList.has_any():
		show_list(-1)
	else:
		show_title()
	LoadingScreen.show_pending_error(screen)     # falha no Carregamento: faixa vermelha na lista (etapa A)
	if dev_routing:
		StartDev.attach(self)            # revisão: RETURN_CHECK, --select_shot, --title_shot, --loading_shot, --path_shot

## Fechar a janela (X) no menu = mesmo caminho do botão Sair. `auto_accept_quit` fica desligado só enquanto o menu existe;
## o `main` (no jogo) volta a ter o padrão e salva sozinho ao fechar.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()
	elif what == NOTIFICATION_EXIT_TREE and is_inside_tree():
		get_tree().auto_accept_quit = true

## Sair do jogo: solta o tema antes. O AudioServer só larga o playback do mp3 no próximo passo de mixagem; com `quit()`
## direto o fim do processo imprimia "resources still in use" (AudioStreamMP3 do tema vazado).
func quit_game() -> void:
	if _quitting:
		return
	_quitting = true
	if menu_audio and is_instance_valid(menu_audio):
		menu_audio.release_streams()
		await get_tree().process_frame
		await get_tree().process_frame
	get_tree().quit()

# ---------------------------------------------------------------------------
# telas
func show_title() -> void:
	var t := TitleScreen.new()
	t.play_requested.connect(_on_title_play)
	t.settings_requested.connect(_on_settings)
	t.quit_requested.connect(quit_game)
	_swap(t, SCREEN_TITLE)

## Lista de personagens; `selected` = espaço já selecionado (-1 = nenhum).
func show_list(selected: int) -> void:
	if not CharList.has_any():               # 0 personagens: a lista nunca aparece vazia
		show_create(SaveSystem.first_free_slot())
		return
	var l := CharList.new()
	l.select_slot(selected)
	l.play_requested.connect(_on_play_slot)
	l.create_requested.connect(show_create)
	l.back_requested.connect(show_title)
	l.selection_changed.connect(preview.show_slot)      # B2: boneco do card no pedestal
	_swap(l, SCREEN_LIST)

## Criação no espaço livre `slot`.
func show_create(slot: int) -> void:
	var c := CharCreate.new()
	c.setup(slot)
	c.attach(menu_set, preview)               # P5: boneco da Criação no pedestal (kits guardados do preview)
	c.create_confirmed.connect(launch)
	c.back_requested.connect(_on_create_back)
	_swap(c, SCREEN_CREATE)

func _swap(next: Node, st: StringName) -> void:
	_close_settings_silently()               # B2: o painel vive dentro da tela que sai
	if preview and st != SCREEN_LIST:
		preview.clear()                      # B2: pedestal só mostra o card na lista (a Criação põe o dela)
	if screen and is_instance_valid(screen):
		screen.queue_free()
	screen = next
	state = st
	if next is Control:
		(next as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ui.add_child(next)
	else:
		add_child(next)
	if menu_set:
		menu_set.go_to(st)
	if next.has_method("focus_default"):
		next.call("focus_default")

func _on_title_play() -> void:
	if CharList.has_any():                   # mesma fonte da lista (espaços reais ou o --menu_saves de dev)
		show_list(-1)
	else:
		show_create(SaveSystem.first_free_slot())

# B2 ---------------------------------------------------------------------
## Configurações sobre o Título (SettingsPanel.overlay); Esc ou [Fechar] fecham.
func _on_settings() -> void:
	if settings != null or not (screen is Control):
		return
	if screen is TitleScreen:
		(screen as TitleScreen).set_interactive(false)
	settings = SettingsPanel.overlay(screen as Control, null, _on_settings_closed)
	if menu_audio:
		menu_audio.open()

## Fecha o painel de Configurações (Esc).
func close_settings() -> void:
	if settings != null:
		SettingsPanel.close_overlay(settings, _on_settings_closed)

func _on_settings_closed() -> void:
	settings = null
	if screen is TitleScreen and is_instance_valid(screen):
		(screen as TitleScreen).set_interactive(true)
	if menu_audio:
		menu_audio.close()

func _close_settings_silently() -> void:
	if settings != null and is_instance_valid(settings):
		settings.queue_free()
	settings = null

## Antes da GUI: Esc fecha as Configurações; clique/Enter/Espaço durante a troca de câmera (ou o fade do Título)
## só pulam a transição (o mesmo toque não aciona o botão por baixo).
func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_ESCAPE and settings != null:
		get_viewport().set_input_as_handled()
		close_settings()
		return
	var skip := false
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		skip = true
	elif k and k.pressed and not k.echo and k.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		skip = true
	if not skip:
		return
	if menu_set and menu_set.is_moving():
		menu_set.skip_transition()
		get_viewport().set_input_as_handled()
	elif screen is TitleScreen and (screen as TitleScreen).modulate.a < 0.99:
		(screen as TitleScreen).skip_fade()
		get_viewport().set_input_as_handled()

## O tema desce enquanto o jogo monta: o MenuAudio vai para a raiz (sobrevive à troca de cena) e se libera no fim.
func _fade_out_audio() -> void:
	if menu_audio == null or not is_instance_valid(menu_audio):
		return
	var a := menu_audio
	menu_audio = null
	if get_tree().node_added.is_connected(a._on_node_added):
		get_tree().node_added.disconnect(a._on_node_added)      # os botões do HUD não ganham o clique do menu
	a.reparent(get_tree().root)
	a.fade_out().finished.connect(a.queue_free)
# ------------------------------------------------------------------------

func _on_create_back() -> void:
	if CharList.has_any():
		show_list(-1)
	else:
		show_title()

func _on_play_slot(slot: int) -> void:
	var d := SaveSystem.slot_summary(slot)
	if d.is_empty():
		return
	launch(StartRequest.from_slot(slot, str(d.get("class", "")), str(d.get("name", "Herói"))))

## Entra no jogo com o pedido: overlay de Carregamento na raiz (sobrevive à troca) e main.tscn.
## Vale uma vez: Enter repetido no nome/botão durante os 2 quadros de espera não abre um 2º Carregamento.
func launch(req: StartRequest) -> void:
	if state == SCREEN_LOADING:
		return
	state = SCREEN_LOADING                   # antes de qualquer await: a 2ª chamada já cai no retorno acima
	_lock_input()
	StartRequest.pending = req
	_fade_out_audio()                        # B2
	var ls := LoadingScreen.new()
	(overlay_parent if overlay_parent else get_tree().root).add_child(ls)
	ls.begin(req)
	if not dev_routing:                      # testes: não troca de cena
		return
	await get_tree().process_frame           # o overlay aparece antes da montagem (síncrona na P1) travar o quadro
	await get_tree().process_frame
	get_tree().change_scene_to_file(MAIN_SCENE)

## Carregamento pedido: a tela atual e o menu param de receber teclado/mouse (o foco sai do botão/campo).
func _lock_input() -> void:
	set_process_input(false)
	_close_settings_silently()
	if screen and is_instance_valid(screen):
		screen.process_mode = Node.PROCESS_MODE_DISABLED
	if is_inside_tree():
		get_viewport().gui_release_focus()
