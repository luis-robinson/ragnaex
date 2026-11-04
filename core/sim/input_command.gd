class_name InputCommand
extends RefCounted
## Um "pacote de input" por tick. Jogador E bots produzem exatamente isso.
## Quando o jogo virar online, é isto que vai pela rede.

var move: Vector2 = Vector2.ZERO    ## direção no plano XZ (já relativa à câmera), magnitude 0..1
var aim: Vector3 = Vector3.ZERO     ## ponto no chão para onde o mouse aponta (world space)
var attack: bool = false            ## botão esquerdo (pressionado neste tick)
var block: bool = false             ## botão direito (segurado)
var skill_slot: int = -1            ## 0..5 (teclas 1..6), -1 = nenhum
var potion_slot: int = -1           ## 0..2 (F1..F3)
var interact: bool = false          ## F
var jump: bool = false              ## Espaço
var dash: bool = false              ## Shift
var mount: bool = false             ## H: montar/desmontar
var recall: bool = false            ## G: voltar à cidade

func has_action() -> bool:
	return attack or skill_slot >= 0 or potion_slot >= 0 or interact or dash

func duplicate_cmd() -> InputCommand:
	var c := InputCommand.new()
	c.move = move; c.aim = aim; c.attack = attack; c.block = block
	c.skill_slot = skill_slot; c.potion_slot = potion_slot; c.interact = interact; c.dash = dash; c.jump = jump; c.mount = mount
	return c
