class_name PlayerController
extends Node
## Lê teclado/mouse e monta o InputCommand do jogador a cada tick de física.
## WASD relativo à câmera, mira = ponto do chão sob o mouse (MOBA), LMB ataque, RMB bloqueio,
## 1-6 skills, F1-F3 poções, Shift dash, Espaço pula, F interage.

var camera: CameraRig
var ui_blocking: bool = false     # true quando uma janela modal/chat está aberta
var _pending := InputCommand.new()
var aim_point: Vector3 = Vector3.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if ui_blocking:
		return
	# ações "one-shot" são acumuladas até o próximo tick de física (não perde clique entre frames)
	if event.is_action_pressed("attack"):
		_pending.attack = true
	for i in range(6):
		if event.is_action_pressed("skill_%d" % (i + 1)):
			_pending.skill_slot = i
	for i in range(3):
		if event.is_action_pressed("potion_%d" % (i + 1)):
			_pending.potion_slot = i
	if event.is_action_pressed("interact"):
		_pending.interact = true
	if event.is_action_pressed("dash"):
		_pending.dash = true
	if event.is_action_pressed("jump"):
		_pending.jump = true
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_H:
		_pending.mount = true          # H: montar/desmontar
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_G:
		_pending.recall = true         # G: voltar à cidade

func _physics_process(_delta: float) -> void:
	var cmd := InputCommand.new()
	var mouse := get_viewport().get_mouse_position()
	aim_point = camera.mouse_ground_point(mouse)
	cmd.aim = aim_point
	if not ui_blocking:
		var iv := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
		var world := camera.forward_flat() * iv.y + camera.right_flat() * iv.x
		cmd.move = Vector2(world.x, world.z)
		cmd.block = Input.is_action_pressed("block")
		# segurar LMB = ataque contínuo (cadência da arma)
		if Input.is_action_pressed("attack"):
			cmd.attack = true
	cmd.attack = cmd.attack or _pending.attack
	cmd.skill_slot = _pending.skill_slot
	cmd.potion_slot = _pending.potion_slot
	cmd.interact = _pending.interact
	cmd.dash = _pending.dash
	cmd.jump = _pending.jump
	cmd.mount = _pending.mount
	cmd.recall = _pending.recall
	_pending = InputCommand.new()
	Sim.set_player_command(cmd)
