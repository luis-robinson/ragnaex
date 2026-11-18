class_name PlayerController
extends Node
## Lê teclado/mouse e monta o InputCommand do jogador a cada tick de física.
## WASD relativo à câmera, mira = ponto do chão sob o mouse (MOBA), LMB ataque, RMB bloqueio,
## 1-6 skills, F1-F3 poções, Shift dash, Espaço pula, F interage, H monta, G volta à cidade, Tab trava no chefe (BossLock).

signal lock_changed(target_id: int)   ## trava no chefe mudou (-1 = solta); HUD e marcador ouvem

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
var lock := BossLock.new()          # Tab: trava no chefe (movimento e mira no chefe)
var _lock_toggle := false

## Soltar vale em qualquer lugar, até sobre uma janela (o _input vem antes da UI consumir o evento).
func _input(event: InputEvent) -> void:
	if event.is_action_released("attack"):
		_attack_held = false
	if event.is_action_released("block"):
		_block_held = false
	# Tab no _input: um botão do HUD com foco comeria o Tab (ui_focus_next) antes do _unhandled_input
	if not ui_blocking and event.is_action_pressed("lock_target") and not event.is_echo():
		_lock_toggle = true
		get_viewport().set_input_as_handled()

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

## Tab: trava no chefe por perto (cursor vence o mais perto) ou solta. Sem chefe: aviso e nada muda.
func toggle_lock(cursor: Vector3) -> void:
	if lock.active():
		_set_lock(null)
		return
	var p: SimEntity = Sim.player
	if p == null or not Sim.maps.has(p.map_id):
		return
	var boss := BossLock.pick(Sim.maps[p.map_id]["entities"], p.position, cursor, Balance.BOSS_LOCK_RANGE, Balance.BOSS_LOCK_CURSOR_PAD)
	if boss == null:
		Events.notification.emit("Nenhum chefe por perto")
		return
	_set_lock(boss)

func _set_lock(boss: SimEntity) -> void:
	if boss:
		lock.lock(boss)
	else:
		lock.release()
	lock_changed.emit(lock.target_id)

## Chefe travado ainda vale? Solta sozinho pelas regras de BossLock.release_reason.
func _locked_boss() -> SimEntity:
	if not lock.active():
		return null
	var boss: SimEntity = Sim.get_entity(lock.target_id)
	if BossLock.release_reason(Sim.player, boss, lock.map_id, lock.epoch, Balance.BOSS_LOCK_RELEASE) != "":
		_set_lock(null)
		return null
	return boss

func _physics_process(_delta: float) -> void:
	var cmd := InputCommand.new()
	var mouse := get_viewport().get_mouse_position()
	aim_point = camera.mouse_ground_point(mouse)
	if _lock_toggle:
		_lock_toggle = false
		toggle_lock(aim_point)
	var boss := _locked_boss()
	cmd.aim = BossLock.aim_point(boss) if boss else aim_point
	if not ui_blocking:
		var iv := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
		if boss and Sim.player:
			cmd.move = _lock_move(Sim.player, boss, iv)
		else:
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

## Movimento travado: W/S mexem a distância (o raio de A/D segue a distância atual); A/D giram no raio guardado.
func _lock_move(p: SimEntity, boss: SimEntity, iv: Vector2) -> Vector2:
	var r := Vector2(p.position.x - boss.position.x, p.position.z - boss.position.z).length()
	if absf(iv.y) > 0.001 or lock.orbit_r <= 0.0:
		lock.orbit_r = r
	return BossLock.move_vector(p.position, boss.position, iv, lock.orbit_r, boss.radius + p.radius + Balance.BOSS_LOCK_MIN_GAP, Balance.BOSS_LOCK_ORBIT_AHEAD)
