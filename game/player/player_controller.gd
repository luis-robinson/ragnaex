class_name PlayerController
extends Node
## Lê teclado/mouse e monta o InputCommand do jogador a cada tick de física.
## WASD relativo à câmera, mira = ponto do chão sob o mouse (MOBA), LMB ataque, RMB bloqueio,
## 1-6 skills, F1-F3 poções, Shift dash, Espaço pula, F interage, H monta, G volta à cidade.

var camera: CameraRig
var ui_blocking: bool = false     # true quando uma janela modal/chat está aberta
var _pending := InputCommand.new()
var aim_point: Vector3 = Vector3.ZERO
var last_cmd: InputCommand = null   # último comando montado (revisão: --ui_click_check)
# LMB/RMB seguro só vale se o aperto chegou aqui, no _unhandled_input (começou no mundo). Clique numa janela,
# barra ou minimapa é consumido pela UI e nunca liga isto, mesmo com Input.is_action_pressed true (o Input
# registra o botão antes da UI). Segurar no mundo e passar por cima de uma janela continua: quem decide é o aperto.
var _attack_held := false
var _block_held := false

## Soltar vale em qualquer lugar, até sobre uma janela (o _input vem antes da UI consumir o evento).
func _input(event: InputEvent) -> void:
	if event.is_action_released("attack"):
		_attack_held = false
	if event.is_action_released("block"):
		_block_held = false

func _unhandled_input(event: InputEvent) -> void:
	if ui_blocking:
		return
	# ações "one-shot" são acumuladas até o próximo tick de física (não perde clique entre frames)
	if event.is_action_pressed("attack"):
		_pending.attack = true
		_attack_held = true
	if event.is_action_pressed("block"):
		_block_held = true
	for i in range(Balance.SKILL_SLOTS + Balance.ASC_SLOTS):     # 1-6 e 7 8 9 0 (ascensão)
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

## Botões H/G da barra de ações: o mesmo comando das teclas.
func queue_mount() -> void:
	_pending.mount = true

func queue_recall() -> void:
	_pending.recall = true

## Ataque contínuo deste passo: o botão está apertado (`input_down`) E o aperto começou no mundo.
func attack_down(input_down: bool) -> bool:
	_attack_held = _attack_held and input_down and not ui_blocking
	return _attack_held

## Bloqueio deste passo: mesma regra do ataque (RMB numa janela/slot não levanta a guarda).
func block_down(input_down: bool) -> bool:
	_block_held = _block_held and input_down and not ui_blocking
	return _block_held

func _physics_process(_delta: float) -> void:
	var cmd := InputCommand.new()
	var mouse := get_viewport().get_mouse_position()
	aim_point = camera.mouse_ground_point(mouse)
	cmd.aim = aim_point
	if not ui_blocking:
		var iv := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
		var world := camera.forward_flat() * iv.y + camera.right_flat() * iv.x
		cmd.move = Vector2(world.x, world.z)
	cmd.block = block_down(Input.is_action_pressed("block"))
	# segurar LMB = ataque contínuo (cadência da arma), só se o aperto foi no mundo
	if attack_down(Input.is_action_pressed("attack")):
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
	last_cmd = cmd
	Sim.set_player_command(cmd)
