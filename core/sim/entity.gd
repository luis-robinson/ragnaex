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
var summon_pdef: float = 0.0         # defesa do companheiro (parte da do dono; sobrevive a recompute_stats); 0 = a do monstro

# stats
var stats: Stats = Stats.new()
var hp: float = 100.0
var mp: float = 50.0
var shield_hp: float = 0.0           # escudo temporário
var form_mult: float = 1.0             # bônus da forma x maestria da skill que transformou (Balance.MASTERY_BONUS_PCT)
var form: String = ""                 # forma de animal do Druida: "" | "wolf" | "bear" | ancestral "ent" | "alpha" | "bird" (skill de forma liga/desliga)
var form_left: float = 0.0             # s até a forma acabar sozinha (0 = até desligar; Balance.FORM_DURATION)
var stealth_left: float = 0.0         # s de furtividade (monstros não enxergam); qualquer golpe quebra
var ambush: bool = false              # o golpe que quebrou a furtividade ganha bônus
var shift_base: MonsterDef = null     # monstro transformado (ShiftSystem): o MonsterDef de origem; null = na forma base
var shift_left: float = 0.0           # s de conjuração da metamorfose (> 0 = conjurando)
var shift_pick: String = ""           # forma sorteada para esta conjuração
var shift_calm: float = 0.0           # s fora de combate transformado (volta em Balance.SHIFT_REVERT_S)
var summon_hp: float = 0.0            # vida máxima fixa: invocação que herda a do dono, cópia do Shazka (a do chefe); 0 = do monstro
# Elemental que evolui (Elementalista ascendido, ElementalSystem). No mago: experiência, forma e modo (salvos);
# na invocação: elem_form/elem_stage dizem que é o elemental persistente (vazio = invocação comum).
var elem_xp: int = 0
var elem_stage: int = 0               # maior estágio alcançado (0 Básico, 1 Maior, 2 Ancestral); só sobe
var elem_form: String = ""            # "fire" | "frost" | "storm"
var grave: bool = false               # invocação: esqueleto erguido pela Marca da Cova (NecroAscension; não ocupa vaga do tipo)
var elem_mode: String = "attack"      # "attack" | "protect" | "support"
var elem_swap_at: float = 0.0         # Sim.time em que trocar de forma / chamar de novo volta
var elem_support_at: float = 0.0      # invocação: Sim.time do próximo pulso de apoio
var elem_uses: int = 0                # vezes que o mago usou a ascensão (chamar, trocar, modo, Fusão): sondas/testes
var last_target_id: int = -1          # último inimigo que este personagem acertou (modo atacar do elemental)
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
var mount_kind: String = "horse"     # qual bicho o H chama (Balance.MOUNT_KINDS; salvo; save antigo = cavalo). Mesma velocidade.
var combat_timer: float = 0.0        # >0 = "em combate" (sem regen)
var regen_hold: float = 0.0         # troll (F3): s até a regeneração voltar depois do fogo/veneno
var bags: Array = ["", "", "", ""]  # bolsas vestidas (ids bag_t*; "" = vaga vazia; Balance.BAG_SLOTS vagas)
var gather_left: float = 0.0        # >0 = colhendo (F perto de um ponto): andar/atacar/levar dano cancela
var gather_node: Dictionary = {}
var gather_hp: float = 0.0
var recall_left: float = 0.0        # >0 = conjurando a volta à cidade (G): andar, agir ou levar dano interrompe
var bind_map: String = ""          # cristal de retorno vinculado (G e renascer); "" = cidade inicial
var bind_pos: Vector3 = Vector3.ZERO
var cooldowns: Dictionary = {}       # skill_id -> segundos restantes
var cc_dr: Dictionary = {}           # categoria de controle -> [aplicações, sim.time do fim da janela] (CcDrSystem; só monstros, fora do save)
var charges: Dictionary = {}         # skill_id -> [cargas usadas, s até a próxima voltar, s de uma carga] (ChargeSystem; fora do save)
## recarga de cada atalho de poção (F1-F3), independentes: vida em F1 e mana em F2 não se bloqueiam.
## (o mesmo item não fica em dois F, então por atalho = por poção)
var potion_cds: Array[float] = [0.0, 0.0, 0.0]
## compatibilidade (cérebro dos bots): lê a recarga do F1 (vida); escrever trava/solta os três
var potion_cd: float:
	get:
		return potion_cds[0]
	set(v):
		for i in range(potion_cds.size()):
			potion_cds[i] = v
var dash_cd: float = 0.0
var dash_dir: Vector3 = Vector3.ZERO
var dash_charges_used: int = 0       # cargas do dash gastas (voltam uma de cada vez, WorldSim._tick_dash_refill)
var dash_refill: float = 0.0         # s até a carga gasta mais antiga voltar
var dash_params: Dictionary = {}     # dash resolvido no início (distância, fantasma, atordoa...)
var is_blocking: bool = false
var parry_left: float = 0.0          # s restantes da janela de aparar
var cc_immune_left: float = 0.0      # s imune a controle (caiu do cavalo: Combate Montado)
var mount_left: float = 0.0          # s até montar (conjuração do H; 0 = não está montando)
var iframe_left: float = 0.0         # s de invulnerabilidade do dash (golpe direto e efeitos de inimigo não pegam)
var sky_left: float = 0.0            # s no ar do Salto Dracônico (fora do chão: intocável, ninguém mira)
var sky: Dictionary = {}             # salto em curso: {from, to, power, effects} (RangerAscension)
var jump_window: float = 0.0         # Salto Duplo: s que ainda dá para o 2º Salto Dracônico sem recarga (RangerAscension)
var jump_window_cd: float = 0.0      # a recarga do salto que entra quando a janela fecha sem o 2º salto
var jump_second: bool = false        # o salto em curso é o 2º (não abre outra janela)
var shade := false                   # clone de sombra (ShadowSystem): não é hostil a ninguém, monstros o ignoram
var echo: Array = []                 # clone: golpes do dono à espera de repetir ({target, amount, crit})
var spirit := false                  # espírito (Anjo Guardião): ninguém mira nem acerta, não empurra, não conta como aliado de área
var choir_t: float = 0.0             # anjo: s até a próxima cura (ChoirSystem)
var aegis_cd: float = 0.0            # Égide Coral: s até a próxima cura por golpe recebido
var res_hold: float = 0.0            # caído: s que espera o Retorno em vez de renascer na cidade
var res_target: int = -1             # Bispo conjurando o Retorno: id do caído
var returned := false                # já voltou pelo Retorno nesta luta (um por aliado por luta)
var falcon: bool = false             # falcão do Caçador ascendido voando sobre ele (FalconSystem; não é entidade)
var falcon_cd: float = 0.0           # s até o próximo mergulho automático
var falcon_target: int = -1          # último inimigo que o caçador acertou (alvo do falcão)
var falcon_dive_time: float = -1000.0  # Sim.time do último mergulho (o desenho lê)
var falcon_dive_pos: Array = []      # onde os falcões mergulharam nesse instante (Revoada: até 3)
var parry_cd: float = 0.0
var shield_react_cd: float = 0.0
var guard_broken: bool = false       # MP zerou segurando a guarda: só volta soltando o botão
var grace_cd: float = 0.0            # recarga da Graça (escudo de bispo)
var fus: Dictionary = {}             # estado da Fusão do conjunto híbrido (FusionEffects: recargas, contadores)
var buffered_cmd: InputCommand = null
var buffered_ticks: int = 0
var last_cmd: InputCommand = InputCommand.new()
var aggro_target: int = -1
var aggro_timer: float = 0.0
var last_damage_from: int = -1
var hurt_at: float = -1000.0         # Sim.time do último dano levado (boneco de treino: quando se recompõe)
var player_owned := false            # invocação do jogador (ou de uma invocação dele): pode bater no boneco de treino
var threat: Dictionary = {}          # attacker_id -> ameaça (dano + provocações); decide o alvo
var damage_by: Dictionary = {}       # attacker_id -> dano real; decide quem levou o abate
var taunt_left: float = 0.0          # s preso no alvo atual
var phase: int = 0                   # fases de chefe já iniciadas
var dmg_mult: float = 1.0            # fúria de chefe (enrage_mult × berserk)
var enrage_mult: float = 1.0         # chefe: fúria da fase (MonsterDef.phases[].enrage)
var fight_time: float = 0.0          # chefe: s em combate nesta luta (MonsterDef.berserk_after)
var berserk := false                 # chefe: passou do tempo da luta e enlouqueceu
var ward_base: float = 0.0           # chefe: fração de dano cortada enquanto os lacaios vivem (fase com "ward")
var ward: float = 0.0                # corte valendo agora (0 = sem lacaio vivo)
var ward_t: float = 0.0              # s até reconferir os lacaios
var crowd: int = 0                   # chefe: quantos lutam contra ele agora (MobSystem.crowd_of)
var crowd_mult: float = 1.0          # chefe: dano × por quem luta (Balance.BOSS_CROWD_*)
var crowd_t: float = 0.0             # s até recontar
var crowd_peak: int = 0              # chefe: maior contagem nesta luta (só avisa quando passa dela)
var boss_id: int = -1                # lacaio: chefe que o chamou
var leader_id: int = -1              # escolta: líder que este monstro segue (capitão, sargento)
var escort_slot: int = 0             # escolta: vaga no anel em volta do líder
var patrol_route: Array = []         # líder em ronda: pontos (Vector3) que ele percorre sem alvo
var patrol_i: int = 0
var boss_spoke := false             # chefe já disse a fala de abertura nesta luta (MonsterDef.intro)
var adds_epoch: int = 0              # chefe: sobe ao resetar; lacaios de época antiga somem
var eggs_ready: bool = false          # chefe com ninho (MonsterDef.eggs): ovos já postos nesta época
var sig: Dictionary = {}             # chefe: estado da assinatura (canal, sequência, muralha; BossSignatures). reset_boss limpa
var dead_time: float = 0.0
var home_position: Vector3 = Vector3.ZERO
var hit_flash: float = 0.0

# progressão / itens (jogadores e bots)
## barra de skills: Balance.SKILL_SLOTS posições (null = vazio) com skills APRENDIDAS. Monstros: lista simples.
var skills: Array[SkillDef] = []
var learned: Dictionary = {}         # skill_id -> true (aprendidas com pontos)
var talents: Dictionary = {}         # talent_id -> true (evoluções compradas)
var tree: Dictionary = {}            # node_id -> true (nós comprados na árvore de pontos)
var asc_tree: Dictionary = {}        # node_id -> true (teia de ascensão; pontos próprios, ProgressionSystem.asc_points)
var tree_bonus: Dictionary = {}      # soma dos passivos da árvore (formato de buff: atk_pct, hp_pct...)
var ct: Dictionary = {}              # ganchos dos talentos de classe escolhidos (ClassTalentSystem.refresh)
var ct_ready_at: float = 0.0         # Sim.time em que "recusa a morrer"/Intercessão volta
var immortal_left: float = 0.0       # s em que nenhum golpe passa de 1 HP (talento de classe)
var mastery: Dictionary = {}         # skill_id -> level 0..5
var mastery_points: int = 0          # "pontos de skill": aprender, maestria e evoluções
var build_id: String = ""            # bots: build escolhida (guia equipamento/skills)
var inventory: Dictionary = {}       # item_id -> count
var leg_cast_at: float = 0.0       # arma lendária que lança magia: quando pode lançar de novo (Balance.LEG_CAST_ICD)
var sig_ready_at: float = 0.0      # efeito-assinatura da build: quando pode disparar de novo (Balance.SIGNATURE_ICD)
var legend_ready_at: float = 0.0   # arma lendária: quando o efeito com recarga (icd) pode disparar de novo
var leg50_ready: Dictionary = {}  # Lendários do 50: "<build>_<peça>" -> quando o gatilho pode disparar de novo (PieceEffects)
var shot_ready_at: float = 0.0     # Bala na Agulha (Corsário): quando a pistola pode atirar de graça de novo (Balance.LEG_SHOT_ICD)
var combo_spent: int = 0           # Bravata gasta no último finalizador (Tiro Entre os Olhos), para o FX e os testes
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
var repeat_cmd: InputCommand = null  # cópia reaproveitada do brain_cmd entre pensamentos (sem alocar um comando por tick)
var npc_data: Dictionary = {}
var guard := false                   # NPC que luta (sentinela do povoado): monstros o atacam e ele revida (GuardBrain)
var raid_id := -1                    # monstro de uma investida (RaidSystem): marcha pela rota, luta no caminho
var raid_leg := 0                    # investida: índice do próximo ponto da rota
var raid_route := 0                  # investida: qual rota do mapa (RaidSystem.routes; 0 = MapDef.raid)
var stance := ""                     # monstro que trocou de arma (MonsterDef.swap): "bow" = espada guardada, arco na mão
var road_event := false              # monstro de evento de estrada (RoadEventSystem): sem XP/saque/quest de abate
var road_grace := false              # graça dos bots: bot de fora do grupo `road_grace_party` não o mira (nem ele ao bot)
var road_grace_party: int = -1
var dormant := false                 # monstro sem ninguém por perto: não pensa nem anda (WorldSim._dormant)
var npc_goal: Vector3 = Vector3.ZERO  # NPC que passeia: para onde está indo
var npc_wait: float = 0.0            # parado olhando em volta antes do próximo passo
var npc_hold: float = 0.0            # conversando: fica parado
var npc_leg: int = 0                 # ronda: índice do próximo ponto
var npc_stuck: float = 0.0
var npc_alarm := false               # morador com `alarm` correndo para o abrigo (leva viva no mapa; NpcSystem)
# Supremas do 40 (UltimateSystem; estado de luta, não vai no save)
var ult_charge: float = 0.0           # Carga Suprema 0..Balance.ULT_MAX
var ult_dealt: float = 0.0           # dano das suas Supremas até agora (só medição: sondas/testes; não vai no save)
var ult_combat_t: float = -1000.0     # Sim.time do último golpe/cura em combate
var ult_gap_until: float = 0.0        # Sim.time até quando nada enche (depois de soltar)
var ult_full_at: float = -1.0         # Sim.time em que encheu (bot segura até BOT_ULT_HOLD); -1 = não está cheia
var ult_ok := false                   # cache: liberada (nível + ascensão), reconferida a cada Balance.ULT_REFRESH_S
var ult_role := "dps"                 # cache: papel da build principal
var ult_check_at: float = -1000.0
var ult_budget: float = Balance.ULT_RATE_BURST          # estoque do teto de ritmo (Balance.ULT_RATE_CAP/ULT_RATE_BURST); enche no tique
var ult_act_tick: int = -1            # ação que está enchendo (tique + skill): conta até Balance.ULT_AOE_TARGETS alvos
var ult_act_skill: String = ""
var ult_act_n: int = 0
var hop: Dictionary = {}              # hop_strikes em andamento (HopSystem)
var shield_src: int = -1              # quem pôs o escudo (a absorção conta como cura dele na Carga Suprema)
var free_summon := false              # invocação fora do limite por tipo (summon.ignore_max)
var expire_blast: Dictionary = {}     # invocação que explode ao acabar o tempo (Maré dos Mortos: {radius, power, skill})

func is_alive() -> bool:
	return state != State.DEAD

## NPC no alto da muralha/torre (npc_data.perch = altura visual): atira, não anda, não é alvo.
func is_perched() -> bool:
	return kind == Kind.NPC and float(npc_data.get("perch", 0.0)) > 0.0

func is_character() -> bool:
	return kind == Kind.PLAYER or kind == Kind.BOT

## Boneco de treino (MonsterDef.dummy).
func is_dummy() -> bool:
	return monster_def != null and monster_def.dummy

func is_hostile_to(other: SimEntity) -> bool:
	if other == null or other == self or shade or other.shade or spirit or other.spirit:
		return false                        # clone de sombra / espírito (Anjo Guardião): ninguém os mira nem acerta, e eles não miram ninguém
	if is_dummy() or other.is_dummy():      # boneco de treino: só contra o jogador e as invocações dele (simétrico)
		var o: SimEntity = other if is_dummy() else self
		return not o.is_dummy() and (o.kind == Kind.PLAYER or (o.kind == Kind.SUMMON and o.player_owned))
	if road_grace and other.kind == Kind.BOT and (other.party_id < 0 or other.party_id != road_grace_party):
		return false                        # evento de estrada: nos primeiros segundos é do jogador (RoadEventSystem._set_grace)
	if other.road_grace and kind == Kind.BOT and (party_id < 0 or party_id != other.road_grace_party):
		return false
	var a_mob := kind == Kind.MONSTER
	var b_mob := other.kind == Kind.MONSTER
	if (other.kind == Kind.NPC and not other.guard) or (kind == Kind.NPC and not guard):
		return false
	if a_mob and other.kind == Kind.NPC and other.is_perched():
		return false                        # besteiro no alto da torre: o monstro não alcança, nem tenta
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

## Põe o debuff trocando o de mesmo id (renova, não acumula). Dano no tempo renovado guarda o acumulado e o relógio
## do pulso (Balance.DOT_PULSE_S): reaplicar mais rápido que o pulso não zera o dano.
func put_debuff(d: Dictionary) -> void:
	var id: Variant = d.get("id")
	if id != null and d.get("kind") == "dot":
		for x in debuffs:
			if x.get("id") == id and x.get("kind") == "dot":
				d["acc"] = float(x.get("acc", 0.0))
				if x.has("pulse"):
					d["pulse"] = x["pulse"]
				break
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
	if spirit or other.spirit:
		return false                        # espírito: cura e buff de área não gastam alvo nele
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
		for b in buffs:                      # aura/desânimo de facção (AuraSystem.mob_aura): só os marcados mexem no monstro
			if b.get("mob_stat", false):
				stats.patk *= 1.0 + float(b.get("atk_pct", 0)) / 100.0
				stats.matk *= 1.0 + float(b.get("atk_pct", 0)) / 100.0
				stats.move_speed *= 1.0 + float(b.get("speed_pct", 0)) / 100.0
				stats.attack_speed += float(b.get("aspd_pct", 0))
				stats.cc_resist_pct += float(b.get("cc_resist_pct", 0))     # Laço Selvagem: o lince resiste a controle
		if kind == Kind.SUMMON:
			stats.max_hp *= 1.0 + 0.1 * level
			if summon_patk > 0.0:            # ataque do dono vale para golpe e magia da invocação
				stats.patk = summon_patk
				stats.matk = summon_patk
			for b in buffs:                 # Laço Selvagem / Maré dos Mortos: buff de invocação depois do ataque do dono
				if b.has("pet_atk_pct"):
					stats.patk *= 1.0 + float(b["pet_atk_pct"]) / 100.0
					stats.matk *= 1.0 + float(b["pet_atk_pct"]) / 100.0
			if summon_pdef > 0.0:
				stats.pdef = summon_pdef       # companheiro: defesa herdada do dono
		if summon_hp > 0.0:                  # invocação que herda a vida do dono, ou cópia do Shazka (vida do chefe)
			stats.max_hp = summon_hp
	else:
		var extra: Array = [tree_bonus] if not tree_bonus.is_empty() else []
		if form != "":
			extra.append(scaled_bonus(Balance.FORM_STATS[form], form_mult))
			if ct.has("form_stats"):
				extra.append(ct["form_stats"])          # talento que só vale na forma (Uivo da Lua)
			extra.append_array(PieceEffects.form_extra(self))     # peças do 50 (form_up)
		stats = Stats.compute(class_def, level, equipment, buffs + extra)
		if form != "" and not stats.meets([Balance.FORM_REQUIRES[form]]):
			form = ""                # trocou de arma: volta à forma humana
			stats = Stats.compute(class_def, level, equipment, buffs + ([tree_bonus] if not tree_bonus.is_empty() else []))
		TitanSystem.apply(self, stats)          # Garras de Titã (Punhos ascendido)
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
	if not buffs.is_empty():
		for b in buffs:
			if b.get("id") == Balance.LEG_DETERMINATION_BUFF:     # Determinação (escudo lendário): mais cura recebida por carga
				f *= 1.0 + float(b.get("heal_in_pct", 0.0)) / 100.0
	if stats != null and stats.heal_taken_pct > 0.0:
		f *= 1.0 + stats.heal_taken_pct / 100.0          # notável de papel (Cura de Si, Seiva, Pacto de Sangue)
	return f

func mastery_of(skill_id: String) -> int:
	return int(mastery.get(skill_id, 0))

## Tipos diferentes que cabem na bolsa (cada pilha ocupa um espaço).
func bag_capacity() -> int:
	var n := Balance.BAG_BASE
	for bid in bags:
		n += ItemSystem.bag_size(str(bid))
	return n

## Item novo não cabe (o que já tem empilha sempre).
func bag_full_for(item_id: String) -> bool:
	return not inventory.has(item_id) and inventory.size() >= bag_capacity()

func add_item(item_id: String, count: int = 1) -> void:
	inventory[item_id] = int(inventory.get(item_id, 0)) + count
	Events.post(&"item_gained", id, item_id, count)

func remove_item(item_id: String, count: int = 1) -> bool:
	var have := int(inventory.get(item_id, 0))
	if have < count:
		return false
	if have == count:
		inventory.erase(item_id)
	else:
		inventory[item_id] = have - count
	Events.post(&"item_removed", id, item_id, count)
	return true

func has_item(item_id: String, count: int = 1) -> bool:
	return int(inventory.get(item_id, 0)) >= count

func inventory_weight() -> int:
	var n := 0
	for k in inventory:
		n += int(inventory[k])
	return n

func knows(skill_id: String) -> bool:
	return learned.has(skill_id)          # skill de ascensão também: comprada na teia de ascensão

func has_talent(talent_id: String) -> bool:
	return talents.has(talent_id)

## Posição da skill na barra (ou -1).
func slot_of(skill_id: String) -> int:
	for i in range(skills.size()):
		if skills[i] and skills[i].id == skill_id:
			return i
	return -1

## Garante a barra (personagens): SKILL_SLOTS posições, + ASC_SLOTS (7, 8, 9, 0) com a ascensão.
func ensure_slots() -> void:
	var n := slot_count()
	while skills.size() < n:
		skills.append(null)
	if skills.size() > n:
		skills.resize(n)

## Tamanho da barra: 6, ou 10 com a ascensão da classe.
func slot_count() -> int:
	return Balance.SKILL_SLOTS + (Balance.ASC_SLOTS if ProgressionSystem.has_ascension(self) else 0)

## Título de honra (Prova 45 e afins): o `reward_title` da última missão concluída que dá título ("" = nenhum).
## Sai das missões concluídas (sem campo novo no save).
func honor_title() -> String:
	for i in range(quests_completed.size() - 1, -1, -1):
		var q = GameData.quests.get(quests_completed[i])
		if q != null and q.reward_title != "":
			return q.reward_title
	return ""

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
