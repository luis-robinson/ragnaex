class_name AudioSettings
extends RefCounted
## Volumes (menu Esc → Som), salvos em user://settings.cfg na seção "audio" (vale para todos os personagens).
## Barramentos: Master ← Music (temas por lugar, chefe, investida), SFX (combate e mundo) e UI (cliques, janelas, nível, quest).

const BUSES := ["Master", "Music", "SFX", "UI"]
const LABELS := {"Master": "Volume geral", "Music": "Música", "SFX": "Efeitos", "UI": "Interface"}
const DEFAULTS := {"Master": 0.8, "Music": 0.55, "SFX": 1.0, "UI": 0.8}

static var volume: Dictionary = DEFAULTS.duplicate()

## Cria os barramentos que faltam (o projeto não tem default_bus_layout) e aplica o salvo.
static func load_and_apply() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	var cfg := ConfigFile.new()
	if cfg.load(GraphicsSettings.PATH) == OK:
		for b in BUSES:
			volume[b] = clampf(float(cfg.get_value("audio", b, DEFAULTS[b])), 0.0, 1.0)
	for b in BUSES:
		_apply(b)

static func set_volume(bus: String, v: float) -> void:
	volume[bus] = clampf(v, 0.0, 1.0)
	_apply(bus)
	var cfg := ConfigFile.new()
	cfg.load(GraphicsSettings.PATH)            # mantém a seção de gráficos
	cfg.set_value("audio", bus, volume[bus])
	cfg.save(GraphicsSettings.PATH)

static func _apply(bus: String) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	var v: float = volume[bus]
	AudioServer.set_bus_mute(i, v <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))
