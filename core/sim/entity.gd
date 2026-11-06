class_name SimEntity
extends RefCounted
## Entidade da simulação: jogador, bot, monstro, NPC ou invocação. Sem nós.

enum Kind { PLAYER, BOT, MONSTER, NPC, SUMMON }
enum State { IDLE, MOVING, ATTACKING, CASTING, BLOCKING, DASHING, STUNNED, DEAD }

var id: int = 0
var name: String = ""
var look: Dictionary = {}           # aparência (LooksCatalog): sexo, cabelo, barba, olhos — só a apresentação usa
var kind: Kind = Kind.PLAYER
var map_id: String = ""
var position: Vector3 = Vector3.ZERO
var facing: float = 0.0            # yaw em radianos (0 = +Z)
var velocity: Vector3 = Vector3.ZERO
var jump_h: float = 0.0              ## altura do pulo (m). A sim é plana: o pulo é só vertical, não passa obstáculos
var jump_v: float = 0.0              ## velocidade vertical do pulo (m/s)
var radius: float = 0.45
var scale: float = 1.0

# identidade
var class_def: ClassDef = null
var monster_def: MonsterDef = null
var level: int = 1
var xp: int = 0
var gold: int = 0
var owner_id: int = -1              # para invocações
var party_id: int = -1              # grupo (WorldSim.parties); invocações herdam o do dono
var summon_expires: float = 0.0
var summon_patk: float = 0.0         # ataque da invocação (vem do dono; sobrevive a recompute_stats)

# stats
var stats: Stats = Stats.new()
var hp: float = 100.0
var mp: float = 50.0
var shield_hp: float = 0.0           # escudo temporário
var form_mult: float = 1.0             # bônus da forma x maestria da skill que transformou (Balance.MASTERY_BONUS_PCT)
var form: String = ""                 # forma de animal do Druida: "" | "wolf" | "bear" (skill de forma liga/desliga)
var form_left: float = 0.0             # s até a forma acabar sozinha (0 = até desligar; Balance.FORM_DURATION)
var stealth_left: float = 0.0         # s de furtividade (monstros não enxergam); qualquer golpe quebra
var ambush: bool = false              # o golpe que quebrou a furtividade ganha bônus
var summon_hp: float = 0.0            # invocação que herda a vida do dono (companheiro); 0 = do monstro
var buffs: Array = []                # [{id, duration, remaining, atk_pct, ...}]
var debuffs: Array = []              # [{id, remaining, kind:"dot|slow|stun|root", ...}]

# combate
var state: State = State.IDLE
var state_time: float = 0.0          # tempo dentro do estado atual
var state_duration: float = 0.0
var current_skill: SkillDef = null
var current_skill_slot: int = -1
var channel_done: int = 0             # pulsos já aplicados da canalização atual
var skill_phase: String = ""         # startup | active | recovery
var skill_applied: bool = false
var skill_aim: Vector3 = Vector3.ZERO
var basic_cd: float = 0.0
var basic_skill: SkillDef = null     # ataque básico (gerado por classe/monstro)
var mounted := false                 # a cavalo (mais rápido; só fora de combate)
var combat_timer: float = 0.0        # >0 = "em combate" (sem regen)
var bag_bonus: int = 0               # Bolsas Ampliadas usadas (0..Balance.BAG_UPGRADES)
var gather_left: float = 0.0        # >0 = colhendo (F perto de um ponto): andar/atacar/levar dano cancela
var gather_node: Dictionary = {}
var gather_hp: float = 0.0
var recall_left: float = 0.0        # >0 = voltando à cidade (G): parado, fora de combate
var bind_map: String = ""          # cristal de retorno vinculado (G e renascer); "" = cidade inicial
var bind_pos: Vector3 = Vector3.ZERO
var cooldowns: Dictionary = {}       # skill_id -> segundos restantes
var potion_cd: float = 0.0
var dash_cd: float = 0.0
var dash_dir: Vector3 = Vector3.ZERO
var dash_charges_used: int = 0       # evolução "2 cargas": dashes já usados na janela atual
var dash_params: Dictionary = {}     # dash resolvido no início (distância, fantasma, atordoa...)
var is_blocking: bool = false
var parry_left: float = 0.0          # s restantes da janela de aparar
var parry_cd: float = 0.0
var shield_react_cd: float = 0.0
var guard_broken: bool = false       # MP zerou segurando a guarda: só volta soltando o botão
var grace_cd: float = 0.0            # recarga da Graça (escudo de bispo)
var buffered_cmd: InputCommand = null
var buffered_ticks: int = 0
var last_cmd: InputCommand = InputCommand.new()
var aggro_target: int = -1
var aggro_timer: float = 0.0
var last_damage_from: int = -1
var threat: Dictionary = {}          # attacker_id -> ameaça (dano + provocações); decide o alvo
var damage_by: Dictionary = {}       # attacker_id -> dano real; decide quem levou o abate
var taunt_left: float = 0.0          # s preso no alvo atual
var phase: int = 0                   # fases de chefe já iniciadas
var dmg_mult: float = 1.0            # fúria de chefe
var boss_id: int = -1                # lacaio: chefe que o chamou
var boss_spoke := false             # chefe já disse a fala de abertura nesta luta (MonsterDef.intro)
var adds_epoch: int = 0              # chefe: sobe ao resetar; lacaios de época antiga somem
var dead_time: float = 0.0
var home_position: Vector3 = Vector3.ZERO
var hit_flash: float = 0.0

# progressão / itens (jogadores e bots)
## barra de skills: Balance.SKILL_SLOTS posições (null = vazio) com skills APRENDIDAS. Monstros: lista simples.
var skills: Array[SkillDef] = []
var learned: Dictionary = {}         # skill_id -> true (aprendidas com pontos)
var talents: Dictionary = {}         # talent_id -> true (evoluções compradas)
var tree: Dictionary = {}            # node_id -> true (nós comprados na árvore de pontos)
var tree_bonus: Dictionary = {}      # soma dos passivos da árvore (formato de buff: atk_pct, hp_pct...)
var mastery: Dictionary = {}         # skill_id -> level 0..5
var mastery_points: int = 0          # "pontos de skill": aprender, maestria e evoluções
var build_id: String = ""            # bots: build escolhida (guia equipamento/skills)
var inventory: Dictionary = {}       # item_id -> count
var leg_cast_at: float = 0.0       # arma lendária que lança magia: quando pode lançar de novo (Balance.LEG_CAST_ICD)
var sig_ready_at: float = 0.0      # efeito-assinatura da build: quando pode disparar de novo (Balance.SIGNATURE_ICD)
var legend_ready_at: float = 0.0   # arma lendária: quando o efeito com recarga (icd) pode disparar de novo
var lost_leader_t: float = 0.0     # s em outro mapa que o líder do grupo (bots: reaparecem ao lado dele)
var storage: Dictionary = {}         # depósito (NPC Guarda-volumes): item_id -> count; salvo com o personagem
var equipment: Dictionary = {}       # ItemDef.Slot -> ItemDef
var potion_slots: Array[String] = ["", "", ""]
var quests_active: Dictionary = {}   # quest_id -> progress
var quests_completed: Array[String] = []
var bosses_killed: Dictionary = {}   # monster_id -> true (chefes abatidos, para selos e portões)
var gates_open: Dictionary = {}      # portal_id -> true (portão já aberto continua aberto)
var portal_notice_at: float = 0.0    # próximo aviso de portal bloqueado
var brain = null                     # BotBrain / MonsterBrain (produz InputCommand)
var brain_cmd: InputCommand = null   # último comando do cérebro (reutilizado entre pensamentos)
var npc_data: Dictionary = {}
var guard := false                   # NPC que luta (sentinela do povoado): monstros o atacam e ele revida (GuardBrain)
var raid_id := -1                    # monstro de uma investida (RaidSystem): marcha pela rota, luta no caminho
var raid_leg := 0                    # investida: índice do próximo ponto da rota
var stance := ""                     # monstro que trocou de arma (MonsterDef.swap): "bow" = espada guardada, arco na mão
var dormant := false                 # monstro sem ninguém por perto: não pensa nem anda (WorldSim._dormant)
var npc_goal: Vector3 = Vector3.ZERO  # NPC que passeia: para onde está indo
var npc_wait: float = 0.0            # parado olhando em volta antes do próximo passo
var npc_hold: float = 0.0            # conversando: fica parado
var npc_leg: int = 0                 # ronda: índice do próximo ponto
var npc_stuck: float = 0.0

func is_alive() -> bool:
	return state != State.DEAD

func is_character() -> bool:
	return kind == Kind.PLAYER or kind == Kind.BOT

func is_hostile_to(other: SimEntity) -> bool:
	if other == null or other == self:
		return false
	var a_mob := kind == Kind.MONSTER
	var b_mob := other.kind == Kind.MONSTER
	if (other.kind == Kind.NPC and not other.guard) or (kind == Kind.NPC and not guard):
		return false
	if kind == Kind.SUMMON or kind == Kind.NPC:        # invocação e sentinela: só contra monstros
		return b_mob
	if other.kind == Kind.SUMMON or other.kind == Kind.NPC:
		return a_mob
	return a_mob != b_mob

## Chave de "time": o grupo, ou a própria entidade (invocações usam a do dono).
func group_key() -> int:
	if party_id >= 0:
		return party_id
	return -10 - (owner_id if kind == Kind.SUMMON else id)

## Põe o buff trocando o de mesmo id (renova, não acumula).
func put_buff(b: Dictionary) -> void:
	var id: Variant = b.get("id")
	buffs = buffs.filter(func(x): return x.get("id") != id)
	buffs.append(b)

## Põe o debuff trocando o de mesmo id (renova, não acumula).
func put_debuff(d: Dictionary) -> void:
	var id: Variant = d.get("id")
	debuffs = debuffs.filter(func(x): return x.get("id") != id)
	debuffs.append(d)

func drop_buff(id: String) -> void:
	buffs = buffs.filter(func(x): return x.get("id") != id)

## Acúmulos do buff `id` (0 se não tem).
func buff_stacks(id: String) -> int:
	for b in buffs:
		if b.get("id") == id:
			return int(b.get("stacks", 0))
	return 0

## Aliado para cura/buff: si mesmo, o grupo e as invocações deles (monstros entre si).
func is_friend(other: SimEntity) -> bool:
	if other == null:
		return false
	if other == self:
		return true
	if kind == Kind.MONSTER or other.kind == Kind.MONSTER:
		return kind == other.kind
	if kind == Kind.NPC or other.kind == Kind.NPC:
		return guard or other.guard            # sentinela: aliada de todos (cura e buff de área pegam nela)
	return group_key() == other.group_key()

func can_act() -> bool:
	return state in [State.IDLE, State.MOVING, State.BLOCKING]

## No ar (pulando): anda e dá dash, mas golpes/skills esperam o pouso.
func airborne() -> bool:
	return jump_h > 0.0 or jump_v > 0.0

func forward() -> Vector3:
	return Vector3(sin(facing), 0.0, cos(facing))

func face_towards(point: Vector3) -> void:
	var d := point - position
	d.y = 0.0
	if d.length_squared() > 0.0001:
		facing = atan2(d.x, d.z)

func recompute_stats() -> void:
	if monster_def:
		stats = Stats.from_monster(monster_def)
		stats.patk *= dmg_mult
		stats.matk *= dmg_mult
		if kind == Kind.SUMMON:
			stats.max_hp *= 1.0 + 0.1 * level
			if summon_patk > 0.0:            # ataque do dono vale para golpe e magia da invocação
				stats.patk = summon_patk
				stats.matk = summon_patk
			if summon_hp > 0.0:
				stats.max_hp = summon_hp
	else:
		var extra: Array = [tree_bonus] if not tree_bonus.is_empty() else []
		if form != "":
			extra.append(scaled_bonus(Balance.FORM_STATS[form], form_mult))
		stats = Stats.compute(class_def, level, equipment, buffs + extra)
		if form != "" and not stats.meets([Balance.FORM_REQUIRES[form]]):
			form = ""                # trocou de arma: volta à forma humana
			stats = Stats.compute(class_def, level, equipment, buffs + ([tree_bonus] if not tree_bonus.is_empty() else []))
		if class_def:
			basic_skill = GameData.basic_skill_for_class(class_def, stats.weapon_type, stats.offhand_type, LegendEffects.signature_build(self))
	hp = minf(hp, stats.max_hp)
	mp = minf(mp, stats.max_mp)

func heal_full() -> void:
	hp = stats.max_hp
	mp = stats.max_mp

func set_state(s: State, duration: float = 0.0) -> void:
	state = s
	state_time = 0.0
	state_duration = duration

func has_debuff(kind: String) -> bool:
	for d in debuffs:
		if d.get("kind") == kind:
			return true
	return false

func slow_factor() -> float:
	var f := 1.0
	for d in debuffs:
		if d.get("kind") == "slow":
			f *= 1.0 - float(d.get("pct", 0)) / 100.0
	return maxf(f, 0.1)

## Cura recebida: Murchar reduz.
func heal_factor() -> float:
	var f := 1.0
	for d in debuffs:
		if d.get("kind") == "wither":
			f *= 1.0 - float(d.get("pct", 0)) / 100.0
	return f

func mastery_of(skill_id: String) -> int:
	return int(mastery.get(skill_id, 0))

## Tipos diferentes que cabem na bolsa (cada pilha ocupa um espaço).
func bag_capacity() -> int:
	return Balance.BAG_BASE + Balance.BAG_STEP * bag_bonus

## Item novo não cabe (o que já tem empilha sempre).
func bag_full_for(item_id: String) -> bool:
	return not inventory.has(item_id) and inventory.size() >= bag_capacity()

func add_item(item_id: String, count: int = 1) -> void:
	inventory[item_id] = int(inventory.get(item_id, 0)) + count
	Events.item_gained.emit(id, item_id, count)

func remove_item(item_id: String, count: int = 1) -> bool:
	var have := int(inventory.get(item_id, 0))
	if have < count:
		return false
	if have == count:
		inventory.erase(item_id)
	else:
		inventory[item_id] = have - count
	Events.item_removed.emit(id, item_id, count)
	return true

func has_item(item_id: String, count: int = 1) -> bool:
	return int(inventory.get(item_id, 0)) >= count

func inventory_weight() -> int:
	var n := 0
	for k in inventory:
		n += int(inventory[k])
	return n

func knows(skill_id: String) -> bool:
	return learned.has(skill_id)

func has_talent(talent_id: String) -> bool:
	return talents.has(talent_id)

## Posição da skill na barra (ou -1).
func slot_of(skill_id: String) -> int:
	for i in range(skills.size()):
		if skills[i] and skills[i].id == skill_id:
			return i
	return -1

## Garante a barra com SKILL_SLOTS posições (personagens).
func ensure_slots() -> void:
	while skills.size() < Balance.SKILL_SLOTS:
		skills.append(null)

func display_title() -> String:
	if class_def:
		return "%s Lv.%d" % [class_def.name, level]
	if monster_def:
		return "Lv.%d" % level
	return ""


## Bônus (buff ou forma) com a maestria: valores positivos x mult; penalidades, id e tempos ficam iguais.
const BONUS_FIXED_KEYS := ["id", "duration", "remaining", "stacks"]
static func scaled_bonus(d: Dictionary, mult: float) -> Dictionary:
	if is_equal_approx(mult, 1.0):
		return d
	var out := d.duplicate()
	for k in out:
		var v: Variant = out[k]
		if not (k in BONUS_FIXED_KEYS) and (v is float or v is int) and float(v) > 0.0:
			out[k] = float(v) * mult
	return out
