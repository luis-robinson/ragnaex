class_name WindowKeys
extends Node
## Teclas de janela que valem em qualquer tela (menu, Carregamento, jogo): F11 = janela 1920x1080 centralizada <->
## tela cheia (começa em janela, ver project.godot). Nó na raiz, instalado uma vez (design/ux/start-flow.md §9).

const WINDOWED_SIZE := Vector2i(1920, 1080)
static var _installed: WindowKeys = null

## Põe o nó na raiz se ainda não houver (seguro chamar várias vezes no mesmo quadro).
static func install(tree: SceneTree) -> void:
	if is_instance_valid(_installed):
		return
	_installed = WindowKeys.new()
	_installed.name = "WindowKeys"
	tree.root.add_child.call_deferred(_installed)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		toggle_fullscreen()
		get_viewport().set_input_as_handled()

## Janela <-> tela cheia.
static func toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(WINDOWED_SIZE)
		var screen := DisplayServer.screen_get_usable_rect()
		DisplayServer.window_set_position(screen.position + (screen.size - WINDOWED_SIZE) / 2)
