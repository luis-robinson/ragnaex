class_name MonsterBrain
extends RefCounted
## IA de monstro (e de invocações): idle → wander → chase → attack → leash.
## Produz InputCommand igual a um jogador.

enum S { IDLE, WANDER, CHASE, RETURN }
const SKILL_GAP := 2.0      # s mínimos entre skills de um monstro
const RETURN_LIMIT := 15.0  # s voltando para casa; preso em obstáculo reaparece lá

var state: S = S.IDLE
var timer: float = 0.0
var wander_target: Vector3 = Vector3.ZERO
var skill_timer: float = 0.0
var return_time: float = 0.0
# investida (RaidSystem): marcha pela rota
var calm: float = 0.0          # s sem puxar briga nova (acabou de largar um alvo longe da rota)
var was_retreat := false
var fought := false
var water_path: Array = []
var water_goal := Vector3.INF
var water_timer: float = 0.0
var last_pos := Vector3.ZERO
var stuck: float = 0.0
var detour := Vector2.ZERO
var detour_left: float = 0.0
# atirador cujo tiro não chega (obstáculo no meio): chega mais perto um tempo
var shot_target := -1
var shot_hp := 0.0
var no_hit: float = 0.0
var close_in: float = 0.0
var skill_rethink: float = 0.0   # invocação: s até reescolher o alvo
const NO_HIT_LIMIT := 3.0
const RAID_RETHINK := 1.2
const CLOSE_IN_TIME := 2.0

func think(e: SimEntity, sim, m: Dictionary, dt: float) -> InputCommand:
	var cmd := InputCommand.new()
	cmd.aim = e.position + e.forward()      # sem alvo: mantém o rumo (padrão do comando é a origem do mundo)
	timer -= dt
	skill_timer -= dt
	calm -= dt
	var raider := e.raid_id >= 0
	var def: MapDef = m["def"]
	var mdef := e.monster_def
	var is_summon := e.kind == SimEntity.Kind.SUMMON
	var owner: SimEntity = sim.entities.get(e.owner_id) if is_summon else null
	# troca de arma com pouca vida (batedor élfico: guarda a espada, puxa o arco)
	if not mdef.swap.is_empty() and e.stance == "" and e.hp < e.stats.max_hp * float(mdef.swap.get("hp", 0.4)):
		var as_def: MonsterDef = GameData.monsters.get(str(mdef.swap.get("as", "")))
		if as_def:
			e.stance = str(mdef.swap.get("stance", "bow"))
			e.basic_skill = GameData.basic_skill_for_monster(as_def)
			e.basic_cd = 0.6                      # tempo de trocar de arma
	var style := _style_def(e)             # de quem vêm alcance e tiro (o próprio monstro ou a arma trocada)
	var ranged := style.ranged
	var atk_range := style.attack_range

	# --- escolher alvo ---
	var target: SimEntity = null
	if state == S.RETURN and not is_summon:
		e.aggro_target = -1          # voltando: só chega em casa, senão fica indo e vindo no limite do leash
	if e.aggro_target >= 0:
		target = sim.entities.get(e.aggro_target)
		if target and (not target.is_alive() or target.map_id != e.map_id or (target.stealth_left > 0.0 and e.taunt_left <= 0.0)):
			target = null
			e.aggro_target = -1
			e.taunt_left = 0.0
	var leader: SimEntity = sim.entities.get(e.leader_id) if e.leader_id >= 0 else null
	if leader and (not leader.is_alive() or leader.map_id != e.map_id):
		leader = null
	if leader and target == null and leader.aggro_target >= 0 and state != S.RETURN:      # escolta entra na briga do líder
		var lt: SimEntity = sim.entities.get(leader.aggro_target)
		if lt and lt.is_alive() and lt.map_id == e.map_id:
			target = lt
			e.aggro_target = lt.id
			e.aggro_timer = Balance.AGGRO_LOSE_TIME
	if is_summon and owner:
		target = _summon_target(e, sim, m, owner, target, dt)
	elif raider and not (calm > 0.0) and e.taunt_left <= 0.0:
		target = _raid_target(e, sim, m, target, dt)
	elif target == null and state != S.RETURN and not (raider and calm > 0.0):
		target = Combat.nearest_hostile(e, m.get("chars", m["entities"]), mdef.aggro_range)     # só personagens e invocações (lista do tick)
		if target:
			e.aggro_target = target.id
			e.aggro_timer = Balance.AGGRO_LOSE_TIME
	# invocação volta pro dono se ele se afastar
	if is_summon and owner and target == null:
		var d := owner.position.distance_to(e.position)
		if d > 3.0:
			cmd.move = _dir_to(e, owner.position + Vector3(0.8, 0, 0.8))
			cmd.aim = owner.position
			return cmd
		cmd.aim = e.position + e.forward()
		return cmd

	# invasor ferido e sozinho: recua pela rota até achar a leva (calma: não puxa briga nova)
	if raider and target != null and e.hp < e.stats.max_hp * Balance.RAID_FLEE_HP and _alone(e, m, 8.0):
		e.aggro_target = -1
		target = null
		calm = 3.0
		var back: Vector3 = (RaidSystem.route_def(def, e.raid_route).get("from", e.position) as Vector3)
		cmd.move = _steer(e, sim, back, dt)
		cmd.aim = back
		return cmd

	# --- leash: longe demais de casa ---
	if raider and target != null and e.position.distance_to(e.home_position) > mdef.leash_range:
		e.aggro_target = -1             # investida: larga quem foge e volta para a rota (sem teleporte para casa)
		e.taunt_left = 0.0
		target = null
		calm = 4.0
	elif not is_summon and not raider and e.position.distance_to(e.home_position) > mdef.leash_range:
		state = S.RETURN
		e.aggro_target = -1
		e.taunt_left = 0.0
		target = null

	if target != null:
		state = S.CHASE
		fought = true
		var dist := e.position.distance_to(target.position) - target.radius    # o acerto mede do centro de quem bate até a borda do alvo
		cmd.aim = target.position
		# skill especial? As últimas da lista são as mais novas (fases de chefe)
		if skill_timer <= 0.0 and e.can_act():
			for i in range(e.skills.size() - 1, -1, -1):
				var s: SkillDef = e.skills[i]
				var reach_s: float = s.radius - 0.3 if s.target == SkillDef.Target.SELF else maxf(s.range, s.radius) + (0.0 if s.effects.has("dash") else 0.5)
				if float(e.cooldowns.get(s.id, 0.0)) <= 0.0 and dist <= reach_s and (not s.is_charge() or sim.charge_lands(e, s, target, m)):
					cmd.skill_slot = i
					skill_timer = minf(s.cooldown + 1.0, SKILL_GAP / (Balance.RAID_SMART if raider else 1.0))
					return cmd
		var reach := atk_range if not is_summon or ranged else 1.5
		if ranged and _shots_blocked(e, target, dt) and dist > 1.5:
			cmd.move = _steer(e, sim, target.position, dt)
			return cmd
		if dist <= reach * 0.85:
			if e.basic_cd <= 0.0 and e.can_act():
				cmd.attack = true
			elif ranged and dist < reach * 0.5 and (e.position.distance_to(e.home_position) < mdef.leash_range * 0.7 or (is_summon and owner and e.position.distance_to(owner.position) < Balance.SUMMON_LEASH * 0.7)):
				var away := -_dir_to(e, target.position)      # recua entre os tiros (invocação: medido do dono, não de onde nasceu)
				if raider:                                   # arqueiros da leva se espalham: cada um recua para um lado
					away = (away + away.orthogonal() * (0.6 if e.id % 2 == 0 else -0.6)).normalized()
				cmd.move = away
		else:
			cmd.move = _steer(e, sim, target.position, dt)     # contorna árvore/muro/água em vez de empurrar parado
		return cmd

	if raider:
		return _march(e, sim, cmd, dt)
	if leader:                         # escolta sem briga: a casa anda com o líder (vaga no anel em volta dele)
		return _follow_leader(e, sim, leader, cmd, dt)
	if not e.patrol_route.is_empty() and state != S.RETURN and not (mdef.is_boss and e.combat_timer <= 0.0 and (e.hp < e.stats.max_hp or e.phase > 0)):
		return _patrol(e, sim, cmd, dt)

	# chefe sem alvo e fora de combate volta para casa e reseta: só wipe de verdade, não quem atira de longe
	if mdef.is_boss and state != S.RETURN and e.combat_timer <= 0.0 and (e.hp < e.stats.max_hp or e.phase > 0):
		state = S.RETURN

	match state:
		S.RETURN:
			return_time += dt
			if return_time >= RETURN_LIMIT:
				e.position = e.home_position
			if e.position.distance_to(e.home_position) < 1.0:
				state = S.IDLE
				timer = 1.0
				return_time = 0.0
				e.threat.clear()
				e.damage_by.clear()
				if mdef.is_boss:
					sim.reset_boss(e)
				else:
					e.hp = minf(e.stats.max_hp, e.hp + e.stats.max_hp * 0.5)
			else:
				cmd.move = _dir_to(e, e.home_position)
				cmd.aim = e.home_position
		S.IDLE:
			if timer <= 0.0:
				state = S.WANDER
				wander_target = sim.random_walkable(def, e.home_position, 5.0)
				timer = 6.0
			cmd.aim = e.position + e.forward()
		S.WANDER:
			if timer <= 0.0 or e.position.distance_to(wander_target) < 0.6:
				state = S.IDLE
				timer = sim.rng.randf_range(1.5, 4.0)
			else:
				cmd.move = _dir_to(e, wander_target) * 0.5
				cmd.aim = wander_target
		_:
			state = S.IDLE
	return cmd

## Estilo de ataque atual: o próprio monstro, ou o monstro cuja arma ele pegou (MonsterDef.swap).
static func _style_def(e: SimEntity) -> MonsterDef:
	if e.stance != "" and not e.monster_def.swap.is_empty():
		var d: MonsterDef = GameData.monsters.get(str(e.monster_def.swap.get("as", "")))
		if d:
			return d
	return e.monster_def

## Nenhum outro invasor vivo a `r` m.
static func _alone(e: SimEntity, m: Dictionary, r: float) -> bool:
	for o in m["entities"]:
		if o != e and o.raid_id >= 0 and o.is_alive() and o.position.distance_to(e.position) < r:
			return false
	return true

## Alvo do invasor ("inteligência" da leva): entre quem está no alcance de aggro, prefere quem cura, quem está
## ferido e quem está isolado; reavalia a cada RAID_RETHINK s e segura o alvo atual com um bônus (não fica trocando).
func _raid_target(e: SimEntity, sim, m: Dictionary, cur: SimEntity, dt: float) -> SimEntity:
	skill_rethink -= dt
	if cur != null and skill_rethink > 0.0:
		return cur
	skill_rethink = RAID_RETHINK
	var chars: Array = m.get("chars", m["entities"])
	var best: SimEntity = null
	var best_s := -INF
	var aggro: float = e.monster_def.aggro_range
	for o in chars:
		if o == e or not o.is_alive() or not e.is_hostile_to(o) or o.stealth_left > 0.0:
			continue
		var d: float = o.position.distance_to(e.position) - o.radius
		if d > aggro and o != cur:
			continue
		var s: float = -d
		if o.stats and o.stats.max_hp > 0.0:
			s += (1.0 - o.hp / o.stats.max_hp) * 8.0      # ferido: termina o serviço
		if o.class_def and (o.class_def.id == "bishop" or o.build_id == "xama"):
			s += 6.0                                     # quem cura cai primeiro
		var isolated := _isolated(o, m)
		if isolated:
			s += 3.0
		if o == cur:
			s += 4.0
		if s > best_s:
			best_s = s
			best = o
	if best:
		e.aggro_target = best.id
		e.aggro_timer = Balance.AGGRO_LOSE_TIME
	elif cur == null:
		e.aggro_target = -1
	return best if best else cur

## Ninguém amigo a menos de 5 m (só nas células vizinhas da grade de separação: era um laço em todos os personagens por candidato).
static func _isolated(o: SimEntity, m: Dictionary) -> bool:
	var grid: Dictionary = m.get("sep_grid", {})
	var cx := floori(o.position.x / 3.0)
	var cz := floori(o.position.z / 3.0)
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			var cell = grid.get(Vector2i(cx + dx, cz + dz))
			if cell == null:
				continue
			for f in cell:
				if f != o and f.kind != SimEntity.Kind.MONSTER and f.is_alive() and o.is_friend(f) and f.position.distance_to(o.position) < 5.0:
					return false
	return true

## Alvo da invocação, nesta ordem: quem bate no dono, quem o dono está atacando, quem bate na invocação,
## o monstro mais perto do dono. Nada longe do dono (coleira): dono se afastou, larga a briga e volta.
## Reescolhe a cada SUMMON_RETHINK s (lista de entidades do mapa inteiro).
func _summon_target(e: SimEntity, sim, m: Dictionary, owner: SimEntity, cur: SimEntity, dt: float) -> SimEntity:
	if owner.map_id != e.map_id or not owner.is_alive() or e.position.distance_to(owner.position) > Balance.SUMMON_LEASH:
		e.aggro_target = -1
		return null
	if cur and cur.position.distance_to(owner.position) > Balance.SUMMON_LEASH:
		cur = null
		e.aggro_target = -1
	skill_rethink -= dt
	if cur != null and skill_rethink > 0.0:
		return cur
	skill_rethink = Balance.SUMMON_RETHINK
	var best: SimEntity = null
	var best_s := -INF
	for o in m["entities"]:
		if o.kind != SimEntity.Kind.MONSTER or not o.is_alive() or o.stealth_left > 0.0 or not e.is_hostile_to(o):
			continue
		var d_owner: float = o.position.distance_to(owner.position)
		if d_owner > Balance.SUMMON_ASSIST_RANGE:
			continue
		var s: float = -d_owner - 0.5 * o.position.distance_to(e.position)
		if o.aggro_target == owner.id:
			s += 100.0                       # defende o dono
		elif o.threat.has(owner.id):
			s += 60.0                        # entra na briga do dono
		elif o.aggro_target == e.id:
			s += 40.0                        # revida
		if cur and o == cur:
			s += 8.0                         # não fica trocando à toa
		if s > best_s:
			best_s = s
			best = o
	if best:
		e.aggro_target = best.id
		e.aggro_timer = Balance.AGGRO_LOSE_TIME
	else:
		e.aggro_target = -1
	return best

## Escolta: vai para a vaga dela em volta do líder; longe, corre; perto, acompanha o passo dele.
func _follow_leader(e: SimEntity, sim, leader: SimEntity, cmd: InputCommand, dt: float) -> InputCommand:
	state = S.IDLE
	var es: Dictionary = leader.monster_def.escort
	var slot: Vector3 = leader.position + MobSystem.escort_offset(e.escort_slot, int(es.get("count", 1)))
	e.home_position = slot
	var d := e.position.distance_to(slot)
	if d > 0.8:
		cmd.move = _steer(e, sim, slot, dt) * (1.0 if d > 4.0 else clampf(d / 3.0, 0.35, 1.0))
		cmd.aim = e.position + Vector3(cmd.move.x, 0.0, cmd.move.y)
	else:
		cmd.aim = e.position + leader.forward()
	return cmd

## Ronda do líder (spawner com `route`): anda devagar de ponto em ponto; a casa anda junto (a perseguição se mede de
## onde a briga começou, como na investida).
func _patrol(e: SimEntity, sim, cmd: InputCommand, dt: float) -> InputCommand:
	state = S.IDLE
	e.home_position = e.position
	var goal: Vector3 = e.patrol_route[e.patrol_i % e.patrol_route.size()]
	if e.position.distance_to(goal) < 1.5:
		e.patrol_i = (e.patrol_i + 1) % e.patrol_route.size()
		goal = e.patrol_route[e.patrol_i]
	cmd.move = _steer(e, sim, goal, dt) * Balance.PATROL_PACE
	cmd.aim = e.position + Vector3(cmd.move.x, 0.0, cmd.move.y)
	return cmd

## Investida sem alvo: segue a rota (ida ou recuo), desviando do rio pelas pontes e de obstáculos.
## A âncora da luta (home_position) anda junto: a perseguição se mede de onde a briga começou.
func _march(e: SimEntity, sim, cmd: InputCommand, dt: float) -> InputCommand:
	state = S.IDLE
	e.home_position = e.position
	var retreat: bool = RaidSystem.retreating(sim, e)
	if retreat != was_retreat or fought:
		was_retreat = retreat
		fought = false
		e.raid_leg = RaidSystem.nearest_leg(sim, e)
	var goal := RaidSystem.march_point(sim, e)
	if not retreat and RaidSystem.mustering(sim, e):
		cmd.aim = goal                      # trompas: a leva se junta na garganta antes de descer
		return cmd
	var last := e.raid_leg >= RaidSystem.march_len(sim, e) - 1
	if e.position.distance_to(goal) < (2.5 if not last else 1.5):
		if not last:
			e.raid_leg += 1
			goal = RaidSystem.march_point(sim, e)
		elif not retreat:
			# chegou ao povoado: ronda pela praça procurando briga
			var r: float = float(RaidSystem.route_def(sim.maps[e.map_id]["def"], e.raid_route).get("radius", 25.0)) * 0.6
			wander_target = sim.random_walkable(sim.maps[e.map_id]["def"], goal, r)
			cmd.move = _dir_to(e, wander_target) * 0.6
			cmd.aim = wander_target
			return cmd
	cmd.move = _steer(e, sim, goal, dt) * (Balance.RAID_MARCH_PACE if not retreat else 1.0)     # marcha cautelosa; na luta, velocidade cheia
	cmd.aim = e.position + Vector3(cmd.move.x, 0.0, cmd.move.y)
	return cmd

## Atirando e o alvo não perde vida há NO_HIT_LIMIT s (árvore/muro no caminho do tiro): CLOSE_IN_TIME s andando até ele.
func _shots_blocked(e: SimEntity, target: SimEntity, dt: float) -> bool:
	close_in -= dt
	if close_in > 0.0:
		return true
	var hp := target.hp + target.shield_hp
	if target.id != shot_target or hp < shot_hp - 0.01:
		no_hit = 0.0
	else:
		no_hit += dt
	shot_target = target.id
	shot_hp = hp
	if no_hit >= NO_HIT_LIMIT:
		no_hit = 0.0
		close_in = CLOSE_IN_TIME
		return true
	return false

func _steer(e: SimEntity, sim, p: Vector3, dt: float) -> Vector2:
	water_timer -= dt
	if water_timer <= 0.0 or water_goal.distance_to(p) > 3.0:
		water_timer = 1.5
		water_goal = p
		water_path = sim.water_path(e.map_id, e.position, p)
	while not water_path.is_empty() and Vector2(e.position.x, e.position.z).distance_to(water_path[0]) < 1.2:
		water_path.pop_front()
	if not water_path.is_empty():
		p = Vector3(water_path[0].x, 0.0, water_path[0].y)
	var v := _dir_to(e, p)
	if e.position.distance_to(last_pos) < 0.02 * (dt * 60.0):
		stuck += dt
	else:
		stuck = 0.0
	last_pos = e.position
	if stuck > 0.5 and detour_left <= 0.0:
		detour = v.rotated(PI * 0.5 * (1.0 if sim.rng.randf() < 0.5 else -1.0))
		detour_left = sim.rng.randf_range(0.8, 1.4)
		stuck = 0.0
	detour_left -= dt
	if detour_left > 0.0:
		return (v * 0.3 + detour).normalized()
	return v

static func _dir_to(e: SimEntity, p: Vector3) -> Vector2:
	var d := p - e.position
	var v := Vector2(d.x, d.z)
	return v.normalized() if v.length() > 0.05 else Vector2.ZERO
