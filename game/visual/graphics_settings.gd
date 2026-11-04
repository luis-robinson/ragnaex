class_name GraphicsSettings
extends RefCounted
## Qualidade de imagem (menu Esc → Gráficos), salva em user://settings.cfg (vale para todos os personagens).
## "Nítido" é o padrão de sempre: renderiza acima da tela (125%) e reduz — o mais limpo para o toon com contorno.
## FSR 2 renderiza abaixo da tela e reconstrói a imagem: ganha FPS em PC fraco, mas o contorno fino pode tremular um pouco.

const PATH := "user://settings.cfg"
## [nome no menu, modo de escala, escala 3D] — escala < 0 = automática (ver `_auto_scale`)
const PRESETS := [
	["Nítido", Viewport.SCALING_3D_MODE_BILINEAR, -1.0],
	["FSR 2 Qualidade", Viewport.SCALING_3D_MODE_FSR2, 0.67],
	["FSR 2 Equilibrado", Viewport.SCALING_3D_MODE_FSR2, 0.59],
	["FSR 2 Desempenho", Viewport.SCALING_3D_MODE_FSR2, 0.5],
]
const FSR_SHARPNESS := 0.2          # 0 = mais nítido (o padrão do Godot, 0.2, já é um meio-termo bom)

static var preset := 0

static func load_and_apply(vp: Viewport) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		preset = clampi(int(cfg.get_value("graphics", "preset", 0)), 0, PRESETS.size() - 1)
	apply(vp)

static func apply(vp: Viewport) -> void:
	var p: Array = PRESETS[preset]
	vp.scaling_3d_mode = p[1]
	vp.scaling_3d_scale = _auto_scale() if float(p[2]) < 0.0 else float(p[2])
	vp.fsr_sharpness = FSR_SHARPNESS

## Troca para o próximo preset, aplica e salva. Devolve o nome novo.
static func cycle(vp: Viewport) -> String:
	preset = (preset + 1) % PRESETS.size()
	apply(vp)
	var cfg := ConfigFile.new()
	cfg.load(PATH)                    # mantém outras seções, se existirem
	cfg.set_value("graphics", "preset", preset)
	cfg.save(PATH)
	return name()

static func name() -> String:
	return PRESETS[preset][0]

## Nítido: 125% (project.godot), mas tela grande (ultrawide, 1440p+) já tem pixel de sobra — 100%.
static func _auto_scale() -> float:
	var scr := DisplayServer.screen_get_size()
	if scr.x * scr.y >= 2560 * 1300:
		return 1.0
	return float(ProjectSettings.get_setting("rendering/scaling_3d/scale", 1.25))
