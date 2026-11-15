extends Node
## Gera a imagem do splash de boot (`application/boot_splash/image`) a partir do logo, no fundo escuro do jogo.
## O splash fica na tela do início do motor até o primeiro quadro (autoloads + GameData + primeira cena).
##   godot --headless --path . tools/splash/make_splash.tscn      (depois rode --import)
## Logo e subtítulo vão no MESMO lugar e tamanho do Título (design/ux/start-flow.md §3; constantes do
## `TitleScreen`): com o stretch `Keep` do splash e o `canvas_items` + `expand` do jogo, os dois escalam pela altura
## em telas largas (16:9, 21:9), então o logo não pula quando o Título entra.

const OUT := "res://assets/ui/boot_splash.png"
const SIZE := Vector2i(2560, 1440)       # 16:9; em 1080p reduz (filtro ligado), em 1440p é 1:1
const BASE := Vector2(1600, 900)         # resolução base do projeto (display/window/size/viewport_*)
# Arte, lugar e tamanho vêm do Título (px na base): mexeu lá, rode esta ferramenta de novo.
const LOGO := TitleScreen.LOGO
const SUBTITLE := TitleScreen.SUBTITLE
const LOGO_W := TitleScreen.LOGO_W
const LOGO_TOP := TitleScreen.LOGO_TOP
const SUBTITLE_W := TitleScreen.SUBTITLE_W
const SUBTITLE_OVERLAP := TitleScreen.SUBTITLE_OVERLAP
const CLEAR_KEY := "rendering/environment/defaults/default_clear_color"
const SPLASH_BG_KEY := "application/boot_splash/bg_color"

func _ready() -> void:
	var err := make()
	if err != OK:
		push_error("make_splash: falhou (%s)" % error_string(err))
	get_tree().quit(0 if err == OK else 1)

## Cor do fundo: a cor de limpeza do projeto (o que a janela mostra antes do 3D), sem alfa.
static func bg_color() -> Color:
	var c: Color = ProjectSettings.get_setting(CLEAR_KEY, Color(0.07, 0.08, 0.12))
	return Color(c.r, c.g, c.b, 1.0)

## Monta e grava o PNG. Devolve OK ou o erro do primeiro passo que falhou.
static func make() -> Error:
	var bg := bg_color()
	var img := Image.create_empty(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	img.fill(bg)
	var k := float(SIZE.y) / BASE.y      # base -> imagem (pela altura, como o expand em tela larga)
	var logo := _scaled(LOGO, LOGO_W * k)
	if logo == null:
		return ERR_FILE_NOT_FOUND
	var top := roundi(LOGO_TOP * k)
	img.blend_rect(logo, Rect2i(Vector2i.ZERO, logo.get_size()), Vector2i((SIZE.x - logo.get_width()) / 2, top))
	var sub := _scaled(SUBTITLE, SUBTITLE_W * k)
	if sub != null:
		var sy := top + logo.get_height() - roundi(SUBTITLE_OVERLAP * k)
		img.blend_rect(sub, Rect2i(Vector2i.ZERO, sub.get_size()), Vector2i((SIZE.x - sub.get_width()) / 2, sy))
	img.convert(Image.FORMAT_RGB8)       # sem alfa: borda = bg_color exata nas faixas de 21:9
	var err := img.save_png(OUT)
	var splash_bg: Color = ProjectSettings.get_setting(SPLASH_BG_KEY, Color.BLACK)
	if not splash_bg.is_equal_approx(bg):
		push_warning("make_splash: %s (%s) difere do fundo da imagem (%s)" % [SPLASH_BG_KEY, splash_bg, bg])
	print("make_splash: %s %dx%d fundo %s (%s)" % [OUT, SIZE.x, SIZE.y, bg.to_html(false), error_string(err)])
	return err

## Lê a textura importada (sem perda: compress/mode 0) e reduz para `width` px com Lanczos.
static func _scaled(path: String, width: float) -> Image:
	var tex := load(path) as Texture2D if ResourceLoader.exists(path) else null
	var im := tex.get_image() if tex != null else null
	if im == null or im.is_empty():
		return null
	im.convert(Image.FORMAT_RGBA8)
	var w := roundi(width)
	var h := roundi(width * im.get_height() / float(im.get_width()))
	im.resize(w, h, Image.INTERPOLATE_LANCZOS)
	return im
