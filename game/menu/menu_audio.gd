class_name MenuAudio
extends Node
## Som da tela inicial (spec `design/ux/start-flow.md` §9 "Som do menu"): o tema de Aldara no barramento "Music" e
## cliques/passar o mouse no barramento "UI", sem o `main` (o `Music` e o `Sfx` do jogo dependem dele e do `Sim.player`).
## Não é autoload (o nome `Music` já é class_name). Quem monta o menu chama `AudioSettings.load_and_apply()` antes; este nó
## também chama (é seguro chamar duas vezes) para o barramento existir.
##   var a := MenuAudio.new(); add_child(a)        # toca o tema, botões novos clicam sozinhos

const THEME := "aldara"
const FADE_IN := 2.0                 # s até o volume cheio
const FADE_OUT := 0.6                # s ao sair (`fade_out` antes de trocar de cena)
const CLICK := "click"
const CLICK_DB := -10.0              # = Sfx.VOL["click"]
const HOVER_DB := -24.0              # passar o mouse: o mesmo clique, bem baixo e agudo
const HOVER_PITCH := 1.35
const OPEN := "ui_open"
const OPEN_DB := -14.0
const CLOSE := "ui_close"
const CLOSE_DB := -16.0
const UI_VOICES := 4

var music: AudioStreamPlayer
var played: Dictionary = {}          # nome -> vezes (checks)
var _bank: Dictionary = {}           # nome -> [AudioStream]
var _ui: Array[AudioStreamPlayer] = []
var _next := 0
var _auto_wire := true

## `auto_wire`: liga click/hover em todo botão que entrar na árvore enquanto o menu existe.
static func create(auto_wire := true) -> MenuAudio:
	var a := MenuAudio.new()
	a._auto_wire = auto_wire
	return a

func _init() -> void:
	name = "MenuAudio"

func _ready() -> void:
	AudioSettings.load_and_apply()
	music = AudioStreamPlayer.new()
	music.name = "Theme"
	music.bus = &"Music"
	add_child(music)
	for i in UI_VOICES:
		var u := AudioStreamPlayer.new()
		u.bus = &"UI"
		add_child(u)
		_ui.append(u)
	for s in [CLICK, OPEN, CLOSE]:
		_load_sound(s)
	play_theme()
	if _auto_wire:
		get_tree().node_added.connect(_on_node_added)

## Mesmo laço do `Music._stream`: ogg ou mp3 em `Music.DIR`, em loop.
static func theme_stream(theme: String) -> AudioStream:
	for ext in ["ogg", "mp3"]:
		var path: String = Music.DIR + theme + "." + str(ext)
		if ResourceLoader.exists(path):
			var s: AudioStream = load(path)
			if s is AudioStreamOggVorbis:
				(s as AudioStreamOggVorbis).loop = true
			elif s is AudioStreamMP3:
				(s as AudioStreamMP3).loop = true
			return s
	return null

func play_theme() -> void:
	var s := theme_stream(THEME)
	if s == null:
		return
	music.stream = s
	music.volume_db = -60.0
	music.play()
	played[THEME] = int(played.get(THEME, 0)) + 1
	create_tween().tween_property(music, "volume_db", 0.0, FADE_IN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## Desce o tema (antes de ir para o jogo). Devolve o tween para quem quiser esperar.
func fade_out() -> Tween:
	var t := create_tween()
	t.tween_property(music, "volume_db", -60.0, FADE_OUT)
	t.tween_callback(music.stop)
	return t

## Banco igual ao do `Sfx`: `<nome>_<n>.<ogg|wav>` em `Sfx.DIR`.
func _load_sound(sound: String) -> void:
	var arr: Array = []
	for f in ResourceLoader.list_directory(Sfx.DIR):
		var file := String(f)
		if not (file.ends_with(".ogg") or file.ends_with(".wav")):
			continue
		var key := file.get_basename()
		if key.substr(0, key.rfind("_")) == sound:
			var s: AudioStream = load(Sfx.DIR + file)
			if s:
				arr.append(s)
	_bank[sound] = arr

func has_sound(sound: String) -> bool:
	return not (_bank.get(sound, []) as Array).is_empty()

func play_ui(sound: String, db: float = 0.0, pitch: float = 1.0) -> void:
	var arr: Array = _bank.get(sound, [])
	if arr.is_empty() or _ui.is_empty():
		return
	var u := _ui[_next]
	_next = (_next + 1) % _ui.size()
	u.stream = arr[randi() % arr.size()]
	u.volume_db = db
	u.pitch_scale = pitch * randf_range(0.97, 1.03)
	u.play()
	played[sound] = int(played.get(sound, 0)) + 1

func click() -> void:
	play_ui(CLICK, CLICK_DB)

func hover() -> void:
	play_ui(CLICK, HOVER_DB, HOVER_PITCH)
	played["hover"] = int(played.get("hover", 0)) + 1

func open() -> void:
	play_ui(OPEN, OPEN_DB)

func close() -> void:
	play_ui(CLOSE, CLOSE_DB)

## Liga clique e hover num botão (o auto_wire faz isso sozinho para os botões que entram depois).
func wire(b: BaseButton) -> void:
	if not b.pressed.is_connected(click):
		b.pressed.connect(click)
	if not b.mouse_entered.is_connected(_on_hover.bind(b)):
		b.mouse_entered.connect(_on_hover.bind(b))
	if not b.focus_entered.is_connected(_on_hover.bind(b)):
		b.focus_entered.connect(_on_hover.bind(b))

func _on_hover(b: BaseButton) -> void:
	if not b.disabled:
		hover()

func _on_node_added(n: Node) -> void:
	if n is BaseButton:
		wire(n as BaseButton)
