class_name Music
extends Node
## Música (barramento "Music", volume no Esc → Som). Banco em assets/audio/music/<tema>.<ogg|mp3> (CC0, gerado por
## tools/audio/build_music.py; créditos em CREDITS.md). Tema do lugar pelo mapa do jogador; por cima, "chefe" (chefe de
## verdade em luta perto do jogador) e "investida" (leva atacando o mapa). Troca suave entre duas vozes.
## Só lê o estado da sim (presentation); confere 2x por segundo.

const DIR := "res://assets/audio/music/"
const FADE := 1.6                      # s da troca entre temas
const CHECK_EVERY := 0.5
const BOSS_RANGE := 32.0               # m: chefe em luta até aqui troca para o tema de chefe
const THEMES := ["aldara", "taverna", "campo", "elfos", "bastiao", "masmorra", "caverna", "catacumbas", "trevas", "cidadela", "chefe", "investida",
	"porto", "costa", "goblins", "horda", "kharzun", "kharzun_citadel",
	"lumeria", "lumeria_morning", "perfume", "parade", "rift", "rift_raid", "espelhos", "adegas", "coro"]
## mapa -> tema; o resto sai de theme_for() (masmorras, fortalezas, interiores)
const MAP_THEME := {"city_aldara": "aldara", "field_hollow": "campo", "field_crab_beach": "costa", "field_grove": "campo", "in_tavern": "taverna", "field_forest": "campo", "elf_city": "elfos",
	"field_ruins": "bastiao", "lich_citadel": "cidadela", "dg_catacumbas": "catacumbas", "dg_catacumbas_trono": "catacumbas",
	"dg_gruta": "caverna", "dg_pedreira": "caverna", "dg_pedreira_coracao": "caverna", "dg_covil_dragao": "caverna",
	# Ato II: Porto Esperança, Costa Partida e Grutas Goblin (tambores); a taverna do porto usa a do Ato I
	"city_port": "porto", "in_port_tavern": "taverna", "in_port_warehouse": "porto", "field_coast": "costa", "dg_goblin": "goblins",
	# Ato II (fase 2): Estepes e os três acampamentos da Horda (os "fort_" do Ato I seguem em "trevas")
	"field_steppe": "horda", "fort_trolls": "horda", "fort_fire": "horda", "fort_war": "horda",
	# Ato II (fase 3): Monte Kharzun e Salão dos Matadores (tambores de guerra); a Cidadela com coro grave (raide)
	"field_kharzun": "kharzun", "dg_slayers": "kharzun", "kharzun_citadel": "kharzun_citadel",
	# Ato III parte 1 (WP12): valsa de caixinha de música desafinada na cidade (de manhã, L4, ver theme_for_stage), cordas lentas
	# nas Vinhas, a marcha que se repete demais no Cortejo; Fenda no coro etéreo sem percussão, raide no coro com órgão;
	# Adegas na valsa da morte, Galeria dos Espelhos no baile dos fantasmas, Conservatório no coro ferido
	"city_lumeria": "lumeria", "field_perfume": "perfume", "field_parade": "parade",
	"rift_garden": "rift", "rift_heart": "rift_raid", "dg_cellars": "adegas", "dg_mirrors": "espelhos", "dg_conservatory": "coro", "in_duke_hall": "lumeria"}
## Tema por estágio (só lê `quests_completed` do jogador): mapa -> [missão, tema depois dela]. Manhã em Lumeria (L4, GDD ato3 §2.3).
const STAGE_THEME := {"city_lumeria": ["hx3_veil", "lumeria_morning"]}

var main                                # Main
var current := ""
var played: Dictionary = {}             # tema -> vezes que começou (o smoke imprime)
var _streams: Dictionary = {}           # tema -> AudioStream (em loop)
var _voices: Array[AudioStreamPlayer] = []
var _active := 0                        # voz que está subindo
var _check := 0.0

func _ready() -> void:
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = &"Music"
		p.volume_db = -80.0
		add_child(p)
		_voices.append(p)

## Solta os streams (saída do jogo / troca de cena): o AudioServer só larga o playback no próximo passo de mixagem.
func release_streams() -> void:
	for v in _voices:
		v.stop()
		v.stream = null

func _exit_tree() -> void:
	release_streams()

## Tema de um mapa: tabela, depois por família (masmorra, fortaleza, interior da vila); "" = silêncio.
static func theme_for(map_id: String) -> String:
	if MAP_THEME.has(map_id):
		return MAP_THEME[map_id]
	if map_id.begins_with("dg_"):
		return "masmorra"
	if map_id.begins_with("fort_"):
		return "trevas"
	if map_id.begins_with("in_"):
		return "aldara"
	return ""

## Tema do mapa no estágio do mundo: a troca de STAGE_THEME vale quando a missão está em `done`; senão theme_for.
static func theme_for_stage(map_id: String, done: Array) -> String:
	if STAGE_THEME.has(map_id):
		var st: Array = STAGE_THEME[map_id]
		if str(st[0]) in done:
			return str(st[1])
	return theme_for(map_id)

func _stream(theme: String) -> AudioStream:
	if _streams.has(theme):
		return _streams[theme]
	var s: AudioStream = null
	for ext in ["ogg", "mp3"]:
		var path: String = DIR + theme + "." + str(ext)
		if ResourceLoader.exists(path):
			s = load(path)
			break
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	elif s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true
	_streams[theme] = s
	return s

func _process(delta: float) -> void:
	_check -= delta
	if _check <= 0.0:
		_check = CHECK_EVERY
		var want := _wanted()
		if want != current:
			_switch(want)
	# troca suave: a voz ativa sobe, a outra desce (linear em amplitude)
	for i in _voices.size():
		var v := _voices[i]
		var lin := db_to_linear(v.volume_db)
		var target := 1.0 if i == _active and current != "" else 0.0
		lin = move_toward(lin, target, delta / FADE)
		v.volume_db = linear_to_db(maxf(lin, 0.0001))
		if lin <= 0.0001 and v.playing and i != _active:
			v.stop()

func _wanted() -> String:
	var p: SimEntity = Sim.player
	if p == null:
		return ""
	if _boss_fight(p):
		return "chefe"
	var rs: Dictionary = RaidSystem.status(Sim, p.map_id)
	if bool(rs.get("active", false)) and str(rs.get("phase", "")) != "retreat":
		return "investida"
	return theme_for_stage(p.map_id, p.quests_completed)

## Chefe de verdade (não os elites "Rei") vivo, em luta (com alvo) e perto do jogador.
func _boss_fight(p: SimEntity) -> bool:
	var m: Dictionary = Sim.maps.get(p.map_id, {})
	if m.is_empty():
		return false
	for e in m["entities"]:
		if e.kind != SimEntity.Kind.MONSTER or e.monster_def == null or not e.monster_def.is_boss or e.monster_def.elite_of != "":
			continue
		if e.is_alive() and e.aggro_target >= 0 and e.position.distance_to(p.position) < BOSS_RANGE:
			return true
	return false

func _switch(theme: String) -> void:
	current = theme
	if theme == "":
		_active = 1 - _active          # nenhuma voz sobe: as duas descem
		return
	var s := _stream(theme)
	if s == null:
		current = ""
		return
	_active = 1 - _active
	var v := _voices[_active]
	v.stream = s
	v.volume_db = -80.0
	v.play()
	played[theme] = int(played.get(theme, 0)) + 1
