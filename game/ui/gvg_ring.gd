class_name GvgRing
extends Control
## Anel de recarga do canhão em volta do cursor enquanto o jogador opera um (só desenho).

var frac := 0.0           # 0 = pronto, 1 = acabou de atirar

func _init() -> void:
	name = "GvgRing"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func _process(_delta: float) -> void:
	if visible:
		position = (get_parent() as Control).get_local_mouse_position()
		queue_redraw()

func _draw() -> void:
	draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 40, Color(0, 0, 0, 0.55), 6.0, true)
	if frac <= 0.0:
		draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 40, Color(1.0, 0.85, 0.35), 3.0, true)
		return
	draw_arc(Vector2.ZERO, 22.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - frac), 40, Color(0.9, 0.9, 0.9), 3.0, true)
