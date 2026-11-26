class_name BotBrain
extends RefCounted
## "Jogador falso". FSM utilitária: fica na cidade, conversa, vai caçar num campo do seu nível,
## usa skills/poções/bloqueio, volta pra cidade quando a bolsa enche ou o HP cai, vende, repete.
## Usa o MESMO InputCommand do jogador — a simulação não sabe que é bot.
## Em grupo: o líder segue a própria rotina; os outros seguem o líder (até por portais), curam o grupo e
## atacam o que bate nele. Bots também montam grupos entre si e às vezes convidam o jogador.

enum S { TOWN_IDLE, TOWN_WALK, TRAVEL, HUNT, RETURN, SHOP }

var state: S = S.TOWN_IDLE
var timer: float = 0.0
var chat_timer: float = 0.0
var target_pos: Vector3 = Vector3.ZERO
var dest_map: String = ""
var travel_map := ""           # mapa da última etapa da viagem: a cada portal passado o prazo (BOT_TRAVEL_LEG_S) recomeça
var rng: RandomNumberGenerator
var stuck_timer: float = 0.0
var last_pos: Vector3 = Vector3.ZERO
var detour: Vector2 = Vector2.ZERO
var detour_timer: float = 0.0
var detour_side: float = 1.0
var detour_tries: int = 0
var detour_age: float = 99.0
var hunt_target_id: int = -1
var block_timer: float = 0.0
var engaged := false           # corpo a corpo: já no alcance (histerese: entra a 75% do alcance, sai a 95%)
var flee_timer: float = 0.0    # recuando com pouca vida
var recall_retry: float = 0.0  # volta (G) interrompida: anda para o portal e tenta de novo depois disto
var stall_t: float = 0.0       # no alcance mas o alvo não perde vida (obstáculo no meio): chega mais perto
var stall_hp: float = -1.0
var stealth_peak: float = 0.0   # furtividade no começo desta sombra (quanto tempo já contornou o alvo)
var personality: float = 0.5   # 0 = cauteloso, 1 = agressivo
var cur_def: MapDef = null     # mapa do tick atual (rota pelos portões da vila)
var cur_sim = null             # para desviar da água pelas pontes
var water_path: Array = []     # pontos até atravessar a água pela ponte
var water_goal := Vector3.INF
var water_timer: float = 0.0
var recent_lines: Array = []   # falas recentes (BotChat não repete)
var shop_timer: float = 0.0    # seguidor: reabastece na vila a cada tanto
var defend_wave := -1          # leva da investida que este bot decidiu defender (-1 = nenhuma)
var skip_wave := -1            # leva que ele decidiu ignorar (decide uma vez por leva)
var falling_back := false      # defensor ferido: recua para dentro das muralhas até recuperar
var tank_id := -1              # tanque do grupo (recalculado a cada TANK_RECHECK s; -1 = sem tanque)
var tank_t := 0.0
var my_role := ""              # papel da build (ProgressionSystem.role_of), lido uma vez
const TANK_RECHECK := 2.0
var place_t := 0.0             # s seguidos indo para o lugar do papel (lugar inalcançável: desiste por um tempo)
var place_cool := 0.0
var focus_t := 0.0             # próxima reavaliação do foco no bando (_focus)
var threat_room := INF          # ameaça que cabe antes de passar o tanque (_threat_budget); _best_skill pula a skill que estoura
var threat_boss: SimEntity = null
var opener_id := -1            # chefe/elite da abertura (_opener): quando o vi e desde quando está firme no tanque
var opener_seen := 0.0
var opener_held := -1.0
var sig_pin := false            # assinatura de chefe: chegou no lugar da mecânica (ilha, pedra, marca): luta sem sair dali
var soak_pin := false           # Machado do Trono: já dentro do círculo de dividir: cura/luta dali, sem sair
var sig_guard := false          # Muralha do Ghar e eu sou o alvo dele: parado, de guarda, sem golpe (ele não vira e não junta fúria)
var spread_id := -1             # marca de espalhar em mim: para onde decidi correr (uma vez por marca)
var drag_to := Vector3.INF      # Têmpera na Lava: para onde levo o Kragmar (fica até ele sair da poça)
var spread_to := Vector3.INF
var spread_t := 0.0             # sim.time da última revisão do ponto de espalhar (outra marca planejou perto: escolhe de novo)
var ignore: Dictionary = {}           # id do monstro -> sim.time até quando não escolhe (inalcançável / linha bloqueada)
var think_dt := 0.05                   # dt do pensamento atual (o combate passa para o _steer: sem ele não havia desvio)
var route_map := ""                    # povoado murado: portão escolhido (histerese: vale até sair/entrar BOT_GATE_CLEAR m)
var route_gate := -1
var route_exit := false
var ring_side := 0.0                   # contornando o povoado pelo anel: sentido escolhido (+1/-1; 0 = não está contornando)
var ring_wp := Vector3.INF             # ponto do anel escolhido e até quando vale
var ring_until := 0.0
var ring_best := 0.0                   # contorno: menor ângulo restante (rad) já alcançado no sentido escolhido e quando
var ring_best_t := 0.0
var ring_bias := 0.0                   # quanto o sentido escolhido já era mais longo que o outro ao escolher (lado curto travado)
var line_block: Dictionary = {}       # id -> sim.time: monstro calmo com a linha bloqueada (fora da escolha até lá)
var door_id := ""                      # porta só do jogador onde o seguidor espera, e o ponto escolhido
var door_spot := Vector3.INF
var steer_routed := false              # o último _steer andou para um ponto de rota (portão, anel, ponte), não para o destino
var prog_key := -99                    # progresso até o alvo (_stalled): de quem, melhor distância, desde quando, último uso
var prog_best := INF
var prog_t := 0.0
var prog_at := -1.0
var prog_anchor := Vector3.ZERO
var lead: Dictionary = {}              # líder do grupo do jogador: recrutar e falar do plano (BotLeaderSystem; vazio = não lidera)

## MonsterDef.id → tem skill com grito de guerra (`rally`)? Cache (os catálogos não mudam durante o jogo).
static var _rally_cache: Dictionary = {}
## Sonda (band_probe --pack --no_focus): desliga o foco para comparar.
static var focus_enabled := true
## Sonda (boss_probe --no_opener): desliga a abertura (BotBrain._opener) para comparar.
static var opener_enabled := true
## Sonda (boss_probe/band_probe --no_unstuck): desliga largar alvo travado, teste de linha na escolha e dt no avanço (A/B).
static var unstuck_enabled := true

## Um convite ao jogador por vez no servidor inteiro (não vira spam).
static var next_player_invite: float = 60.0
const PLAYER_INVITE_COOLDOWN := 150.0

func setup(e: SimEntity, r: RandomNumberGenerator) -> void:
	rng = r
	personality = rng.randf()
	chat_timer = rng.randf_range(Balance.BOT_CHAT_MIN, Balance.BOT_CHAT_MAX)
	timer = rng.randf_range(2.0, 12.0)
	last_pos = e.position

func think(e: SimEntity, sim, m: Dictionary, dt: float) -> InputCommand:
	var cmd := InputCommand.new()
	if e.state == SimEntity.State.CASTING and e.current_skill and e.current_skill.effects.has("channel"):
		return cmd                 # canalizando: o bot segura até o fim (o jogador pode cortar com outra skill)
	cmd = _think(e, sim, m, dt)
	if cmd.dash and ult_committed(e):
		cmd.dash = false           # a própria Suprema em andamento: o dash cortaria a mira ou os saltos
	# andando fora de combate: às vezes monta (atacar desmonta sozinho, na sim)
	if not e.mounted and e.mount_left <= 0.0 and e.combat_timer <= 0.0 and cmd.move.length_squared() > 0.25 and not cmd.has_action() and sim.rng.randf() < Balance.BOT_MOUNT_CHANCE \
			and m["def"].parent_map == "":
		cmd.mount = true
	return cmd

func _think(e: SimEntity, sim, m: Dictionary, dt: float) -> InputCommand:
	var cmd := InputCommand.new()
	timer -= dt
	chat_timer -= dt
	block_timer -= dt
	flee_timer -= dt
	recall_retry -= dt
	tank_t -= dt
	place_cool -= dt
	focus_t -= dt
	think_dt = dt
	var def: MapDef = m["def"]
	cur_def = def
	cur_sim = sim
	var in_town := def.in_town(e.position)
	cmd.aim = e.position + e.forward() * 2.0

	# --- chat ---
	if chat_timer <= 0.0:
		chat_timer = rng.randf_range(Balance.BOT_CHAT_MIN, Balance.BOT_CHAT_MAX)
		BotChat.ambient(sim, e)                    # lugar, chefe/investida, classe e build (no grupo do jogador: BotChat.update)

	# --- sobrevivência: poção ---
	var potion_at: float = 0.35 if e.class_def == null or e.class_def.basic_attack_is_ranged else Balance.BOT_POTION_HP_MELEE
	if e.hp < e.stats.max_hp * potion_at and e.potion_cds[0] <= 0.0 and _has_potion(e, 0):
		cmd.potion_slot = 0
		return cmd
	if e.mp < e.stats.max_mp * 0.15 and e.potion_cds[1] <= 0.0 and _has_potion(e, 1):
		cmd.potion_slot = 1
		return cmd

	# --- grupo: quem não é líder segue o líder; o líder também cura, provoca e segura o chefe solto ---
	if e.party_id >= 0:
		var leader: SimEntity = sim.party_leader(e)
		if leader and leader != e:
			return _follow(e, sim, m, leader, cmd, dt)
		if not in_town:
			var members: Array = sim.party_members(e)
			if _soak_move(e, sim, m, cmd) or _sig_move(e, sim, m, cmd) or _evade_boss(e, sim, m, cmd) or _heal_party(e, sim, members, cmd, dt) or _taunt_party(e, sim, m, members, cmd):
				return cmd
			var loose := _loose_big(e, sim, m, members)
			if loose:
				return _fight(e, sim, m, loose, cmd)
			var web := _cocoon_target(e, sim, members)      # líder dps também quebra o casulo de um aliado
			if web:
				return _fight(e, sim, m, web, cmd)
	elif not in_town and sim.player != null and not sim.player.debuffs.is_empty():
		var web := _cocoon_target(e, sim, [sim.player])     # sozinho: casulo segurando o jogador por perto
		if web:
			return _fight(e, sim, m, web, cmd)

	# --- investida no mapa: defende o portão do povoado ---
	var dcmd := _defend(e, sim, m, cmd, dt)
	if dcmd != null:
		return dcmd

	# --- combate reativo: se um monstro me bate, luto mesmo fora do estado HUNT ---
	var threat := Combat.nearest_hostile(e, m["entities"], 9.0)
	if threat != null:
		var keep := _sticky(e, m, 12.0)         # já brigando com alguém por perto: continua nele
		if keep:
			threat = keep
		elif _ignored(threat):
			threat = null                      # largado por inalcançável (muro, rio): não volta a empurrar a parede
	if threat != null and not in_town and state != S.RETURN:
		return _fight(e, sim, m, threat, cmd)

	# --- líder do grupo do jogador: completa o grupo, espera o jogador e conta o plano ---
	if e.party_id >= 0 or not lead.is_empty():
		var lcmd := BotLeaderSystem.lead(self, e, sim, m, cmd, dt)
		if lcmd != null:
			return lcmd

	match state:
		S.TOWN_IDLE:
			if timer <= 0.0:
				# povoado de faixa bem mais baixa (veio de grupo/viagem): não fica à toa aqui, sai para caçar na faixa dele
				var away := BotBandSystem.below_band(e, def) and e.party_id < 0
				if away or (rng.randf() < 0.45 + personality * 0.3 and e.hp > e.stats.max_hp * 0.8):
					_plan_trip(e, sim)
				else:
					state = S.TOWN_WALK
					if def.bot_hangouts.size() > 0:
						target_pos = _pick_hangout(e, m, def) + Vector3(rng.randf_range(-1.5, 1.5), 0, rng.randf_range(-1.5, 1.5))
					else:
						target_pos = sim.random_walkable(def, def.town_center, 10.0)
					timer = 15.0
		S.TOWN_WALK:
			if e.position.distance_to(target_pos) < 0.8 or timer <= 0.0:
				state = S.TOWN_IDLE
				timer = rng.randf_range(4.0, 14.0)
			else:
				cmd.move = _steer(e, target_pos, dt) * 0.8
				cmd.aim = target_pos
		S.TRAVEL:
			# chegou no mapa de caça (pode ser o próprio vale da cidade): caça
			if e.map_id == dest_map:
				state = S.HUNT
				timer = rng.randf_range(150.0, 360.0)
				target_pos = Vector3.ZERO
				HuntPotionSystem.bot_drink(sim, e, rng)        # às vezes chega com Poção de Caça (fala no chat)
				return cmd
			if e.map_id != travel_map:              # passou por um portal no meio do caminho: prazo novo para a próxima etapa
				travel_map = e.map_id
				timer = maxf(timer, Balance.BOT_TRAVEL_LEG_S)
			# anda até o portal do mapa atual que leva a dest_map (ou à cidade)
			var portal := _find_portal(def, dest_map)
			if portal.is_empty():
				state = S.TOWN_IDLE if in_town else S.HUNT
				timer = 3.0
			else:
				cmd.move = _steer(e, portal["pos"], dt)
				cmd.aim = portal["pos"]
				if timer <= 0.0:
					state = S.TOWN_IDLE
		S.HUNT:
			if not def.has_hunting():
				state = S.TOWN_IDLE if in_town else S.RETURN
				timer = 2.0
			elif e.hp < e.stats.max_hp * 0.3 or e.inventory_weight() > 60 or timer <= 0.0:
				_go_home(e, sim)
			else:
				var mob := _sticky(e, m, Balance.BOT_STICKY_RANGE)
				if mob == null:
					mob = _pick_monster(e, m)
				if mob:
					return _fight(e, sim, m, mob, cmd)
				# procurar: anda até um spawner aleatório
				if target_pos == Vector3.ZERO or e.position.distance_to(target_pos) < 2.0:
					if def.spawners.size() > 0:
						var sp = def.spawners[rng.randi() % def.spawners.size()]
						target_pos = sim.random_walkable(def, sp["pos"], float(sp.get("radius", 6.0)))
					else:
						target_pos = sim.random_walkable(def, Vector3.ZERO, 20.0)
				cmd.move = _steer(e, target_pos, dt)
				cmd.aim = target_pos
				if _stalled(e, -2, target_pos):
					target_pos = Vector3.ZERO          # ponto atrás de muro/penhasco: sorteia outro
		S.RETURN:
			var home: String = PortalSystem.home_of(e, sim)["map"]     # povoado da faixa (ou a casa do jogador, no grupo dele)
			if e.map_id == home and def.in_hub(e.position):
				state = S.SHOP
				timer = rng.randf_range(4.0, 9.0)
				var npc := _find_npc(def, "merchant")
				target_pos = npc["pos"] + Vector3(0, 0, 1.6) if npc.has("pos") else def.town_center
			elif def.is_town and e.map_id == home:
				cmd.move = _steer(e, def.town_center, dt)      # mesma zona: volta pela estrada até a praça
				cmd.aim = def.town_center
			elif e.recall_left > 0.0:
				cmd.move = Vector2.ZERO                         # conjurando a volta (G): parado, sem agir
			elif recall_retry <= 0.0 and PortalSystem.recall_blocked(sim, e) == "":
				cmd.recall = true                               # volta como o jogador; dano interrompe
				cmd.move = Vector2.ZERO
				recall_retry = Balance.BOT_RECALL_RETRY
			else:
				var portal := _find_portal(def, home)
				if not portal.is_empty():
					cmd.move = _steer(e, portal["pos"], dt)
					cmd.aim = portal["pos"]
		S.SHOP:
			if e.position.distance_to(target_pos) > 1.0 and timer > 2.0:
				cmd.move = _steer(e, target_pos, dt) * 0.8
				cmd.aim = target_pos
			elif timer <= 0.0:
				_sell_materials(e)
				_restock(e)
				e.hp = e.stats.max_hp
				e.mp = e.stats.max_mp
				state = S.TOWN_IDLE
				timer = rng.randf_range(5.0, 20.0)
				# fim da viagem: grupo só de bots se desfaz às vezes (com o jogador, fica)
				if e.party_id >= 0 and not _party_has_player(e, sim) and rng.randf() < 0.5:
					sim.party_leave(e)
	return cmd

# ---------------------------------------------------------------------------
## Luta + regra da Barreira Sagrada: com uma cúpula do grupo no mapa, o bot entra e fica nela enquanto existir
## (segue a cúpula, não o Bispo). O tanque segurando o alvo fica onde está (andar traria o chefe para cima do grupo).
func _fight(e: SimEntity, sim, m: Dictionary, mob: SimEntity, cmd: InputCommand) -> InputCommand:
	sig_pin = false
	cmd = _fight_core(e, sim, m, mob, cmd)
	if e.ult_charge >= Balance.ULT_MAX and UltimateSystem.bot_release(sim, e, mob):
		cmd.ultimate = true                           # Suprema (regra SkillDef.ult_bot: UltimateSystem.bot_release)
		cmd.aim = mob.position
	if cmd.dash and ult_committed(e):
		cmd.dash = false                              # a própria Suprema em andamento: o dash a cortaria (fuga de área, aproximar)
	if sig_pin:
		cmd.move = Vector2.ZERO                       # no lugar da mecânica: bate/lança dali, sem sair
		cmd.dash = false
	if (m.get("barriers", []) as Array).is_empty():
		return cmd
	var dome: Dictionary = ChoirSystem.party_barrier(sim, e)
	if dome.is_empty() or mob.aggro_target == e.id or int(dome["owner"]) == e.id or not _spread_mark(e, sim, m).is_empty():
		return cmd                                        # o dono é a referência da cúpula: ela é que vem atrás dele
	var c: Vector3 = dome["pos"]
	var keep: float = float(dome["radius"]) * Balance.BOT_BARRIER_STAY - e.radius
	if Vector2(e.position.x - c.x, e.position.z - c.z).length() > keep:
		if e.can_act():
			cmd.move = _steer(e, c, 0.0)                  # fora: entra primeiro (o golpe em andamento termina antes)
			cmd.skill_slot = -1
			cmd.attack = false
			cmd.dash = false
			engaged = false
	elif cmd.move != Vector2.ZERO:
		var nxt := e.position + Vector3(cmd.move.x, 0.0, cmd.move.y) * 0.6
		if Vector2(nxt.x - c.x, nxt.z - c.z).length() > keep:
			cmd.move = Vector2.ZERO                       # dentro: não sai (nem para o lugar do papel, nem recuando)
			cmd.dash = false
	return cmd

## A Suprema de `e` está em andamento e um dash a cortaria: preparo/canal (Disparo do Fim, Lança Incansável) ou a
## sequência de saltos (Sete Ventos, Lua Rubra; HopSystem). Com a vida abaixo de Balance.BOT_ULT_KEEP_HP % ainda foge.
## Ex.: `if cmd.dash and BotBrain.ult_committed(e): cmd.dash = false`.
static func ult_committed(e: SimEntity) -> bool:
	if e.hp < e.stats.max_hp * Balance.BOT_ULT_KEEP_HP / 100.0:
		return false
	if not e.hop.is_empty():
		return true
	return e.state == SimEntity.State.CASTING and e.current_skill != null and e.current_skill.ultimate and e.skill_phase != "recovery"

## Coro Celeste (Bispo ascendido): true = já decidiu o comando. Retorno em quem caiu; Barreira quando o chefe avisa
## chuva/golpe de longe ou há feridos (ChoirSystem.wants_barrier), no meio do grupo; Anjo sempre que pronto em luta
## de chefe (fora dela, só com alguém ferido).
func _choir(e: SimEntity, sim, m: Dictionary, members: Array, cmd: InputCommand) -> bool:
	if e.class_def == null or e.class_def.id != "bishop" or e.skills.size() <= Balance.SKILL_SLOTS or not e.can_act() or not sim.has_ascension(e):
		return false
	var i := e.slot_of(ChoirSystem.RETURN_SKILL)
	if i >= 0 and _ready_to_cast(e, e.skills[i]):
		var f: SimEntity = ChoirSystem.fallen(sim, e, e.position)
		if f != null:
			cmd.skill_slot = i
			cmd.aim = f.position
			return true
	if e.combat_timer <= 0.0 and not members.any(func(o): return o.combat_timer > 0.0 and o.is_alive() and o.map_id == e.map_id):
		return false
	i = e.slot_of(ChoirSystem.BARRIER_SKILL)
	if i >= 0 and _ready_to_cast(e, e.skills[i]) and (m.get("barriers", []) as Array).is_empty() and ChoirSystem.wants_barrier(sim, e, m, members):
		cmd.skill_slot = i
		cmd.aim = ChoirSystem.barrier_spot(e, members)
		return true
	i = e.slot_of(ChoirSystem.ANGEL_SKILL)
	if i >= 0 and _ready_to_cast(e, e.skills[i]) and ChoirSystem.angels_of(sim, e).size() < ChoirSystem.angel_max(e) and ChoirSystem.wants_angel(sim, e, m, members):
		cmd.skill_slot = i
		cmd.aim = e.position + e.forward()
		return true
	return false

func _fight_core(e: SimEntity, sim, m: Dictionary, mob: SimEntity, cmd: InputCommand) -> InputCommand:
	if focus_t <= 0.0 and focus_enabled:
		focus_t = Balance.BOT_FOCUS_EVERY
		var f := _focus(e, sim, m, mob)
		if f:
			mob = f
	var wa := _ward_add(e, sim, m, mob)        # raide: chefe protegido por lacaio (ward) = vai no lacaio
	if wa:
		mob = wa
	# Sombras Gêmeas (R-F): bot sempre acha o Shazka verdadeiro (a sombra no chão); cópia só morre de área
	mob = _decoy_real(sim, mob)
	# assinatura de chefe (GDD act2-boss-signatures; bots sempre perfeitos): canal = todo mundo no chefe
	var sboss := _sig_boss(sim, mob)
	var burst := false
	if sboss != null and sboss.sig.has("channel") and sboss.position.distance_to(e.position) <= Balance.BOSS_CROWD_RANGE:
		mob = sboss
		burst = true
	if mob.id != hunt_target_id:
		engaged = false
	hunt_target_id = mob.id
	cmd.aim = mob.position
	ElementalSystem.bot_orders(e, sim, mob, cmd)       # ascensão do Elementalista: forma e modo do elemental (só o comando)
	var dist := e.position.distance_to(mob.position) - mob.radius - e.radius
	var cls := e.class_def
	var melee: bool = cls == null or not cls.basic_attack_is_ranged or (e.basic_skill != null and e.basic_skill.target == SkillDef.Target.CONE)     # lança do Ranger: básico em cone = corpo a corpo
	sig_guard = false
	var sig := _sig_spot(e, sim, m, sboss, melee)
	if sig_guard:
		cmd.block = true
		return cmd
	if sig != Vector3.INF:
		var off := Vector2(sig.x - e.position.x, sig.z - e.position.z)
		if off.length() > Balance.BOT_SIG_HOLD:
			cmd.move = _steer(e, sig, 0.0)
			if off.length() > Balance.BOT_SIG_DASH_DIST and e.dash_cd <= 0.0 and not _dash_hits(e, sim):
				cmd.dash = true
			engaged = false
			return cmd
		sig_pin = true
	if burst:
		var stun := _stun_skill(e, mob, dist)
		if stun >= 0 and e.can_act():
			cmd.skill_slot = stun            # canal do chefe: o atordoar quebra na hora
			return cmd
	# perigo: área telegrafada de monstro (chão, em volta dele, cone, linha) → sai dela (com dash se der)
	var away := _danger_escape(e, m, e.party_id >= 0 and _role(e, sim) == "tank", sim.time)
	if away != Vector2.ZERO:
		cmd.move = away
		cmd.aim = e.position + Vector3(away.x, 0, away.y) * 3.0
		var jump := _dodge_jump(e)            # Lanceiro ascendido: o Salto Dracônico é a esquiva do golpe grande
		if jump >= 0 and e.can_act() and e.position.distance_to(mob.position) <= e.skills[jump].range:
			cmd.skill_slot = jump                 # no ar o golpe passa; cai de volta colado no alvo depois dele
			cmd.aim = RangerAscension.jump_spot(e, mob)
			return cmd
		var eyes := FalconSystem.bot_eyes_slot(e, m)       # Falcoeiro: barragem no chão = Olhos do Céu (o grupo sai mais rápido)
		if eyes >= 0 and e.can_act():
			cmd.skill_slot = eyes
			return cmd
		if e.dash_cd <= 0.0 and rng.randf() < 0.6 and not (_dash_hits(e, sim) and _opener(e, sim, m, mob, _tank_of(e, sim)) != null):
			cmd.dash = true                   # dash que bate em área não sai na abertura: tirava o chefe do tanque a ~1 s (sai andando)
		engaged = false
		return cmd
	# pouca vida e sem poção: recua um pouco (para o líder, se houver grupo) e volta
	if flee_timer <= 0.0 and e.hp < e.stats.max_hp * Balance.BOT_FLEE_HP and (e.potion_cd > 0.0 or not e.has_item("potion_hp_s")) and not mob.monster_def.is_boss:
		flee_timer = Balance.BOT_FLEE_TIME
	if flee_timer > 0.0 and e.hp < e.stats.max_hp * 0.5:
		var from := Vector2(e.position.x - mob.position.x, e.position.z - mob.position.z).normalized()
		cmd.move = from
		cmd.aim = e.position + Vector3(from.x, 0, from.y) * 3.0
		engaged = false
		return cmd
	# cura própria (bispo/druida/paladino com skill de cura)
	if e.hp < e.stats.max_hp * 0.5:
		for i in range(e.skills.size()):
			var s := e.skills[i]
			if s and s.kind == SkillDef.Kind.HEAL and e.level >= s.unlock_level and e.stats.meets(s.requires) and _ready_to_cast(e, s) and DruidAscension.form_ok(e, s.requires_form):
				cmd.skill_slot = i
				cmd.aim = e.position
				return cmd
	# bloqueio reativo: monstro em startup de ataque e eu sou tank/melee. Em grupo, com o tanque segurando, só bloqueia
	# quem está na frente (nas costas o golpe não vem; ficar de guarda só tira o dano/a cura)
	var held_by := _tank_of(e, sim)
	var shielded_back: bool = held_by != null and held_by != e and mob.aggro_target == held_by.id and not _in_front(e, mob, held_by)
	if mob.state == SimEntity.State.CASTING and dist < 2.5 and e.stats.has_shield and block_timer <= 0.0 and not shielded_back and rng.randf() < 0.6:
		block_timer = 1.2
	if block_timer > 0.0:
		cmd.block = true
		return cmd              # decidiu bloquear: segura a guarda em vez de cortá-la com golpe
	# golpe/skill em andamento: fica parado de frente para o alvo (andar agora só empurra e faz tremer)
	if not e.can_act():
		cmd.move = Vector2.ZERO
		return cmd
	# furtivo: contorna até as costas do alvo e sai da sombra com a skill mais forte (bônus de emboscada + crítico)
	if e.stealth_left > 0.0:
		stealth_peak = maxf(stealth_peak, e.stealth_left)
		var circled: bool = stealth_peak - e.stealth_left > Balance.BOT_STEALTH_CIRCLE      # costas inalcançáveis: vai de frente
		if Combat.is_behind(e, mob) or circled:
			var opener := _best_skill(e, sim, m, mob, dist)
			if opener >= 0:
				cmd.skill_slot = opener
				return cmd
		var spot := mob.position if circled else mob.position - mob.forward() * (mob.radius + e.radius + Balance.BOT_STEALTH_BACK_GAP)
		cmd.move = _steer(e, spot, think_dt)
		return cmd
	stealth_peak = 0.0
	# ascensão do Bispo: Retorno, Barreira e Anjo têm hora certa
	if _choir(e, sim, m, sim.party_members(e), cmd):
		return cmd
	# ascensão do Paladino: Modo Arcano em chefe, monta para abrir com a Carga, desce quando ela recarrega
	if MountedCombat.fights_mounted(e) and _ascension(e, sim, m, mob, dist, cmd):
		return cmd
	# Corpo a corpo é um cone: o alcance do básico é o raio dele (não o "range", que no cone não vale).
	var basic_reach := 1.8
	if e.basic_skill:
		basic_reach = e.basic_skill.radius if e.basic_skill.target == SkillDef.Target.CONE else e.basic_skill.range
	# grupo contra chefe/elite preso no tanque: cada um no seu lugar (fora da frente dele) e de olho na ameaça
	var tank := _tank_of(e, sim)
	var held: bool = tank != null and tank != e and mob.aggro_target == tank.id and _is_big(mob)
	# tanque de raide: o grupo ficou na frente do chefe (parede, chegada) -> dá a volta e vira o chefe de costas para eles
	if tank == e and mob.aggro_target == e.id and _is_big(mob) and place_cool <= 0.0:
		var turn := _turn_spot(e, sim, mob, basic_reach)
		if turn != Vector3.INF and Vector2(turn.x - e.position.x, turn.z - e.position.z).length() > 1.2:
			place_t += 0.05
			if place_t > Balance.BOT_PLACE_GIVEUP:
				place_t = 0.0
				place_cool = Balance.BOT_PLACE_COOL
			cmd.move = _steer(e, turn, 0.0)
			engaged = false
			return cmd
	var hold_skills := false
	var hold_basic_t := false
	if held:
		var spot := _role_spot(e, sim, mob, melee, basic_reach, tank)
		var off_spot := Vector2(spot.x - e.position.x, spot.z - e.position.z).length()
		# só sai do lugar quando precisa: na frente do chefe; de longe, também colado nele, fora do alcance ou (cura) longe do tanque
		var must := _in_front(e, mob, tank)
		if not melee and not must:
			must = dist < Balance.BOT_RANGED_MIN or dist > basic_reach * 0.95 or (_role(e, sim) == "healer" and e.position.distance_to(tank.position) > Balance.BOT_HEALER_LEASH)
		if off_spot > 1.2 and must and place_cool <= 0.0:
			place_t += 0.05
			if place_t > Balance.BOT_PLACE_GIVEUP:      # parede, pilar, outro no caminho: luta de onde está por um tempo
				place_t = 0.0
				place_cool = Balance.BOT_PLACE_COOL
			cmd.move = _steer(e, spot, 0.0)
			engaged = false
			return cmd
		place_t = 0.0
		var mine := float(mob.threat.get(e.id, 0.0)) + _pending_threat(e, mob)     # + o dano no tempo que ainda vai cair
		var theirs := float(mob.threat.get(tank.id, 0.0))
		if mob.monster_def.is_boss and mine >= theirs * Balance.BOT_THREAT_STOP and not burst:
			cmd.move = Vector2.ZERO           # passou o tanque: espera ele abrir distância (senão o chefe vira)
			return cmd
		hold_skills = mob.monster_def.is_boss and mine >= theirs * Balance.BOT_THREAT_HOLD
		# básico pesado (Executor, Fogo) também passava de uma vez: segura o que levaria além de BOT_THREAT_STOP
		hold_basic_t = mob.monster_def.is_boss and e.basic_skill != null and mine + (_skill_threat(e, e.basic_skill, mob, true) + _signature_threat(e, sim, mob)) * Balance.BOT_THREAT_PREDICT >= theirs * Balance.BOT_THREAT_STOP
	# abertura: chefe/elite ainda não firme no tanque do grupo → sem skills; básico só se ficar abaixo de RATIO × a ameaça do tanque
	var hold_basic := hold_basic_t and not burst
	var big: SimEntity = null if burst else _opener(e, sim, m, mob, tank)
	if burst:
		hold_skills = false                  # canal: o maior dano pronto no chefe agora (quebrar vale mais que a ameaça)
	if big != null:
		var mine_o := float(big.threat.get(e.id, 0.0)) + _pending_threat(e, big)
		if e.basic_skill != null:
			mine_o += _skill_threat(e, e.basic_skill, big, true) + _signature_threat(e, sim, big)     # básico: crítico + assinatura
		hold_basic = hold_basic or big.aggro_target != tank.id or mine_o >= float(big.threat.get(tank.id, 0.0)) * Balance.BOT_OPENER_RATIO
	# skill: a melhor disponível (buff que não está ativo, área quando há vários, a mais forte no resto)
	var pick := -1
	if not hold_skills:
		_threat_budget(e, m, mob, tank)
		pick = _best_skill(e, sim, m, mob, dist)
		threat_room = INF
		threat_boss = null
	if pick >= 0 and big != null and not _self_buff(e.skills[pick]):
		pick = -1                          # na abertura só buff em si (não gera ameaça no chefe)
	if pick >= 0:
		cmd.skill_slot = pick
		if e.skills[pick].effects.has("turret"):
			cmd.aim = RangerAscension.turret_spot(e, mob, tank)
		elif e.skills[pick].effects.has("dragon_jump"):
			cmd.aim = RangerAscension.jump_spot(e, mob)      # cai colado no alvo, do lado de onde saiu (não em cima dele)
		elif e.skills[pick].effects.has("falcon_dive"):
			cmd.aim = FalconSystem.bot_dive_aim(e, mob, tank, m)     # Mergulho no alvo do tanque
		return cmd
	# ataque básico, com histerese: entra a 75% do alcance e só sai depois de 95% (não fica entrando e saindo).
	var in_range := dist <= basic_reach * (0.95 if engaged else 0.75)
	# vigia: "no alcance", batendo, e o alvo não perde vida → algo no meio (árvore, pedra). Corpo a corpo chega mais
	# perto; distância anda de lado em volta do alvo até ter linha de tiro.
	if in_range:
		if stall_hp < 0.0 or mob.hp < stall_hp - 0.5:
			stall_hp = mob.hp
			stall_t = 0.0
		else:
			stall_t += 0.05
		if stall_t > (2.5 if melee else 3.5):
			if melee:
				in_range = false
			else:
				var to := Vector2(mob.position.x - e.position.x, mob.position.z - e.position.z).normalized()
				cmd.move = Vector2(-to.y, to.x) * (1.0 if e.id % 2 == 0 else -1.0)     # anda de lado até ter linha de tiro
				if stall_t > 6.0:
					stall_t = 0.0
				return cmd
			if stall_t > 4.0:
				stall_t = 0.0
	else:
		stall_hp = -1.0
	engaged = in_range
	if in_range:
		if e.basic_cd <= 0.0 and not hold_basic:
			cmd.attack = true
		if not melee and dist < basic_reach * 0.4:      # distância: recua um pouco
			cmd.move = -_steer(e, mob.position, 0.0)
		return cmd
	# aproximar: corpo a corpo encosta num lado do alvo (cada bot num ângulo) e usa o dash para fechar distância
	var spot := mob.position
	if held:
		spot = _role_spot(e, sim, mob, melee, basic_reach, tank)
	elif melee:
		var side := Vector3(e.position.x - mob.position.x, 0, e.position.z - mob.position.z).normalized().rotated(Vector3.UP, (float(e.id % 5) - 2.0) * 0.35)
		spot = mob.position + side * (mob.radius + e.radius + basic_reach * 0.5)
	if melee:
		# segurando o básico (abertura/ameaça): dash que bate em área também fica (somaria ameaça no chefe)
		if dist > 5.0 and dist < 9.0 and e.dash_cd <= 0.0 and rng.randf() < 0.12 and not (hold_basic and _dash_hits(e, sim)):
			cmd.dash = true
	cmd.move = _steer(e, spot, think_dt if unstuck_enabled else 0.0)
	# sem chegar mais perto em BOT_CHASE_STALL s (muro, penhasco, rio no meio): larga e ignora por um tempo (chefe não)
	if not held and not mob.monster_def.is_boss and _stalled(e, mob.id, spot):
		_drop(mob)
	return cmd

## Ascensão (Combate Montado + Modo Arcano): true = já decidiu o comando. Liga as asas em luta de chefe (Guardião
## quando segura o aggro; os outros ao abrir dano) e desliga com MP < Balance.BOT_ARCANE_OFF_MP; em campo aberto monta
## para abrir com a Carga (alvo a BOT_CHARGE_MIN..BOT_MOUNT_FIGHT_RANGE) e desce quando ela está recarregando.
func _ascension(e: SimEntity, sim, m: Dictionary, mob: SimEntity, dist: float, cmd: InputCommand) -> bool:
	var arc := e.slot_of(Balance.ARCANE_SKILL)
	var arc_on: bool = sim.arcane_on(e)
	if arc >= 0 and float(e.cooldowns.get(Balance.ARCANE_SKILL, 0.0)) <= 0.0:
		if arc_on and e.mp < e.stats.max_mp * Balance.BOT_ARCANE_OFF_MP:
			cmd.skill_slot = arc
			return true
		var boss: bool = mob.monster_def != null and mob.monster_def.is_boss
		var ready: bool = mob.aggro_target == e.id if e.build_id == "guardiao" else dist < 4.0
		if not arc_on and boss and ready and e.mp >= e.stats.max_mp * Balance.BOT_ARCANE_ON_MP and e.mount_left <= 0.0:
			cmd.skill_slot = arc
			return true
	if arc_on:
		return false
	var ch := e.slot_of(Balance.MOUNT_CHARGE_SKILL)
	if ch < 0:
		return false
	var ch_ready: bool = float(e.cooldowns.get(Balance.MOUNT_CHARGE_SKILL, 0.0)) <= 0.0
	if e.mount_left > 0.0:
		cmd.move = Vector2.ZERO          # montando: parado (agir interromperia)
		return true
	if not e.mounted and ch_ready and not m["def"].no_mount() and dist >= Balance.BOT_CHARGE_MIN and dist <= Balance.BOT_MOUNT_FIGHT_RANGE \
			and mob.aggro_target != e.id and e.combat_timer <= 0.0:          # só para abrir a luta (no meio dela a montaria custa 1,5 s)
		cmd.mount = true
		return true
	if e.mounted and (not ch_ready or dist < Balance.BOT_CHARGE_MIN):
		var tr := e.slot_of(Balance.MOUNT_TRAMPLE_SKILL)
		if tr >= 0 and _ready_to_cast(e, e.skills[tr]) and dist <= float(Balance.MOUNT_TRAMPLE["radius"]):
			cmd.skill_slot = tr
			return true
		cmd.mount = true                 # Carga gasta: desce para usar as skills da build
		return true
	return false

## Slot do Salto Dracônico pronto para esquivar (-1 = nenhum).
func _dodge_jump(e: SimEntity) -> int:
	for i in range(e.skills.size()):
		var s := e.skills[i]
		if s != null and s.effects.has("dragon_jump") and e.knows(s.id) and e.stats.meets(s.requires) and _ready_to_cast(e, s):
			return i
	return -1

## Melhor skill pronta para usar agora (-1 = nenhuma): pontua cada uma em vez de sortear.
func _best_skill(e: SimEntity, sim, m: Dictionary, mob: SimEntity, dist: float) -> int:
	var near := -1                     # inimigos a 4 m: só conta se alguma skill de área estiver na disputa
	var best := -1
	var best_score := 0.0
	for i in range(e.skills.size()):
		var s := e.skills[i]
		if s == null or e.level < s.unlock_level or s.kind == SkillDef.Kind.HEAL or not e.stats.meets(s.requires):
			continue
		if not _ready_to_cast(e, s):
			continue
		if not _charge_spend_ok(e, s, mob):
			continue                        # skill em cargas: no lixo guarda a última; chefe/elite leva tudo
		if threat_boss != null and _skill_threat(e, s, threat_boss) * Balance.BOT_THREAT_PREDICT > threat_room:
			continue                        # um golpe só passaria o tanque (Meteoro, Executar): espera a ameaça dele crescer
		# a sim recusaria (try_cast): sem companheiro para mandar, ou invocações no limite. Escolher assim travava o
		# bot inteiro (pedia a mesma skill todo tick e nunca atacava nem andava: Caçador com o lince morto).
		if (s.effects.has("pet_command") or s.effects.get("pet_buff", false) is bool and s.effects.get("pet_buff", false)) and sim.pet_of(e) == null:
			continue
		if not _fill_ok(e, sim, s, mob):
			continue                        # skills do preenchimento (GDD skills-fill-2026-11-19): hora certa
		if s.effects.has("summon") and sim._summons_full(e, s):
			continue
		if (s.effects.has("aura") and AuraSystem.aura_on(e, s)) or (str(s.effects.get("form", "")) != "" and e.form == str(s.effects["form"])):
			continue                        # aura ligada / já na forma: bot não desliga
		if DruidAscension.bot_skips(e, s):
			continue                        # Druida ascendido: fica na forma ancestral (não volta à de base); skill de outra forma não sai
		if e.is_character() and not e.knows(s.id):
			continue
		if s.effects.has("choir_angel") or s.effects.has("choir_barrier") or s.effects.has("choir_return"):
			continue                        # Coro Celeste: hora certa em _choir
		if s.effects.has("arcane") or sim.mount_block(e, s) != "":
			continue                        # Modo Arcano tem hora certa (_ascension); a cavalo só as montáveis
		if s.mount_only and s.is_charge() and dist < Balance.BOT_CHARGE_MIN:
			continue                        # Carga Montada só de longe (abre a luta)
		if s.effects.has("channel") and mob.monster_def and mob.monster_def.is_boss and mob.aggro_target == e.id:
			continue                        # canalizar parado com o chefe em cima = morrer (Pestilento solo: 2/40)
		if s.effects.has("stun") and _save_stun(sim, mob):
			continue                        # guarda o atordoar para o canal do chefe que está para vir
		if e.stealth_left > 0.0 and not (s.kind in [SkillDef.Kind.PHYSICAL, SkillDef.Kind.MAGICAL]):
			continue                        # na sombra: só golpe (o resto quebraria a furtividade sem o bônus)
		var score := 0.0
		if Balance.BOT_LOW_HP_SKILLS.has(s.id):     # Curativo de Campo: só com a vida baixa
			score = Balance.BOT_LOW_HP_SCORE
		elif FalconSystem.is_skill(s):         # Falcoeiro: chama o falcão, Mergulho na recarga, Olhos do Céu em chefe/barragem
			score = FalconSystem.bot_score(e, s, mob, dist, m)
			if score <= 0.0:
				continue
		elif NecroAscension.is_mine(s):      # Senhor dos Mortos: Pacto, Miasma, Marca da Cova e Forma de Lich têm hora certa
			score = NecroAscension.bot_score(sim, e, s, mob, dist, m)
			if score <= 0.0:
				continue
		elif s.effects.has("turret"):          # Atirador ascendido: torreta no começo da luta (uma viva por vez)
			if dist > Balance.BOT_TURRET_REACH or RangerAscension.turrets_of(sim, e).size() >= RangerAscension.turret_max(e):
				continue
			score = Balance.BOT_TURRET_SCORE
		elif s.effects.has("shout") and RangerAscension.shouting(e) and not RangerAscension.can_combo(e, s):
			continue                         # um Brado por vez (Brado Combinado pronto: o 2º elemento)
		elif s.effects.has("dragon_jump") and dist < Balance.BOT_JUMP_MIN:
			continue                         # Salto Dracônico: fecha distância (6-9 m) ou esquiva (_danger_escape); colado, o básico rende mais
		elif s.effects.has("shadow_clone"):  # Assassino ascendido: Sombra Gêmea ao colar no alvo e sempre que recarrega
			if not ShadowSystem.bot_wants_clone(sim, e, dist):
				continue
			score = Balance.BOT_SHADOW_SCORE
		elif s.effects.has("riposte"):       # Guarda do Duelista: hora certa em _fill_ok (golpe vindo / cercado)
			score = Balance.BOT_RIPOSTE_SCORE
		elif s.effects.has("execute"):       # Execução: só com o alvo abaixo do limiar (acima é um corte fraco)
			if not ShadowSystem.executable(mob) or dist > s.range + 0.3:
				continue
			score = Balance.BOT_EXECUTION_SCORE
		elif s.effects.has("stealth"):
			if e.stealth_left > 0.0 or dist > Balance.BOT_STEALTH_RANGE or not DruidAscension.form_ok(e, s.requires_form):
				continue
			if e.combat_timer > 0.0 or mob.aggro_target == e.id:
				continue                    # só abertura: no meio da luta o chefe perde o alvo e pode resetar
			score = Balance.BOT_STEALTH_SCORE
		elif s.kind == SkillDef.Kind.BUFF:
			var b = s.effects.get("buff")
			var bid: String = b.get("id", "") if b is Dictionary else ""
			if bid != "" and e.buffs.any(func(x): return x.get("id") == bid):
				continue                    # já está ativo
			if s.effects.has("form") and str(s.effects["form"]) in Balance.BOT_AUTO_FORMS:
				score = Balance.BOT_FORM_SCORE if dist < Balance.BOT_FORM_RANGE else 0.0     # Lobo/Urso: entra na forma antes de bater
			elif s.effects.has("form") or s.effects.has("taunt"):
				continue                    # outras formas e provocar têm hora certa (fora daqui)
			elif s.ascension and s.radius >= Balance.BLESS_RADIUS:
				score = 2.5                 # bênção de grupo da ascensão (Asas da Aurora, Égide Coral): vale de longe também
			elif s.ascension and b is Dictionary and b.get("toggle", false):
				score = Balance.BOT_FORM_SCORE if dist < Balance.BOT_FORM_RANGE else 0.0     # postura (Modo Gladiador): liga antes de bater
			else:
				score = 2.5 if dist < 6.0 else 0.0
		elif s.kind == SkillDef.Kind.MOVEMENT or (s.effects.has("dash") and s.power <= 0.0):
			continue
		elif s.kind == SkillDef.Kind.SUMMON or s.effects.has("summon"):
			score = 2.2 if dist < 9.0 else 0.0     # invocação: o limite por tipo é da sim
		else:
			var reach := s.range if s.target != SkillDef.Target.SELF else (s.radius if s.radius > 0.0 else 3.0)
			if s.target == SkillDef.Target.CONE:
				reach = s.radius
			if s.target in [SkillDef.Target.DIRECTION, SkillDef.Target.TARGET] and s.projectile_speed <= 0.0 and s.range <= 0.0:
				reach = maxf(s.radius, 1.5)
			if dist > reach + 0.3 or (s.is_charge() and not sim.charge_lands(e, s, mob, m)):
				continue
			score = s.power_at(e.mastery_of(s.id))
			var area: bool = (s.target == SkillDef.Target.SELF and s.radius > 0.0) or s.target == SkillDef.Target.CONE or (s.target == SkillDef.Target.GROUND and s.radius >= 2.0) or (s.max_targets > 1 and s.max_targets < 99)
			if area:
				if near < 0:
					near = 0
					for o: SimEntity in m["entities"]:
						if o.kind == SimEntity.Kind.MONSTER and o.is_alive() and o.position.distance_to(e.position) <= 4.0:
							near += 1
				score *= 0.8 + 0.45 * maxi(0, near - 1)
			if mob.hp < mob.stats.max_hp * 0.35:
				score *= 1.15
			if mob.monster_def and mob.monster_def.regen > 0.0 and cuts_regen(s) and not MobSystem.regen_blocked(mob):
				score *= Balance.BOT_REGEN_CUT_SCORE     # troll regenerando: fogo/veneno primeiro (GDD ato2-horda F3, pergunta 7)
			score *= FusionEffects.bot_skill_mult(e, mob, s)     # Fusão que pede uma skill na hora certa (E1 Vapor: gelo no alvo que queima)
		score *= rng.randf_range(0.85, 1.15)
		if score > best_score:
			best_score = score
			best = i
	return best

## Condições das skills do preenchimento (GDD skills-fill-2026-11-19): Oferenda só com mortos-vivos perto do alvo, Garra da
## Cova nunca em chefe, finalizador do Executor espera a rachadura (se o Fender está pronto), Curativo só com a vida baixa.
func _fill_ok(e: SimEntity, sim, s: SkillDef, mob: SimEntity) -> bool:
	if s.effects.has("riposte"):
		return RiposteSystem.bot_wants(sim, e)       # aparar: inimigo colado preparando golpe nele, ou cercado
	if s.effects.get("sacrifice") is Dictionary:
		return SummonRites.pick(sim, e, mob.position, s.effects["sacrifice"]).size() >= Balance.BOT_SACRIFICE_MIN
	if s.effects.has("pull") and mob.monster_def != null and mob.monster_def.is_boss:
		return false
	if Balance.BOT_LOW_HP_SKILLS.has(s.id):
		return e.hp <= e.stats.max_hp * float(Balance.BOT_LOW_HP_SKILLS[s.id])
	if s.effects.get("sunder_consume") is Dictionary and SunderSystem.stacks(mob) < Balance.BOT_SUNDER_MIN 			and mob.hp > mob.stats.max_hp * Balance.BOT_SUNDER_LOW_HP:
		for o: SkillDef in e.skills:
			if o != null and o.effects.get("sunder") is Dictionary and e.level >= o.unlock_level and e.knows(o.id) and _ready_to_cast(e, o):
				return false            # rachar primeiro: o Fender está pronto
	return true

## A skill põe fogo ou veneno (dano no tempo que não é sangramento): corta a regeneração do troll (MobSystem.regen_blocked).
static func cuts_regen(s: SkillDef) -> bool:
	var d = s.effects.get("dot")
	return d is Dictionary and not (d as Dictionary).has("atk_pct")

## Foco no bando (GDD ato2-horda AC-20): troca o alvo por quem pesa mais na luta: troll que regenera (só para quem tem
## fogo/veneno), emissor de aura (Agitador), quem dá grito de guerra. null = continua no alvo. Fora de luta de chefe, e o
## tanque do grupo não troca (segura o bando). Pesos em Balance.BOT_FOCUS_*.
func _focus(e: SimEntity, sim, m: Dictionary, mob: SimEntity) -> SimEntity:
	if mob.monster_def == null or mob.monster_def.is_boss:
		return null
	if e.party_id >= 0 and _role(e, sim) == "tank":
		return null
	var cut := _has_regen_cut(e)
	var best: SimEntity = null
	var best_v := focus_value(mob.monster_def, cut)
	var best_d := INF
	var r2 := Balance.BOT_FOCUS_RANGE * Balance.BOT_FOCUS_RANGE
	var p2 := Balance.BOT_FOCUS_PACK * Balance.BOT_FOCUS_PACK
	for o in m["entities"]:
		if o.kind != SimEntity.Kind.MONSTER or o == mob:
			continue
		var d2: float = o.position.distance_squared_to(e.position)
		if d2 > r2 or not o.is_alive() or o.monster_def == null or o.monster_def.is_boss:
			continue
		if o.aggro_target < 0 and o.position.distance_squared_to(mob.position) > p2:
			continue                       # bando de outro lugar, ainda quieto: não puxa
		if not e.is_hostile_to(o) or o.stealth_left > 0.0:
			continue
		var v := focus_value(o.monster_def, cut)
		if v > best_v or (best != null and v == best_v and d2 < best_d):
			best_v = v
			best_d = d2
			best = o
	return best

## Peso de foco de um monstro (0 = comum). `regen_cut` = o bot tem skill de fogo/veneno pronta para usar.
static func focus_value(d: MonsterDef, regen_cut: bool) -> float:
	if regen_cut and d.regen > 0.0:
		return Balance.BOT_FOCUS_REGEN
	if d.aura != "":
		return Balance.BOT_FOCUS_AURA
	if rallies(d):
		return Balance.BOT_FOCUS_RALLY
	return 0.0

## O monstro tem grito de guerra (skill com `rally`)?
static func rallies(d: MonsterDef) -> bool:
	if not _rally_cache.has(d.id):
		var yes := false
		for sid in d.skill_ids:
			var s: SkillDef = GameData.skills.get(sid)
			if s and s.effects.has("rally"):
				yes = true
		_rally_cache[d.id] = yes
	return bool(_rally_cache[d.id])

## O bot sabe e pode usar alguma skill de fogo/veneno (cuts_regen)?
func _has_regen_cut(e: SimEntity) -> bool:
	for s in e.skills:
		if s and cuts_regen(s) and e.level >= s.unlock_level and e.stats.meets(s.requires) and (not e.is_character() or e.knows(s.id)):
			return true
	return false

## Para onde sair de uma área de golpe de monstro que está começando (Vector2.ZERO = seguro).
## Tanque (`tank`): não foge do golpe de frente/em volta do monstro que está segurando (ele viria atrás e o grupo
## inteiro teria de se mexer): bloqueia e aguenta. Círculos no chão e golpes de outros monstros ele evita como todos.
## `now` (>= 0): faixa/anel que ainda demora mais de BOT_SIG_REACT s para cair não tira o bot da luta.
func _danger_escape(e: SimEntity, m: Dictionary, tank: bool = false, now: float = -1.0) -> Vector2:
	var first: Dictionary = {}
	var linger: Dictionary = {}
	for h in m.get("hazards", []):           # círculos de chefe (barrage) já marcados no chão; faixas e anéis (BossSignatures)
		if h.get("invert", false) or (h.get("mark", false) and not h.get("landed", false) and (int(h.get("victim", -1)) == e.id or str(h.get("mode", "")) == "soak")):
			continue                             # ilha é o lugar seguro; marca minha/de dividir: _sig_spot decide (a que já caiu e ficou é poça: sai)
		if str(h.get("shape", "circle")) != "circle":
			if h.get("landed", false):           # faixa que caiu e ficou (Cortejo, Fumo em Fileiras): perigo vivo enquanto dura
				if linger.is_empty() and BossSignatures.inside(h, e.position, e.radius + Balance.BOT_SIG_PAD):
					linger = h
				continue
			if now >= 0.0 and float(h["at"]) - now > Balance.BOT_SIG_REACT:
				continue
			if (first.is_empty() or float(h["at"]) < float(first["at"])) and not h.get("landed", false) and BossSignatures.inside(h, e.position, e.radius + Balance.BOT_SIG_PAD):
				first = h                             # faixa/anel: foge do que cai primeiro (vãos de 3 m, folga curta)
			continue
		var esc := BossSignatures.escape(h, e.position, e.radius + Balance.BOT_DODGE_PAD)
		if esc != Vector2.ZERO:
			if h.get("landed", false):                # poça que fica (Têmpera na Lava): sai para o ponto livre mais perto, não para outra poça
				var out := _free_near(m, e.position, e.radius + Balance.BOT_DODGE_PAD, 8.0)
				if out != Vector3.INF:
					var v := Vector2(out.x - e.position.x, out.z - e.position.z)
					if v.length() > 0.05:
						return v.normalized()
			return esc
	if not linger.is_empty():                    # já dentro da faixa que tiquea: sai pelo lado que não cai noutra logo
		var lp: float = e.radius + Balance.BOT_SIG_PAD
		return _side_escape(e, m, linger, BossSignatures.escape(linger, e.position, lp), lp, now)
	if not first.is_empty():
		var sp: float = e.radius + Balance.BOT_SIG_PAD
		return _side_escape(e, m, first, BossSignatures.escape(first, e.position, sp), sp)
	for o: SimEntity in m["entities"]:
		if o.state != SimEntity.State.CASTING or o.kind != SimEntity.Kind.MONSTER or o.current_skill == null:       # o barato primeiro
			continue
		if o.skill_phase != "startup" or o.position.distance_to(e.position) > 14.0:
			continue
		var s: SkillDef = o.current_skill
		if s == o.basic_skill or s.kind == SkillDef.Kind.BUFF:
			continue                             # golpe básico (curto: bloqueia ou aguenta) e grito/buff do próprio monstro não são área de perigo
		if tank and o.aggro_target == e.id and s.target != SkillDef.Target.GROUND:
			continue
		if (s.radius < Balance.BOT_DODGE_MIN_RADIUS and not s.is_charge()) or s.target == SkillDef.Target.TARGET or s.effects.has("barrage"):
			continue                             # chuva: quem marca o perigo são os círculos (acima), não o lançamento
		var me := Vector2(e.position.x, e.position.z)
		var pad: float = e.radius + Balance.BOT_DODGE_PAD
		match s.target:
			SkillDef.Target.GROUND, SkillDef.Target.SELF:
				var c3: Vector3 = o.skill_aim if s.target == SkillDef.Target.GROUND else o.position
				var c := Vector2(c3.x, c3.z)
				if me.distance_to(c) < s.radius + pad:
					return (me - c).normalized() if me.distance_to(c) > 0.05 else Vector2.RIGHT
			SkillDef.Target.CONE:
				var c := Vector2(o.position.x, o.position.z)
				var f := Vector2(o.forward().x, o.forward().z)
				var to := me - c
				if to.length() < s.radius + pad and f.angle_to(to.normalized()) * f.angle_to(to.normalized()) < pow(deg_to_rad(s.cone_angle_deg * 0.5 + 15.0), 2):
					return Vector2(-f.y, f.x) if f.cross(to) >= 0.0 else Vector2(f.y, -f.x)     # sai de lado
			SkillDef.Target.DIRECTION:
				var c := Vector2(o.position.x, o.position.z)
				var f := Vector2(o.forward().x, o.forward().z)
				var to := me - c
				var along := to.dot(f)
				if along > 0.0 and along < maxf(s.range, 2.0) + pad and absf(f.cross(to)) < s.radius + pad:
					return Vector2(-f.y, f.x) if f.cross(to) >= 0.0 else Vector2(f.y, -f.x)
	return Vector2.ZERO

## Cópia do Shazka (R-F) → o verdadeiro (visível); qualquer outro alvo fica como está.
static func _decoy_real(sim, mob: SimEntity) -> SimEntity:
	if mob.monster_def != null and mob.monster_def.decoy:
		var real: SimEntity = sim.entities.get(int(mob.sig.get("decoy_of", -1)))
		if real != null and real.is_alive() and real.stealth_left <= 0.0:
			return real
	return mob

## Faixa/anel: dos dois lados de saída, o que fica livre por mais tempo depois que este cai (até BOT_SIG_LOOKAHEAD s;
## Ondas da Montanha: entra-sai no ritmo das pisadas) e, empatado, o mais perto. Anel: para dentro só se cabe fora do chefe.
## `now` (>= 0) conta como a hora da queda quando `h` já caiu (faixa que ficou): o que cai logo depois pesa contra o lado.
func _side_escape(e: SimEntity, m: Dictionary, h: Dictionary, esc: Vector2, pad: float, now: float = -1.0) -> Vector2:
	var best := esc
	var best_s := -INF
	var c: Vector3 = h["pos"]
	var t_ref := maxf(float(h["at"]), now)
	for dir: Vector2 in [esc, -esc]:
		var p := e.position
		var d := 0.0
		while d < 20.0 and BossSignatures.inside(h, p, pad):
			d += 0.5
			p = e.position + Vector3(dir.x, 0, dir.y) * d
		if d >= 20.0:
			continue
		if str(h["shape"]) == "ring" and Vector2(p.x - c.x, p.z - c.z).length() < float(h.get("core", 0.0)) + e.radius:
			continue                                 # para dentro esbarra no chefe
		var free := INF
		for o in m.get("hazards", []):
			if o == h or o.get("invert", false) or o.get("mark", false):
				continue
			if BossSignatures.inside(o, p, pad):           # o que cai antes deste dá nota negativa (não fuja para ele)
				free = minf(free, t_ref if o.get("landed", false) else float(o["at"]))     # outra faixa que ficou = já
		var sc := minf(free - t_ref, Balance.BOT_SIG_LOOKAHEAD) * 10.0 - d
		if sc > best_s:
			best_s = sc
			best = dir
	return best

# ---------------------------------------------------------------------------
# Assinaturas de chefe (GDD design/gdd/act2-boss-signatures.md): resposta perfeita de cada regra
# ---------------------------------------------------------------------------

## Chefe da luta: o próprio alvo, o chefe do lacaio ou o líder da escolta.
static func _sig_boss(sim, mob: SimEntity) -> SimEntity:
	if mob == null or mob.monster_def == null:
		return null
	if mob.monster_def.is_boss:
		return mob
	var b: SimEntity = sim.entities.get(mob.boss_id if mob.boss_id >= 0 else mob.leader_id)
	return b if b != null and b.is_alive() and b.monster_def != null and b.monster_def.is_boss else null

## Ilha (hazard `invert`) onde ficar (INF = nenhuma; e.position = já dentro). Ver _sig_spot.
func _island_spot(e: SimEntity, sim, hz: Array) -> Vector3:
	# Maré Cheia: dentro de uma ilha (o golpe é para quem está fora). Quem não é o tanque prefere ilha longe do chefe
	# (a do tanque fica embaixo dele: golpe em volta e cone); só sobra ela, vai nela.
	var best := Vector3.INF
	var bd := INF
	var tanky := _role(e, sim) == "tank"
	for pass_i in 2:
		for h in hz:
			if not h.get("invert", false):
				continue
			var ow: SimEntity = sim.entities.get(h["owner"])
			if ow == null or not ow.is_hostile_to(e):
				continue
			var c: Vector3 = h["pos"]
			if pass_i == 0 and not tanky and Vector2(c.x - ow.position.x, c.z - ow.position.z).length() < Balance.BOT_SIG_ISLAND_AVOID:
				continue
			var d := Vector2(c.x - e.position.x, c.z - e.position.z).length()
			if d <= float(h["radius"]) - e.radius - 0.4:
				return e.position                   # já dentro: fica
			if d < bd:
				bd = d
				best = c
		if best != Vector3.INF:
			return best
	return Vector3.INF

## Onde ficar por causa de uma assinatura (Vector3.INF = nada). Ordem: ilhas, marca, cobertura, Muralha.
func _sig_spot(e: SimEntity, sim, m: Dictionary, boss: SimEntity, melee: bool) -> Vector3:
	var hz: Array = m.get("hazards", [])
	if not hz.is_empty():
		var isl := _island_spot(e, sim, hz)      # Maré Cheia / Palco Seguro: dentro de uma ilha
		if isl != Vector3.INF:
			return isl
		# marcas
		for h in hz:
			if not h.get("mark", false) or h.get("landed", false):
				continue
			var ow: SimEntity = sim.entities.get(h["owner"])
			if ow == null or not ow.is_hostile_to(e):
				continue
			var c: Vector3 = h["pos"]
			if str(h.get("mode", "")) == "soak":
				var sp := soak_spot(e, sim, h)
				if sp != Vector3.INF:
					return sp
			elif int(h.get("victim", -1)) == e.id and not ChoirSystem.shelters(sim, ow, e):      # na cúpula com o chefe fora: fica
				if spread_id != int(h["id"]) or (sim.time - spread_t >= Balance.BOT_SIG_SPREAD_REPLAN and _spread_clash(e, sim, h, spread_to)):
					spread_id = int(h["id"])
					spread_t = sim.time
					spread_to = _spread_spot(e, sim, m, hz, h)
				return spread_to
	# Têmpera na Lava: quem o chefe mira leva ele para o ponto livre de poça mais perto (ele vem atrás e sai da lava)
	if boss != null and boss.aggro_target == e.id and BossSignatures.in_empower_pool(m, boss):
		if drag_to == Vector3.INF or not _drag_ok(e, m, boss, drag_to):
			drag_to = _drag_spot(e, sim, m, boss)
		if drag_to != Vector3.INF:
			return drag_to
	else:
		drag_to = Vector3.INF
	# Avalanche: atrás da pedra mais perto (a pedra entre mim e o chefe)
	if boss != null and boss.current_skill != null and boss.skill_phase == "startup" and boss.current_skill.effects.has("avalanche"):
		var r := float((boss.current_skill.effects["avalanche"] as Dictionary).get("radius", 18.0))
		if e.position.distance_to(boss.position) <= r + e.radius + 2.0:
			var spot := Vector3.INF
			var sd := INF
			for c in BossSignatures.covers_of(m, boss.id):
				var cp: Vector3 = c["pos"]
				var dir := Vector3(cp.x - boss.position.x, 0, cp.z - boss.position.z)
				dir = dir.normalized() if dir.length() > 0.05 else Vector3.FORWARD
				var p: Vector3 = cp + dir * (float(c["radius"]) + Balance.BOT_SIG_COVER_GAP)
				var d := p.distance_to(e.position)
				if d < sd:
					sd = d
					spot = p
			if spot != Vector3.INF:
				return spot
	# Muralha: quem o chefe mira fica de guarda parado na frente (golpe bloqueado = fúria; andar fazia ele virar para o
	# grupo); os outros vão para as costas e não batem de frente
	if boss != null and (boss.sig.has("wall") or boss.sig.has("counter")):         # contragolpe armando: idem até o golpe sair
		if boss.aggro_target == e.id:
			sig_guard = true
			return Vector3.INF
		if BossSignatures.wall_blocks(boss, e.position):
			return boss.position - boss.forward() * (boss.radius + e.radius + (Balance.BOT_SIG_WALL_MELEE if melee else minf(Balance.BOT_RANGED_DIST, Balance.BOT_SIG_WALL_RANGED)))
	return Vector3.INF

## Machado do Trono (marca de dividir, GDD act2-boss-signatures 3.11): onde ficar por causa da marca `h`. O marcado para nos
## últimos BOT_SIG_SOAK_VICTIM_HOLD s (o grupo vem até ele); antes segue no que fazia. Quem não é o tanque, a até BOT_SIG_SOAK_RANGE m, segue o que fazia (estandarte, vaga, cura) até
## o tempo que falta mal dar para chegar (distância até a borda de dentro ÷ velocidade + BOT_SIG_SOAK_MARGIN s) e aí vai ao
## centro; já dentro (BOT_SIG_SOAK_PAD m da borda), fica. Depois que cai, a marca some e ele volta. INF = não é comigo.
func soak_spot(e: SimEntity, sim, h: Dictionary) -> Vector3:
	if int(h.get("victim", -1)) == e.id:          # o marcado segue no que fazia e só para nos últimos segundos (o grupo chega nele)
		return e.position if float(h["at"]) - sim.time <= Balance.BOT_SIG_SOAK_VICTIM_HOLD else Vector3.INF
	if _role(e, sim) == "tank":
		return Vector3.INF
	var c: Vector3 = h["pos"]
	var d := Vector2(c.x - e.position.x, c.z - e.position.z).length()
	if d > Balance.BOT_SIG_SOAK_RANGE:
		return Vector3.INF
	var inner: float = maxf(0.0, float(h["radius"]) - e.radius - Balance.BOT_SIG_SOAK_PAD)
	if d <= inner:
		return e.position
	if not _soak_helper(e, sim, h, d):
		return Vector3.INF
	var speed: float = maxf(1.0, e.stats.move_speed if e.stats else 5.0)
	var need := (d - inner) / speed + Balance.BOT_SIG_SOAK_MARGIN
	return c if float(h["at"]) - sim.time <= need else Vector3.INF

## Sou um dos BOT_SIG_SOAK_HELPERS personagens mais perto do círculo (fora a vítima, o alvo do chefe e quem já está dentro, que
## conta como ajuda)? Os outros seguem no que faziam: com 3 dentro o golpe já cai a 1/3 e cada um tira a própria DEF.
func _soak_helper(e: SimEntity, sim, h: Dictionary, d: float) -> bool:
	var m: Dictionary = sim.maps.get(e.map_id, {})
	var ow: SimEntity = sim.entities.get(h["owner"])
	var c: Vector3 = h["pos"]
	var ahead := 0
	for o: SimEntity in m.get("chars", m.get("entities", [])):
		if o == e or not o.is_alive() or not o.is_character() or o.id == int(h.get("victim", -1)) or (ow != null and o.id == ow.aggro_target):
			continue
		if ow != null and not ow.is_hostile_to(o):
			continue
		var od := Vector2(c.x - o.position.x, c.z - o.position.z).length()
		if od <= float(h["radius"]) or od < d or (is_equal_approx(od, d) and o.id < e.id):
			ahead += 1
	return ahead < Balance.BOT_SIG_SOAK_HELPERS

## Marca de dividir ativa que me chama (vale para quem cura/segue o líder, antes da cura): anda até ela. Já no lugar =
## soak_pin (a cura não o tira de lá) e false (cura/luta dali). true = andou.
func _soak_move(e: SimEntity, sim, m: Dictionary, cmd: InputCommand) -> bool:
	soak_pin = false
	for h in m.get("hazards", []):
		if not h.get("mark", false) or h.get("landed", false) or str(h.get("mode", "")) != "soak":
			continue
		var ow: SimEntity = sim.entities.get(h["owner"])
		if ow == null or not ow.is_hostile_to(e):
			continue
		var sp := soak_spot(e, sim, h)
		if sp == Vector3.INF:
			continue
		var off := Vector2(sp.x - e.position.x, sp.z - e.position.z)
		if off.length() <= Balance.BOT_SIG_HOLD:
			soak_pin = true
			return false
		if not e.can_act():
			return false
		cmd.move = _steer(e, sp, 0.0)
		cmd.aim = sp
		if off.length() > Balance.BOT_SIG_DASH_DIST and e.dash_cd <= 0.0 and float(h["at"]) - sim.time < off.length() / maxf(1.0, e.stats.move_speed) + 0.5:
			cmd.dash = true
		engaged = false
		return true
	return false

## Marca de espalhar em mim que pede para sair ({} = nenhuma; dentro de cúpula aliada com o chefe fora dela, a marca não
## acerta ninguém: fica).
func _spread_mark(e: SimEntity, sim, m: Dictionary) -> Dictionary:
	for h in m.get("hazards", []):
		if not h.get("mark", false) or h.get("landed", false) or int(h.get("victim", -1)) != e.id or str(h.get("mode", "")) == "soak":
			continue
		var ow: SimEntity = sim.entities.get(h["owner"])
		if ow == null or not ow.is_hostile_to(e) or ChoirSystem.shelters(sim, ow, e):
			continue
		return h
	return {}

## Ilha (Maré Cheia, Palco Seguro) ou marca de espalhar em mim, para quem cura/segue o líder (antes da cura; a luta usa os
## mesmos pontos via _sig_spot): anda até lá. Chegou = soak_pin (a cura não o tira de lá) e false (cura/luta dali). true = andou.
func _sig_move(e: SimEntity, sim, m: Dictionary, cmd: InputCommand) -> bool:
	var isl := _island_spot(e, sim, m.get("hazards", []))
	if isl != Vector3.INF:
		var io := Vector2(isl.x - e.position.x, isl.z - e.position.z)
		if io.length() <= Balance.BOT_SIG_HOLD:
			soak_pin = true
			return false
		if not e.can_act():
			return false
		cmd.move = _steer(e, isl, 0.0)
		cmd.aim = isl
		if io.length() > Balance.BOT_SIG_DASH_DIST and e.dash_cd <= 0.0:
			cmd.dash = true
		engaged = false
		return true
	var h := _spread_mark(e, sim, m)
	if h.is_empty():
		return false
	if spread_id != int(h["id"]) or (sim.time - spread_t >= Balance.BOT_SIG_SPREAD_REPLAN and _spread_clash(e, sim, h, spread_to)):
		spread_id = int(h["id"])
		spread_t = sim.time
		spread_to = _spread_spot(e, sim, m, m.get("hazards", []), h)
	var off := Vector2(spread_to.x - e.position.x, spread_to.z - e.position.z)
	if off.length() <= Balance.BOT_SIG_HOLD:
		soak_pin = true
		return false
	if not e.can_act():
		return false
	cmd.move = _steer(e, spread_to, 0.0)
	cmd.aim = spread_to
	if off.length() > Balance.BOT_SIG_DASH_DIST and e.dash_cd <= 0.0 and float(h["at"]) - sim.time < off.length() / maxf(1.0, e.stats.move_speed) + 0.5:
		cmd.dash = true
	engaged = false
	return true

## Têmpera na Lava: ponto a BOT_SIG_DRAG_DIST m+ de mim (16 direções, anéis de 2 m), fora das poças do chefe, onde ele
## também para fora delas (chega pelo lado dele, a alcance de golpe). Empate: o mais longe das poças. INF = nenhum.
func _drag_spot(e: SimEntity, sim, m: Dictionary, boss: SimEntity) -> Vector3:
	for ring in range(6):
		var dist := Balance.BOT_SIG_DRAG_DIST + 2.0 * ring
		var best := Vector3.INF
		var best_s := -INF
		for k in range(16):
			var a := TAU * k / 16.0
			var p := e.position + Vector3(cos(a), 0, sin(a)) * dist
			if not MapGeometry.is_walkable(sim, p, m["def"], e.radius) or not _drag_ok(e, m, boss, p):
				continue
			var sc := INF
			for h in m.get("hazards", []):
				if h.get("landed", false) and h.get("empower") is Dictionary and int(h["owner"]) == boss.id:
					var c: Vector3 = h["pos"]
					sc = minf(sc, Vector2(c.x - p.x, c.z - p.z).length() - float(h["radius"]))
			if sc > best_s:
				best_s = sc
				best = p
		if best != Vector3.INF:
			return best
	return Vector3.INF

## O ponto `p` serve para arrastar: eu fora das poças dele e o chefe, chegando em mim, também.
func _drag_ok(e: SimEntity, m: Dictionary, boss: SimEntity, p: Vector3) -> bool:
	var to := Vector3(boss.position.x - p.x, 0, boss.position.z - p.z)
	var q := p + (to.normalized() if to.length() > 0.05 else Vector3.RIGHT) * minf(to.length(), boss.monster_def.attack_range + boss.radius)
	for h in m.get("hazards", []):
		if not h.get("landed", false) or not (h.get("empower") is Dictionary) or int(h["owner"]) != boss.id:
			continue
		if BossSignatures.inside(h, p, e.radius + Balance.BOT_DODGE_PAD) or BossSignatures.inside(h, q, boss.radius):
			return false
	return true

## Marca de espalhar em mim (`mine`): dos pontos andáveis em 16 direções (a BOT_SIG_SPREAD_DIST m e à metade), o que fica a
## mais folga das outras marcas (onde o bot marcado PLANEJOU ir, senão onde a marca está; distância segura = maior entre o
## `touch` do Cânone e a soma dos raios + BOT_SIG_SPREAD_GAP) e, depois, dos aliados (raio da minha + BOT_SIG_SPREAD_GAP).
func _spread_spot(e: SimEntity, sim, m: Dictionary, hz: Array, mine: Dictionary = {}) -> Vector3:
	var r_me: float = float(mine.get("radius", 4.0))
	var others: Array = []
	for o: SimEntity in m.get("chars", m["entities"]):
		if o != e and o.is_alive() and o.is_character() and not o.is_hostile_to(e) and o.position.distance_to(e.position) < Balance.BOT_SIG_SPREAD_SCAN:
			others.append(o.position)
	var marks: Array = []                       # [ponto, distância segura]
	for h in hz:
		if h.get("mark", false) and not h.get("landed", false) and int(h.get("victim", -1)) != e.id and str(h.get("mode", "")) != "soak":
			marks.append([_mark_goal(sim, h), _mark_gap(mine, h, r_me)])
	var best := e.position
	var best_s := -INF
	for ring: float in [1.0, 0.5]:
		for k in range(16):
			var a := TAU * k / 16.0
			var p := e.position + Vector3(cos(a), 0, sin(a)) * Balance.BOT_SIG_SPREAD_DIST * ring
			if not MapGeometry.is_walkable(sim, p, m["def"], e.radius):
				continue
			var mk := INF
			for q in marks:
				var qp: Vector3 = q[0]
				mk = minf(mk, Vector2(qp.x - p.x, qp.z - p.z).length() - float(q[1]))
			var al := INF
			for q: Vector3 in others:
				al = minf(al, Vector2(q.x - p.x, q.z - p.z).length())
			# folga das marcas manda (dobrar no Cânone/acertar o outro marcado); depois aliados; empate: mais perto
			var sc := minf(mk, Balance.BOT_SIG_SPREAD_GAP) * 10.0 + minf(al - r_me - Balance.BOT_SIG_SPREAD_GAP, Balance.BOT_SIG_SPREAD_DIST) - ring * 0.1
			if sc > best_s:
				best_s = sc
				best = p
	return best

## Para onde vai a marca `h`: o ponto de espalhar que o bot marcado escolheu (se escolheu), senão onde ela está.
static func _mark_goal(sim, h: Dictionary) -> Vector3:
	var v: SimEntity = sim.entities.get(int(h.get("victim", -1)))
	if v != null and v.brain is BotBrain and v.brain.spread_id == int(h["id"]) and v.brain.spread_to != Vector3.INF:
		return v.brain.spread_to
	return h["pos"]

## Distância segura entre o centro da minha marca e o de `h`: Cânone (`touch`) ou não encostar os círculos.
static func _mark_gap(mine: Dictionary, h: Dictionary, r_me: float) -> float:
	return maxf(float(mine.get("touch", 0.0)) if int(mine.get("batch", -1)) == int(h.get("batch", -2)) else 0.0, r_me + float(h.get("radius", 4.0))) + Balance.BOT_SIG_SPREAD_GAP * 0.5

## O ponto `to` da minha marca `mine` ficou perto demais do plano de outra marcada (ela escolheu depois de mim)?
func _spread_clash(e: SimEntity, sim, mine: Dictionary, to: Vector3) -> bool:
	if to == Vector3.INF:
		return true
	var r_me: float = float(mine.get("radius", 4.0))
	for h in sim.maps.get(e.map_id, {}).get("hazards", []):
		if h == mine or not h.get("mark", false) or h.get("landed", false) or int(h.get("victim", -1)) == e.id or str(h.get("mode", "")) == "soak":
			continue
		var g := _mark_goal(sim, h)
		if Vector2(g.x - to.x, g.z - to.z).length() < _mark_gap(mine, h, r_me) - Balance.BOT_SIG_SPREAD_GAP * 0.5:
			return true
	return false

## Skill de atordoar pronta que alcança o alvo (-1 = nenhuma).
func _stun_skill(e: SimEntity, mob: SimEntity, dist: float) -> int:
	for i in range(e.skills.size()):
		var s := e.skills[i]
		if s == null or not s.effects.has("stun") or e.level < s.unlock_level or not e.stats.meets(s.requires) or not _ready_to_cast(e, s):
			continue
		if e.is_character() and not e.knows(s.id):
			continue
		var reach := s.range if s.target != SkillDef.Target.SELF else s.radius
		if s.target == SkillDef.Target.CONE:
			reach = s.radius
		if dist <= maxf(reach, 1.5) + 0.3:
			return i
	return -1

## Guardar o atordoar: o chefe por perto tem canal que volta em menos de BOT_SIG_STUN_SAVE da recarga.
static func _save_stun(sim, mob: SimEntity) -> bool:
	var b := _sig_boss(sim, mob)
	if b == null or b.sig.has("channel"):
		return false
	for s: SkillDef in b.skills:
		if s != null and s.effects.has("boss_channel"):
			return float(b.cooldowns.get(s.id, 0.0)) < s.cooldown * Balance.BOT_SIG_STUN_SAVE
	return false

func _pick_monster(e: SimEntity, m: Dictionary) -> SimEntity:
	var best: SimEntity = null
	var best_score := INF
	for o: SimEntity in m["entities"]:
		if o.kind != SimEntity.Kind.MONSTER or not o.is_alive() or o.monster_def.dummy:     # boneco de treino é do jogador
			continue
		if o.monster_def.is_boss and e.level < o.level + 2 and personality < 0.7:
			continue
		var d: float = o.position.distance_to(e.position)
		if d > 18.0:
			continue
		var score: float = d + absf(o.level - e.level) * 1.5
		if o.aggro_target >= 0 and o.aggro_target != e.id:
			score += 6.0   # evita roubar monstro de outro
		if score >= best_score or _ignored(o):
			continue
		# calmo e com muro/cerca/rio no meio: não escolhe (antes empurrava a parede até o prazo da caça)
		if o.aggro_target != e.id and cur_sim != null and unstuck_enabled:
			if float(line_block.get(o.id, -1.0)) > cur_sim.time:
				continue
			if not MapGeometry.line_walkable(cur_sim, m, e.position, o.position, o.radius + 0.6):
				if line_block.size() > 24:
					line_block.clear()
				line_block[o.id] = cur_sim.time + Balance.BOT_LINE_RECHECK
				continue
		best_score = score
		best = o
	return best

## Monstro largado (inalcançável ou linha bloqueada) e ainda no prazo.
func _ignored(o: SimEntity) -> bool:
	if ignore.is_empty() or cur_sim == null:
		return false
	var until: float = ignore.get(o.id, -1.0)
	if until < 0.0:
		return false
	if cur_sim.time < until:
		return true
	ignore.erase(o.id)
	return false

## Larga o alvo e o ignora por BOT_UNREACHABLE_IGNORE s.
func _drop(mob: SimEntity) -> void:
	if ignore.size() > 24:
		for k in ignore.keys():
			if float(ignore[k]) <= cur_sim.time:
				ignore.erase(k)
	ignore[mob.id] = cur_sim.time + Balance.BOT_UNREACHABLE_IGNORE
	hunt_target_id = -1
	engaged = false
	prog_key = -99

## Travado indo para `goal` (chave `key`: id do alvo ou -2 = ponto de caça)? Progresso = chegar BOT_CHASE_PROGRESS m mais
## perto; andando por rota (portão, anel, ponte) vale sair 2 m do lugar. Sem progresso por BOT_CHASE_STALL s = true.
func _stalled(e: SimEntity, key: int, goal: Vector3) -> bool:
	if cur_sim == null or not unstuck_enabled:
		return false                   # cérebro solto (teste chamando _fight_core direto): sem relógio
	var now: float = cur_sim.time
	if key != prog_key or now - prog_at > 1.0:
		prog_key = key
		prog_best = INF
		prog_t = 0.0
		prog_anchor = e.position
	prog_at = now
	var d := e.position.distance_to(goal)
	if d < prog_best - Balance.BOT_CHASE_PROGRESS:
		prog_best = d
		prog_anchor = e.position
		prog_t = 0.0
		return false
	prog_t += think_dt
	if prog_t <= Balance.BOT_CHASE_STALL * (Balance.BOT_ROUTED_STALL_MULT if steer_routed else 1.0):
		return false
	prog_key = -99                 # quem chamou troca de alvo/ponto: a contagem recomeça
	# sai do bolsão: anda para trás (em relação ao ponto) por um tempo antes de seguir para o próximo
	var back := Vector2(e.position.x - goal.x, e.position.z - goal.z)
	if back.length() > 0.01:
		detour = back.normalized().rotated(rng.randf_range(-0.5, 0.5))
		detour_timer = Balance.BOT_ESCAPE_TIME
		detour_age = 0.0
		ring_wp = Vector3.INF
	return true

func _plan_trip(e: SimEntity, sim) -> void:
	var fields: Array = []
	for mid in GameData.maps:
		var md: MapDef = GameData.maps[mid]
		if not md.has_hunting() or md.parent_map != "":
			continue
		if e.level >= md.level_range.x - 1 and e.level <= md.level_range.y + 3:
			fields.append(mid)
	if fields.is_empty():
		for mid in GameData.maps:
			if GameData.maps[mid].has_hunting() and GameData.maps[mid].parent_map == "":
				fields.append(mid)
	dest_map = fields[rng.randi() % fields.size()]
	state = S.TRAVEL
	timer = Balance.BOT_TRAVEL_LEG_S
	travel_map = e.map_id
	if rng.randf() < 0.3:
		Events.post(&"chat_message", e.name, GameData.random_bot_line("leaving").format(BotsCatalog.place_words(GameData.maps[dest_map].name)), "global")
	_gather_party(e, sim)

func _go_home(e: SimEntity, sim) -> void:
	state = S.RETURN
	dest_map = PortalSystem.home_of(e, sim)["map"]
	timer = 90.0

## Ponto de encontro do povoado: BOT_HANGOUT_PICKS sorteados, fica o com menos bots em volta; com a praça cheia
## (BOT_SQUARE_CAP bots à toa a BOT_SQUARE_RADIUS do centro) os da praça ficam de fora.
func _pick_hangout(e: SimEntity, m: Dictionary, def: MapDef) -> Vector3:
	var hs: Array = def.bot_hangouts
	var square := 0
	for o: SimEntity in m["entities"]:
		if o != e and o.kind == SimEntity.Kind.BOT and o.position.distance_to(def.town_center) < Balance.BOT_SQUARE_RADIUS:
			square += 1
	var full := square >= Balance.BOT_SQUARE_CAP
	var best: Vector3 = hs[rng.randi() % hs.size()]
	var best_n := 1 << 30
	for i in Balance.BOT_HANGOUT_PICKS:
		var h: Vector3 = hs[rng.randi() % hs.size()]
		var n := 0
		if full and h.distance_to(def.town_center) < Balance.BOT_SQUARE_RADIUS:
			n += 1000
		for o: SimEntity in m["entities"]:
			if o != e and o.kind == SimEntity.Kind.BOT and o.position.distance_to(h) < Balance.BOT_HANGOUT_CROWD_R:
				n += 1
		if n < best_n:
			best = h
			best_n = n
	return best

## Portal do mapa atual no caminho até `target_map` (busca no grafo de portais, como o seguidor do grupo).
## Antes caía em `portals[0]` quando o destino ficava a 2+ portais: no mapa vizinho o `portals[0]` apontava de volta
## e o bot ia e voltava pelo mesmo portal até a viagem expirar.
func _find_portal(def: MapDef, target_map: String) -> Dictionary:
	return PortalSystem.portal_towards(def, target_map, true)

## Sem recarga e com mana para a skill (no nível de maestria atual).
func _ready_to_cast(e: SimEntity, s: SkillDef) -> bool:
	return e.cooldowns.get(s.id, 0.0) <= 0.0 and e.mp >= s.mp_cost_at(e.mastery_of(s.id))

func _find_npc(def: MapDef, role: String) -> Dictionary:
	for n in def.npcs:
		if n.get("role", "") == role:
			return n
	return {}

func _sell_materials(e: SimEntity) -> void:
	for item_id in e.inventory.keys():
		var it: ItemDef = GameData.items.get(item_id)
		if it and (it.type == ItemDef.Type.MATERIAL or it.type == ItemDef.Type.CARD) and it.price > 0:      # moeda lendária não se vende; carta: bot não encaixa, vende
			var n := int(e.inventory[item_id])
			e.remove_item(item_id, n)
			e.gold += it.price * n

func _restock(e: SimEntity) -> void:
	var med := e.level >= Balance.BOT_MED_POTION_LEVEL
	var want := [["potion_hp_m" if med else "potion_hp_s", 5], ["potion_mp_m" if med else "potion_mp_s", 3]]
	for slot in range(2):
		var iid: String = want[slot][0]
		var it: ItemDef = GameData.items.get(iid)
		if it == null:
			continue
		e.potion_slots[slot] = iid
		while int(e.inventory.get(iid, 0)) < int(want[slot][1]) and e.gold >= it.price:
			e.gold -= it.price
			e.add_item(iid, 1)

## Tem poção no atalho `slot` (bot sem a do atalho usa a pequena que sobrou).
func _has_potion(e: SimEntity, slot: int) -> bool:
	var iid: String = e.potion_slots[slot]
	if iid != "" and e.has_item(iid):
		return true
	var small: String = ["potion_hp_s", "potion_mp_s"][slot]
	if e.has_item(small):
		e.potion_slots[slot] = small
		return true
	return false

# ---------------------------------------------------------------------------
## Investida no mapa (RaidSystem): bot perto do povoado decide uma vez por leva se defende. Defensor vai ao portão
## atacado, pega o invasor mais perto (até RAID_DEFEND_LEASH além da muralha), segura a posição entre um e outro,
## e recua para dentro (sentinelas + Bastião) quando a vida cai, voltando inteiro. Null = não está defendendo.
const DEFEND_LINES := ["Investida no portão! Bora segurar!", "Elfos no portão norte, vou ajudar", "segura o portão galera",
	"de novo esses elfos kkk", "indo defender o posto"]

func _defend(e: SimEntity, sim, m: Dictionary, cmd: InputCommand, dt: float) -> InputCommand:
	var def: MapDef = m["def"]
	if def.raid.is_empty() and def.raids.is_empty():
		return null
	var rs: Dictionary = sim.raid_status(e.map_id)
	if not rs["active"] or rs["phase"] == "retreat":
		defend_wave = -1
		falling_back = false
		return null
	var wave: int = rs["wave"]
	var target: Vector3 = rs["target"]
	if defend_wave != wave:
		if skip_wave == wave:
			return null
		if state == S.RETURN or e.position.distance_to(target) > Balance.RAID_DEFEND_RANGE or rng.randf() > Balance.RAID_DEFEND_CHANCE:
			skip_wave = wave
			return null
		if e.party_id < 0 and not SiegeSystem.bot_may_defend(m, wave):      # Cerco Vivo: só alguns avulsos acodem; o grupo do jogador vai sempre
			skip_wave = wave
			return null
		defend_wave = wave
		falling_back = false
		if rng.randf() < 0.4:
			Events.post(&"chat_message", e.name, DEFEND_LINES[rng.randi() % DEFEND_LINES.size()], "global")
	var gate: Vector3 = rs["gate"]
	var out := (gate - target).normalized() if gate.distance_to(target) > 0.5 else Vector3(0, 0, -1)
	# ferido: recua para dentro das muralhas (Bastião regenera, sentinelas cobrem) e volta com vida
	if e.hp < e.stats.max_hp * Balance.RAID_DEFEND_FALLBACK:
		falling_back = true
	elif e.hp > e.stats.max_hp * Balance.RAID_DEFEND_RETURN:
		falling_back = false
	if falling_back:
		var inside := target + out * float(rs["radius"]) * 0.45
		if e.position.distance_to(inside) > 2.0:
			cmd.move = _steer(e, inside, dt)
			cmd.aim = inside
			return cmd
		var near := Combat.nearest_hostile(e, m["entities"], 5.0)     # encurralado: briga
		if near:
			return _fight(e, sim, m, near, cmd)
		cmd.aim = gate
		return cmd
	# alvo: o que já está brigando, senão o invasor vivo mais perto dentro da coleira, senão quem me bate
	var leash: float = float(rs["radius"]) + Balance.RAID_DEFEND_LEASH
	var mob := _sticky(e, m, 14.0)
	if mob and mob.position.distance_to(target) > leash + 4.0:
		mob = null
	if mob == null:
		var bd := 1e9
		for id in rs["ids"]:
			var r: SimEntity = sim.entities.get(id)
			if r == null or not r.is_alive() or r.position.distance_to(target) > leash:
				continue
			var d := r.position.distance_to(e.position)
			if d < bd:
				bd = d
				mob = r
	if mob == null:
		mob = Combat.nearest_hostile(e, m["entities"], 7.0)
	if mob:
		return _fight(e, sim, m, mob, cmd)
	# ninguém ao alcance: posição no portão, em leque, olhando para fora
	var side := Vector3(-out.z, 0, out.x)
	var spot := gate + out * 2.5 + side * float((e.id % 5) - 2) * 2.2
	if e.position.distance_to(spot) > 1.2:
		cmd.move = _steer(e, spot, dt)
		cmd.aim = spot
	else:
		cmd.aim = gate + out * 10.0
	return cmd

## Ponto intermediário para entrar/sair de povoado murado (vila, forte, cidade élfica, posto: town_radius + portões no JSON).
## Teste pela distância ao centro (não `in_town`, que só vale com is_town). Sai pelo portão de frente para o destino, entra
## pelo mais perto; o portão escolhido vale até passar BOT_GATE_CLEAR m do muro (antes ia e voltava no vão). Fora, linha que
## cortaria o povoado contorna por um anel a BOT_GATE_RING_PAD m do muro.
func _route(e: SimEntity, p: Vector3) -> Vector3:
	if cur_def == null or cur_def.town_radius <= 0.0 or cur_def.town_gates.is_empty():
		return p
	var c := cur_def.town_center
	var r := cur_def.town_radius
	var from_c := Vector2(e.position.x - c.x, e.position.z - c.z).length()
	var p_in := Vector2(p.x - c.x, p.z - c.z).length() < r
	if route_map != cur_def.id:
		route_map = cur_def.id
		route_gate = -1
		ring_side = 0.0
	var gates: Array = cur_def.town_gates
	if route_gate >= gates.size():
		route_gate = -1
	if route_gate >= 0:
		if route_exit and (p_in or from_c > r + Balance.BOT_GATE_CLEAR):
			route_gate = -1
		elif not route_exit and (not p_in or from_c < r - Balance.BOT_GATE_CLEAR):
			route_gate = -1
	if route_gate < 0:
		var inside := from_c < r
		if inside == p_in:
			return p if inside else _ring(e, p, from_c)
		route_exit = inside
		var best := INF
		for i in range(gates.size()):
			var g: Vector3 = gates[i]
			var cost: float = p.distance_to(g) if inside else e.position.distance_to(g)
			if cost < best:
				best = cost
				route_gate = i
	var gate: Vector3 = gates[route_gate]
	var dir := Vector3(gate.x - c.x, 0.0, gate.z - c.z).normalized()
	var inner := c + dir * (r - 5.0)
	var outer := c + dir * (r + 5.0)
	if route_exit:
		# sai: primeiro até a rua do portão, depois atravessa
		return inner if from_c < r - 5.5 and e.position.distance_to(inner) > 2.5 else outer
	if from_c > r + 3.5 and e.position.distance_to(outer) > 2.5:
		return _ring(e, outer, from_c)                  # até a frente do portão, contornando o muro
	return inner

## Fora do povoado: a linha até `p` corta o muro? Então contorna por um anel: candidatos a BOT_GATE_RING_STEP (ou meio)
## graus no sentido escolhido (uma vez por contorno), no anel a 1x..4x BOT_GATE_RING_PAD m do muro (o passo reto só para fora);
## vale o primeiro com a linha
## livre (morro, torre ou casa colados no muro: abre o anel).
## Sentido com histerese: escolhido pelo lado curto e mantido até largar o contorno; só vira se o outro lado ficar
## BOT_RING_FLIP_DEG mais curto ou se o escolhido passar BOT_RING_BLOCK_S s sem ponto livre (nem sem a água) — antes
## virava num só pensamento sem ponto (ex.: na ponte da Floresta) e dava a volta longa. Nada livre: o anel de sempre.
## O ponto vale por 1 s ou até chegar (os testes de linha não rodam a cada pensamento).
func _ring(e: SimEntity, p: Vector3, from_c: float) -> Vector3:
	var c := cur_def.town_center
	var r := cur_def.town_radius
	var a2 := Vector2(e.position.x - c.x, e.position.z - c.z)
	var b2 := Vector2(p.x - c.x, p.z - c.z)
	var q := Geometry2D.get_closest_point_to_segment(Vector2.ZERO, a2, b2)
	var pad: float = Balance.BOT_GATE_CROSS_PAD + (Balance.BOT_GATE_CROSS_HYST if ring_side != 0.0 else 0.0)     # já contornando: só larga com folga
	if q.length() >= r + pad or q.distance_squared_to(a2) < 0.0001 or q.distance_squared_to(b2) < 0.0001:
		ring_side = 0.0
		ring_wp = Vector3.INF
		return p
	var now: float = cur_sim.time if cur_sim else 0.0
	if ring_wp != Vector3.INF and now < ring_until and Vector2(e.position.x - ring_wp.x, e.position.z - ring_wp.z).length() > 1.5:
		return ring_wp
	var a0 := a2.angle()
	var delta := wrapf(b2.angle() - a0, -PI, PI)
	var fresh := ring_side == 0.0
	var stalled := false
	if fresh:
		ring_side = 1.0 if delta >= 0.0 else -1.0
	else:
		var left := absf(_ring_travel(delta, ring_side))
		if left - absf(_ring_travel(delta, -ring_side)) > maxf(ring_bias, 0.0) + deg_to_rad(Balance.BOT_RING_FLIP_DEG):
			_ring_commit(-ring_side, delta, now)        # alvo mudou: o outro lado ficou bem mais curto
		elif left < ring_best - deg_to_rad(Balance.BOT_RING_PROGRESS_DEG):
			ring_best = left
			ring_best_t = now
		else:
			stalled = now - ring_best_t >= Balance.BOT_RING_BLOCK_S     # parado neste sentido: pode tentar o outro
	var may_flip: bool = fresh or stalled
	var sides: Array = [ring_side] if not may_flip else ([ring_side, -ring_side] if fresh else [-ring_side, ring_side])
	var m: Dictionary = cur_sim.maps.get(e.map_id, {}) if cur_sim else {}
	# sem rio entre o bot e o alvo (ex.: em cima da ponte): passo do anel que põe um rio no meio não serve
	var p2 := Vector2(p.x, p.z)
	var clear_now: bool = not m.is_empty() and not MapGeometry.crosses_river(cur_sim, m, Vector2(e.position.x, e.position.z), p2)
	var pick := Vector3.INF
	for dry: bool in [false, true]:      # 1º com a água; nada livre: sem ela (o desvio pela ponte leva até o ponto)
		for side: float in sides:
			var full := minf(absf(_ring_travel(delta, side)), deg_to_rad(Balance.BOT_GATE_RING_STEP))
			var steps: Array = [0.0] if from_c < r + 3.0 else [full, full * 0.5, 0.0]     # colado no muro: sai reto primeiro
			for k in range(1, 5):
				var rad: float = r + Balance.BOT_GATE_RING_PAD * k
				for st: float in steps:
					if st == 0.0 and rad < from_c + 1.0:
						continue                              # passo só para fora: nunca volta para perto do muro
					var w := Vector2.from_angle(a0 + side * st) * rad
					var wp := cur_def.clamp_inside(c + Vector3(w.x, 0.0, w.y), 1.0)
					if Vector2(wp.x - e.position.x, wp.z - e.position.z).length() < 2.0:
						continue                              # já está nele: não serve de passo
					if clear_now and not dry and MapGeometry.crosses_river(cur_sim, m, Vector2(wp.x, wp.z), p2):
						continue
					if m.is_empty() or MapGeometry.line_walkable(cur_sim, m, e.position, wp, 0.0, 0.4, dry):
						pick = wp
						break
				if pick != Vector3.INF:
					break
			if pick != Vector3.INF:
				if fresh or side != ring_side:
					_ring_commit(side, delta, now)
				break
		if pick != Vector3.INF:
			break
	var hold := 1.0
	if pick == Vector3.INF:
		if fresh:
			_ring_commit(ring_side, delta, now)
		if not may_flip:
			hold = Balance.BOT_RING_HOLD_S
		if not may_flip and ring_wp != Vector3.INF and Vector2(e.position.x - ring_wp.x, e.position.z - ring_wp.z).length() > 1.5:
			pick = ring_wp                            # segura o ponto anterior (no mesmo sentido) e olha de novo logo
		else:
			var st0 := 0.0 if from_c < r + 3.0 else minf(absf(_ring_travel(delta, ring_side)), deg_to_rad(Balance.BOT_GATE_RING_STEP))
			var w0 := Vector2.from_angle(a0 + ring_side * st0) * (r + Balance.BOT_GATE_RING_PAD)
			pick = cur_def.clamp_inside(c + Vector3(w0.x, 0.0, w0.y), 1.0)
	ring_wp = pick
	ring_until = now + hold
	return pick

## Fixa o sentido do contorno: guarda o quanto ele já era mais longo que o outro (lado curto travado não volta pelo
## ângulo) e zera o relógio de progresso.
func _ring_commit(side: float, delta: float, now: float) -> void:
	ring_side = side
	ring_best = absf(_ring_travel(delta, side))
	ring_best_t = now
	ring_bias = ring_best - absf(_ring_travel(delta, -side))

## Ângulo (rad, com sinal) a percorrer no anel do ângulo atual até o alvo (`delta` em -PI..PI) indo pelo sentido `side`.
static func _ring_travel(delta: float, side: float) -> float:
	return delta if signf(delta) == side or delta == 0.0 else delta + side * TAU

## Desvio dos rios pelas pontes: caminho recalculado quando o alvo muda ou a cada 1,5 s; avança ponto a ponto.
func _water_step(e: SimEntity, p: Vector3, dt: float) -> Vector3:
	water_timer -= dt
	if water_timer <= 0.0 or water_goal.distance_to(p) > 3.0:
		water_timer = 1.5
		water_goal = p
		water_path = cur_sim.water_path(e.map_id, e.position, p)
	while not water_path.is_empty() and Vector2(e.position.x, e.position.z).distance_to(water_path[0]) < 1.2:
		water_path.pop_front()
	if water_path.is_empty():
		return p
	return Vector3(water_path[0].x, 0.0, water_path[0].y)

## Direção até `p` com desvio simples quando preso.
func _steer(e: SimEntity, p: Vector3, dt: float) -> Vector2:
	var goal := p
	if cur_sim:
		p = _water_step(e, p, dt)           # rio primeiro (ponte); o muro do povoado vale para cada trecho
	p = _route(e, p)
	steer_routed = p.distance_squared_to(goal) > 0.01
	var d := p - e.position
	var v := Vector2(d.x, d.z)
	if v.length() < 0.05:
		return Vector2.ZERO
	v = v.normalized()
	if dt > 0.0:
		if e.position.distance_to(last_pos) < 0.02 * (dt * 60.0):
			stuck_timer += dt
		else:
			stuck_timer = 0.0
		last_pos = e.position
		if stuck_timer > 0.5 and detour_timer <= 0.0:
			# preso de novo logo depois de um desvio: insiste no mesmo lado, por mais tempo
			detour_tries = detour_tries + 1 if detour_age < 3.0 else 0
			if detour_tries == 0 or detour_tries % 4 == 0:
				detour_side = 1.0 if rng.randf() < 0.5 else -1.0
			# 90° primeiro; se insistir em prender, abre até voltar (sai de bolsões entre árvore e rio)
			detour = v.rotated((PI * 0.5 + minf(detour_tries, 2) * PI * 0.25) * detour_side)
			detour_timer = rng.randf_range(0.8, 1.4) + minf(detour_tries, 3) * 0.6
			detour_age = 0.0
			stuck_timer = 0.0
		detour_age += dt
		detour_timer -= dt
	if detour_timer > 0.0:
		return (v * 0.3 + detour).normalized()
	return v

# ---------------------------------------------------------------------------
# GRUPO
## Bot decide um convite (chamado pela sim 1-3 s depois do convite).
func wants_party(e: SimEntity, from: SimEntity, sim) -> bool:
	if from == sim.player and e.roster_id >= 0 and sim.roster_on and e.party_id < 0 and e.is_alive():
		return RosterSystem.accepts_player(sim, e)      # elenco sempre aceita; afinidade negativa só fala seco (§9.4)
	if e.party_id >= 0 or not e.is_alive() or absi(e.level - from.level) > Balance.PARTY_LEVEL_GAP:
		return false
	var yes := rng.randf() < (0.9 if from == sim.player else Balance.BOT_PARTY_ACCEPT)
	if from == sim.player:
		if not yes:
			Events.post(&"chat_message", e.name, ["agora não, valeu", "to indo deslogar já", "to solando quest, foi mal"][rng.randi() % 3], "whisper")
	return yes

## Saindo pra caçar: chama bots parados na vila (nível parecido) e, às vezes, o jogador.
func _gather_party(e: SimEntity, sim) -> void:
	if e.party_id >= 0 or cur_def == null:
		return
	if rng.randf() < Balance.BOT_PARTY_FORM_CHANCE:
		var wanted := rng.randi_range(1, 2)
		for o in sim.map_entities(e.map_id):
			if wanted <= 0:
				break
			if o == e or o.kind != SimEntity.Kind.BOT or o.party_id >= 0 or not o.is_alive():
				continue
			if absi(o.level - e.level) > 5 or o.position.distance_to(e.position) > 30.0 or not cur_def.in_hub(o.position):
				continue
			if o.brain and o.brain.state in [S.TOWN_IDLE, S.TOWN_WALK] and sim.party_invite(e, o):
				wanted -= 1
	var pl: SimEntity = sim.player
	if pl and pl.map_id == e.map_id and pl.party_id < 0 and sim.time >= next_player_invite and pl.is_alive() \
			and absi(pl.level - e.level) <= 5 and pl.position.distance_to(e.position) < 25.0 and rng.randf() < Balance.BOT_INVITE_PLAYER_CHANCE:
		next_player_invite = sim.time + PLAYER_INVITE_COOLDOWN
		if sim.party_invite(e, pl):
			Events.post(&"chat_message", e.name, "bora caçar %s? te mandei convite" % BotsCatalog.place_words(GameData.maps[dest_map].name)["em"], "whisper")

func _party_has_player(e: SimEntity, sim) -> bool:
	return sim.player != null and sim.same_party(e, sim.player)

## Seguidor: vai até o mapa do líder, cura quem precisa, ajuda no combate e anda em formação atrás dele.
func _follow(e: SimEntity, sim, m: Dictionary, leader: SimEntity, cmd: InputCommand, dt: float) -> InputCommand:
	var def: MapDef = m["def"]
	var in_town := def.in_town(e.position)
	state = S.TOWN_IDLE if in_town else S.HUNT     # se sair do grupo, continua de onde está
	timer = 30.0
	if leader.map_id != e.map_id:
		var door := _door_to(def, leader.map_id)
		if not door.is_empty():
			return _wait_at_door(e, sim, door, cmd, dt)     # líder numa casa (porta só do jogador): espera do lado de fora
		var portal := PortalSystem.portal_towards(def, leader.map_id, true)
		if not portal.is_empty():
			cmd.move = _steer(e, portal["pos"], dt)
			cmd.aim = portal["pos"]
		return cmd
	var members: Array = sim.party_members(e)
	if not in_town and _soak_move(e, sim, m, cmd):      # Machado do Trono: entra no círculo a tempo (passa na frente da cura)
		return cmd
	if not in_town and _sig_move(e, sim, m, cmd):    # marca de espalhar em mim: sai do grupo antes de curar
		return cmd
	if _choir(e, sim, m, members, cmd):          # Bispo ascendido: Retorno/Barreira/Anjo passam na frente da cura
		return cmd
	if _evade_boss(e, sim, m, cmd):              # quem cura sai do alcance do Matador (Golpe de Misericórdia)
		return cmd
	if _heal_party(e, sim, members, cmd, dt):
		return cmd
	var foe := _loose_big(e, sim, m, members) if not in_town else null      # tanque: chefe que largou dele
	if foe == null and not in_town:
		foe = _cocoon_target(e, sim, members)                                  # casulo da Rainha segurando um aliado: quebra
	if foe == null and not in_town:
		foe = _peel_target(e, sim, m, members)                                 # dps de perto: lacaio em cima de quem cura/atira
	if foe == null:
		foe = _sticky(e, m, Balance.BOT_STICKY_RANGE)
	if foe and foe.position.distance_to(leader.position) > Balance.PARTY_ASSIST_RANGE * 1.6:
		foe = null                       # o líder foi embora: larga e acompanha
	if foe == null:
		foe = _party_threat(e, m, members, leader)
	if foe == null and not in_town:
		foe = _tank_pull(e, sim, m, members, leader)                          # tanque: abre no chefe/elite à frente do grupo
	if foe and _ignored(foe):
		foe = null                       # largado por inalcançável: acompanha o líder
	if foe and not in_town:
		if _taunt_party(e, sim, m, members, cmd):
			return cmd
		return _fight(e, sim, m, foe, cmd)
	# na vila: vende e reabastece de tempos em tempos (o líder decide quando voltar)
	shop_timer -= dt
	if in_town and shop_timer <= 0.0:
		shop_timer = 20.0
		_sell_materials(e)
		_restock(e)
	# formação: leque atrás do líder
	var idx := maxi(0, members.find(e) - 1)
	var behind := -leader.forward()
	var spot: Vector3 = leader.position + behind.rotated(Vector3.UP, (idx - 1.5) * 0.6) * Balance.PARTY_FOLLOW_DIST
	var far := e.position.distance_to(leader.position)
	if far > Balance.PARTY_FOLLOW_DIST + 1.2 or (e.position.distance_to(spot) > 1.5 and leader.velocity.length() > 0.1):
		cmd.move = _steer(e, spot, dt) * (1.0 if far > 6.0 else 0.75)
		cmd.aim = spot
	else:
		cmd.aim = e.position + leader.forward() * 3.0
	return cmd

## Porta só do jogador deste mapa que leva a `map_id` ({} = nenhuma).
static func _door_to(def: MapDef, map_id: String) -> Dictionary:
	for pt: Dictionary in def.portals:
		if pt["target_map"] == map_id and pt.get("player_only", false):
			return pt
	return {}

## Seguidor esperando o líder sair de casa: fica num ponto livre a BOT_DOOR_WAIT m da porta, com linha até ela (8 direções,
## a mais perto do bot; escolhido uma vez por porta), em leque por ordem no grupo, virado para a porta.
func _wait_at_door(e: SimEntity, sim, door: Dictionary, cmd: InputCommand, dt: float) -> InputCommand:
	var dp: Vector3 = door["pos"]
	if door_id != str(door["id"]) or door_spot == Vector3.INF:
		door_id = str(door["id"])
		door_spot = dp
		var m: Dictionary = sim.maps.get(e.map_id, {})
		var best := INF
		for k in range(8):
			var q := dp + Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 8.0) * Balance.BOT_DOOR_WAIT
			if not sim.is_walkable(q, cur_def, 0.6) or (not m.is_empty() and not MapGeometry.line_walkable(sim, m, q, dp, 0.0, 0.4)):
				continue
			var d := q.distance_to(e.position)
			if d < best:
				best = d
				door_spot = q
	var members: Array = sim.party_members(e)
	var idx := maxi(0, members.find(e) - 1)
	var spot := door_spot + Vector3(cos(idx * 2.1), 0.0, sin(idx * 2.1)) * (0.0 if idx == 0 else 1.2)
	if e.position.distance_to(spot) > 1.0:
		cmd.move = _steer(e, spot, dt) * 0.8
		cmd.aim = spot
	else:
		cmd.aim = dp
	return cmd

## Tanque: provoca quando há monstro por perto batendo em outro membro do grupo. O tanque também provoca de novo o
## chefe/elite que já segura quando alguém do grupo chega a BOT_TANK_RETAUNT × a ameaça dele (antes de o dps frear).
func _taunt_party(e: SimEntity, sim, m: Dictionary, members: Array, cmd: InputCommand) -> bool:
	if not e.can_act():
		return false
	var tank := _role(e, sim) == "tank"
	var ptank: SimEntity = null if tank else _tank_of(e, sim)   # quem não é o tanque não rouba o que o tanque do grupo segura
	for i in range(e.skills.size()):
		var s := e.skills[i]
		if s == null or not s.effects.has("taunt") or e.level < s.unlock_level or not e.stats.meets(s.requires):
			continue
		if not _ready_to_cast(e, s):
			continue
		for o: SimEntity in m["entities"]:
			if o.kind != SimEntity.Kind.MONSTER or not o.is_alive() or o.aggro_target < 0:
				continue
			if o.position.distance_to(e.position) > s.radius:
				continue
			if ptank != null and o.aggro_target == ptank.id:
				continue
			var mine: bool = o.aggro_target == e.id
			if (not mine and members.any(func(x): return x.id == o.aggro_target)) or (mine and tank and (_threat_close(e, o, members) or soft_in_danger(o, members))):
				cmd.skill_slot = i
				cmd.aim = o.position
				return true
	return false

## Chefe/elite preso em `e` (sem provocação valendo) com alguém do grupo a BOT_TANK_RETAUNT × a ameaça de `e` ou mais.
static func _threat_close(e: SimEntity, o: SimEntity, members: Array) -> bool:
	if not _is_big(o) or o.taunt_left > 0.0:
		return false
	var lim := float(o.threat.get(e.id, 0.0)) * Balance.BOT_TANK_RETAUNT
	for x in members:
		if x != e and float(o.threat.get(x.id, 0.0)) >= lim and float(o.threat.get(x.id, 0.0)) > 0.0:
			return true
	return false

## Cura o membro mais ferido (< 60% HP) com a primeira skill de cura pronta; anda até ele se precisar.
func _heal_party(e: SimEntity, sim, members: Array, cmd: InputCommand, dt: float) -> bool:
	if not e.can_act():
		return false
	# ordem: alguém quase morrendo (< BOT_HEAL_CRIT_HP) se o tanque não estiver em perigo; depois o tanque abaixo de
	# BOT_HEAL_TANK_HP (segura o chefe: cai e o grupo cai junto); depois o mais ferido abaixo de BOT_HEAL_HP
	var hurt: SimEntity = null
	var worst := Balance.BOT_HEAL_HP
	var crit: SimEntity = null
	var crit_r := Balance.BOT_HEAL_CRIT_HP
	var tank := _tank_of(e, sim)
	var tank_r := 1.0
	for o in members:
		if o.map_id != e.map_id or not o.is_alive() or o.position.distance_to(e.position) > Balance.BOT_HEAL_RANGE:
			continue
		var r: float = o.hp / maxf(1.0, o.stats.max_hp)
		if o == tank:
			tank_r = r
		elif r < crit_r:
			crit_r = r
			crit = o
		if r < worst:
			worst = r
			hurt = o
	if crit and tank_r >= Balance.BOT_HEAL_TANK_SAFE:
		hurt = crit
	elif tank and tank_r < Balance.BOT_HEAL_TANK_HP:
		hurt = tank
	if hurt == null:
		return false
	for i in range(e.skills.size()):
		var base := e.skills[i]
		if base == null or base.kind != SkillDef.Kind.HEAL or e.level < base.unlock_level or not e.stats.meets(base.requires) or not DruidAscension.form_ok(e, base.requires_form):
			continue
		if not _ready_to_cast(e, base):
			continue
		var s: SkillDef = sim.resolve_skill(e, base)
		var d := e.position.distance_to(hurt.position)
		var reach := 0.0 if s.target == SkillDef.Target.SELF and s.radius <= 0.0 else (s.radius if s.target == SkillDef.Target.SELF else s.range)
		if hurt != e and reach <= 0.0:
			continue
		if hurt == e or d <= reach - 0.3:
			cmd.skill_slot = i
			cmd.aim = hurt.position
			return true
		if soak_pin:
			continue                           # dentro do Machado do Trono: não sai para curar de perto
		cmd.move = _steer(e, hurt.position, dt)
		cmd.aim = hurt.position
		return true
	return false

## Inimigo que bate em alguém do grupo (ou o mais perto do líder em combate).
func _party_threat(e: SimEntity, m: Dictionary, members: Array, leader: SimEntity) -> SimEntity:
	var ids := {}
	for o in members:
		ids[o.id] = true
	var best: SimEntity = null
	var best_d := INF
	for o: SimEntity in m["entities"]:
		if o.kind != SimEntity.Kind.MONSTER or not o.is_alive() or o.monster_def.dummy:     # o grupo não ajuda no boneco de treino
			continue
		var d: float = o.position.distance_to(leader.position)
		if d > Balance.PARTY_BIG_ASSIST_RANGE:
			continue
		var hits_us: bool = ids.has(o.aggro_target) or ids.has(o.last_damage_from) or o.damage_by.has(leader.id)
		# chefe/elite que o tanque puxou ou em que o líder bate de longe: vale até PARTY_BIG_ASSIST_RANGE do líder
		var lim := Balance.PARTY_BIG_ASSIST_RANGE if hits_us and (_is_big(o) or o.damage_by.has(leader.id)) else Balance.PARTY_ASSIST_RANGE
		if d > lim or d >= best_d:
			continue
		if hits_us or (leader.combat_timer > 0.0 and d < 8.0 and o.aggro_target >= 0):     # líder brigando: ajuda no que estiver perto dele
			best_d = d
			best = o
	return best

## Tanque seguidor proativo (2026-11-19, usuário: "preciso chegar perto do boss para que ele entenda"): com o líder a pé e
## fora da vila, abre no chefe a até BOT_TANK_PULL_BOSS m do líder (elite: BOT_TANK_PULL_ELITE) que ainda não briga com
## outro grupo, com caminho livre até ele. O resto do grupo entra pela ameaça (_party_threat) depois que o tanque segura.
func _tank_pull(e: SimEntity, sim, m: Dictionary, members: Array, leader: SimEntity) -> SimEntity:
	if _role(e, sim) != "tank" or leader.mounted or not leader.is_alive() or e.hp < e.stats.max_hp * Balance.BOT_TANK_PULL_HP:
		return null
	var ids := {}
	for o in members:
		ids[o.id] = true
	var best: SimEntity = null
	var best_d := INF
	for o: SimEntity in m["entities"]:
		if o.kind != SimEntity.Kind.MONSTER or o.monster_def == null:
			continue
		var d: float = o.position.distance_to(leader.position)
		if d > Balance.BOT_TANK_PULL_BOSS or d >= best_d or not o.is_alive() or not _is_big(o) or o.monster_def.dummy or o.monster_def.decoy:
			continue
		if not o.monster_def.is_boss and d > Balance.BOT_TANK_PULL_ELITE:
			continue
		if o.aggro_target >= 0 and not ids.has(o.aggro_target):
			continue                       # brigando com outro grupo: não rouba
		if _ignored(o) or float(line_block.get(o.id, -1.0)) > sim.time:
			continue
		if o.aggro_target < 0 and not MapGeometry.line_walkable(sim, m, e.position, o.position, o.radius + 0.6):
			if line_block.size() > 24:
				line_block.clear()
			line_block[o.id] = sim.time + Balance.BOT_LINE_RECHECK
			continue                       # muro/rio no meio: o jogador decide o caminho
		best_d = d
		best = o
	return best

## Alvo atual, enquanto vale a pena (vivo, mesmo mapa, perto): sem isso o bot troca de alvo a cada pensamento e fica indo e voltando.
func _sticky(e: SimEntity, m: Dictionary, max_d: float) -> SimEntity:
	if hunt_target_id < 0:
		return null
	var o: SimEntity = cur_sim.entities.get(hunt_target_id) if cur_sim else null       # busca direta (antes varria o mapa)
	if o and o.map_id == e.map_id and o.is_alive() and o.kind == SimEntity.Kind.MONSTER and o.position.distance_to(e.position) <= max_d:
		return o
	hunt_target_id = -1
	engaged = false
	return null

## Casulo de Seda (GDD spider-queen-4p): casulo vivo segurando alguém de `allies` a até BOT_COCOON_RANGE m. Só quem não é
## tanque (segue no chefe) nem curandeiro (segue curando) quebra; vale para líder, seguidor e bot sozinho perto do jogador.
func _cocoon_target(e: SimEntity, sim, allies: Array) -> SimEntity:
	if _role(e, sim) in ["tank", "healer"]:
		return null
	return MobSystem.cocoon_of(sim, e, allies, Balance.BOT_COCOON_RANGE)

## Papel da build (tank, healer, dps, caster, ranged), lido uma vez.
func _role(e: SimEntity, sim) -> String:
	if my_role == "":
		my_role = sim.role_of(e)
	return my_role

## Tanque do grupo no mesmo mapa (o primeiro membro vivo com papel "tank"; null = sem tanque). Recalcula de tempos em tempos.
func _tank_of(e: SimEntity, sim) -> SimEntity:
	if e.party_id < 0:
		return null
	if tank_t <= 0.0:
		tank_t = TANK_RECHECK
		tank_id = -1
		for o in sim.party_members(e):
			if o.is_alive() and o.map_id == e.map_id and sim.role_of(o) == "tank":
				tank_id = o.id
				break
	var t: SimEntity = sim.entities.get(tank_id) if tank_id >= 0 else null
	return t if t and t.is_alive() and t.map_id == e.map_id else null

## Skill com o nó "em Cargas": contra chefe/elite gasta todas; no resto só com mais de uma pronta (guarda a rajada).
static func _charge_spend_ok(e: SimEntity, s: SkillDef, mob: SimEntity) -> bool:
	if e.charges.is_empty() or ChargeSystem.max_of(e, s.id) <= 1:
		return true
	return _is_big(mob) or ChargeSystem.available(e, s.id) > 1

## Chefe ou elite: vale a pena se posicionar e cuidar da ameaça.
static func _is_big(mob: SimEntity) -> bool:
	return mob.monster_def != null and (mob.monster_def.is_boss or mob.monster_def.elite_of != "")

## Frente do monstro preso no tanque: a direção dele até o tanque (para onde vão os golpes normais). Estável: o
## forward gira a cada golpe mirado em outro (mob_pick) e fazia o grupo correr à toa.
static func _front_dir(mob: SimEntity, tank: SimEntity) -> Vector3:
	var f := tank.position - mob.position
	f.y = 0.0
	if f.length() < 0.3:
		f = mob.forward()
		f.y = 0.0
	return f.normalized() if f.length() > 0.01 else Vector3.FORWARD

## Estou na frente do monstro (±BOT_FRONT_ARC_DEG da direção do tanque), perto o bastante para levar o golpe frontal?
static func _in_front(e: SimEntity, mob: SimEntity, tank: SimEntity) -> bool:
	var to := Vector2(e.position.x - mob.position.x, e.position.z - mob.position.z)
	if to.length() > mob.radius + e.radius + Balance.BOT_FRONT_RANGE or to.length() < 0.01:
		return false
	var f3 := _front_dir(mob, tank)
	return absf(Vector2(f3.x, f3.z).angle_to(to)) < deg_to_rad(front_arc(mob))

## Meia-abertura da frente do monstro em graus: BOT_FRONT_ARC_DEG ou, se ele tem golpe em cone mais largo (talho de 150° do
## Durgash), metade do cone + BOT_FRONT_ARC_PAD. Cone de 240°+ é giro (ninguém escapa ficando de lado): não conta.
static func front_arc(mob: SimEntity) -> float:
	var arc := Balance.BOT_FRONT_ARC_DEG
	for s in mob.skills:
		if s and s.target == SkillDef.Target.CONE and s.cone_angle_deg < 240.0:
			arc = maxf(arc, s.cone_angle_deg * 0.5 + Balance.BOT_FRONT_ARC_PAD)
	return minf(arc, Balance.BOT_FRONT_ARC_MAX)

## Lugar do papel com o tanque segurando o monstro: perto = costas (espalhados por id); longe = flanco de trás a
## BOT_RANGED_DIST m; quem cura fica a até BOT_HEALER_LEASH m do tanque.
func _role_spot(e: SimEntity, sim, mob: SimEntity, melee: bool, reach: float, tank: SimEntity) -> Vector3:
	var spot := _role_spot_raw(e, sim, mob, melee, reach, tank)
	var m: Dictionary = sim.maps.get(e.map_id, {})
	if m.is_empty() or _pool_free(m, spot, e.radius + Balance.BOT_DODGE_PAD, true):
		return spot
	var out := _free_near(m, spot, e.radius + Balance.BOT_DODGE_PAD, 6.0, true)      # lugar caiu numa poça: o ponto livre mais perto dele
	return out if out != Vector3.INF else spot

## Fora de toda poça que fica (hazard `landed`: círculo, faixa, marca) e (sem `landed_only`) de todo círculo ainda por cair, com folga `pad`.
static func _pool_free(m: Dictionary, p: Vector3, pad: float, landed_only: bool = false) -> bool:
	for h in m.get("hazards", []):
		var landed: bool = h.get("landed", false)
		if (not landed and (str(h.get("shape", "circle")) != "circle" or h.get("mark", false))) or h.get("invert", false):
			continue                             # faixa/marca que já caiu e ficou também é poça
		if landed_only and not landed:
			continue
		if BossSignatures.inside(h, p, pad):
			return false
	return true

## Ponto livre (_pool_free) mais perto de `p`: 16 direções em passos de 0,75 m até `maxd`. INF = nenhum.
static func _free_near(m: Dictionary, p: Vector3, pad: float, maxd: float, landed_only: bool = false) -> Vector3:
	var d := 0.75
	while d <= maxd:
		for k in range(16):
			var a := TAU * k / 16.0
			var q := p + Vector3(cos(a), 0, sin(a)) * d
			if _pool_free(m, q, pad, landed_only):
				return q
		d += 0.75
	return Vector3.INF

func _role_spot_raw(e: SimEntity, sim, mob: SimEntity, melee: bool, reach: float, tank: SimEntity) -> Vector3:
	var back := -_front_dir(mob, tank)
	var slot := _slot(e, sim, melee)           # vaga entre os do mesmo jeito (perto/longe) no grupo: raide de 5 sem dois no mesmo lugar
	if melee:
		var ang := 0.0 if slot.y <= 1 else lerpf(-Balance.BOT_BACK_SPREAD, Balance.BOT_BACK_SPREAD, float(slot.x) / float(slot.y - 1))
		return mob.position + back.rotated(Vector3.UP, ang) * (mob.radius + e.radius + reach * 0.6)
	var side := 1.0 if slot.x % 2 == 0 else -1.0
	var d := minf(Balance.BOT_RANGED_DIST, maxf(reach * 0.8, 3.0))
	var ang_r := Balance.BOT_RANGED_SPREAD + float(slot.x / 2) * Balance.BOT_RANGED_SPREAD_STEP
	ang_r = minf(ang_r, PI - deg_to_rad(front_arc(mob)) - 0.1)     # nunca entra na frente do chefe
	var spot := mob.position + back.rotated(Vector3.UP, side * ang_r) * (mob.radius + d)
	if _role(e, sim) == "healer" and spot.distance_to(tank.position) > Balance.BOT_HEALER_LEASH:
		spot = tank.position + (spot - tank.position).limit_length(Balance.BOT_HEALER_LEASH - 1.0)
	return spot

## Dash com evolução que causa dano (DashParams.power > 0): conta como golpe para a abertura/ameaça.
static func _dash_hits(e: SimEntity, sim) -> bool:
	return float(sim.dash_params(e)["power"]) > 0.0

## Abertura (quem não é o tanque): chefe/elite (o alvo ou um a BOT_OPENER_AOE_RANGE m dele: a área no lacaio pega o chefe) que
## ainda não está preso no tanque do grupo há BOT_OPENER_TIME s. Devolve esse monstro (segura skills) ou null (luta normal).
## Sem tanque, tanque longe do monstro ou tanque que não chega em BOT_OPENER_WAIT s: null (não trava o grupo).
func _opener(e: SimEntity, sim, m: Dictionary, mob: SimEntity, tank: SimEntity) -> SimEntity:
	if not opener_enabled or tank == null or tank == e:
		return null
	var big: SimEntity = mob if _is_big(mob) else null
	if big == null:
		var r2 := Balance.BOT_OPENER_AOE_RANGE * Balance.BOT_OPENER_AOE_RANGE
		for o: SimEntity in m["entities"]:
			if o.kind == SimEntity.Kind.MONSTER and o.position.distance_squared_to(mob.position) <= r2 and o.is_alive() and _is_big(o):
				big = o
				break
	if big == null or big.position.distance_to(tank.position) > Balance.PARTY_ASSIST_RANGE:
		return null
	if big.id != opener_id:
		opener_id = big.id
		opener_seen = sim.time
		opener_held = -1.0
	if big.aggro_target == tank.id and float(big.threat.get(tank.id, 0.0)) > 0.0:
		if opener_held < 0.0:
			opener_held = sim.time
	else:
		opener_held = -1.0          # largou o tanque: a abertura recomeça quando ele o pegar de volta
	if opener_held >= 0.0:
		return big if sim.time - opener_held < Balance.BOT_OPENER_TIME else null
	return big if sim.time - opener_seen < Balance.BOT_OPENER_WAIT else null

## Orçamento de ameaça (chefe preso no tanque do grupo: o alvo ou, para área no lacaio, o chefe a BOT_OPENER_AOE_RANGE m dele):
## threat_room = BOT_THREAT_HOLD × ameaça do tanque − a minha (com o dano no tempo pendente). Sem chefe preso: INF.
func _threat_budget(e: SimEntity, m: Dictionary, mob: SimEntity, tank: SimEntity) -> void:
	threat_room = INF
	threat_boss = null
	if tank == null or tank == e:
		return
	var boss: SimEntity = mob if mob.monster_def != null and mob.monster_def.is_boss else null
	if boss == null:
		var r2 := Balance.BOT_OPENER_AOE_RANGE * Balance.BOT_OPENER_AOE_RANGE
		for o: SimEntity in m["entities"]:
			if o.kind == SimEntity.Kind.MONSTER and o.position.distance_squared_to(mob.position) <= r2 and o.monster_def != null and o.monster_def.is_boss and o.is_alive():
				boss = o
				break
	if boss == null or boss.aggro_target != tank.id:
		return
	threat_boss = boss
	threat_room = float(boss.threat.get(tank.id, 0.0)) * Balance.BOT_THREAT_HOLD - float(boss.threat.get(e.id, 0.0)) - _pending_threat(e, boss)

## Ameaça que o dano no tempo deste bot ainda vai dar no monstro (queimadura, sangramento, praga).
static func _pending_threat(e: SimEntity, mob: SimEntity) -> float:
	var left := 0.0
	for d in mob.debuffs:
		if d.get("kind") == "dot" and int(d.get("src", -1)) == e.id:
			left += float(d.get("dps", 0.0)) * maxf(0.0, float(d.get("remaining", 0.0))) + float(d.get("acc", 0.0))
	return left * (1.0 + e.stats.threat_pct / 100.0)

## Ameaça estimada de uma skill num alvo (golpe + dano no tempo, crítico médio, talento ferido/execução e marcas no alvo): o
## bastante para saber se um golpe só passa o tanque. Skill sem dano: 0. `crit_hit` (básico, que sai muitas vezes): com
## crítico a partir de Balance.BOT_THREAT_CRIT_CHANCE %, conta o golpe crítico no teto da variação, não o crítico médio.
static func _skill_threat(e: SimEntity, s: SkillDef, mob: SimEntity, crit_hit := false) -> float:
	var total := 0.0
	if s.power > 0.0 and s.kind in [SkillDef.Kind.PHYSICAL, SkillDef.Kind.MAGICAL]:
		var magical := s.kind == SkillDef.Kind.MAGICAL
		var atk: float = e.stats.matk if magical else e.stats.patk
		var def: float = mob.stats.mdef if magical else mob.stats.pdef
		var crit: float = (e.stats.crit_mag if magical else e.stats.crit_phys) / 100.0
		var cm := 1.0 + clampf(crit, 0.0, 1.0) * (Balance.CRIT_MULT - 1.0)
		if crit_hit and crit * 100.0 >= Balance.BOT_THREAT_CRIT_CHANCE:
			cm = Balance.CRIT_MULT * (1.0 + Balance.DMG_VARIANCE)
		total = maxf(atk * s.power - def * Balance.DEF_FACTOR, atk * s.power * 0.15) * cm
		total *= ClassTalentSystem.damage_mult(e, mob)          # ferido / execução (o golpe de verdade leva)
		if not mob.debuffs.is_empty():
			total *= 1.0 + Combat.taken_pct(mob) / 100.0       # marcas no alvo
	var d = s.effects.get("dot")
	if d is Dictionary:
		if d.has("atk_pct"):
			total += e.stats.patk * float(d["atk_pct"]) / 100.0 * float(d.get("duration", Balance.BLEED_TIME_DEFAULT))
		else:
			total += float(d.get("dps", 5)) * (e.stats.matk / 20.0) * float(d.get("duration", 4))
	return total * (1.0 + e.stats.threat_pct / 100.0)

## Ameaça da magia-assinatura que o básico pode lançar junto (Golpe Avassalador do Executor: 17% no nível 39, 0,6 × o poder):
## com chance a partir de Balance.BOT_THREAT_CRIT_CHANCE % e fora da recarga dela, conta como certa (o básico sai muitas vezes).
static func _signature_threat(e: SimEntity, sim, mob: SimEntity) -> float:
	if not sim.signatures_on or not e.is_character() or e.class_def == null or sim.time < e.sig_ready_at:
		return 0.0
	var sid := LegendEffects.signature_skill(e)
	var sk: SkillDef = GameData.skills.get(sid) if sid != "" else null
	if sk == null or LegendEffects.signature_chance(e, true, sid) < Balance.BOT_THREAT_CRIT_CHANCE:
		return 0.0
	return _skill_threat(e, sk, mob) * Balance.SIGNATURE_POWER * float(Balance.SIGNATURE_BUILD_POWER.get(LegendEffects.signature_build(e), 1.0))

## Buff só em si, sem dano nem provocação/invocação/aura (forma, Sede de Sangue): não gera ameaça no chefe.
static func _self_buff(s: SkillDef) -> bool:
	if s.target != SkillDef.Target.SELF or s.power > 0.0:
		return false
	for k in ["taunt", "summon", "aura", "dot", "stun", "slow", "root"]:
		if s.effects.has(k):
			return false
	return s.effects.has("buff") or s.effects.has("shield")

## Tanque: chefe/elite por perto que largou dele e está batendo em outro do grupo (vai buscar; _taunt_party provoca).
func _loose_big(e: SimEntity, sim, m: Dictionary, members: Array) -> SimEntity:
	if _role(e, sim) != "tank":
		return null
	var ids := {}
	for o in members:
		ids[o.id] = true
	for o: SimEntity in m["entities"]:
		if o.kind != SimEntity.Kind.MONSTER or not o.is_alive() or o.position.distance_to(e.position) > Balance.PARTY_ASSIST_RANGE:
			continue
		if _is_big(o) and o.aggro_target >= 0 and o.aggro_target != e.id and ids.has(o.aggro_target):
			return o
	return null

## Dps de perto: lacaio batendo em quem cura/luta de longe (a até BOT_PEEL_RANGE m dele) que nenhum outro do grupo já pegou.
func _peel_target(e: SimEntity, sim, m: Dictionary, members: Array) -> SimEntity:
	if _role(e, sim) != "dps" or (e.class_def and e.class_def.basic_attack_is_ranged):
		return null
	var soft := {}
	for o in members:
		if o != e and o.map_id == e.map_id and sim.role_of(o) in ["healer", "ranged", "caster"]:
			soft[o.id] = o
	if soft.is_empty():
		return null
	for o: SimEntity in m["entities"]:
		if o.kind != SimEntity.Kind.MONSTER or not o.is_alive() or _is_big(o) or not soft.has(o.aggro_target):
			continue
		if o.position.distance_to((soft[o.aggro_target] as SimEntity).position) > Balance.BOT_PEEL_RANGE:
			continue
		if o.id == hunt_target_id or not members.any(func(x): return x != e and x.brain is BotBrain and x.brain.hunt_target_id == o.id):
			return o
	return null

## Vaga de `e` entre os membros vivos (fora o tanque) do mesmo jeito de lutar (perto = true): Vector2i(índice, quantos).
func _slot(e: SimEntity, sim, melee: bool) -> Vector2i:
	var i := 0
	var n := 0
	for o in sim.party_members(e):
		if o.map_id != e.map_id or not o.is_alive() or sim.role_of(o) == "tank":
			continue
		var om: bool = o.class_def == null or not o.class_def.basic_attack_is_ranged or (o.basic_skill != null and o.basic_skill.target == SkillDef.Target.CONE)
		if om != melee:
			continue
		if o == e:
			i = n
		n += 1
	return Vector2i(i, maxi(n, 1))

## Tanque de raide (BOT_TANK_TURN_MIN+ vivos no grupo): onde ficar para o chefe ficar de costas para o grupo, quando o meio do
## grupo está dentro da frente dele (front_arc). Vector3.INF = o grupo já está fora da frente.
func _turn_spot(e: SimEntity, sim, mob: SimEntity, reach: float) -> Vector3:
	var c := Vector3.ZERO
	var n := 0
	for o in sim.party_members(e):
		if o != e and o.is_alive() and o.map_id == e.map_id and o.position.distance_to(mob.position) < Balance.BOT_GROUP_CENTROID:
			c += o.position
			n += 1
	if n + 1 < Balance.BOT_TANK_TURN_MIN:
		return Vector3.INF
	c /= float(n)
	var to_c := Vector2(c.x - mob.position.x, c.z - mob.position.z)
	var f3 := _front_dir(mob, e)
	if to_c.length() < 0.5 or absf(Vector2(f3.x, f3.z).angle_to(to_c)) >= deg_to_rad(front_arc(mob)):
		return Vector3.INF
	var away := -Vector3(to_c.x, 0.0, to_c.y).normalized()
	return mob.position + away * (mob.radius + e.radius + reach * 0.7)

## Lacaio de `ward` (raide, GDD kharzun §4): o alvo é um chefe (ou lacaio dele) com o escudo dos lacaios ligado. Quem não é
## tanque nem cura vai no lacaio vivo do chefe a até BOT_WARD_RANGE m: estandarte (lacaio parado) primeiro, o mais perto.
## null = segue no alvo (sem grupo, sem ward, ou já num lacaio do mesmo tipo).
func _ward_add(e: SimEntity, sim, m: Dictionary, mob: SimEntity) -> SimEntity:
	if e.party_id < 0 or mob.monster_def == null:
		return null
	var boss: SimEntity = mob if mob.monster_def.is_boss else sim.entities.get(mob.boss_id)
	if boss == null or not boss.is_alive() or boss.ward <= 0.0 or _role(e, sim) in ["tank", "healer"]:
		return null
	var best: SimEntity = null
	var best_v := INF
	var r2 := Balance.BOT_WARD_RANGE * Balance.BOT_WARD_RANGE
	for o: SimEntity in m["entities"]:
		if o.boss_id != boss.id or o.kind != SimEntity.Kind.MONSTER or not o.is_alive() or o.stealth_left > 0.0:
			continue
		var d2: float = o.position.distance_squared_to(e.position)
		if d2 > r2:
			continue
		var v := d2 + (0.0 if is_banner(o) else 10000.0)       # estandarte antes de qualquer lacaio que anda
		if v < best_v:
			best_v = v
			best = o
	if best == null or best == mob or (mob != boss and is_banner(mob) == is_banner(best)):
		return null                          # já num lacaio do mesmo tipo: não fica trocando
	return best

## Lacaio parado (Estandarte de Clã): velocidade 0.
static func is_banner(o: SimEntity) -> bool:
	return o.monster_def != null and o.monster_def.move_speed <= 0.0

## Chefe/elite (sem provocação valendo) a até BOT_GUARD_SOFT m de quem cura no grupo, ou mirando nele uma skill de mob_pick
## (faca, Passo nas Costas do Matador): o tanque provoca de novo (_taunt_party).
static func soft_in_danger(o: SimEntity, members: Array) -> bool:
	if not _is_big(o) or o.taunt_left > 0.0:
		return false
	var aim_soft: bool = o.state == SimEntity.State.CASTING and o.current_skill != null and o.current_skill.mob_pick != ""
	for x in members:
		if x.id == o.aggro_target or not x.is_alive() or x.map_id != o.map_id or MobSystem.role_of(x) != "healer":
			continue
		if o.position.distance_to(x.position) < Balance.BOT_GUARD_SOFT + o.radius:
			return true
		if aim_soft and Vector2(o.skill_aim.x - x.position.x, o.skill_aim.z - x.position.z).length() < Balance.BOT_SOFT_AIM:
			return true
	return false

## Quem cura: chefe com golpe curto que escolhe quem cura (soft_striker: Golpe de Misericórdia) a menos de BOT_HEALER_EVADE m
## e sem me ter por alvo -> sai para longe dele (um passo; o tanque o leva de volta). true = andou.
func _evade_boss(e: SimEntity, sim, m: Dictionary, cmd: InputCommand) -> bool:
	if e.party_id < 0 or not e.can_act() or _role(e, sim) != "healer":
		return false
	for o: SimEntity in m["entities"]:
		if o.kind != SimEntity.Kind.MONSTER or o.monster_def == null or not o.monster_def.is_boss or o.aggro_target == e.id or o.aggro_target < 0:
			continue
		var to := Vector2(e.position.x - o.position.x, e.position.z - o.position.z)
		if to.length() > Balance.BOT_HEALER_EVADE + o.radius + e.radius or not o.is_alive() or not soft_striker(o):
			continue
		var dir := to.normalized() if to.length() > 0.05 else Vector2.RIGHT
		cmd.move = dir
		cmd.aim = e.position + Vector3(dir.x, 0.0, dir.y) * 3.0
		engaged = false
		return true
	return false

## O chefe tem golpe curto que escolhe quem cura (mob_pick "soft", alcance até BOT_HEALER_EVADE m)?
static func soft_striker(o: SimEntity) -> bool:
	for s in o.skills:
		if s and s.mob_pick == "soft" and s.target == SkillDef.Target.TARGET and s.range <= Balance.BOT_HEALER_EVADE:
			return true
	return false
