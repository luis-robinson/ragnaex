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
			if _heal_party(e, sim, members, cmd, dt) or _taunt_party(e, m, members, cmd):
				return cmd
			var loose := _loose_big(e, sim, m, members)
			if loose:
				return _fight(e, sim, m, loose, cmd)

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
	if threat != null and not in_town and state != S.RETURN:
		return _fight(e, sim, m, threat, cmd)

	match state:
		S.TOWN_IDLE:
			if timer <= 0.0:
				if rng.randf() < 0.45 + personality * 0.3 and e.hp > e.stats.max_hp * 0.8:
					_plan_trip(e, sim)
				else:
					state = S.TOWN_WALK
					if def.bot_hangouts.size() > 0:
						target_pos = def.bot_hangouts[rng.randi() % def.bot_hangouts.size()] + Vector3(rng.randf_range(-1.5, 1.5), 0, rng.randf_range(-1.5, 1.5))
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
				return cmd
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
				_go_home()
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
		S.RETURN:
			if in_town:
				state = S.SHOP
				timer = rng.randf_range(4.0, 9.0)
				var npc := _find_npc(def, "merchant")
				target_pos = npc.get("pos", Vector3.ZERO) + Vector3(0, 0, 1.6)
			elif def.is_town:
				cmd.move = _steer(e, def.town_center, dt)      # mesma zona: volta pela estrada até a praça
				cmd.aim = def.town_center
			elif e.recall_left > 0.0:
				cmd.move = Vector2.ZERO                         # conjurando a volta (G): parado, sem agir
			elif recall_retry <= 0.0 and PortalSystem.recall_blocked(sim, e) == "":
				cmd.recall = true                               # volta como o jogador; dano interrompe
				cmd.move = Vector2.ZERO
				recall_retry = Balance.BOT_RECALL_RETRY
			else:
				var portal := _find_portal(def, GameData.town_map_id())
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
func _fight(e: SimEntity, sim, m: Dictionary, mob: SimEntity, cmd: InputCommand) -> InputCommand:
	if mob.id != hunt_target_id:
		engaged = false
	hunt_target_id = mob.id
	cmd.aim = mob.position
	var dist := e.position.distance_to(mob.position) - mob.radius - e.radius
	var cls := e.class_def
	var melee: bool = cls == null or not cls.basic_attack_is_ranged or (e.basic_skill != null and e.basic_skill.target == SkillDef.Target.CONE)     # lança do Ranger: básico em cone = corpo a corpo
	# perigo: área telegrafada de monstro (chão, em volta dele, cone, linha) → sai dela (com dash se der)
	var away := _danger_escape(e, m, e.party_id >= 0 and _role(e, sim) == "tank")
	if away != Vector2.ZERO:
		cmd.move = away
		cmd.aim = e.position + Vector3(away.x, 0, away.y) * 3.0
		if e.dash_cd <= 0.0 and rng.randf() < 0.6:
			cmd.dash = true
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
			if s and s.kind == SkillDef.Kind.HEAL and e.level >= s.unlock_level and e.stats.meets(s.requires) and _ready_to_cast(e, s):
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
		cmd.move = _steer(e, spot, 0.0)
		return cmd
	stealth_peak = 0.0
	# Corpo a corpo é um cone: o alcance do básico é o raio dele (não o "range", que no cone não vale).
	var basic_reach := 1.8
	if e.basic_skill:
		basic_reach = e.basic_skill.radius if e.basic_skill.target == SkillDef.Target.CONE else e.basic_skill.range
	# grupo contra chefe/elite preso no tanque: cada um no seu lugar (fora da frente dele) e de olho na ameaça
	var tank := _tank_of(e, sim)
	var held: bool = tank != null and tank != e and mob.aggro_target == tank.id and _is_big(mob)
	var hold_skills := false
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
		var mine := float(mob.threat.get(e.id, 0.0))
		var theirs := float(mob.threat.get(tank.id, 0.0))
		if mob.monster_def.is_boss and mine >= theirs * Balance.BOT_THREAT_STOP:
			cmd.move = Vector2.ZERO           # passou o tanque: espera ele abrir distância (senão o chefe vira)
			return cmd
		hold_skills = mob.monster_def.is_boss and mine >= theirs * Balance.BOT_THREAT_HOLD
	# skill: a melhor disponível (buff que não está ativo, área quando há vários, a mais forte no resto)
	var pick := -1 if hold_skills else _best_skill(e, sim, m, mob, dist)
	if pick >= 0:
		cmd.skill_slot = pick
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
		if e.basic_cd <= 0.0:
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
		if dist > 5.0 and dist < 9.0 and e.dash_cd <= 0.0 and rng.randf() < 0.12:
			cmd.dash = true
	cmd.move = _steer(e, spot, 0.0)
	return cmd

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
		# a sim recusaria (try_cast): sem companheiro para mandar, ou invocações no limite. Escolher assim travava o
		# bot inteiro (pedia a mesma skill todo tick e nunca atacava nem andava: Caçador com o lince morto).
		if (s.effects.has("pet_command") or s.effects.get("pet_buff", false)) and sim.pet_of(e) == null:
			continue
		if s.effects.has("summon") and sim._summons_full(e, s):
			continue
		if (s.effects.has("aura") and AuraSystem.aura_on(e, s)) or (str(s.effects.get("form", "")) != "" and e.form == str(s.effects["form"])):
			continue                        # aura ligada / já na forma: bot não desliga
		if e.is_character() and not e.knows(s.id):
			continue
		if s.effects.has("channel") and mob.monster_def and mob.monster_def.is_boss and mob.aggro_target == e.id:
			continue                        # canalizar parado com o chefe em cima = morrer (Pestilento solo: 2/40)
		if e.stealth_left > 0.0 and not (s.kind in [SkillDef.Kind.PHYSICAL, SkillDef.Kind.MAGICAL]):
			continue                        # na sombra: só golpe (o resto quebraria a furtividade sem o bônus)
		var score := 0.0
		if s.effects.has("stealth"):
			if e.stealth_left > 0.0 or dist > Balance.BOT_STEALTH_RANGE or (s.requires_form != "" and e.form != s.requires_form):
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
					for o in m["entities"]:
						if o.kind == SimEntity.Kind.MONSTER and o.is_alive() and o.position.distance_to(e.position) <= 4.0:
							near += 1
				score *= 0.8 + 0.45 * maxi(0, near - 1)
			if mob.hp < mob.stats.max_hp * 0.35:
				score *= 1.15
		score *= rng.randf_range(0.85, 1.15)
		if score > best_score:
			best_score = score
			best = i
	return best

## Para onde sair de uma área de golpe de monstro que está começando (Vector2.ZERO = seguro).
## Tanque (`tank`): não foge do golpe de frente/em volta do monstro que está segurando (ele viria atrás e o grupo
## inteiro teria de se mexer): bloqueia e aguenta. Círculos no chão e golpes de outros monstros ele evita como todos.
func _danger_escape(e: SimEntity, m: Dictionary, tank: bool = false) -> Vector2:
	for h in m.get("hazards", []):           # círculos de chefe (barrage) já marcados no chão
		var hp: Vector3 = h["pos"]
		var hc := Vector2(hp.x, hp.z)
		var mine := Vector2(e.position.x, e.position.z)
		if mine.distance_to(hc) < float(h["radius"]) + e.radius + Balance.BOT_DODGE_PAD:
			return (mine - hc).normalized() if mine.distance_to(hc) > 0.05 else Vector2.RIGHT
	for o in m["entities"]:
		if o.state != SimEntity.State.CASTING or o.kind != SimEntity.Kind.MONSTER or o.current_skill == null:       # o barato primeiro
			continue
		if o.skill_phase != "startup" or o.position.distance_to(e.position) > 14.0:
			continue
		var s: SkillDef = o.current_skill
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

func _pick_monster(e: SimEntity, m: Dictionary) -> SimEntity:
	var best: SimEntity = null
	var best_score := INF
	for o in m["entities"]:
		if o.kind != SimEntity.Kind.MONSTER or not o.is_alive():
			continue
		if o.monster_def.is_boss and e.level < o.level + 2 and personality < 0.7:
			continue
		var d: float = o.position.distance_to(e.position)
		if d > 18.0:
			continue
		var score: float = d + absf(o.level - e.level) * 1.5
		if o.aggro_target >= 0 and o.aggro_target != e.id:
			score += 6.0   # evita roubar monstro de outro
		if score < best_score:
			best_score = score
			best = o
	return best

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
	timer = 60.0
	if rng.randf() < 0.3:
		Events.post(&"chat_message", e.name, GameData.random_bot_line("leaving") % GameData.maps[dest_map].name, "global")
	_gather_party(e, sim)

func _go_home() -> void:
	state = S.RETURN
	dest_map = GameData.town_map_id()
	timer = 90.0

func _find_portal(def: MapDef, target_map: String) -> Dictionary:
	for p in def.portals:
		if p["target_map"] == target_map:
			return p
	# fallback: qualquer portal
	return def.portals[0] if def.portals.size() > 0 else {}

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
		if it and it.type == ItemDef.Type.MATERIAL and it.price > 0:      # moeda lendária não se vende
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

## Ponto intermediário para entrar/sair da vila murada pelo portão mais conveniente.
func _route(e: SimEntity, p: Vector3) -> Vector3:
	if cur_def == null or cur_def.town_radius <= 0.0 or cur_def.town_gates.is_empty():
		return p
	var inside := cur_def.in_town(e.position)
	if inside == cur_def.in_town(p):
		return p
	var c := cur_def.town_center
	var gate: Vector3 = cur_def.town_gates[0]
	var best := INF
	for g in cur_def.town_gates:
		var cost: float = e.position.distance_to(g) + p.distance_to(g)
		if cost < best:
			best = cost
			gate = g
	var dir := (gate - c).normalized()
	var r := cur_def.town_radius
	var inner := c + dir * (r - 5.0)
	var outer := c + dir * (r + 5.0)
	var from_c := e.position.distance_to(c)
	if inside:
		# sai: primeiro até a rua do portão, depois atravessa
		return inner if from_c < r - 5.5 and e.position.distance_to(inner) > 2.5 else outer
	return outer if from_c > r + 3.5 and e.position.distance_to(outer) > 2.5 else inner

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
	p = _route(e, p)
	if cur_sim:
		p = _water_step(e, p, dt)
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
			if absi(o.level - e.level) > 5 or o.position.distance_to(e.position) > 30.0 or not cur_def.in_town(o.position):
				continue
			if o.brain and o.brain.state in [S.TOWN_IDLE, S.TOWN_WALK] and sim.party_invite(e, o):
				wanted -= 1
	var pl: SimEntity = sim.player
	if pl and pl.map_id == e.map_id and pl.party_id < 0 and sim.time >= next_player_invite and pl.is_alive() \
			and absi(pl.level - e.level) <= 5 and pl.position.distance_to(e.position) < 25.0 and rng.randf() < Balance.BOT_INVITE_PLAYER_CHANCE:
		next_player_invite = sim.time + PLAYER_INVITE_COOLDOWN
		if sim.party_invite(e, pl):
			Events.post(&"chat_message", e.name, "bora caçar na %s? te mandei convite" % GameData.maps[dest_map].name, "whisper")

func _party_has_player(e: SimEntity, sim) -> bool:
	return sim.player != null and sim.same_party(e, sim.player)

## Seguidor: vai até o mapa do líder, cura quem precisa, ajuda no combate e anda em formação atrás dele.
func _follow(e: SimEntity, sim, m: Dictionary, leader: SimEntity, cmd: InputCommand, dt: float) -> InputCommand:
	var def: MapDef = m["def"]
	var in_town := def.in_town(e.position)
	state = S.TOWN_IDLE if in_town else S.HUNT     # se sair do grupo, continua de onde está
	timer = 30.0
	if leader.map_id != e.map_id:
		var portal := PortalSystem.portal_towards(def, leader.map_id)
		if not portal.is_empty():
			cmd.move = _steer(e, portal["pos"], dt)
			cmd.aim = portal["pos"]
		return cmd
	var members: Array = sim.party_members(e)
	if _heal_party(e, sim, members, cmd, dt):
		return cmd
	var foe := _loose_big(e, sim, m, members) if not in_town else null      # tanque: chefe que largou dele
	if foe == null and not in_town:
		foe = _peel_target(e, sim, m, members)                                 # dps de perto: lacaio em cima de quem cura/atira
	if foe == null:
		foe = _sticky(e, m, Balance.BOT_STICKY_RANGE)
	if foe and foe.position.distance_to(leader.position) > Balance.PARTY_ASSIST_RANGE * 1.6:
		foe = null                       # o líder foi embora: larga e acompanha
	if foe == null:
		foe = _party_threat(e, m, members, leader)
	if foe and not in_town:
		if _taunt_party(e, m, members, cmd):
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

## Tanque: provoca quando há monstro por perto batendo em outro membro do grupo.
func _taunt_party(e: SimEntity, m: Dictionary, members: Array, cmd: InputCommand) -> bool:
	if not e.can_act():
		return false
	for i in range(e.skills.size()):
		var s := e.skills[i]
		if s == null or not s.effects.has("taunt") or e.level < s.unlock_level or not e.stats.meets(s.requires):
			continue
		if not _ready_to_cast(e, s):
			continue
		for o in m["entities"]:
			if o.kind != SimEntity.Kind.MONSTER or not o.is_alive() or o.aggro_target < 0 or o.aggro_target == e.id:
				continue
			if o.position.distance_to(e.position) <= s.radius and members.any(func(x): return x.id == o.aggro_target):
				cmd.skill_slot = i
				cmd.aim = o.position
				return true
	return false

## Cura o membro mais ferido (< 60% HP) com a primeira skill de cura pronta; anda até ele se precisar.
func _heal_party(e: SimEntity, sim, members: Array, cmd: InputCommand, dt: float) -> bool:
	if not e.can_act():
		return false
	var hurt: SimEntity = null
	var worst := Balance.BOT_HEAL_HP
	var tank := _tank_of(e, sim)
	for o in members:
		if o.map_id != e.map_id or not o.is_alive() or o.position.distance_to(e.position) > Balance.BOT_HEAL_RANGE:
			continue
		var r: float = o.hp / maxf(1.0, o.stats.max_hp)
		if o == tank and r < Balance.BOT_HEAL_TANK_HP:
			hurt = o                     # o tanque vem primeiro (segura o chefe; cai e o grupo cai junto)
			break
		if r < worst:
			worst = r
			hurt = o
	if hurt == null:
		return false
	for i in range(e.skills.size()):
		var base := e.skills[i]
		if base == null or base.kind != SkillDef.Kind.HEAL or e.level < base.unlock_level or not e.stats.meets(base.requires):
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
	var best_d := Balance.PARTY_ASSIST_RANGE
	for o in m["entities"]:
		if o.kind != SimEntity.Kind.MONSTER or not o.is_alive():
			continue
		var d: float = o.position.distance_to(leader.position)
		if d > best_d:
			continue
		var hits_us: bool = ids.has(o.aggro_target) or ids.has(o.last_damage_from) or o.damage_by.has(leader.id)
		if hits_us or (leader.combat_timer > 0.0 and d < 8.0 and o.aggro_target >= 0):     # líder brigando: ajuda no que estiver perto dele
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
	return absf(Vector2(f3.x, f3.z).angle_to(to)) < deg_to_rad(Balance.BOT_FRONT_ARC_DEG)

## Lugar do papel com o tanque segurando o monstro: perto = costas (espalhados por id); longe = flanco de trás a
## BOT_RANGED_DIST m; quem cura fica a até BOT_HEALER_LEASH m do tanque.
func _role_spot(e: SimEntity, sim, mob: SimEntity, melee: bool, reach: float, tank: SimEntity) -> Vector3:
	var back := -_front_dir(mob, tank)
	if melee:
		var ang := (float(e.id % 3) - 1.0) * Balance.BOT_BACK_SPREAD
		return mob.position + back.rotated(Vector3.UP, ang) * (mob.radius + e.radius + reach * 0.6)
	var side := 1.0 if e.id % 2 == 0 else -1.0
	var d := minf(Balance.BOT_RANGED_DIST, maxf(reach * 0.8, 3.0))
	var spot := mob.position + back.rotated(Vector3.UP, side * Balance.BOT_RANGED_SPREAD) * (mob.radius + d)
	if _role(e, sim) == "healer" and spot.distance_to(tank.position) > Balance.BOT_HEALER_LEASH:
		spot = tank.position + (spot - tank.position).limit_length(Balance.BOT_HEALER_LEASH - 1.0)
	return spot

## Tanque: chefe/elite por perto que largou dele e está batendo em outro do grupo (vai buscar; _taunt_party provoca).
func _loose_big(e: SimEntity, sim, m: Dictionary, members: Array) -> SimEntity:
	if _role(e, sim) != "tank":
		return null
	var ids := {}
	for o in members:
		ids[o.id] = true
	for o in m["entities"]:
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
	for o in m["entities"]:
		if o.kind != SimEntity.Kind.MONSTER or not o.is_alive() or _is_big(o) or not soft.has(o.aggro_target):
			continue
		if o.position.distance_to((soft[o.aggro_target] as SimEntity).position) > Balance.BOT_PEEL_RANGE:
			continue
		if o.id == hunt_target_id or not members.any(func(x): return x != e and x.brain is BotBrain and x.brain.hunt_target_id == o.id):
			return o
	return null
